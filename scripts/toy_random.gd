extends Node3D
# Toy prototype #1: "random defense" (WC3/SC custom-map style).
# Enemies loop around a track. Summon random units with gold, merge 3 identical units into a random higher tier,
# upgrade unit classes. Lose if too many enemies are alive at once or a boss survives its timer. Win at wave 20.
# Logic lives in step(dt) so tests can run it headless.

const SLOT_COLS := 6
const SLOT_ROWS := 4
const MAX_ALIVE := 70
const LAST_WAVE := 20
const WAVE_TIME := 25.0
const SPAWN_GAP := 0.55
const PER_WAVE := 20
const SUMMON_COST := 30
const TIER_NAMES := ["일반", "희귀", "영웅", "전설"]
const TIER_COLORS := [Color(0.85, 0.85, 0.85), Color(0.35, 0.65, 1.0), Color(0.75, 0.35, 1.0), Color(1.0, 0.75, 0.2)]
# type: [name, color, damage, interval, range, splash, slow, gold_on_kill, description]
const TYPES := {
	"archer": ["궁수", Color(0.35, 0.75, 0.35), 9.0, 0.45, 4.2, 0.0, 0.0, 0, "빠른 단일 공격. 무난한 딜러."],
	"mage": ["마법사", Color(0.55, 0.35, 0.95), 13.0, 1.1, 3.6, 1.3, 0.0, 0, "범위 마법. 몰려오는 적에 강함."],
	"frost": ["빙결사", Color(0.55, 0.85, 1.0), 5.0, 0.8, 3.8, 0.0, 0.45, 0, "공격한 적을 느리게 만든다."],
	"cannon": ["포병", Color(0.75, 0.45, 0.25), 34.0, 2.0, 5.2, 0.9, 0.0, 0, "느리지만 강한 범위 포격. 보스에 강함."],
	"thief": ["도적", Color(0.95, 0.85, 0.3), 7.0, 0.55, 3.4, 0.0, 0.0, 2, "적을 처치하면 골드를 더 번다."],
}
const TYPE_KEYS := ["archer", "mage", "frost", "cannon", "thief"]
const CORNERS := [Vector3(-8, 0, -5), Vector3(8, 0, -5), Vector3(8, 0, 5), Vector3(-8, 0, 5)]

var rng := RandomNumberGenerator.new()
var gold := 100
var wave := 0
var wave_t := 0.0
var to_spawn := 0
var spawn_t := 0.0
var boss_alive := false
var boss_timer := 0.0
var over := false
var won := false
var lose_reason := ""
var units: Array = []      # {type, tier, slot, cd, node}
var enemies: Array = []    # {hp, maxhp, d, speed, slow_t, boss, node, bar}
var shots: Array = []      # {node, from, to, t}
var floaters: Array = []   # {text, pos(Vector3), t, color}
var upgrades := {"archer": 0, "mage": 0, "frost": 0, "cannon": 0, "thief": 0}
var speed := 1
var selected := -1         # index into units
var msg := ""
var kills := 0
var headless := false

var cam: Camera3D
var hud: Control
var font: Font
var btns: Array = []
var hover_btn := -1
var perimeter := 0.0
var mats := {}
var t_acc := 0.0


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	rng.randomize()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Apple SD Gothic Neo", "NanumGothic", "WenQuanYi Zen Hei", "sans-serif"])
	sf.fallbacks = [ThemeDB.fallback_font]
	sf.multichannel_signed_distance_field = true
	font = sf
	for k in range(4):
		perimeter += CORNERS[k].distance_to(CORNERS[(k + 1) % 4])
	_setup_world()
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.draw.connect(_draw_hud)
	msg = "'소환'으로 유닛을 뽑으세요. 같은 유닛 3개 = 합성 (더 높은 등급의 랜덤 유닛)."


