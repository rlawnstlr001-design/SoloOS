extends Node3D
# "도깨비 디펜스" (toy 2 → main prototype): random summon & merge defense with Korean folklore units.
#  A) pool building: every 2 waves pick 1 of 3 cards (add unit to summon pool / remove one / relic)
#  B) recipes (3 specific units -> named hero), neighbour synergy (same-kin neighbours) and kin-count synergy (2/4/6)
#  C) MP skills: 영웅 등급 이상 units charge MP and cast a lore skill (auto, or manual per unit)
#  D) 50 waves in 5 acts; each run rolls 4 yokai per act (traits: armor, spirit, split, stealth...) and a boss
#  E) difficulty (보통/어려움/지옥), board expansion with gold, and a saved village profile: 엽전 earned per run buys
#     decorations placed around the stage (small buffs), permanent unit unlocks and extra starting cells
#  F) 2-player co-op over direct IP (net.gd): each player defends their own stage, waves start together,
#     the partner's stage is mirrored next to yours, one stage falling ends the run for both
# Merges roll a random unit FROM YOUR POOL, so curating the pool is the strategy.
# Logic is in step(dt); tests drive it headless. Content tables: toy2_data.gd. Models/effects: toy2_art.gd.

const Art := preload("res://scripts/toy2_art.gd")
const NetScript := preload("res://scripts/net.gd")
const D := preload("res://scripts/toy2_data.gd")
const KINS = D.KINS
const UNITS = D.UNITS
const BASE_KEYS = D.BASE_KEYS
const HERO_KEYS = D.HERO_KEYS
const RELICS = D.RELICS
const ENEMIES = D.ENEMIES
const ACTS = D.ACTS
const COLS := 8
const ROWS := 5
const PROFILE_PATH := "user://dokkaebi_profile.json"
const WAVES_PER_ACT := 10
const LAST_WAVE := 50
const WAVE_TIME := 25.0
const SPAWN_GAP := 0.55
const MP_MAX := 100.0
const TIER_NAMES := ["일반", "희귀", "영웅", "전설"]
const TIER_COLORS := [Color(0.85, 0.85, 0.85), Color(0.35, 0.65, 1.0), Color(0.75, 0.35, 1.0), Color(1.0, 0.75, 0.2)]
const CORNERS := [Vector3(-9, 0, -6), Vector3(9, 0, -6), Vector3(9, 0, 6), Vector3(-9, 0, 6)]
# board: 8x5 cells; 24 open at start (outer rows of the middle 6 columns), the rest bought with gold (무대 확장)
const START_SLOTS := [1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 25, 26, 27, 28, 29, 30, 33, 34, 35, 36, 37, 38]
const EXTRA_SLOTS := [8, 15, 24, 31, 16, 23, 0, 7, 32, 39, 18, 21, 17, 22, 19, 20]
const CAM_DIR := Vector3(0, 0.797, 0.603)
const PARTNER_OFS := Vector3(38, 0, 0)

var rng := RandomNumberGenerator.new()
var gold := 100
var wave := 0
var wave_t := 0.0
var to_spawn := 0
var spawn_t := 0.0
var spawn_list: Array = []
var spawn_i := 0
var boss_alive := false
var boss_timer := 0.0
var over := false
var won := false
var lose_reason := ""
var units: Array = []
var enemies: Array = []
var shots: Array = []
var floaters: Array = []
var upgrades := {}
var pool: Array = D.START_POOL.duplicate()
var relics: Array = []
var discovered: Array = []
var seen_enemies: Array = []
var choosing := false
var cards: Array = []
var speed := 1
var selected := -1
var msg := ""
var kills := 0
var casts := 0
var hp_growth := 1.175
var headless := false
var show_codex := false
var codex_tab := 0
var kin_count := {}
var manpa_done := false
var unlocked: Array = []
var bought_slots := 0
var sel_slot := -1
var cam_target := Vector3(3.6, 0, 0.9)
var cam_dist := 24.0
var drag_btn := 0
var started := false
var diff_key := "hard"
var max_alive := 70
var profile := {}
var meta_all := false
var no_save := false   # tests/screenshots: never touch the player's save file
var auto_start := true  # headless runs start solo on the first step unless a test turns this off
var deco_fx := {}
var act_roster: Array = []
var act_boss: Array = []
var bosses_killed := 0
var yeop_earned := -1
var bounty_t := 0.0
var bounty_g := 0
var blessing_n := 0
var prep_tab := 0
var deco_sel := ""
var spot_marks: Array = []
var deco_nodes := {}
# multiplayer
var net: Node = null
var mp := false
var waiting_next := false
var next_eid := 0
var partner_built := false
var partner_units := {}     # slot -> [type, tier, node]
var partner_enemies := {}   # id -> {node, segs, d0, d1, t0, boss}
var partner_snap_t := 0
var ip_edit: LineEdit = null

var art: Art
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
	for k in KINS: upgrades[k] = 0
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Apple SD Gothic Neo", "NanumGothic", "WenQuanYi Zen Hei", "sans-serif"])
	sf.fallbacks = [ThemeDB.fallback_font]
	sf.multichannel_signed_distance_field = true
	font = sf
	for k in range(4):
		perimeter += CORNERS[k].distance_to(CORNERS[(k + 1) % 4])
	art = Art.new(self, headless)
	_load_profile()
	set_difficulty(profile.get("diff", "hard"))
	_setup_world()
	_build_village()
	net = NetScript.get_net(get_tree())
	net.game = self
	if net.active() and not net.is_host:
		msg = "멀티: 방장이 시작하기를 기다리는 중입니다."
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.draw.connect(_draw_hud)
	if not headless:
		ip_edit = LineEdit.new()
		ip_edit.position = Vector2(434, 146)
		ip_edit.size = Vector2(140, 18)
		ip_edit.placeholder_text = "방장 IP (예: 192.168.0.5)"
		ip_edit.add_theme_font_override("font", font)
		ip_edit.add_theme_font_size_override("font_size", 10)
		ip_edit.visible = false
		ip_edit.text_submitted.connect(_join_typed)
		layer.add_child(ip_edit)
	msg = "준비: 난이도를 고르고 '판 시작'(Enter). 마을 꾸미기·해금은 엽전으로. 휠=줌, 우클릭 드래그=이동."


# ---------------- profile (meta) ----------------
func _load_profile() -> void:
	profile = {"yeop": 0, "decos": [], "placed": {}, "spots": D.DECO_START, "start_slots": 0, "units": [], "best": {}, "runs": 0, "diff": "hard"}
	meta_all = headless
	if headless or not FileAccess.file_exists(PROFILE_PATH): return
	var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if f == null: return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for k in data: profile[k] = data[k]


func _save_profile() -> void:
	if headless or no_save: return
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(profile, "  "))


func unit_unlocked(t: String) -> bool:
	return meta_all or not UNITS[t].get("lock", false) or profile["units"].has(t)


func set_difficulty(k: String) -> void:
	if not D.DIFFS.has(k) or started: return
	diff_key = k
	hp_growth = D.DIFFS[k]["growth"]
	max_alive = D.DIFFS[k]["alive"]
	profile["diff"] = k


func start_game() -> void:
	if started: return
	if net != null and net.active():
		if net.is_host: net.start_match(randi(), diff_key)
		else: msg = "방장이 판을 시작합니다."
		return
	_begin(-1)


func _begin(seed: int) -> void:
	started = true
	_save_profile()
	# acts: 4 yokai from each pool (pool order kept) + one boss. In co-op both peers use the shared seed.
	var arng := RandomNumberGenerator.new()
	if seed >= 0: arng.seed = seed
	else: arng.seed = rng.randi()
	act_roster.clear(); act_boss.clear()
	for A in ACTS:
		var pool_a: Array = A["pool"].duplicate()
		while pool_a.size() > 4: pool_a.remove_at(arng.randi() % pool_a.size())
		act_roster.append(pool_a)
		act_boss.append(A["bosses"][arng.randi() % A["bosses"].size()])
	# village decorations
	deco_fx = {"kin": {}}
	for sp in profile["placed"]:
		var dk: String = profile["placed"][sp]
		if not D.DECOS.has(dk): continue
		var fx: Dictionary = D.DECOS[dk]["fx"]
		for k in fx:
			if k == "kin":
				for kin in fx["kin"]: deco_fx["kin"][kin] = deco_fx["kin"].get(kin, 0.0) + fx["kin"][kin]
			else: deco_fx[k] = deco_fx.get(k, 0) + fx[k]
	gold += int(deco_fx.get("start_gold", 0))
	for k in range(int(profile["start_slots"])):
		if k < EXTRA_SLOTS.size():
			unlocked[EXTRA_SLOTS[k]] = true
			art.set_slot_locked(EXTRA_SLOTS[k], false)
	if deco_fx.get("start_relic", 0) > 0:
		var rk: Array = RELICS.keys()
		var r: String = rk[rng.randi() % rk.size()]
		relics.append(r)
		msg = "오방기: 유물 '%s'로 시작합니다." % RELICS[r][0]
	else:
		msg = "%s 난이도 시작! Q = 소환, 같은 유닛 3개 = 합성. 영웅 등급부터 MP 스킬 (F, T)." % D.DIFFS[diff_key]["n"]
	for m in spot_marks: m.visible = false
	deco_sel = ""
	if ip_edit != null: ip_edit.visible = false
	if mp:
		art.build_partner_stage(PARTNER_OFS, CORNERS, COLS * ROWS, slot_pos)
		partner_built = true
		msg = "협동 시작! 각자 자기 무대를 지킵니다. 한쪽이 무너지면 둘 다 패배. V = 동료 무대 보기, G = 골드 20 보내기."


func _end_run(win: bool, reason: String) -> void:
	if over: return
	if mp: net.send_result(win, reason)
	over = true
	won = win
	lose_reason = reason
	msg = ("승리! " if win else "패배: ") + reason
	var cleared := wave - (0 if win else 1)
	yeop_earned = int(round((cleared + bosses_killed * 5 + (20 if win else 0)) * D.DIFFS[diff_key]["yeop"]))
	profile["yeop"] = int(profile["yeop"]) + yeop_earned
	profile["runs"] = int(profile["runs"]) + 1
	var best: Dictionary = profile["best"]
	if wave > int(best.get(diff_key, 0)): best[diff_key] = wave
	_save_profile()


# ---------------- village (decorations, unlocks) ----------------
func _build_village() -> void:
	spot_marks = art.build_deco_spots(D.DECO_SPOTS)
	_refresh_village()


func _refresh_village() -> void:
	var nspots := int(profile["spots"])
	for i in range(spot_marks.size()):
		art.set_spot_state(spot_marks[i], i < nspots, profile["placed"].has(str(i)))
		spot_marks[i].visible = not started
	for k in deco_nodes.keys():
		deco_nodes[k].queue_free()
	deco_nodes.clear()
	for sp in profile["placed"]:
		var dk: String = profile["placed"][sp]
		if D.DECOS.has(dk): deco_nodes[sp] = art.make_deco(dk, D.DECO_SPOTS[int(sp)])


func deco_owned(k: String) -> bool:
	return profile["decos"].has(k)


func deco_placed_at(k: String) -> String:
	for sp in profile["placed"]:
		if profile["placed"][sp] == k: return sp
	return ""


func click_deco(k: String) -> void:
	if started: return
	if deco_owned(k):
		deco_sel = "" if deco_sel == k else k
		msg = ("'%s' 선택: 마을의 빈 자리(초록 고리)를 클릭해 놓으세요." % D.DECOS[k]["n"]) if deco_sel != "" else "선택 해제."
		return
	var c: int = D.DECOS[k]["cost"]
	if int(profile["yeop"]) < c:
		msg = "엽전이 부족합니다 (%d 필요). 판을 끝내면 엽전을 받습니다." % c
		return
	profile["yeop"] = int(profile["yeop"]) - c
	profile["decos"].append(k)
	deco_sel = k
	msg = "'%s' 구입! 마을의 빈 자리(초록 고리)를 클릭해 놓으세요." % D.DECOS[k]["n"]
	_save_profile()


func click_spot(i: int) -> void:
	var key := str(i)
	if i >= int(profile["spots"]):
		msg = "닫힌 자리입니다. '해금' 탭에서 꾸밈 자리를 늘리세요."
		return
	if deco_sel != "":
		var old := deco_placed_at(deco_sel)
		if old != "": profile["placed"].erase(old)
		profile["placed"][key] = deco_sel
		msg = "'%s'을(를) 놓았습니다. 다음 판부터 효과: %s" % [D.DECOS[deco_sel]["n"], D.DECOS[deco_sel]["d"]]
		deco_sel = ""
	elif profile["placed"].has(key):
		msg = "'%s'을(를) 치웠습니다 (보관함으로)." % D.DECOS[profile["placed"][key]]["n"]
		profile["placed"].erase(key)
	_save_profile()
	_refresh_village()


func meta_cost(kind: String) -> int:
	if kind == "start_slots": return 80 + 40 * int(profile["start_slots"])
	return 50 + 30 * (int(profile["spots"]) - D.DECO_START)


func buy_meta(kind: String) -> void:
	if started: return
	var c := meta_cost(kind)
	var cap := EXTRA_SLOTS.size() if kind == "start_slots" else D.DECO_SPOTS.size()
	var cur := int(profile[kind])
	if cur >= cap: return
	if int(profile["yeop"]) < c:
		msg = "엽전이 부족합니다 (%d 필요)." % c
		return
	profile["yeop"] = int(profile["yeop"]) - c
	profile[kind] = cur + 1
	msg = "시작 칸 +1 (다음 판부터)." if kind == "start_slots" else "꾸밈 자리 +1."
	_save_profile()
	_refresh_village()


func buy_unit(t: String) -> void:
	if started or unit_unlocked(t): return
	var c: int = UNITS[t]["price"]
	if int(profile["yeop"]) < c:
		msg = "엽전이 부족합니다 (%d 필요)." % c
		return
	profile["yeop"] = int(profile["yeop"]) - c
	profile["units"].append(t)
	msg = "'%s' 해금! 이제 보상 카드에 나옵니다." % UNITS[t]["n"]
	_save_profile()


# ---------------- multiplayer hooks (called by net.gd) ----------------
func net_set_difficulty(k: String) -> void:
	set_difficulty(k)


func net_start(seed: int, k: String) -> void:
	if started: return
	set_difficulty(k)
	mp = true
	_begin(seed)


func net_next_wave(w: int) -> void:
	if not mp or w != wave + 1: return
	waiting_next = false
	start_wave()


func _mp_wave_done() -> void:
	waiting_next = true
	msg = "웨이브 %d 끝 — 동료를 기다리는 중..." % wave
	net.wave_done(wave)


func set_speed(sp: int) -> void:
	if mp and not net.is_host:
		msg = "속도와 일시정지는 방장이 정합니다."
		return
	speed = sp
	if mp: net.send_speed(sp)


func on_partner_result(win: bool, reason: String) -> void:
	if not mp: return
	if not win and not over:
		_end_run(false, "동료의 무대가 무너졌습니다 (%s)" % reason)
	elif win:
		msg = "동료가 최종 보스를 물리쳤습니다!" if not over else ("협동 승리!" if won else msg)


func on_partner_left() -> void:
	if not mp: return
	mp = false
	msg = "동료와 연결이 끊겼습니다. 혼자 계속합니다."
	if waiting_next:
		waiting_next = false
		start_wave()


func on_gift(amount: int) -> void:
	gold += amount
	msg = "동료가 골드 %d을(를) 보냈습니다!" % amount
	_float("+%d 선물" % amount, Vector3(0, 2, 0), Color(1, 0.85, 0.3))


func send_gift() -> void:
	if not mp or over or gold < 20: return
	gold -= 20
	net.send_gold(20)
	msg = "동료에게 골드 20을 보냈습니다."


func make_snapshot() -> Dictionary:
	var us := []
	for u in units: us.append([u["slot"], u["type"], u["tier"]])
	var es := []
	for e in enemies: es.append([e["id"], e["key"], snappedf(e["d"], 0.01), snappedf(e["hp"] / e["maxhp"], 0.01), e["boss"]])
	return {"wave": wave, "gold": gold, "alive": enemies.size(), "units": us, "en": es, "over": over, "won": won, "cap": max_alive}


func on_partner_snap(data: Dictionary) -> void:
	if not partner_built or headless: return
	var now := Time.get_ticks_msec()
	# units
	var seen := {}
	for row in data.get("units", []):
		var sl: int = row[0]
		seen[sl] = true
		var cur = partner_units.get(sl)
		if cur == null or cur[0] != row[1] or cur[1] != row[2]:
			if cur != null: cur[2].queue_free()
			var nd := _make_unit_node(row[1], row[2])
			nd.position = slot_pos(sl) + PARTNER_OFS + Vector3(0, 0.12, 0)
			partner_units[sl] = [row[1], row[2], nd]
	for sl in partner_units.keys():
		if not seen.has(sl):
			partner_units[sl][2].queue_free()
			partner_units.erase(sl)
	# enemies
	var alive := {}
	for row in data.get("en", []):
		var id: int = row[0]
		alive[id] = true
		var pe = partner_enemies.get(id)
		if pe == null:
			var look := art.make_enemy(ENEMIES[row[1]]["look"], row[4])
			var nd2: Node3D = look["node"]
			var sc := 1.0 if row[4] else 0.75 + 0.01 * int(data.get("wave", 1))
			nd2.scale = Vector3.ONE * sc
			pe = {"node": nd2, "segs": look["segs"], "d0": row[2], "d1": row[2], "t0": now, "boss": row[4]}
			partner_enemies[id] = pe
		else:
			pe["d0"] = _partner_d(pe, now)
			pe["d1"] = row[2]
			pe["t0"] = now
	for id in partner_enemies.keys():
		if not alive.has(id):
			var pe2: Dictionary = partner_enemies[id]
			art.puff(pe2["node"].position, Color(0.6, 0.35, 0.8), 4, 0.14)
			pe2["node"].queue_free()
			for sg in pe2["segs"]: sg.queue_free()
			partner_enemies.erase(id)


func _partner_d(pe: Dictionary, now: int) -> float:
	var f := clampf(float(now - pe["t0"]) / (NetScript.SNAP_EVERY * 1000.0), 0.0, 1.0)
	return lerpf(pe["d0"], pe["d1"], f)


func _update_partner_visuals() -> void:
	var now := Time.get_ticks_msec()
	for id in partner_enemies:
		var pe: Dictionary = partner_enemies[id]
		var d := _partner_d(pe, now)
		var pos := path_pos(d) + PARTNER_OFS
		var nxt := path_pos(d + 0.3) + PARTNER_OFS
		pe["node"].position = pos
		if nxt.distance_to(pos) > 0.01: pe["node"].look_at(nxt, Vector3.UP, true)
		for k in range(pe["segs"].size()):
			pe["segs"][k].position = path_pos(d - 0.75 * (k + 1)) + PARTNER_OFS + Vector3(0, 0.55, 0)


func toggle_partner_view() -> void:
	if not mp: return
	if cam_target.x > PARTNER_OFS.x * 0.5: cam_target.x -= PARTNER_OFS.x
	else: cam_target.x += PARTNER_OFS.x
	_update_cam()


func _exit_tree() -> void:
	if net != null and net.game == self: net.game = null


func fx(k: String) -> float:
	return float(deco_fx.get(k, 0.0))


func cost() -> int:
	return 24 if relics.has("bangmang") else 30


# ---------------- world ----------------
func _setup_world() -> void:
	cam = Camera3D.new()
	cam.fov = 45
	add_child(cam)
	_update_cam()
	unlocked.clear()
	for s in range(COLS * ROWS): unlocked.append(START_SLOTS.has(s))
	var slots: Array = []
	for s in range(COLS * ROWS): slots.append(slot_pos(s))
	art.build_world(CORNERS, slots, unlocked)


func _update_cam() -> void:
	cam_dist = clampf(cam_dist, 9.0, 36.0)
	cam_target.x = clampf(cam_target.x, -12.0, 15.0 + (PARTNER_OFS.x if mp else 0.0))
	cam_target.z = clampf(cam_target.z, -9.0, 9.0)
	cam.position = cam_target + CAM_DIR * cam_dist
	cam.look_at(cam_target, Vector3.UP)


func zoom_cam(f: float) -> void:
	cam_dist *= f
	_update_cam()


func reset_cam() -> void:
	cam_target = Vector3(3.6, 0, 0.9)
	cam_dist = 24.0
	_update_cam()


# ---------------- board expansion ----------------
func slot_cost() -> int:
	return 60 + 40 * bought_slots


func unlock_slot(s: int) -> bool:
	if s < 0 or s >= unlocked.size() or unlocked[s] or over or gold < slot_cost(): return false
	gold -= slot_cost()
	bought_slots += 1
	unlocked[s] = true
	art.set_slot_locked(s, false)
	art.pillar(slot_pos(s), Color(0.6, 0.9, 0.6), false)
	msg = "무대 확장: 칸을 열었습니다. 다음 칸 %d골드." % slot_cost()
	sel_slot = -1
	return true


func open_slots() -> Array:
	var out := []
	for s in range(unlocked.size()):
		if unlocked[s]: out.append(s)
	return out


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


func slot_pos(s: int) -> Vector3:
	return Vector3(-7.0 + (s % COLS) * 2.0, 0, -4.0 + (s / COLS) * 2.0)


func path_pos(d: float) -> Vector3:
	d = fposmod(d, perimeter)
	for k in range(4):
		var a: Vector3 = CORNERS[k]; var b: Vector3 = CORNERS[(k + 1) % 4]
		var L := a.distance_to(b)
		if d <= L: return a.lerp(b, d / L)
		d -= L
	return CORNERS[0]


# ---------------- units & pool ----------------
func _make_unit_node(t: String, tier: int) -> Node3D:
	var U: Dictionary = UNITS[t]
	return art.make_unit(t, tier, KINS[U["kin"]][1], TIER_COLORS[tier], U.get("hero", false))


func unit_at(s: int) -> int:
	for i in range(units.size()):
		if units[i]["slot"] == s: return i
	return -1


func free_slot() -> int:
	for s in range(COLS * ROWS):
		if unlocked[s] and unit_at(s) < 0: return s
	return -1


func _add_unit(t: String, tier: int, s: int) -> void:
	var u := {"type": t, "tier": tier, "slot": s, "cd": 0.0, "node": _make_unit_node(t, tier), "atk": 0.0,
		"mp": 50.0 if UNITS[t].get("hero", false) else 0.0, "auto": true, "buff_t": 0.0, "buff_m": 1.0}
	u["rig"] = u["node"].get_node("rig")
	u["node"].position = slot_pos(s) + Vector3(0, 0.12, 0)
	u["face"] = 0.0
	art.pop(u["node"])
	units.append(u)
	_recount()


func _recount() -> void:
	kin_count.clear()
	for k in KINS: kin_count[k] = 0
	for u in units: kin_count[UNITS[u["type"]]["kin"]] += 1


func syn_level(kin: String) -> int:
	var n: int = kin_count.get(kin, 0)
	var lv := 0
	for th in D.SYN_STEPS:
		if n >= th: lv += 1
	return lv