func _setup_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.7)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.7
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(25), 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 45
	cam.position = Vector3(4.2, 17, 13)
	add_child(cam)
	cam.look_at(Vector3(4.2, 0, 0.6), Vector3.UP)
	# ground, track, slots
	_box(Vector3(22, 0.4, 15), Vector3(0, -0.2, 0), _mat(Color(0.20, 0.32, 0.22)))
	for k in range(4):
		var a: Vector3 = CORNERS[k]; var b: Vector3 = CORNERS[(k + 1) % 4]
		var mid := (a + b) / 2.0
		var sz := Vector3(absf(b.x - a.x) + 1.4, 0.05, absf(b.z - a.z) + 1.4)
		_box(sz, mid + Vector3(0, 0.02, 0), _mat(Color(0.45, 0.38, 0.28)))
	for s in range(SLOT_COLS * SLOT_ROWS):
		var p := slot_pos(s)
		_box(Vector3(1.6, 0.12, 1.6), p + Vector3(0, 0.06, 0), _mat(Color(0.28, 0.42, 0.30)))
	# spawn portal
	var portal := MeshInstance3D.new()
	var tor := TorusMesh.new(); tor.inner_radius = 0.5; tor.outer_radius = 0.75
	portal.mesh = tor
	portal.material_override = _mat(Color(0.6, 0.1, 0.2), Color(1, 0.1, 0.3), 2.5)
	portal.position = CORNERS[0] + Vector3(0, 0.8, 0)
	portal.rotation = Vector3(PI / 2, 0, 0)
	add_child(portal)


func _mat(c: Color, emis: Color = Color.BLACK, e: float = 0.0) -> StandardMaterial3D:
	var key := "%s%s%.2f" % [c.to_html(), emis.to_html(), e]
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if e > 0:
		m.emission_enabled = true; m.emission = emis; m.emission_energy_multiplier = e
	mats[key] = m
	return m


func _box(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new(); b.size = size
	mi.mesh = b; mi.material_override = m; mi.position = pos
	add_child(mi)
	return mi


func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = m; mi.position = pos
	parent.add_child(mi)
	return mi


func slot_pos(s: int) -> Vector3:
	var c := s % SLOT_COLS
	var r := s / SLOT_COLS
	return Vector3(-5.0 + c * 2.0, 0, -3.0 + r * 2.0)


func path_pos(d: float) -> Vector3:
	d = fposmod(d, perimeter)
	for k in range(4):
		var a: Vector3 = CORNERS[k]; var b: Vector3 = CORNERS[(k + 1) % 4]
		var L := a.distance_to(b)
		if d <= L: return a.lerp(b, d / L)
		d -= L
	return CORNERS[0]


# ---------------- units ----------------
func free_slot() -> int:
	var used := {}
	for u in units: used[u["slot"]] = true
	for s in range(SLOT_COLS * SLOT_ROWS):
		if not used.has(s): return s
	return -1


func summon() -> bool:
	if over or gold < SUMMON_COST: return false
	var s := free_slot()
	if s < 0:
		msg = "자리가 꽉 찼습니다. 합성하거나 판매하세요."
		return false
	gold -= SUMMON_COST
	var t: String = TYPE_KEYS[rng.randi() % TYPE_KEYS.size()]
	_add_unit(t, 0, s)
	msg = "%s %s 소환!" % [TIER_NAMES[0], TYPES[t][0]]
	return true


func _add_unit(t: String, tier: int, s: int) -> void:
	var u := {"type": t, "tier": tier, "slot": s, "cd": 0.0, "node": null}
	u["node"] = _make_unit_node(t, tier)
	u["node"].position = slot_pos(s) + Vector3(0, 0.12, 0)
	units.append(u)


func _make_unit_node(t: String, tier: int) -> Node3D:
	var n := Node3D.new()
	var c: Color = TYPES[t][1]
	var sc := 1.0 + tier * 0.18
	var body := CylinderMesh.new(); body.top_radius = 0.22; body.bottom_radius = 0.32; body.height = 0.7; body.radial_segments = 8
	_part(n, body, _mat(c), Vector3(0, 0.35, 0))
	var head := SphereMesh.new(); head.radius = 0.2; head.height = 0.4
	_part(n, head, _mat(Color(0.95, 0.85, 0.75)), Vector3(0, 0.85, 0))
	var hat := CylinderMesh.new(); hat.top_radius = 0.0; hat.bottom_radius = 0.24; hat.height = 0.35; hat.radial_segments = 6
	_part(n, hat, _mat(c.darkened(0.3)), Vector3(0, 1.12, 0))
	var ring := TorusMesh.new(); ring.inner_radius = 0.42; ring.outer_radius = 0.52
	var tc: Color = TIER_COLORS[tier]
	_part(n, ring, _mat(tc, tc, 1.0 + tier * 1.2), Vector3(0, 0.03, 0))
	if tier >= 2:
		var l := OmniLight3D.new(); l.light_color = tc; l.omni_range = 2.0; l.light_energy = 0.8 + tier * 0.4; l.position = Vector3(0, 1.0, 0)
		n.add_child(l)
	n.scale = Vector3(sc, sc, sc)
	add_child(n)
	return n


func same_count(t: String, tier: int) -> int:
	var c := 0
	for u in units:
		if u["type"] == t and u["tier"] == tier: c += 1
	return c


func can_merge(i: int) -> bool:
	if i < 0 or i >= units.size(): return false
	var u: Dictionary = units[i]
	return u["tier"] < 3 and same_count(u["type"], u["tier"]) >= 3


func merge(i: int) -> bool:
	if not can_merge(i): return false
	var u: Dictionary = units[i]
	var t: String = u["type"]; var tier: int = u["tier"]; var s: int = u["slot"]
	var removed := 0
	# remove the selected one plus two others of the same kind
	var idx := [i]
	for k in range(units.size()):
		if k != i and units[k]["type"] == t and units[k]["tier"] == tier and idx.size() < 3: idx.append(k)
	idx.sort()
	idx.reverse()
	for k in idx:
		units[k]["node"].queue_free()
		units.remove_at(k)
		removed += 1
	var nt: String = TYPE_KEYS[rng.randi() % TYPE_KEYS.size()]
	_add_unit(nt, tier + 1, s)
	selected = units.size() - 1
	msg = "합성 성공! → %s %s" % [TIER_NAMES[tier + 1], TYPES[nt][0]]
	_float("합성!", slot_pos(s) + Vector3(0, 2, 0), TIER_COLORS[tier + 1])
	return true


func sell(i: int) -> void:
	if i < 0 or i >= units.size(): return
	var u: Dictionary = units[i]
	var refund := int(SUMMON_COST * pow(3, u["tier"]) * 0.5)
	gold += refund
	u["node"].queue_free()
	units.remove_at(i)
	selected = -1
	msg = "판매: +%d 골드" % refund


func upgrade_cost(t: String) -> int:
	return 40 + upgrades[t] * 30


func upgrade(t: String) -> bool:
	var c := upgrade_cost(t)
	if gold < c or over: return false
	gold -= c
	upgrades[t] += 1
	msg = "%s 공격력 강화 Lv%d (+15%%)" % [TYPES[t][0], upgrades[t]]
	return true


func unit_damage(u: Dictionary) -> float:
	return TYPES[u["type"]][2] * pow(3.2, u["tier"]) * (1.0 + 0.15 * upgrades[u["type"]])


# ---------------- enemies / waves ----------------
func start_wave() -> void:
	wave += 1
	wave_t = WAVE_TIME
	if wave % 10 == 0:
		_spawn_enemy(true)
		boss_alive = true
		boss_timer = WAVE_TIME * (2.4 if wave < LAST_WAVE else 3.2)
		to_spawn = 0
		msg = "보스 등장! %d초 안에 처치하세요." % int(boss_timer)
	else:
		to_spawn = PER_WAVE
		spawn_t = 0.0
		msg = "%d 웨이브 시작" % wave


func enemy_hp() -> float:
	return 28.0 * pow(1.21, wave - 1)


func _spawn_enemy(boss: bool) -> void:
	var hp := enemy_hp() * ((22.0 if wave < LAST_WAVE else 11.0) if boss else 1.0)
	var e := {"hp": hp, "maxhp": hp, "d": 0.0, "speed": (1.6 if boss else 2.4), "slow_t": 0.0, "boss": boss, "node": null, "bar": null}
	var n := Node3D.new()
	var sc := 1.8 if boss else 0.75 + 0.02 * wave
	var blob := SphereMesh.new(); blob.radius = 0.35; blob.height = 0.6
	_part(n, blob, _mat(Color(0.25, 0.08, 0.3) if not boss else Color(0.45, 0.05, 0.1)), Vector3(0, 0.3, 0))
	var eye := SphereMesh.new(); eye.radius = 0.06; eye.height = 0.12
	_part(n, eye, _mat(Color(1, 0.2, 0.2), Color(1, 0.1, 0.1), 3.0), Vector3(0.12, 0.42, 0.28))
	_part(n, eye, _mat(Color(1, 0.2, 0.2), Color(1, 0.1, 0.1), 3.0), Vector3(-0.12, 0.42, 0.28))
	n.scale = Vector3(sc, sc, sc)
	add_child(n)
	e["node"] = n
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.8, 0.08, 0.08)
	bar.mesh = bm
	bar.material_override = _mat(Color(0.3, 1, 0.3), Color(0.2, 1, 0.2), 1.0)
	n.add_child(bar)
	bar.position = Vector3(0, 0.95, 0)
	e["bar"] = bar
	enemies.append(e)