func summon() -> bool:
	if over or choosing or gold < cost(): return false
	var s := free_slot()
	if s < 0:
		msg = "자리가 꽉 찼습니다. 합성하거나 판매하세요."
		return false
	gold -= cost()
	var t: String = pool[rng.randi() % pool.size()]
	var tier := 0
	if blessing_n > 0:
		blessing_n -= 1; tier = 1
	_add_unit(t, tier, s)
	art.puff(slot_pos(s), KINS[UNITS[t]["kin"]][1], 6, 0.15)
	msg = "%s 소환!" % UNITS[t]["n"]
	return true


func same_count(t: String, tier: int) -> int:
	var c := 0
	for u in units:
		if u["type"] == t and u["tier"] == tier: c += 1
	return c


func can_merge(i: int) -> bool:
	if i < 0 or i >= units.size(): return false
	var u: Dictionary = units[i]
	return u["tier"] < 3 and not UNITS[u["type"]].get("hero", false) and same_count(u["type"], u["tier"]) >= 3


func _remove_units(idx: Array) -> void:
	idx.sort(); idx.reverse()
	for k in idx:
		units[k]["node"].queue_free()
		units.remove_at(k)
	_recount()


func merge(i: int) -> bool:
	if not can_merge(i): return false
	var u: Dictionary = units[i]
	var t: String = u["type"]; var tier: int = u["tier"]; var s: int = u["slot"]
	var idx := [i]
	for k in range(units.size()):
		if k != i and units[k]["type"] == t and units[k]["tier"] == tier and idx.size() < 3: idx.append(k)
	_remove_units(idx)
	var nt: String = pool[rng.randi() % pool.size()]
	var ntier := tier + 1
	if relics.has("bok") and rng.randf() < 0.15: ntier = mini(3, tier + 2)
	_add_unit(nt, ntier, s)
	selected = units.size() - 1
	msg = "합성! → %s %s%s" % [TIER_NAMES[ntier], UNITS[nt]["n"], "  (복주머니 대박!)" if ntier == tier + 2 else ""]
	if ntier == 2: msg += "  MP 스킬 해금!"
	_float("합성!", slot_pos(s) + Vector3(0, 2, 0), TIER_COLORS[ntier])
	art.pillar(slot_pos(s), TIER_COLORS[ntier], false)
	return true


func recipe_for(i: int) -> String:
	# returns a hero key whose recipe can be completed with unit i plus other units (each ingredient tier >= 1)
	if i < 0 or i >= units.size(): return ""
	var t: String = units[i]["type"]
	if units[i]["tier"] < 1: return ""
	for h in HERO_KEYS:
		var rec: Array = UNITS[h]["rec"]
		if not rec.has(t): continue
		if _recipe_pick(i, rec).size() == 3: return h
	return ""


func _recipe_pick(i: int, rec: Array) -> Array:
	var need := rec.duplicate()
	var picked := [i]
	need.erase(units[i]["type"])
	for k in range(units.size()):
		if k == i or units[k]["tier"] < 1: continue
		if need.has(units[k]["type"]):
			need.erase(units[k]["type"]); picked.append(k)
		if need.is_empty(): break
	return picked if need.is_empty() else []


func craft(i: int) -> bool:
	var h := recipe_for(i)
	if h == "": return false
	var s: int = units[i]["slot"]
	_remove_units(_recipe_pick(i, UNITS[h]["rec"]))
	_add_unit(h, 3, s)
	selected = units.size() - 1
	if not discovered.has(h): discovered.append(h)
	msg = "레시피 완성! 전설 영웅 '%s' 등장!" % UNITS[h]["n"]
	_float(UNITS[h]["n"] + "!", slot_pos(s) + Vector3(0, 2.2, 0), Color(1, 0.8, 0.2))
	art.pillar(slot_pos(s), Color(1, 0.8, 0.25), true)
	return true


func sell(i: int) -> void:
	if i < 0 or i >= units.size(): return
	var refund := int(cost() * pow(3, units[i]["tier"]) * minf(1.0, (1.0 if relics.has("hwansaeng") else 0.5) + fx("refund")))
	gold += refund
	_remove_units([i])
	selected = -1
	msg = "판매: +%d 골드" % refund


func move_selected(s: int) -> void:
	if selected < 0 or selected >= units.size() or not unlocked[s]: return
	var other := unit_at(s)
	var from: int = units[selected]["slot"]
	if other >= 0: units[other]["slot"] = from
	units[selected]["slot"] = s
	for u in units: u["node"].position = slot_pos(u["slot"]) + Vector3(0, 0.12, 0)
	msg = "배치를 바꿨습니다. 같은 계열끼리 붙이면 시너지!"


func neighbours(s: int) -> Array:
	var out := []
	var c := s % COLS; var r := s / COLS
	if c > 0: out.append(s - 1)
	if c < COLS - 1: out.append(s + 1)
	if r > 0: out.append(s - COLS)
	if r < ROWS - 1: out.append(s + COLS)
	return out


func synergy(i: int) -> int:
	var kin: String = UNITS[units[i]["type"]]["kin"]
	var n := 0
	for s in neighbours(units[i]["slot"]):
		var j := unit_at(s)
		if j >= 0 and UNITS[units[j]["type"]]["kin"] == kin: n += 1
	return mini(n, 3)


func upgrade_cost(kin: String) -> int:
	return 40 + upgrades[kin] * 30


func upgrade(kin: String) -> bool:
	if gold < upgrade_cost(kin) or over: return false
	gold -= upgrade_cost(kin)
	upgrades[kin] += 1
	msg = "%s 계열 강화 Lv%d (공격력·스킬 +20%%)" % [KINS[kin][0], upgrades[kin]]
	return true


func unit_damage(i: int) -> float:
	var u: Dictionary = units[i]
	var U: Dictionary = UNITS[u["type"]]
	var kin: String = U["kin"]
	var dmg: float = U["dmg"] * pow(3.2, u["tier"]) * (1.0 + 0.2 * upgrades[kin])
	dmg *= 1.0 + (0.20 if relics.has("bujeok") else 0.12) * synergy(i)
	if u["tier"] == 3 and relics.has("yeouiju"): dmg *= 1.25
	if kin == "dokkaebi" and syn_level("dokkaebi") >= 2: dmg *= 1.25
	if kin == "sugun" and syn_level("sugun") >= 3: dmg *= 1.25
	if relics.has("cheonbuin"): dmg *= 1.1
	dmg *= 1.0 + float(deco_fx.get("kin", {}).get(kin, 0.0))
	if U["sp"] == "militia":
		var n := 0
		for u2 in units:
			if u2["type"] == u["type"]: n += 1
		dmg *= 1.0 + 0.06 * n
	return dmg


func unit_range(i: int) -> float:
	var U: Dictionary = UNITS[units[i]["type"]]
	var r: float = U["rng"]
	if U["kin"] == "muin": r += 0.5 * syn_level("muin")
	return r + fx("range")


func unit_interval(i: int) -> float:
	var u: Dictionary = units[i]
	var U: Dictionary = UNITS[u["type"]]
	var iv: float = U["int"]
	if U["kin"] == "muin" and syn_level("muin") >= 2: iv /= 1.0 + 0.1 * (syn_level("muin") - 1)
	if u["buff_t"] > 0.0: iv /= u["buff_m"]
	if relics.has("cheonmado"): iv /= 1.1
	if u.get("plagued", false): iv *= 1.33
	return iv


func unit_splash(i: int) -> float:
	var U: Dictionary = UNITS[units[i]["type"]]
	var r: float = U["spl"]
	if r <= 0.0: return 0.0
	if relics.has("bigyeok"): r += 0.4
	if U["kin"] == "sugun": r += [0.0, 0.3, 0.3, 0.6][syn_level("sugun")]
	return r


func unit_targets(i: int) -> int:
	var sp: String = UNITS[units[i]["type"]]["sp"]
	var n := 2 if sp == "multi" else (3 if sp == "pierce" else 1)
	if n > 1 and relics.has("chiljido"): n += 1
	return n


func skill_mult(i: int) -> float:
	if UNITS[units[i]["type"]]["kin"] != "sinseon": return 1.0
	return [1.0, 1.3, 1.6, 2.0][syn_level("sinseon")]


func mp_gain_mult(i: int) -> float:
	var kin: String = UNITS[units[i]["type"]]["kin"]
	if kin == "jusul" and syn_level("jusul") >= 3: return 1.5
	if kin == "sinseon": return [1.0, 1.0, 1.25, 1.5][syn_level("sinseon")]
	return 1.0


func has_skill(i: int) -> bool:
	if i < 0 or i >= units.size(): return false
	return units[i]["tier"] >= 2 and UNITS[units[i]["type"]].has("sk")


func boss_mult(U: Dictionary) -> float:
	var m := 1.0
	if U["sp"] == "boss": m *= 1.5
	if relics.has("haetae_stone"): m *= 1.3
	m *= [1.0, 1.25, 1.5, 1.9][syn_level("sinsu")]
	return m * (1.0 + fx("boss_dmg"))


# ---------------- damage & traits ----------------
func _hit(e: Dictionary, dd: float, U: Dictionary) -> void:
	var tr: Array = e["tr"]
	var holy: bool = U["sp"] == "holy"
	var sealed: bool = e["dispel_t"] > 0.0
	if e["boss"]: dd *= boss_mult(U)
	if tr.has("spirit") and not holy and not relics.has("cheoyong_face") and (U["kin"] == "muin" or U["kin"] == "dokkaebi"): dd *= 0.4
	if U["sp"] == "exorcist" and (tr.has("spirit") or tr.has("plague")): dd *= 2.0
	if tr.has("ironeater"):
		if U["kin"] == "muin" or U["kin"] == "sugun": dd *= 0.25
		if U.get("fire", false): dd *= 1.5
	if e["shielded"] and not sealed: dd *= 0.6
	var armor: float = e["armor"]
	if sealed or holy: armor = 0.0
	elif U["kin"] == "sugun" and syn_level("sugun") >= 2: armor *= 0.5
	if armor > 0.0: dd = maxf(dd * 0.25, dd - armor)
	e["hp"] -= dd
	e["hit"] = 0.12


func targetable(e: Dictionary) -> bool:
	if e["hp"] <= 0.0: return false
	if e["tr"].has("stealth") and e["dispel_t"] <= 0.0 and fposmod(e["age"], 4.0) > 2.6: return false
	return true


func _slow(e: Dictionary, t: float) -> void:
	if e["tr"].has("slowimm"): return
	e["slow_t"] = maxf(e["slow_t"], t)


func exec_bonus() -> float:
	return (0.05 if syn_level("jusul") >= 2 else 0.0) + fx("exec")


# ---------------- MP skills ----------------
func cast(i: int) -> bool:
	if not has_skill(i) or units[i]["mp"] < MP_MAX or over or choosing: return false
	var u: Dictionary = units[i]
	var U: Dictionary = UNITS[u["type"]]
	var S: Dictionary = U["sk"]
	var up: Vector3 = slot_pos(u["slot"])
	var dmg := unit_damage(i) * skill_mult(i)
	var kc: Color = KINS[U["kin"]][1]
	var lv: float = 1.0 + (u["tier"] - 2) * 0.6
	var alive := []
	for e in enemies:
		if targetable(e): alive.append(e)
	var needs_target: bool = S["k"] in ["chain", "nuke", "boss", "exec", "dispel", "nova"]
	if needs_target and alive.is_empty(): return false
	match S["k"]:
		"gold":
			var g := int(S["g"] * lv)
			gold += g
			_float("+%d 뚝딱!" % g, up + Vector3(0, 2.2, 0), Color(1, 0.85, 0.2))
		"chain":
			var by: String = S.get("by", "d")
			alive.sort_custom(func(a, b): return a[by if by == "hp" else "d"] > b[by if by == "hp" else "d"])
			for k in range(mini(int(S["n_t"]), alive.size())):
				_hit(alive[k], dmg * S["m"], U)
				art.ring(alive[k]["node"].position, kc, 0.8)
		"nuke":
			var best: Dictionary = alive[0]
			for e in alive:
				if e["d"] > best["d"] and _flat(e["node"].position, up) <= unit_range(i) * 1.6: best = e
			var c: Vector3 = best["node"].position
			for e in alive:
				if e["node"].position.distance_to(c) <= S["r"]: _hit(e, dmg * S["m"], U)
			art.ring(c, kc, S["r"])
			art.pillar(c, kc, false)
		"boss":
			var tgt: Dictionary = alive[0]
			for e in alive:
				if e["hp"] > tgt["hp"]: tgt = e
			_hit(tgt, dmg * S["m"], U)
			if S.has("hold"): tgt["stun_t"] = maxf(tgt["stun_t"], S["hold"] * (0.5 if tgt["boss"] else 1.0))
			art.pillar(tgt["node"].position, kc, true)
		"exec":
			var thr: float = S["thr"] + exec_bonus()
			var n := 0
			for e in alive:
				if _flat(e["node"].position, up) > unit_range(i) * 1.6: continue
				if e["boss"]: _hit(e, dmg * 8.0, U)
				elif e["hp"] < e["maxhp"] * thr:
					e["hp"] = 0.0; n += 1
			art.ring(up, kc, unit_range(i) * 1.6)
		"push":
			for e in enemies:
				e["d"] = maxf(0.0, e["d"] - S["dist"] * (0.25 if e["boss"] else 1.0) * lv)
			art.ring(up, kc, 6.0)
		"stun":
			for e in enemies: e["stun_t"] = maxf(e["stun_t"], S["t"] * lv * (0.5 if e["boss"] else 1.0))
			art.ring(up, kc, 6.0)
		"slow":
			for e in enemies: _slow(e, S["t"] * lv)
			art.ring(up, kc, 6.0)
		"buff":
			for j in range(units.size()):
				var ds: Vector3 = slot_pos(units[j]["slot"]) - up
				if absf(ds.x) <= 2.1 and absf(ds.z) <= 2.1:
					units[j]["buff_t"] = S["t"]; units[j]["buff_m"] = S["m"]
			art.ring(up, kc, 3.0)
		"buff_self":
			u["buff_t"] = S["t"]; u["buff_m"] = S["m"]
			art.pillar(up, kc, false)
		"buff_all":
			for j in range(units.size()):
				units[j]["buff_t"] = S["t"]; units[j]["buff_m"] = S["m"]
			art.ring(up, kc, 8.0)
		"mp_all":
			for j in range(units.size()):
				if j != i: units[j]["mp"] = minf(MP_MAX, units[j]["mp"] + S["amt"])
			art.ring(up, kc, 8.0)
		"nova":
			for e in alive:
				if _flat(e["node"].position, up) <= unit_range(i) * 1.2: _hit(e, dmg * S["m"], U)
			art.ring(up, kc, unit_range(i) * 1.2)
		"dispel":
			for e in alive:
				if _flat(e["node"].position, up) <= unit_range(i) * 1.6:
					e["dispel_t"] = maxf(e["dispel_t"], S["t"])
					_hit(e, dmg * S["m"], U)
			art.ring(up, kc, unit_range(i) * 1.6)
		"bounty":
			bounty_t = S["t"]; bounty_g = int(S["g"] * lv)
			art.ring(up, Color(1, 0.85, 0.2), 4.0)
		"blessing":
			blessing_n += int(S["n_t"])
			art.pillar(up, kc, false)
		"mp":
			for j in range(units.size()):
				if j != i and _flat(slot_pos(units[j]["slot"]), up) <= 2.1: units[j]["mp"] = minf(MP_MAX, units[j]["mp"] + S["amt"])
			art.ring(up, kc, 3.0)
	u["mp"] = 0.0
	u["atk"] = 1.0
	casts += 1
	_float(S["n"] + "!", up + Vector3(0, 2.6, 0), kc.lightened(0.3))
	return true


func toggle_auto(i: int) -> void:
	if not has_skill(i): return
	units[i]["auto"] = not units[i]["auto"]
	msg = "%s 스킬: %s" % [UNITS[units[i]["type"]]["n"], "자동" if units[i]["auto"] else "수동 (MP가 차면 F로 시전)"]


# ---------------- cards (pool building) ----------------
func make_cards() -> void:
	cards.clear()
	var opts := []
	for t in BASE_KEYS:
		if not pool.has(t) and unit_unlocked(t): opts.append({"kind": "add", "key": t})
	if pool.size() > 3:
		for t in pool: opts.append({"kind": "remove", "key": t})
	for r in RELICS:
		if not relics.has(r): opts.append({"kind": "relic", "key": r})
	opts.shuffle()
	# prefer one of each kind when possible
	for kind in ["relic", "add", "remove"]:
		for o in opts:
			if o["kind"] == kind and not cards.has(o):
				cards.append(o); break
	for o in opts:
		if cards.size() >= 3: break
		if not cards.has(o): cards.append(o)
	while cards.size() > 3: cards.pop_back()
	choosing = true
	msg = "보상 선택: 카드 1장을 고르세요 (건너뛰면 +20골드)."


func card_text(c: Dictionary) -> Array:
	match c["kind"]:
		"add": return ["소환 풀에 추가", UNITS[c["key"]]["n"], "[%s] %s" % [KINS[UNITS[c["key"]]["kin"]][0], UNITS[c["key"]]["d"]]]
		"remove": return ["소환 풀에서 제거", UNITS[c["key"]]["n"], "이 유닛이 더 이상 소환·합성 결과로 나오지 않습니다. 원하는 유닛이 나올 확률이 올라갑니다."]
		_: return ["유물", RELICS[c["key"]][0], RELICS[c["key"]][1]]


func pick_card(k: int) -> void:
	if not choosing: return
	if k < 0 or k >= cards.size():
		gold += 20
		msg = "건너뜀: +20골드"
	else:
		var c: Dictionary = cards[k]
		match c["kind"]:
			"add": pool.append(c["key"]); msg = "%s이(가) 소환 풀에 들어왔습니다." % UNITS[c["key"]]["n"]
			"remove": pool.erase(c["key"]); msg = "%s을(를) 소환 풀에서 뺐습니다." % UNITS[c["key"]]["n"]
			"relic": relics.append(c["key"]); msg = "유물 획득: %s" % RELICS[c["key"]][0]
	choosing = false
	if mp: _mp_wave_done()
	else: start_wave()


# ---------------- waves ----------------
func act_of(w: int) -> int:
	return clampi((w - 1) / WAVES_PER_ACT, 0, ACTS.size() - 1)


func wave_roster(w: int) -> Array:
	# enemy keys of a normal wave: each act introduces its 4 yokai one by one, then mixes them
	var r: Array = act_roster[act_of(w)]
	match (w - 1) % WAVES_PER_ACT:
		0, 1: return [r[0]]
		2: return [r[1]]
		3: return [r[0], r[1]]
		4: return [r[2]]
		5: return [r[1], r[2]]
		6: return [r[3]]
		7: return [r[2], r[3]]
		_: return r.duplicate()


func is_boss_wave(w: int) -> bool:
	return w % WAVES_PER_ACT == 0


func per_wave(w: int) -> int:
	return 20 + 2 * act_of(w) + int(D.DIFFS[diff_key]["count"])


func start_wave() -> void:
	wave += 1
	wave_t = WAVE_TIME
	manpa_done = false
	if is_boss_wave(wave):
		var bk: String = act_boss[act_of(wave)]
		_spawn_enemy(bk, false, 0.0)
		boss_alive = true
		boss_timer = WAVE_TIME * (2.4 if wave < LAST_WAVE else 3.2)
		to_spawn = 0
		msg = "%s 등장! %d초 안에 처치하세요." % [ENEMIES[bk]["n"], int(boss_timer)]
	else:
		spawn_list = wave_roster(wave)
		spawn_i = 0
		to_spawn = per_wave(wave)
		spawn_t = 0.0
		if (wave - 1) % WAVES_PER_ACT == 0: msg = ACTS[act_of(wave)]["n"] + " — 새로운 요괴가 몰려옵니다."


func enemy_hp() -> float:
	return 28.0 * pow(hp_growth, wave - 1)


func _spawn_enemy(key: String, child: bool, at_d: float) -> void:
	var E: Dictionary = ENEMIES[key]
	var boss: bool = E.get("boss", false)
	var hp: float = enemy_hp() * E["hp"] * (0.3 if child else 1.0) * (D.DIFFS[diff_key]["boss"] if boss else 1.0)
	var tr: Array = E["tr"]
	var e := {"key": key, "hp": hp, "maxhp": hp, "d": at_d, "speed": (1.6 if boss else 2.4) * E["spd"] * (0.88 if relics.has("jangseung") else 1.0) * (1.0 + fx("espeed")),
		"slow_t": 0.0, "stun_t": 0.0, "boss": boss, "tr": tr, "armor": enemy_hp() * 0.12 * (1.0 if not boss else 3.0) if tr.has("armor") else 0.0,
		"age": rng.randf() * 4.0 if tr.has("stealth") else 0.0, "child": child, "shielded": false, "summon_t": 6.0,
		"dispel_t": 0.0, "lap": 0, "hex_t": 3.0 + rng.randf() * 3.0, "revived": false, "node": null, "bar": null, "segs": [], "hit": 0.0}
	if boss and relics.has("jeokpae"): e["hp"] = hp * 0.85
	if not seen_enemies.has(key): seen_enemies.append(key)
	e["id"] = next_eid
	next_eid += 1
	var look := art.make_enemy(E["look"], boss)
	var n: Node3D = look["node"]
	e["segs"] = look["segs"]
	e["rig"] = look["rig"]
	e["flash"] = look["flash"]
	e["sc"] = 1.0 if boss else (0.75 + 0.01 * wave) * (0.7 if child else 1.0)
	n.scale = Vector3.ONE * e["sc"]
	n.position = path_pos(at_d)
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.8 if not boss else 1.8, 0.08, 0.08)
	bar.mesh = bm
	bar.material_override = _mat(Color(0.3, 1, 0.3), Color(0.2, 1, 0.2), 1.0)
	n.add_child(bar)
	bar.position = Vector3(0, 1.45 if not boss else 2.0, 0)
	e["node"] = n; e["bar"] = bar
	enemies.append(e)


func _float(text: String, pos: Vector3, c: Color) -> void:
	if floaters.size() > 60: floaters.remove_at(0)
	floaters.append({"text": text, "pos": pos, "t": 1.0, "color": c})