func _float(text: String, pos: Vector3, c: Color) -> void:
	floaters.append({"text": text, "pos": pos, "t": 1.0, "color": c})


# ---------------- simulation step ----------------
func step(dt: float) -> void:
	if over: return
	# waves
	if wave == 0:
		start_wave()
	wave_t -= dt
	if to_spawn > 0:
		spawn_t -= dt
		if spawn_t <= 0:
			_spawn_enemy(false); to_spawn -= 1; spawn_t = SPAWN_GAP
	if wave_t <= 0 and wave < LAST_WAVE:
		gold += 15 + wave * 2
		start_wave()
	if boss_alive:
		boss_timer -= dt
		if boss_timer <= 0:
			over = true; lose_reason = "보스를 시간 안에 처치하지 못했습니다."; msg = "패배: " + lose_reason
			return
	# enemies move
	for e in enemies:
		var sp: float = e["speed"] * (0.55 if e["slow_t"] > 0 else 1.0)
		e["slow_t"] = maxf(0.0, e["slow_t"] - dt)
		e["d"] += sp * dt
		e["node"].position = path_pos(e["d"])
		var ratio: float = clampf(e["hp"] / e["maxhp"], 0, 1)
		e["bar"].scale = Vector3(ratio, 1, 1)
	if enemies.size() > MAX_ALIVE:
		over = true; lose_reason = "적이 %d마리를 넘었습니다." % MAX_ALIVE; msg = "패배: " + lose_reason
		return
	# units attack
	for u in units:
		u["cd"] -= dt
		if u["cd"] > 0: continue
		var T: Array = TYPES[u["type"]]
		var up: Vector3 = slot_pos(u["slot"])
		var best := -1
		var bestd := -1.0
		for k in range(enemies.size()):
			var ep: Vector3 = enemies[k]["node"].position
			if Vector2(ep.x - up.x, ep.z - up.z).length() <= T[4] and enemies[k]["d"] > bestd:
				bestd = enemies[k]["d"]; best = k
		if best < 0: continue
		u["cd"] = T[3]
		var tgt: Dictionary = enemies[best]
		var dmg := unit_damage(u)
		var tp: Vector3 = tgt["node"].position
		if T[5] > 0.0:
			for e2 in enemies:
				if e2["node"].position.distance_to(tp) <= T[5]: e2["hp"] -= dmg
		else:
			tgt["hp"] -= dmg
		if T[6] > 0.0: tgt["slow_t"] = 1.5
		_shot(up + Vector3(0, 1.0, 0), tp + Vector3(0, 0.4, 0), T[1])
		u["node"].rotation.y = atan2(tp.x - up.x, tp.z - up.z)
		if T[7] > 0: u["_thief"] = true
	# deaths
	for k in range(enemies.size() - 1, -1, -1):
		var e3: Dictionary = enemies[k]
		if e3["hp"] <= 0:
			var g := 40 if e3["boss"] else 3
			gold += g
			kills += 1
			_float("+%d" % g, e3["node"].position + Vector3(0, 1.2, 0), Color(1, 0.9, 0.3))
			if e3["boss"]:
				boss_alive = false; msg = "보스 처치! 보너스 +40 골드"
				if wave >= LAST_WAVE:
					over = true; won = true; msg = "승리! 최종 보스를 쓰러뜨렸습니다."
			e3["node"].queue_free()
			enemies.remove_at(k)
	# thieves earn gold per attack that lands near a dying enemy (simple: per attack)
	for u in units:
		if u.get("_thief", false):
			u["_thief"] = false
			if rng.randf() < 0.25 + 0.1 * u["tier"]: gold += TYPES["thief"][7]
	# shots & floaters
	for k in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[k]
		s["t"] += dt * 6.0
		s["node"].position = s["from"].lerp(s["to"], minf(1.0, s["t"]))
		if s["t"] >= 1.0:
			s["node"].queue_free(); shots.remove_at(k)
	for k in range(floaters.size() - 1, -1, -1):
		floaters[k]["t"] -= dt
		floaters[k]["pos"] += Vector3(0, dt * 1.2, 0)
		if floaters[k]["t"] <= 0: floaters.remove_at(k)


func _shot(a: Vector3, b: Vector3, c: Color) -> void:
	if headless or shots.size() > 80: return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.09; sm.height = 0.18
	mi.mesh = sm
	mi.material_override = _mat(c, c, 3.0)
	add_child(mi)
	mi.position = a
	shots.append({"node": mi, "from": a, "to": b, "t": 0.0})