func _shot(a: Vector3, b: Vector3, c: Color, t: String, splash: float) -> void:
	if headless or shots.size() > 90: return
	var p := art.make_projectile(t, c)
	var mi: Node3D = p["node"]
	mi.position = a
	if not p["spin"] and a.distance_to(b) > 0.01: mi.look_at(b, Vector3.UP, true)
	shots.append({"node": mi, "from": a, "to": b, "t": 0.0, "spin": p["spin"], "color": c, "splash": splash})


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------- simulation step ----------------
func step(dt: float) -> void:
	if not started:
		if headless and auto_start and (net == null or net.peer == null): start_game()
		else: return
	if over or choosing: return
	if wave == 0: start_wave()
	bounty_t = maxf(0.0, bounty_t - dt)
	wave_t -= dt
	if to_spawn > 0:
		spawn_t -= dt
		if spawn_t <= 0:
			var sk: String = spawn_list[spawn_i % spawn_list.size()]
			_spawn_enemy(sk, false, 0.0)
			if ENEMIES[sk]["tr"].has("swarm"): _spawn_enemy(sk, false, 0.0)
			spawn_i += 1; to_spawn -= 1; spawn_t = SPAWN_GAP
	if wave_t <= 0 and wave < LAST_WAVE and not waiting_next and not (boss_alive and wave >= LAST_WAVE):
		gold += int((15 + wave * 2) * D.DIFFS[diff_key]["gold"]) + (12 if relics.has("yeopjeon") else 0) + int(fx("wave_gold"))
		if wave % 2 == 0:
			make_cards()
			return
		if mp: _mp_wave_done()
		else: start_wave()
	if relics.has("manpa") and not manpa_done and wave_t <= WAVE_TIME - 8.0:
		manpa_done = true
		for e in enemies: e["stun_t"] = maxf(e["stun_t"], 2.0)
		msg = "만파식적: 요괴들이 잠시 멈춘다."
	if boss_alive:
		boss_timer -= dt
		if boss_timer <= 0:
			_end_run(false, "보스를 시간 안에 처치하지 못했습니다.")
			return
	_enemies_step(dt)
	if enemies.size() > max_alive:
		_end_run(false, "요괴가 %d마리를 넘었습니다." % max_alive)
		return
	_units_step(dt)
	_deaths()
	for k in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[k]
		s["t"] += dt * 6.0
		s["node"].position = s["from"].lerp(s["to"], minf(1.0, s["t"]))
		if s["spin"]: s["node"].rotation.y += dt * 18.0
		if s["t"] >= 1.0:
			if s["splash"] > 0.0: art.ring(s["to"] - Vector3(0, 0.4, 0), s["color"], s["splash"])
			s["node"].queue_free(); shots.remove_at(k)
	for k in range(floaters.size() - 1, -1, -1):
		floaters[k]["t"] -= dt
		floaters[k]["pos"] += Vector3(0, dt * 1.2, 0)
		if floaters[k]["t"] <= 0: floaters.remove_at(k)


func _enemies_step(dt: float) -> void:
	var shields := []
	for e in enemies:
		e["shielded"] = false
		if e["tr"].has("shield"): shields.append(e)
	for sh in shields:
		if sh["dispel_t"] > 0.0: continue
		for e in enemies:
			if e["d"] > sh["d"] - 1.6 and e["d"] < sh["d"] + 1.6: e["shielded"] = true
	for e in enemies:
		e["age"] += dt
		var sp: float = e["speed"]
		if e["slow_t"] > 0: sp *= 0.55
		if e["stun_t"] > 0: sp = 0.0
		var bp: String = ENEMIES[e["key"]].get("bp", "")
		if e["boss"] and bp == "enrage" and e["hp"] < e["maxhp"] * 0.5: sp *= 1.6
		if e["tr"].has("flee") and e["hp"] < e["maxhp"] * 0.5: sp *= 1.8
		e["slow_t"] = maxf(0.0, e["slow_t"] - dt)
		e["stun_t"] = maxf(0.0, e["stun_t"] - dt)
		e["dispel_t"] = maxf(0.0, e["dispel_t"] - dt)
		if e["tr"].has("hex") and e["dispel_t"] <= 0.0:
			e["hex_t"] -= dt
			if e["hex_t"] <= 0.0:
				e["hex_t"] = 6.0
				var best := -1
				var bd := 3.0
				for j in range(units.size()):
					var dj := _flat(slot_pos(units[j]["slot"]), e["node"].position)
					if dj < bd: bd = dj; best = j
				if best >= 0:
					units[best]["cd"] = maxf(units[best]["cd"], 2.0)
					_float("빙의!", slot_pos(units[best]["slot"]) + Vector3(0, 2.0, 0), Color(0.8, 0.6, 1.0))
		if e["tr"].has("regen") and e["dispel_t"] <= 0.0: e["hp"] = minf(e["maxhp"], e["hp"] + e["maxhp"] * (0.006 if e["boss"] else 0.025) * dt)
		if e["boss"] and bp == "summon":
			e["summon_t"] -= dt
			if e["summon_t"] <= 0.0:
				e["summon_t"] = 7.0
				for k in range(3): _spawn_enemy(ENEMIES[e["key"]]["minion"], true, maxf(0.0, e["d"] - 0.5 - 0.4 * k))
		e["d"] += sp * dt
		if e["tr"].has("thief"):
			var lap := int(e["d"] / perimeter)
			if lap > e["lap"]:
				e["lap"] = lap
				var stolen := mini(gold, 3)
				gold -= stolen
				if stolen > 0: _float("-%d 도둑!" % stolen, e["node"].position + Vector3(0, 1.4, 0), Color(1, 0.4, 0.4))
		e["node"].position = path_pos(e["d"])
		var nxt := path_pos(e["d"] + 0.3)
		if nxt.distance_to(e["node"].position) > 0.01: e["node"].look_at(nxt, Vector3.UP, true)
		for k in range(e["segs"].size()):
			e["segs"][k].position = path_pos(e["d"] - 0.75 * (k + 1)) + Vector3(0, 0.55, 0)
		e["bar"].scale = Vector3(clampf(e["hp"] / e["maxhp"], 0, 1), 1, 1)


func _units_step(dt: float) -> void:
	var gold_x2 := syn_level("dokkaebi") >= 1
	var slow_t := 1.5 * (1.5 if syn_level("jusul") >= 1 else 1.0)
	var plague_at := []
	for e in enemies:
		if e["dispel_t"] > 0.0 or e["hp"] <= 0.0: continue
		if e["tr"].has("plague"): plague_at.append([e["node"].position, 2.5])
		if e["tr"].has("drought"): plague_at.append([e["node"].position, 4.5])
	for i in range(units.size()):
		var u: Dictionary = units[i]
		var U: Dictionary = UNITS[u["type"]]
		u["buff_t"] = maxf(0.0, u["buff_t"] - dt)
		var upos: Vector3 = slot_pos(u["slot"])
		u["plagued"] = false
		for pp in plague_at:
			if _flat(pp[0], upos) <= pp[1]:
				u["plagued"] = true
				if pp[1] > 3.0: u["buff_t"] = 0.0
				break
		var skill := has_skill(i)
		if skill:
			u["mp"] = minf(MP_MAX, u["mp"] + 3.0 * (2.0 if relics.has("angbu") else 1.0) * (1.0 + fx("mp_regen")) * dt)
			if u["mp"] >= MP_MAX and u["auto"]: cast(i)
		u["cd"] -= dt
		if u["cd"] > 0: continue
		var up: Vector3 = slot_pos(u["slot"])
		var rr := unit_range(i)
		var cands := []
		for k in range(enemies.size()):
			if targetable(enemies[k]) and _flat(enemies[k]["node"].position, up) <= rr: cands.append(k)
		if cands.is_empty(): continue
		cands.sort_custom(func(a, b): return enemies[a]["d"] > enemies[b]["d"])
		var ntarget := unit_targets(i)
		var spl := unit_splash(i)
		u["cd"] = unit_interval(i)
		if skill: u["mp"] = minf(MP_MAX, u["mp"] + 10.0 * mp_gain_mult(i))
		var dmg := unit_damage(i)
		if U["sp"] == "crit" and rng.randf() < 0.25: dmg *= 3.0
		var tp := Vector3.ZERO
		for ti in range(mini(ntarget, cands.size())):
			var tgt: Dictionary = enemies[cands[ti]]
			tp = tgt["node"].position
			var hit := []
			if spl > 0.0:
				for e2 in enemies:
					if e2["hp"] > 0.0 and e2["node"].position.distance_to(tp) <= spl: hit.append(e2)
			else:
				hit.append(tgt)
			for e3 in hit:
				_hit(e3, dmg, U)
				if U["slow"] > 0.0: _slow(e3, slow_t)
				if U["sp"] == "stun" and not e3["boss"]: e3["stun_t"] = maxf(e3["stun_t"], 0.4)
				if U["sp"] == "dispel": e3["dispel_t"] = maxf(e3["dispel_t"], 2.0)
				if not e3["boss"] and e3["hp"] > 0:
					var thr := 0.0
					if U["sp"] == "exec": thr = 0.15
					elif U["sp"] == "exec30": thr = 0.30
					if thr > 0.0 and e3["hp"] < e3["maxhp"] * (thr + exec_bonus()): e3["hp"] = 0
			_shot(up + Vector3(0, 1.0, 0), tp + Vector3(0, 0.4, 0), KINS[U["kin"]][1], u["type"], spl)
		if U["sp"] == "gold" and rng.randf() < (0.25 if U.get("hero", false) else 0.08) * (2.0 if gold_x2 else 1.0):
			gold += 1
			_float("+1 뚝딱", up + Vector3(0, 1.8, 0), Color(1, 0.85, 0.2))
		u["face"] = atan2(tp.x - up.x, tp.z - up.z)
		u["atk"] = 1.0


func _deaths() -> void:
	var kill_bonus := 1 if syn_level("dokkaebi") >= 3 else 0
	for k in range(enemies.size() - 1, -1, -1):
		var e4: Dictionary = enemies[k]
		if e4["hp"] > 0: continue
		if e4["tr"].has("revive") and not e4["revived"] and e4["dispel_t"] <= 0.0:
			e4["revived"] = true
			e4["hp"] = e4["maxhp"] * 0.5
			_float("부활!", e4["node"].position + Vector3(0, 1.6, 0), Color(0.6, 1.0, 0.6))
			continue
		var g: int = (40 if e4["boss"] else (1 if e4["child"] else 3)) + kill_bonus + (bounty_g if bounty_t > 0.0 else 0)
		if e4["boss"] and ENEMIES[e4["key"]].get("bp", "") == "goldpig": g += 100
		gold += g
		kills += 1
		_float("+%d" % g, e4["node"].position + Vector3(0, 1.2, 0), Color(1, 0.9, 0.3))
		art.puff(e4["node"].position, Color(0.6, 0.35, 0.8) if not e4["boss"] else Color(1, 0.8, 0.3), 7 if not e4["boss"] else 14, 0.18 if not e4["boss"] else 0.35)
		var d: float = e4["d"]
		var key: String = e4["key"]
		var split: bool = e4["tr"].has("split") and not e4["child"]
		var boss_split: bool = e4["boss"] and ENEMIES[key].get("bp", "") == "split"
		if e4["boss"]:
			boss_alive = false; msg = "%s 처치! +%d골드" % [ENEMIES[key]["n"], g]
			bosses_killed += 1
			for sgm in e4["segs"]: sgm.queue_free()
			if wave >= LAST_WAVE:
				_end_run(true, "최종 보스 %s 격퇴!" % ENEMIES[key]["n"])
		art.die(e4["node"])
		enemies.remove_at(k)
		if split:
			_spawn_enemy(key, true, maxf(0.0, d - 0.2))
			_spawn_enemy(key, true, maxf(0.0, d - 0.6))
		if boss_split:
			for j in range(3): _spawn_enemy(ENEMIES[key]["minion"], false, maxf(0.0, d - 0.4 * j))


func _process(delta: float) -> void:
	t_acc += delta
	for k in range(speed): step(delta)
	art.update(delta, t_acc)
	if partner_built: _update_partner_visuals()
	for u in units:
		if u["tier"] == 3: u["node"].position.y = 0.12 + 0.08 * sin(t_acc * 3.0)
		u["atk"] = maxf(0.0, u["atk"] - delta * 5.0)
		var rig: Node3D = u["rig"]
		var a := sin(u["atk"] * PI)
		rig.position = Vector3(0, 0.08, 0.22 * a)
		rig.scale = Vector3(1.0 + 0.1 * a, 1.0 - 0.12 * a + 0.035 * sin(t_acc * 2.4 + u["slot"]), 1.0 + 0.1 * a)
		u["node"].rotation.y = lerp_angle(u["node"].rotation.y, u["face"], minf(1.0, delta * 12.0))
	for e in enemies:
		e["hit"] = maxf(0.0, e["hit"] - delta)
		e["node"].scale = Vector3.ONE * e["sc"] * (1.0 + 1.6 * e["hit"])
		if e.has("flash"): e["flash"].visible = e["hit"] > 0.05
		e["rig"].visible = targetable(e) or e["hp"] <= 0.0
		if not e["boss"]: e["rig"].rotation.z = 0.15 * sin(t_acc * 9.0 + e["d"] * 2.0)
	hud.queue_redraw()


# ---------------- input ----------------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE):
		drag_btn = e.button_index if e.pressed else 0
		return
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if not show_codex: zoom_cam(0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1)
		return
	if e is InputEventMagnifyGesture:
		zoom_cam(1.0 / e.factor)
		return
	if e is InputEventPanGesture:
		cam_target += Vector3(e.delta.x, 0, e.delta.y) * cam_dist * 0.02
		_update_cam()
		return
	if e is InputEventMouseMotion:
		hover_btn = _btn_at(_hud_pos(e.position))
		if drag_btn == MOUSE_BUTTON_RIGHT:
			cam_target -= Vector3(e.relative.x, 0, e.relative.y) * cam_dist * 0.0022
			_update_cam()
		elif drag_btn == MOUSE_BUTTON_MIDDLE:
			zoom_cam(1.0 + e.relative.y * 0.006)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var hp := _hud_pos(e.position)
		var bi := _btn_at(hp)
		if bi >= 0:
			if btns[bi]["on"]: btns[bi]["cb"].call()
			return
		if show_codex:
			show_codex = false; return
		if choosing or hp.x > 430: return
		var o := cam.project_ray_origin(e.position)
		var d := cam.project_ray_normal(e.position)
		var p := o + d * ((0.3 - o.y) / d.y)
		if not started:
			for i in range(D.DECO_SPOTS.size()):
				if _flat(D.DECO_SPOTS[i], p) < 1.3:
					click_spot(i); return
			return
		var hit_slot := -1
		for s in range(COLS * ROWS):
			var sp := slot_pos(s)
			if absf(p.x - sp.x) < 0.9 and absf(p.z - sp.z) < 0.9: hit_slot = s
		if hit_slot < 0:
			selected = -1; sel_slot = -1; return
		if not unlocked[hit_slot]:
			selected = -1
			sel_slot = hit_slot
			msg = "닫힌 칸입니다. '칸 열기'(B)로 %d골드에 열 수 있습니다." % slot_cost()
			return
		sel_slot = -1
		var ui := unit_at(hit_slot)
		if ui >= 0 and ui != selected:
			selected = ui
		elif ui < 0 and selected >= 0:
			move_selected(hit_slot)
		else:
			selected = -1
	elif e is InputEventKey and e.pressed and not e.echo:
		if not started and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER):
			start_game(); return
		match e.keycode:
			KEY_Q: summon()
			KEY_W:
				if not merge(selected): craft(selected)
			KEY_E: craft(selected)
			KEY_F: cast(selected)
			KEY_B: unlock_slot(sel_slot)
			KEY_Z: reset_cam()
			KEY_EQUAL, KEY_KP_ADD: zoom_cam(0.9)
			KEY_MINUS, KEY_KP_SUBTRACT: zoom_cam(1.1)
			KEY_T: toggle_auto(selected)
			KEY_C: show_codex = not show_codex
			KEY_TAB: codex_tab = (codex_tab + 1) % 8
			KEY_SPACE: set_speed(0 if speed > 0 else 1)
			KEY_1: set_speed(1)
			KEY_2: set_speed(2)
			KEY_3: set_speed(3)
			KEY_V: toggle_partner_view()
			KEY_G: send_gift()
			KEY_R: restart()
			KEY_M: to_menu()


func restart() -> void:
	if mp and not over:
		msg = "협동 중에는 판이 끝난 뒤에 다시 시작할 수 있습니다."
		return
	get_tree().reload_current_scene()


func to_menu() -> void:
	if net != null: net.leave()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _hud_pos(p: Vector2) -> Vector2:
	return hud.get_global_transform_with_canvas().affine_inverse() * p


func _proj(p: Vector3) -> Vector2:
	return _hud_pos(cam.unproject_position(p))


# ---------------- HUD ----------------
func _btn(t: String, r: Rect2, cb: Callable, on: bool, act: bool = false, tip: String = "") -> void:
	btns.append({"r": r, "t": t, "cb": cb, "on": on, "act": act, "tip": tip})


func _btn_at(p: Vector2) -> int:
	for i in range(btns.size()):
		if btns[i]["r"].has_point(p): return i
	return -1


func _build_buttons() -> void:
	btns.clear()
	if choosing:
		for k in range(cards.size()):
			_btn("", Rect2(20 + k * 136, 110, 128, 150), pick_card.bind(k), true)
		_btn("건너뛰기 (+20골드)", Rect2(160, 270, 120, 18), pick_card.bind(-1), true)
		return
	if show_codex:
		var tabs := ["유닛 1", "유닛 2", "유닛 3", "영웅", "요괴 1", "요괴 2", "요괴 3", "시너지"]
		for k in range(tabs.size()):
			_btn(tabs[k], Rect2(14 + k * 51, 46, 48, 16), func(): codex_tab = k, true, codex_tab == k)
		return
	if not started:
		_build_prep_buttons()
		return
	var x := 434.0
	var y := 64.0
	_btn("소환  (골드 %d)  [Q]" % cost(), Rect2(x, y, 200, 22), summon, gold >= cost() and not over, true, "소환 풀에서 랜덤 유닛 1개 (일반 등급).\n현재 풀: " + _pool_text())
	y += 25
	var mt := "합성  [W]"
	var sel_ok := selected >= 0 and selected < units.size()
	if sel_ok:
		mt = "합성: %s %s (%d/3)  [W]" % [TIER_NAMES[units[selected]["tier"]], UNITS[units[selected]["type"]]["n"], same_count(units[selected]["type"], units[selected]["tier"])]
	_btn(mt, Rect2(x, y, 200, 17), func(): merge(selected), can_merge(selected), false, "같은 유닛·같은 등급 3개 → 한 등급 높은 유닛 1개.\n결과는 내 소환 풀에서 랜덤으로 나옵니다.\n영웅 등급부터 MP 스킬을 씁니다.")
	y += 20
	var h := recipe_for(selected)
	_btn(("레시피: %s  [E]" % UNITS[h]["n"]) if h != "" else "레시피 (조건 미충족)  [E]", Rect2(x, y, 200, 17), func(): craft(selected), h != "", h != "", "특정 3개 유닛(각각 희귀 이상)을 모으면 전설 영웅이 됩니다.\n레시피 목록은 도감(C)에서 확인.")
	y += 20
	_btn("판매 (선택 유닛)", Rect2(x, y, 98, 16), func(): sell(selected), sel_ok)
	_btn("도감 (C)", Rect2(x + 102, y, 98, 16), func(): show_codex = not show_codex, true, show_codex)
	y += 20
	var col := 0
	for kin in KINS:
		_btn("%s Lv%d (%d)" % [KINS[kin][0], upgrades[kin], upgrade_cost(kin)], Rect2(x + col * 102, y, 98, 15), upgrade.bind(kin), gold >= upgrade_cost(kin) and not over, false, "%s 계열 모든 유닛 공격력·스킬 피해 +20%%.\n뒤 막으로 갈수록 강화 없이는 버티기 어렵습니다." % KINS[kin][0])
		col += 1
		if col == 2:
			col = 0; y += 17
	if col == 1: y += 17
	y += 3
	for s in range(4):
		var lab: String = ["일시정지", "1배속", "2배속", "3배속"][s]
		_btn(lab, Rect2(x + s * 50, y, 48, 15), func(): set_speed(s), not mp or net.is_host, speed == s)
	y += 18
	_btn("다시 시작 (R)", Rect2(x, y, 98, 15), restart, not mp or over)
	_btn("메뉴 (M)", Rect2(x + 102, y, 98, 15), to_menu, true)
	if mp:
		y += 18
		_btn("동료 무대 보기 [V]", Rect2(x, y, 98, 15), toggle_partner_view, true)
		_btn("골드 20 보내기 [G]", Rect2(x + 102, y, 98, 15), send_gift, gold >= 20 and not over, false, "동료에게 골드 20을 보냅니다.")
	if sel_slot >= 0 and not unlocked[sel_slot]:
		_btn("칸 열기 (%d골드) [B]" % slot_cost(), Rect2(x + 4, 336, 192, 16), func(): unlock_slot(sel_slot), gold >= slot_cost() and not over, true, "무대 확장: 이 칸을 열어 유닛을 더 놓습니다.\n열 때마다 값이 40골드씩 오릅니다.")
	if sel_ok and has_skill(selected):
		var u: Dictionary = units[selected]
		_btn("스킬 시전 [F]", Rect2(x + 4, 336, 96, 16), func(): cast(selected), u["mp"] >= MP_MAX, u["mp"] >= MP_MAX)
		_btn("자동" if u["auto"] else "수동", Rect2(x + 104, 336, 92, 16), func(): toggle_auto(selected), true, u["auto"], "자동: MP가 차면 바로 시전.\n수동: MP를 모아 두었다가 원하는 때 F로 시전 (보스 등).\n단축키 T.")


func _build_prep_buttons() -> void:
	var x := 434.0
	var k := 0
	for dk in D.DIFF_KEYS:
		var Df: Dictionary = D.DIFFS[dk]
		_btn(Df["n"], Rect2(x + k * 68, 30, 64, 18), _pick_difficulty.bind(dk), not net.active() or net.is_host, diff_key == dk, Df["d"] + "\n엽전 보상 ×%.1f" % Df["yeop"])
		k += 1
	var client: bool = net.active() and not net.is_host
	var start_label := "방장이 시작합니다" if client else ("협동 시작  [Enter]" if net.active() else "판 시작  [Enter]")
	_btn(start_label, Rect2(x, 76, 200, 22), start_game, not client, true, "선택한 난이도로 50웨이브를 시작합니다.\n막마다 나오는 요괴와 보스는 판마다 바뀝니다.")
	_btn("마을 꾸미기", Rect2(x, 104, 64, 16), func(): prep_tab = 0, true, prep_tab == 0)
	_btn("해금", Rect2(x + 68, 104, 64, 16), func(): prep_tab = 1, true, prep_tab == 1)
	_btn("멀티", Rect2(x + 136, 104, 64, 16), func(): prep_tab = 2, true, prep_tab == 2, "친구와 IP로 접속해 각자 무대 협동.")
	if ip_edit != null: ip_edit.visible = prep_tab == 2 and not started
	var y := 124.0
	var yeop := int(profile["yeop"])
	if prep_tab == 2:
		_btn("방 만들기", Rect2(x, y, 98, 16), func(): net.host(), net.peer == null, net.is_host, "내가 방장이 됩니다. 친구에게 아래 IP를 알려 주세요.")
		_btn("나가기", Rect2(x + 102, y, 98, 16), func(): net.leave(), net.peer != null)
		_btn("접속", Rect2(x + 146, y + 22, 54, 18), _join_typed, net.peer == null, false, "입력한 IP의 방에 접속합니다.")
		return
	if prep_tab == 0:
		var col := 0
		for dk in D.DECO_KEYS:
			var De: Dictionary = D.DECOS[dk]
			var label: String = De["n"]
			if deco_placed_at(dk) != "": label += " ✓"
			elif deco_owned(dk): label += " (보관)"
			else: label += " %d" % De["cost"]
			_btn(label, Rect2(x + col * 102, y, 98, 15), click_deco.bind(dk), deco_owned(dk) or yeop >= De["cost"], deco_sel == dk, De["d"] + ("\n\n보유: 클릭 후 마을 빈 자리 클릭으로 배치." if deco_owned(dk) else "\n\n클릭하면 엽전 %d로 구입." % De["cost"]))
			col += 1
			if col == 2:
				col = 0; y += 17
	else:
		var ns := int(profile["start_slots"])
		_btn("시작 칸 +1 (지금 +%d) %d" % [ns, meta_cost("start_slots")], Rect2(x, y, 200, 15), buy_meta.bind("start_slots"), ns < EXTRA_SLOTS.size() and yeop >= meta_cost("start_slots"), false, "판을 시작할 때 열려 있는 칸이 하나 늘어납니다 (영구).")
		y += 17
		var nsp := int(profile["spots"])
		_btn("꾸밈 자리 +1 (%d/%d) %d" % [nsp, D.DECO_SPOTS.size(), meta_cost("spots")], Rect2(x, y, 200, 15), buy_meta.bind("spots"), nsp < D.DECO_SPOTS.size() and yeop >= meta_cost("spots"), false, "마을에 장식을 놓을 자리가 하나 늘어납니다.")
		y += 20
		var col2 := 0
		for t in BASE_KEYS:
			if not UNITS[t].get("lock", false): continue
			var U: Dictionary = UNITS[t]
			var have := unit_unlocked(t)
			_btn(("%s ✓" % U["n"]) if have else ("%s %d" % [U["n"], U["price"]]), Rect2(x + col2 * 102, y, 98, 15), buy_unit.bind(t), not have and yeop >= U["price"], have, "[%s] %s\n스킬 %s: %s" % [KINS[U["kin"]][0], U["d"], U["sk"]["n"], U["sk"]["d"]])
			col2 += 1
			if col2 == 2:
				col2 = 0; y += 17