func _process(delta: float) -> void:
	t_acc += delta
	if speed > 0:
		var n := speed
		for k in range(n): step(delta)
	for u in units:
		if u["tier"] == 3: u["node"].position.y = 0.12 + 0.08 * sin(t_acc * 3.0)
	hud.queue_redraw()


# ---------------- input ----------------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover_btn = _btn_at(_hud_pos(e.position))
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var hp := _hud_pos(e.position)
		var bi := _btn_at(hp)
		if bi >= 0:
			if btns[bi]["on"]: btns[bi]["cb"].call()
			return
		if hp.x > 430: return
		var o := cam.project_ray_origin(e.position)
		var d := cam.project_ray_normal(e.position)
		var p := o + d * ((0.3 - o.y) / d.y)
		selected = -1
		for k in range(units.size()):
			var sp := slot_pos(units[k]["slot"])
			if absf(p.x - sp.x) < 0.9 and absf(p.z - sp.z) < 0.9: selected = k
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_Q: summon()
			KEY_W: merge(selected)
			KEY_SPACE: speed = 0 if speed > 0 else 1
			KEY_1: speed = 1
			KEY_2: speed = 2
			KEY_3: speed = 3
			KEY_R: get_tree().reload_current_scene()
			KEY_M: get_tree().change_scene_to_file("res://scenes/main.tscn")


func _hud_pos(p: Vector2) -> Vector2:
	return hud.get_global_transform_with_canvas().affine_inverse() * p


# ---------------- HUD ----------------
func _btn(t: String, r: Rect2, cb: Callable, on: bool, act: bool = false, tip: String = "") -> void:
	btns.append({"r": r, "t": t, "cb": cb, "on": on, "act": act, "tip": tip})


func _btn_at(p: Vector2) -> int:
	for i in range(btns.size()):
		if btns[i]["r"].has_point(p): return i
	return -1


func _build_buttons() -> void:
	btns.clear()
	var x := 434.0
	var y := 70.0
	_btn("소환  (골드 %d)  [Q]" % SUMMON_COST, Rect2(x, y, 200, 24), summon, gold >= SUMMON_COST and not over, true, "랜덤 유닛 1개를 소환합니다 (5종 중 하나, 일반 등급).")
	y += 30
	var mtxt := "합성  [W]"
	if selected >= 0 and selected < units.size():
		mtxt = "합성: %s %s (%d/3)  [W]" % [TIER_NAMES[units[selected]["tier"]], TYPES[units[selected]["type"]][0], same_count(units[selected]["type"], units[selected]["tier"])]
	_btn(mtxt, Rect2(x, y, 200, 20), func(): merge(selected), can_merge(selected), false, "같은 종류·같은 등급 유닛 3개 → 한 단계 높은 등급의 랜덤 유닛 1개.\n먼저 유닛을 클릭해 선택하세요.")
	y += 24
	_btn("판매 (선택 유닛)", Rect2(x, y, 200, 16), func(): sell(selected), selected >= 0 and selected < units.size(), false, "선택한 유닛을 팔아 골드를 일부 돌려받습니다.")
	y += 24
	for t in TYPE_KEYS:
		var T: Array = TYPES[t]
		_btn("%s 강화 Lv%d  (%d골드)" % [T[0], upgrades[t], upgrade_cost(t)], Rect2(x, y, 200, 16), upgrade.bind(t), gold >= upgrade_cost(t) and not over, false, "%s: %s\n강화할 때마다 이 종류 모든 유닛 공격력 +15%%." % [T[0], T[8]])
		y += 18
	y += 6
	for s in range(4):
		var lab: String = ["일시정지", "1배속", "2배속", "3배속"][s]
		_btn(lab, Rect2(x + s * 50, y, 48, 16), func(): speed = s, true, speed == s)
	y += 22
	_btn("다시 시작 (R)", Rect2(x, y, 98, 16), func(): get_tree().reload_current_scene(), true)
	_btn("메뉴 (M)", Rect2(x + 102, y, 98, 16), func(): get_tree().change_scene_to_file("res://scenes/main.tscn"), true)