func _pick_difficulty(k: String) -> void:
	set_difficulty(k)
	net.send_difficulty(k)


func _join_typed(_t: String = "") -> void:
	if ip_edit != null: net.join(ip_edit.text)


func _pool_text() -> String:
	var names := []
	for t in pool: names.append(UNITS[t]["n"])
	return ", ".join(names)


func _traits_text(key: String) -> String:
	var tr: Array = ENEMIES[key]["tr"]
	if tr.is_empty(): return ""
	var names := []
	for t in tr: names.append(D.TRAIT_NAMES[t])
	return "[" + "·".join(names) + "]"


func _wave_text(w: int) -> String:
	if w < 1 or w > LAST_WAVE: return ""
	if is_boss_wave(w):
		var bk: String = act_boss[act_of(w)]
		return "보스 %s %s" % [ENEMIES[bk]["n"], _traits_text(bk)]
	var parts := []
	for k in wave_roster(w):
		var s := "%s%s" % [ENEMIES[k]["n"], _traits_text(k)]
		if not parts.has(s): parts.append(s)
	return " · ".join(parts)


func _draw_btn(i: int) -> void:
	var b: Dictionary = btns[i]
	var r: Rect2 = b["r"]
	var bg := Color(0.20, 0.24, 0.34)
	if not b["on"]: bg = Color(0.11, 0.12, 0.16)
	elif b["act"]: bg = Color(0.55, 0.42, 0.12)
	if i == hover_btn and b["on"]: bg = bg.lightened(0.15)
	hud.draw_rect(r, bg)
	hud.draw_rect(r, Color(0.5, 0.55, 0.7) if b["on"] else Color(0.25, 0.26, 0.32), false, 1.0)
	hud.draw_string(font, r.position + Vector2(5, r.size.y / 2 + 4), b["t"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 10, Color(1, 1, 1) if b["on"] else Color(0.45, 0.45, 0.5))


func _draw_hud() -> void:
	_build_buttons()
	var c := hud
	# top-left: pool, relics, kin synergy
	c.draw_rect(Rect2(4, 4, 420, 46), Color(0.03, 0.04, 0.08, 0.75))
	c.draw_string(font, Vector2(10, 17), "[%s] 소환 풀: %s" % [D.DIFFS[diff_key]["n"], _pool_text()], HORIZONTAL_ALIGNMENT_LEFT, 410, 10, Color(0.95, 0.9, 0.75))
	var rn := []
	for r in relics: rn.append(RELICS[r][0])
	c.draw_string(font, Vector2(10, 30), "유물: " + (", ".join(rn) if not rn.is_empty() else "없음"), HORIZONTAL_ALIGNMENT_LEFT, 410, 9, Color(0.8, 0.85, 1.0))
	var sx := 10.0
	for kin in KINS:
		var lv := syn_level(kin)
		var kc: Color = KINS[kin][1]
		var txt := "%s %d%s" % [KINS[kin][0], kin_count.get(kin, 0), (" ★%d" % lv) if lv > 0 else ""]
		c.draw_string(font, Vector2(sx, 44), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, kc.lightened(0.3) if lv > 0 else Color(0.55, 0.55, 0.62))
		sx += font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12
	if mp:
		var ps: Dictionary = net.partner_snap
		var ptxt := "동료: 연결 대기"
		if not ps.is_empty():
			ptxt = "동료: 웨이브 %d · 요괴 %d/%d · 골드 %d%s" % [int(ps.get("wave", 0)), int(ps.get("alive", 0)), int(ps.get("cap", 70)), int(ps.get("gold", 0)), ("  (패배)" if ps.get("over", false) and not ps.get("won", false) else "")]
		if waiting_next: ptxt += "  · 동료 기다리는 중"
		c.draw_rect(Rect2(4, 52, 300, 14), Color(0.03, 0.04, 0.08, 0.75))
		c.draw_string(font, Vector2(10, 63), ptxt, HORIZONTAL_ALIGNMENT_LEFT, 296, 9, Color(0.6, 1.0, 0.8))
	# synergy lines between same-kin neighbours
	for i in range(units.size()):
		var ki: String = UNITS[units[i]["type"]]["kin"]
		for s in neighbours(units[i]["slot"]):
			var j := unit_at(s)
			if j > i and UNITS[units[j]["type"]]["kin"] == ki:
				c.draw_line(_proj(slot_pos(units[i]["slot"]) + Vector3(0, 0.2, 0)), _proj(slot_pos(units[j]["slot"]) + Vector3(0, 0.2, 0)), Color(KINS[ki][1], 0.85), 3.0)
	# MP bars under skill units
	for i in range(units.size()):
		if not has_skill(i): continue
		var u: Dictionary = units[i]
		var bp := _proj(slot_pos(u["slot"]) + Vector3(0, 0.1, 0.95))
		var full: bool = u["mp"] >= MP_MAX
		c.draw_rect(Rect2(bp.x - 13, bp.y, 26, 4), Color(0.05, 0.05, 0.1, 0.9))
		var mc := Color(0.35, 0.6, 1.0) if not full else Color(1, 0.9, 0.3, 0.6 + 0.4 * sin(t_acc * 8.0))
		c.draw_rect(Rect2(bp.x - 13, bp.y, 26.0 * u["mp"] / MP_MAX, 4), mc)
		if full and not u["auto"]: c.draw_string(font, bp + Vector2(15, 5), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.9, 0.3))
	# right panel
	c.draw_rect(Rect2(430, 0, 210, 360), Color(0.03, 0.04, 0.08, 0.85))
	if not started:
		_draw_prep()
		return
	c.draw_string(font, Vector2(434, 18), "웨이브 %d / %d" % [wave, LAST_WAVE], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
	if wave > 0: c.draw_string(font, Vector2(530, 16), ACTS[act_of(wave)]["n"], HORIZONTAL_ALIGNMENT_LEFT, 106, 9, Color(0.85, 0.6, 1.0))
	c.draw_string(font, Vector2(434, 36), "골드 %d" % gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.3))
	var danger := float(enemies.size()) / max_alive
	c.draw_string(font, Vector2(434, 54), "요괴 %d / %d" % [enemies.size(), max_alive], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1 - danger, 1 - danger))
	c.draw_rect(Rect2(530, 46, 100, 8), Color(0.2, 0.2, 0.25))
	c.draw_rect(Rect2(530, 46, 100 * minf(1, danger), 8), Color(1, 0.3, 0.2))
	c.draw_string(font, Vector2(530, 32), "다음 웨이브 %.0f초" % maxf(0, wave_t), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.9))
	if boss_alive:
		c.draw_string(font, Vector2(10, 66), "보스 제한시간 %.0f초" % boss_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.3, 0.3))
	if not choosing and not show_codex:
		for i in range(btns.size()): _draw_btn(i)
	# selected unit info (with skill)
	if selected >= 0 and selected < units.size() and not choosing:
		var u: Dictionary = units[selected]
		var U: Dictionary = UNITS[u["type"]]
		var info := "%s %s  [%s 계열]\n%s\n공격력 %.0f  (이웃 시너지 %d)" % [TIER_NAMES[u["tier"]], U["n"], KINS[U["kin"]][0], U["d"], unit_damage(selected), synergy(selected)]
		if U.has("sk"):
			var S: Dictionary = U["sk"]
			if has_skill(selected): info += "\n스킬 '%s' MP %d/100: %s" % [S["n"], int(u["mp"]), S["d"]]
			else: info += "\n스킬 '%s' (영웅 등급부터): %s" % [S["n"], S["d"]]
		c.draw_rect(Rect2(434, 254, 202, 102), Color(0.08, 0.09, 0.14, 0.95))
		c.draw_multiline_string(font, Vector2(438, 266), info, HORIZONTAL_ALIGNMENT_LEFT, 196, 9, 7, Color(0.92, 0.92, 0.97))
		for i in range(btns.size()):
			if btns[i]["r"].position.y >= 330: _draw_btn(i)
		var spos := _proj(slot_pos(u["slot"]) + Vector3(0, 2.0, 0))
		c.draw_colored_polygon(PackedVector2Array([spos, spos + Vector2(-6, -9), spos + Vector2(6, -9)]), Color(1, 1, 0.3))
	# wave preview + message
	c.draw_rect(Rect2(4, 312, 420, 20), Color(0.03, 0.04, 0.08, 0.7))
	c.draw_string(font, Vector2(10, 326), "이번: %s   다음: %s" % [_wave_text(wave), _wave_text(wave + 1)], HORIZONTAL_ALIGNMENT_LEFT, 410, 9, Color(0.85, 0.75, 1.0))
	c.draw_rect(Rect2(4, 334, 420, 22), Color(0.03, 0.04, 0.08, 0.8))
	c.draw_string(font, Vector2(10, 349), msg, HORIZONTAL_ALIGNMENT_LEFT, 410, 10, Color(1, 1, 1))
	for f in floaters:
		if cam.is_position_behind(f["pos"]): continue
		var lp := _proj(f["pos"])
		c.draw_string(font, lp + Vector2(-60, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(f["color"].r, f["color"].g, f["color"].b, f["t"]))
	if choosing: _draw_cards()
	if show_codex: _draw_codex()
	if over:
		c.draw_rect(Rect2(60, 140, 320, 60), Color(0, 0, 0, 0.8))
		c.draw_string(font, Vector2(60, 168), "승리!" if won else "패배", HORIZONTAL_ALIGNMENT_CENTER, 320, 22, Color(1, 0.9, 0.4))
		c.draw_string(font, Vector2(60, 186), lose_reason if not won else "처치 %d마리 · 영웅 %d명 발견" % [kills, discovered.size()], HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(1, 1, 1))
		c.draw_string(font, Vector2(60, 198), "엽전 +%d (보유 %d) · R: 마을로" % [yeop_earned, int(profile["yeop"])], HORIZONTAL_ALIGNMENT_CENTER, 320, 9, Color(1, 0.85, 0.3))
		if mp and won:
			var pr: String = net.partner_result
			c.draw_string(font, Vector2(60, 152), "협동 승리!" if pr == "won" else "동료가 아직 싸우는 중...", HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(0.6, 1.0, 0.8))
	if hover_btn >= 0 and hover_btn < btns.size() and String(btns[hover_btn]["tip"]) != "" and not choosing:
		var tip: String = btns[hover_btn]["tip"]
		var sz := font.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, 196, 10)
		var r4: Rect2 = btns[hover_btn]["r"]
		var box := Rect2(r4.position.x - 216, clampf(r4.position.y, 4, 350 - sz.y), 210, sz.y + 14)
		c.draw_rect(box, Color(0.05, 0.06, 0.10, 0.97))
		c.draw_rect(box, Color(1, 0.85, 0.4), false, 1.2)
		c.draw_multiline_string(font, box.position + Vector2(7, 15), tip, HORIZONTAL_ALIGNMENT_LEFT, 196, 10, -1, Color(0.95, 0.95, 1))


func _draw_prep() -> void:
	var c := hud
	c.draw_string(font, Vector2(434, 18), "준비 — 마을", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
	c.draw_string(font, Vector2(540, 18), "엽전 %d" % int(profile["yeop"]), HORIZONTAL_ALIGNMENT_LEFT, 96, 12, Color(1, 0.85, 0.3))
	var best: Dictionary = profile["best"]
	var Df: Dictionary = D.DIFFS[diff_key]
	c.draw_multiline_string(font, Vector2(434, 58), "%s  (최고 %d웨이브)" % [Df["d"], int(best.get(diff_key, 0))], HORIZONTAL_ALIGNMENT_LEFT, 200, 8, 2, Color(0.8, 0.8, 0.9))
	for i in range(btns.size()): _draw_btn(i)
	if prep_tab == 2:
		var info := "상태: %s\n\n같은 와이파이: 방장의 IP를 입력.\n인터넷: 방장이 공유기에서 UDP %d 포트를 열거나, 둘 다 Radmin VPN·Tailscale에 들어가 그 IP로 접속.\n\n각자 자기 무대를 지키고, 한쪽이 무너지면 둘 다 패배. 엽전·마을은 각자." % [net.status if net.status != "" else "연결 안 됨", NetScript.PORT]
		c.draw_multiline_string(font, Vector2(434, 180), info, HORIZONTAL_ALIGNMENT_LEFT, 200, 9, -1, Color(0.85, 0.88, 0.95))
	var np: int = profile["placed"].size()
	c.draw_string(font, Vector2(434, 352), "꾸밈 %d/%d자리 · 판 수 %d" % [np, int(profile["spots"]), int(profile["runs"])], HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color(0.7, 0.75, 0.85))
	# spot labels in the world
	for i in range(D.DECO_SPOTS.size()):
		var sp := _proj(D.DECO_SPOTS[i] + Vector3(0, 0.3, 0))
		if sp.x > 420.0 or sp.y > 330.0: continue
		var key := str(i)
		var txt := ""
		if i >= int(profile["spots"]): txt = "닫힘"
		elif profile["placed"].has(key): txt = D.DECOS[profile["placed"][key]]["n"]
		else: txt = "빈 자리"
		c.draw_string(font, sp + Vector2(-40, 14), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color(0.9, 1, 0.85) if i < int(profile["spots"]) else Color(0.6, 0.6, 0.65))
	c.draw_rect(Rect2(4, 334, 420, 22), Color(0.03, 0.04, 0.08, 0.8))
	c.draw_string(font, Vector2(10, 349), msg, HORIZONTAL_ALIGNMENT_LEFT, 410, 10, Color(1, 1, 1))
	if hover_btn >= 0 and hover_btn < btns.size() and String(btns[hover_btn]["tip"]) != "":
		var tip: String = btns[hover_btn]["tip"]
		var sz := font.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, 196, 10)
		var r4: Rect2 = btns[hover_btn]["r"]
		var box := Rect2(r4.position.x - 216, clampf(r4.position.y, 4, 350 - sz.y), 210, sz.y + 14)
		c.draw_rect(box, Color(0.05, 0.06, 0.10, 0.97))
		c.draw_rect(box, Color(1, 0.85, 0.4), false, 1.2)
		c.draw_multiline_string(font, box.position + Vector2(7, 15), tip, HORIZONTAL_ALIGNMENT_LEFT, 196, 10, -1, Color(0.95, 0.95, 1))
	if show_codex: _draw_codex()


func _draw_cards() -> void:
	var c := hud
	c.draw_rect(Rect2(10, 70, 420, 228), Color(0.02, 0.02, 0.05, 0.92))
	c.draw_string(font, Vector2(20, 92), "웨이브 보상: 카드 1장을 고르세요", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.88, 0.5))
	for k in range(cards.size()):
		var r2 := Rect2(20 + k * 136, 110, 128, 150)
		var ct := card_text(cards[k])
		var col := Color(0.3, 0.55, 0.35) if cards[k]["kind"] == "add" else (Color(0.55, 0.3, 0.3) if cards[k]["kind"] == "remove" else Color(0.6, 0.48, 0.18))
		c.draw_rect(r2, Color(0.08, 0.09, 0.14) if hover_btn != k else Color(0.14, 0.15, 0.22))
		c.draw_rect(Rect2(r2.position, Vector2(r2.size.x, 22)), col)
		c.draw_rect(r2, Color(1, 0.85, 0.4), false, 1.5)
		c.draw_string(font, r2.position + Vector2(6, 15), ct[0], HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color(1, 1, 1))
		c.draw_string(font, r2.position + Vector2(6, 42), ct[1], HORIZONTAL_ALIGNMENT_LEFT, 120, 13, Color(1, 0.92, 0.7))
		c.draw_multiline_string(font, r2.position + Vector2(6, 62), ct[2], HORIZONTAL_ALIGNMENT_LEFT, 116, 9, 7, Color(0.9, 0.9, 0.95))
	for i in range(btns.size()):
		if btns[i]["t"] != "": _draw_btn(i)


func _draw_codex() -> void:
	var c := hud
	c.draw_rect(Rect2(10, 42, 416, 290), Color(0.02, 0.02, 0.05, 0.96))
	c.draw_rect(Rect2(10, 42, 416, 290), Color(1, 0.85, 0.4), false, 1.5)
	for i in range(btns.size()): _draw_btn(i)
	c.draw_string(font, Vector2(318, 58), "Tab: 다음 · 클릭: 닫기", HORIZONTAL_ALIGNMENT_LEFT, 104, 8, Color(0.7, 0.7, 0.78))
	var yy := 76.0
	var ekeys: Array = ENEMIES.keys()
	match codex_tab:
		0, 1, 2:
			for t in BASE_KEYS.slice(codex_tab * 12, codex_tab * 12 + 12):
				var U2: Dictionary = UNITS[t]
				var tag := " ●" if pool.has(t) else ("" if unit_unlocked(t) else " (잠김)")
				c.draw_string(font, Vector2(18, yy), "%s [%s]%s" % [U2["n"], KINS[U2["kin"]][0], tag], HORIZONTAL_ALIGNMENT_LEFT, 120, 9, KINS[U2["kin"]][1].lightened(0.3))
				c.draw_string(font, Vector2(130, yy), U2["d"], HORIZONTAL_ALIGNMENT_LEFT, 290, 8, Color(0.88, 0.88, 0.93))
				yy += 10
				if U2.has("sk"):
					c.draw_string(font, Vector2(130, yy), "스킬 %s: %s" % [U2["sk"]["n"], U2["sk"]["d"]], HORIZONTAL_ALIGNMENT_LEFT, 290, 8, Color(0.6, 0.75, 1.0))
				yy += 11
				if yy > 322: break
		3:
			c.draw_string(font, Vector2(18, yy), "레시피 (각 재료는 희귀 등급 이상) — 발견 %d/%d" % [discovered.size(), HERO_KEYS.size()], HORIZONTAL_ALIGNMENT_LEFT, 400, 10, Color(1, 0.88, 0.5))
			yy += 14
			for hk in HERO_KEYS:
				var H: Dictionary = UNITS[hk]
				var rec_names := []
				for r3 in H["rec"]: rec_names.append(UNITS[r3]["n"])
				c.draw_string(font, Vector2(18, yy), "%s%s [%s] = %s" % ["★ " if discovered.has(hk) else "", H["n"], KINS[H["kin"]][0], " + ".join(rec_names)], HORIZONTAL_ALIGNMENT_LEFT, 400, 9, Color(1, 0.85, 0.4) if discovered.has(hk) else Color(0.85, 0.85, 0.9))
				yy += 10
				c.draw_string(font, Vector2(30, yy), "스킬 %s: %s" % [H["sk"]["n"], H["sk"]["d"]], HORIZONTAL_ALIGNMENT_LEFT, 390, 8, Color(0.62, 0.72, 0.95))
				yy += 9
				if yy > 322: break
		4, 5, 6:
			c.draw_string(font, Vector2(18, yy), "요괴 도감 — 만난 요괴 %d / %d" % [seen_enemies.size(), ENEMIES.size()], HORIZONTAL_ALIGNMENT_LEFT, 400, 10, Color(1, 0.88, 0.5))
			yy += 14
			var third := (ekeys.size() + 2) / 3
			for k in ekeys.slice((codex_tab - 4) * third, (codex_tab - 4) * third + third):
				var E: Dictionary = ENEMIES[k]
				var known := seen_enemies.has(k)
				var line: String = ("%s%s %s — %s (%s)" % ["[보스] " if E.get("boss", false) else "", E["n"], _traits_text(k), E["d"], E["src"]]) if known else "??? (아직 만나지 않음)"
				c.draw_string(font, Vector2(18, yy), line, HORIZONTAL_ALIGNMENT_LEFT, 400, 9, Color(0.9, 0.8, 1.0) if known else Color(0.5, 0.5, 0.55))
				yy += 12
				if yy > 236: break
			var tips := []
			for t in D.TRAIT_TIPS: tips.append("%s: %s" % [D.TRAIT_NAMES[t], D.TRAIT_TIPS[t]])
			c.draw_multiline_string(font, Vector2(18, maxf(yy, 250)), "  ".join(tips), HORIZONTAL_ALIGNMENT_LEFT, 400, 8, 6, Color(0.65, 0.65, 0.72))
		7:
			c.draw_string(font, Vector2(18, yy), "계열 시너지 — 필드 위 같은 계열 %s명" % "/".join(D.SYN_STEPS.map(func(x): return str(x))), HORIZONTAL_ALIGNMENT_LEFT, 400, 10, Color(1, 0.88, 0.5))
			yy += 14
			for kin in D.SYN:
				var lv := syn_level(kin)
				c.draw_string(font, Vector2(18, yy), "%s '%s' (지금 %d명, ★%d)" % [KINS[kin][0], D.SYN[kin][0], kin_count.get(kin, 0), lv], HORIZONTAL_ALIGNMENT_LEFT, 400, 9, KINS[kin][1].lightened(0.3))
				yy += 11
				var xx := 30.0
				for k in range(3):
					var st := "%d명: %s" % [D.SYN_STEPS[k], D.SYN[kin][1][k]]
					c.draw_string(font, Vector2(xx, yy), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1) if lv > k else Color(0.6, 0.6, 0.66))
					xx += font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10
				yy += 16
			c.draw_string(font, Vector2(18, yy + 4), "이웃 시너지: 상하좌우로 붙은 같은 계열 1명당 공격력 +12%", HORIZONTAL_ALIGNMENT_LEFT, 400, 8, Color(0.75, 0.75, 0.8))