func _draw_hud() -> void:
	_build_buttons()
	var c := hud
	c.draw_rect(Rect2(430, 0, 210, 360), Color(0.03, 0.04, 0.08, 0.85))
	c.draw_string(font, Vector2(434, 18), "웨이브 %d / %d" % [wave, LAST_WAVE], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
	c.draw_string(font, Vector2(434, 36), "골드 %d" % gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.3))
	var danger := float(enemies.size()) / MAX_ALIVE
	c.draw_string(font, Vector2(434, 54), "적 %d / %d" % [enemies.size(), MAX_ALIVE], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1 - danger, 1 - danger))
	c.draw_rect(Rect2(530, 46, 100, 8), Color(0.2, 0.2, 0.25))
	c.draw_rect(Rect2(530, 46, 100 * minf(1, danger), 8), Color(1, 0.3, 0.2))
	c.draw_string(font, Vector2(530, 30), "다음 웨이브 %.0f초" % maxf(0, wave_t), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.9))
	if boss_alive:
		c.draw_string(font, Vector2(8, 20), "보스 제한시간 %.0f초" % boss_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.3, 0.3))
	for i in range(btns.size()):
		var b: Dictionary = btns[i]
		var r: Rect2 = b["r"]
		var bg := Color(0.20, 0.24, 0.34)
		if not b["on"]: bg = Color(0.11, 0.12, 0.16)
		elif b["act"]: bg = Color(0.55, 0.42, 0.12)
		if i == hover_btn and b["on"]: bg = bg.lightened(0.15)
		c.draw_rect(r, bg)
		c.draw_rect(r, Color(0.5, 0.55, 0.7) if b["on"] else Color(0.25, 0.26, 0.32), false, 1.0)
		c.draw_string(font, r.position + Vector2(5, r.size.y / 2 + 4), b["t"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 10, Color(1, 1, 1) if b["on"] else Color(0.45, 0.45, 0.5))
	# unit list summary
	var y := 300.0
	var counts := {}
	for u in units:
		var k: String = "%s %s" % [TIER_NAMES[u["tier"]], TYPES[u["type"]][0]]
		counts[k] = counts.get(k, 0) + 1
	var summary := "보유: "
	for k in counts: summary += "%s×%d  " % [k, counts[k]]
	c.draw_multiline_string(font, Vector2(434, y), summary, HORIZONTAL_ALIGNMENT_LEFT, 200, 9, 4, Color(0.85, 0.85, 0.95))
	# message
	c.draw_rect(Rect2(4, 334, 420, 22), Color(0.03, 0.04, 0.08, 0.8))
	c.draw_string(font, Vector2(10, 349), msg, HORIZONTAL_ALIGNMENT_LEFT, 410, 10, Color(1, 1, 1))
	# floating texts (projected)
	for f in floaters:
		if cam.is_position_behind(f["pos"]): continue
		var sp := cam.unproject_position(f["pos"])
		var lp := _hud_pos(sp)
		c.draw_string(font, lp, f["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(f["color"].r, f["color"].g, f["color"].b, f["t"]))
	# selection marker
	if selected >= 0 and selected < units.size():
		var spos := cam.unproject_position(slot_pos(units[selected]["slot"]) + Vector3(0, 1.9, 0))
		var lp2 := _hud_pos(spos)
		c.draw_colored_polygon(PackedVector2Array([lp2, lp2 + Vector2(-6, -9), lp2 + Vector2(6, -9)]), Color(1, 1, 0.3))
	if over:
		c.draw_rect(Rect2(60, 140, 320, 60), Color(0, 0, 0, 0.8))
		c.draw_string(font, Vector2(60, 168), "승리!" if won else "패배", HORIZONTAL_ALIGNMENT_CENTER, 320, 22, Color(1, 0.9, 0.4))
		c.draw_string(font, Vector2(60, 190), lose_reason if not won else "처치 %d마리" % kills, HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(1, 1, 1))
	# tooltip
	if hover_btn >= 0 and hover_btn < btns.size() and String(btns[hover_btn]["tip"]) != "":
		var tip: String = btns[hover_btn]["tip"]
		var sz := font.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, 196, 10)
		var r2: Rect2 = btns[hover_btn]["r"]
		var box := Rect2(r2.position.x - 216, clampf(r2.position.y, 4, 350 - sz.y), 210, sz.y + 14)
		c.draw_rect(box, Color(0.05, 0.06, 0.10, 0.97))
		c.draw_rect(box, Color(1, 0.85, 0.4), false, 1.2)
		c.draw_multiline_string(font, box.position + Vector2(7, 15), tip, HORIZONTAL_ALIGNMENT_LEFT, 196, 10, -1, Color(0.95, 0.95, 1))
