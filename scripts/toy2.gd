extends Node3D
# Toy prototype #2: "도깨비 디펜스" — random summon & merge defense with Korean folklore units, plus
#  A) pool building: every 2 waves pick 1 of 3 cards (add unit to summon pool / remove one / relic)
#  B) recipes (3 specific units -> named hero) and kin synergy (same-kin neighbours boost damage)
# Merges roll a random unit FROM YOUR POOL, so curating the pool is the strategy.
# Logic is in step(dt); tests drive it headless.

const COLS := 6
const ROWS := 4
const MAX_ALIVE := 70
const LAST_WAVE := 20
const WAVE_TIME := 25.0
const SPAWN_GAP := 0.55
const PER_WAVE := 20
const TIER_NAMES := ["일반", "희귀", "영웅", "전설"]
const TIER_COLORS := [Color(0.85, 0.85, 0.85), Color(0.35, 0.65, 1.0), Color(0.75, 0.35, 1.0), Color(1.0, 0.75, 0.2)]
const KINS := {
	"dokkaebi": ["도깨비", Color(0.90, 0.30, 0.25)],
	"sinsu": ["신수", Color(0.95, 0.78, 0.30)],
	"muin": ["무인", Color(0.35, 0.60, 0.95)],
	"jusul": ["주술", Color(0.65, 0.40, 0.95)],
}
# key: name, kin, base dmg, interval, range, splash, slow, special, description, hero, recipe
const UNITS := {
	"dokkaebi": {"n": "도깨비", "kin": "dokkaebi", "dmg": 11.0, "int": 0.6, "rng": 3.6, "spl": 0.0, "slow": 0.0, "sp": "gold", "d": "방망이로 때린다. 맞힐 때마다 8% 확률로 '금 나와라 뚝딱' (+1골드)."},
	"gungsa": {"n": "궁사", "kin": "muin", "dmg": 8.0, "int": 0.4, "rng": 4.4, "spl": 0.0, "slow": 0.0, "sp": "", "d": "빠르고 멀리 쏘는 활잡이. 무난한 딜러."},
	"mudang": {"n": "무당", "kin": "jusul", "dmg": 12.0, "int": 1.1, "rng": 3.6, "spl": 1.3, "slow": 0.0, "sp": "", "d": "굿판을 벌여 주변 요괴를 한꺼번에 공격."},
	"mulgwisin": {"n": "물귀신", "kin": "jusul", "dmg": 5.0, "int": 0.8, "rng": 3.8, "spl": 0.0, "slow": 0.45, "sp": "", "d": "요괴의 발목을 잡아 느리게 만든다."},
	"haetae": {"n": "해태", "kin": "sinsu", "dmg": 30.0, "int": 2.0, "rng": 5.0, "spl": 0.8, "slow": 0.0, "sp": "boss", "d": "정의의 신수. 느리지만 강한 일격, 보스에게 피해 +50%."},
	"gumiho": {"n": "구미호", "kin": "sinsu", "dmg": 10.0, "int": 0.6, "rng": 3.8, "spl": 0.0, "slow": 0.0, "sp": "multi", "d": "여우불로 요괴 두 마리를 동시에 공격."},
	"posu": {"n": "포수", "kin": "muin", "dmg": 40.0, "int": 2.2, "rng": 6.0, "spl": 0.0, "slow": 0.0, "sp": "", "d": "호랑이도 잡는 사냥꾼. 가장 멀리서 강한 한 발."},
	"jeoseung": {"n": "저승사자", "kin": "jusul", "dmg": 7.0, "int": 0.9, "rng": 3.8, "spl": 0.0, "slow": 0.0, "sp": "exec", "d": "체력 15% 이하인 요괴를 즉시 저승으로 데려간다 (보스 제외)."},
	"dokkaebi_king": {"n": "도깨비 대왕", "kin": "dokkaebi", "dmg": 14.0, "int": 0.5, "rng": 4.2, "spl": 1.0, "slow": 0.0, "sp": "gold", "hero": true, "rec": ["dokkaebi", "dokkaebi", "mudang"], "d": "[영웅] 범위 방망이질 + 금 나와라 뚝딱 확률 25%."},
	"chakho": {"n": "착호갑사", "kin": "muin", "dmg": 45.0, "int": 1.6, "rng": 6.5, "spl": 0.0, "slow": 0.0, "sp": "boss", "hero": true, "rec": ["gungsa", "posu", "haetae"], "d": "[영웅] 조선의 호랑이 사냥 부대. 보스 사냥 전문."},
	"cheonnyeon": {"n": "천년 구미호", "kin": "sinsu", "dmg": 16.0, "int": 0.6, "rng": 4.2, "spl": 1.2, "slow": 0.0, "sp": "multi", "hero": true, "rec": ["gumiho", "gumiho", "mudang"], "d": "[영웅] 여우불 범위 공격을 두 곳에 동시에."},
	"yeomra": {"n": "염라대왕", "kin": "jusul", "dmg": 10.0, "int": 0.8, "rng": 4.5, "spl": 0.0, "slow": 0.3, "sp": "exec30", "hero": true, "rec": ["jeoseung", "mulgwisin", "mudang"], "d": "[영웅] 체력 30% 이하 요괴를 즉시 심판. 느리게도 만든다."},
}
const BASE_KEYS := ["dokkaebi", "gungsa", "mudang", "mulgwisin", "haetae", "gumiho", "posu", "jeoseung"]
const HERO_KEYS := ["dokkaebi_king", "chakho", "cheonnyeon", "yeomra"]
const RELICS := {
	"bangmang": ["도깨비 방망이", "소환 비용 30 → 24"],
	"bok": ["복주머니", "합성할 때 15% 확률로 두 단계 상승"],
	"haetae_stone": ["해태 석상", "보스에게 주는 피해 +30%"],
	"bujeok": ["부적", "같은 계열 시너지 +12% → +20%"],
	"jangseung": ["장승", "요괴 이동 속도 -12%"],
	"yeopjeon": ["엽전 꾸러미", "웨이브 보상 +12골드"],
	"yeouiju": ["여의주", "전설 등급(영웅 포함) 공격력 +25%"],
}
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
var units: Array = []
var enemies: Array = []
var shots: Array = []
var floaters: Array = []
var upgrades := {"dokkaebi": 0, "sinsu": 0, "muin": 0, "jusul": 0}
var pool: Array = ["dokkaebi", "gungsa", "mudang", "mulgwisin", "haetae"]
var relics: Array = []
var discovered: Array = []
var choosing := false
var cards: Array = []
var speed := 1
var selected := -1
var msg := ""
var kills := 0
var hp_growth := 1.28
var headless := false
var show_codex := false

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
	msg = "Q = 소환. 유닛 클릭 후 빈 칸 클릭 = 이동. 같은 계열끼리 붙이면 강해집니다. C = 도감."


func cost() -> int:
	return 24 if relics.has("bangmang") else 30


# ---------------- world ----------------
func _setup_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.7)
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.7
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.shadow_enabled = true
	moon.light_color = Color(0.85, 0.85, 1.0)
	moon.rotation = Vector3(deg_to_rad(-55), deg_to_rad(25), 0)
	add_child(moon)
	cam = Camera3D.new()
	cam.fov = 45
	cam.position = Vector3(4.2, 17, 13)
	add_child(cam)
	cam.look_at(Vector3(4.2, 0, 0.6), Vector3.UP)
	_box(Vector3(22, 0.4, 15), Vector3(0, -0.2, 0), _mat(Color(0.20, 0.27, 0.20)))
	for k in range(4):
		var a: Vector3 = CORNERS[k]; var b: Vector3 = CORNERS[(k + 1) % 4]
		_box(Vector3(absf(b.x - a.x) + 1.4, 0.05, absf(b.z - a.z) + 1.4), (a + b) / 2.0 + Vector3(0, 0.02, 0), _mat(Color(0.42, 0.34, 0.26)))
	for s in range(COLS * ROWS):
		_box(Vector3(1.6, 0.12, 1.6), slot_pos(s) + Vector3(0, 0.06, 0), _mat(Color(0.30, 0.38, 0.28)))
	# 장승 pair at the gate + red torii-like gate (hongsalmun)
	for sx in [-1.0, 1.0]:
		var p: Vector3 = CORNERS[0] + Vector3(sx * 1.1, 0, -0.9)
		_box(Vector3(0.3, 1.6, 0.3), p + Vector3(0, 0.8, 0), _mat(Color(0.55, 0.38, 0.25)))
		_box(Vector3(0.36, 0.36, 0.36), p + Vector3(0, 1.7, 0), _mat(Color(0.8, 0.25, 0.2)))
	_box(Vector3(2.8, 0.15, 0.15), CORNERS[0] + Vector3(0, 2.1, -0.9), _mat(Color(0.75, 0.18, 0.15)))
	var portal := MeshInstance3D.new()
	var tor := TorusMesh.new(); tor.inner_radius = 0.5; tor.outer_radius = 0.75
	portal.mesh = tor
	portal.material_override = _mat(Color(0.5, 0.1, 0.4), Color(0.8, 0.2, 1.0), 2.5)
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


func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = m; mi.position = pos; mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(top: float, bot: float, h: float, seg: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top; c.bottom_radius = bot; c.height = h; c.radial_segments = seg
	return c


func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2
	return s


func slot_pos(s: int) -> Vector3:
	return Vector3(-5.0 + (s % COLS) * 2.0, 0, -3.0 + (s / COLS) * 2.0)


func path_pos(d: float) -> Vector3:
	d = fposmod(d, perimeter)
	for k in range(4):
		var a: Vector3 = CORNERS[k]; var b: Vector3 = CORNERS[(k + 1) % 4]
		var L := a.distance_to(b)
		if d <= L: return a.lerp(b, d / L)
		d -= L
	return CORNERS[0]


# ---------------- unit visuals ----------------
func _make_unit_node(t: String, tier: int) -> Node3D:
	var n := Node3D.new()
	var U: Dictionary = UNITS[t]
	var kc: Color = KINS[U["kin"]][1]
	var skin := _mat(Color(0.95, 0.85, 0.75))
	match t:
		"dokkaebi", "dokkaebi_king":
			_part(n, _cyl(0.25, 0.34, 0.7), _mat(Color(0.85, 0.28, 0.22)), Vector3(0, 0.35, 0))
			_part(n, _sph(0.24), _mat(Color(0.9, 0.35, 0.28)), Vector3(0, 0.9, 0))
			_part(n, _cyl(0.0, 0.07, 0.25, 5), _mat(Color(0.95, 0.9, 0.7)), Vector3(0.1, 1.18, 0))
			_part(n, _cyl(0.0, 0.07, 0.25, 5), _mat(Color(0.95, 0.9, 0.7)), Vector3(-0.1, 1.18, 0))
			_part(n, _cyl(0.1, 0.05, 0.6, 6), _mat(Color(0.5, 0.33, 0.2)), Vector3(0.38, 0.6, 0), Vector3(0, 0, 0.5))
		"gungsa", "chakho":
			_part(n, _cyl(0.22, 0.3, 0.7), _mat(Color(0.3, 0.5, 0.85)), Vector3(0, 0.35, 0))
			_part(n, _sph(0.2), skin, Vector3(0, 0.85, 0))
			_part(n, _cyl(0.38, 0.38, 0.04, 12), _mat(Color(0.1, 0.1, 0.12)), Vector3(0, 1.02, 0))
			_part(n, _cyl(0.12, 0.12, 0.2, 10), _mat(Color(0.1, 0.1, 0.12)), Vector3(0, 1.12, 0))
			var bow := TorusMesh.new(); bow.inner_radius = 0.3; bow.outer_radius = 0.34
			_part(n, bow, _mat(Color(0.55, 0.35, 0.2)), Vector3(0.3, 0.6, 0), Vector3(0, 0, PI / 2))
		"posu":
			_part(n, _cyl(0.22, 0.3, 0.7), _mat(Color(0.35, 0.45, 0.65)), Vector3(0, 0.35, 0))
			_part(n, _sph(0.2), skin, Vector3(0, 0.85, 0))
			_part(n, _cyl(0.38, 0.38, 0.04, 12), _mat(Color(0.1, 0.1, 0.12)), Vector3(0, 1.02, 0))
			_part(n, _cyl(0.04, 0.04, 1.0, 6), _mat(Color(0.25, 0.22, 0.2)), Vector3(0.3, 0.7, 0), Vector3(0.9, 0, 0))
		"mudang":
			_part(n, _cyl(0.18, 0.4, 0.75), _mat(Color(0.85, 0.2, 0.3)), Vector3(0, 0.37, 0))
			_part(n, _sph(0.2), skin, Vector3(0, 0.88, 0))
			_part(n, _cyl(0.15, 0.22, 0.25, 8), _mat(Color(0.95, 0.85, 0.2)), Vector3(0, 1.12, 0))
			_part(n, _cyl(0.02, 0.02, 0.6, 4), _mat(Color(0.9, 0.9, 0.9), Color(1, 1, 1), 1.0), Vector3(0.3, 0.8, 0))
		"mulgwisin":
			_part(n, _cyl(0.2, 0.32, 0.75), _mat(Color(0.35, 0.65, 0.85), Color(0.3, 0.6, 1.0), 0.8), Vector3(0, 0.37, 0))
			_part(n, _sph(0.21), _mat(Color(0.75, 0.85, 0.95)), Vector3(0, 0.88, 0))
			_part(n, _cyl(0.24, 0.1, 0.5, 8), _mat(Color(0.05, 0.05, 0.08)), Vector3(0, 0.9, -0.08))
		"jeoseung", "yeomra":
			_part(n, _cyl(0.22, 0.36, 0.8), _mat(Color(0.08, 0.08, 0.1)), Vector3(0, 0.4, 0))
			_part(n, _sph(0.2), _mat(Color(0.85, 0.85, 0.9)), Vector3(0, 0.92, 0))
			_part(n, _cyl(0.46, 0.46, 0.04, 14), _mat(Color(0.03, 0.03, 0.04)), Vector3(0, 1.08, 0))
			_part(n, _cyl(0.13, 0.13, 0.24, 10), _mat(Color(0.03, 0.03, 0.04)), Vector3(0, 1.2, 0))
		"haetae":
			var b := BoxMesh.new(); b.size = Vector3(0.5, 0.45, 0.8)
			_part(n, b, _mat(Color(0.95, 0.8, 0.35)), Vector3(0, 0.4, 0))
			_part(n, _sph(0.26), _mat(Color(0.95, 0.75, 0.3)), Vector3(0, 0.75, 0.38))
			_part(n, _cyl(0.0, 0.06, 0.3, 5), _mat(Color(0.3, 0.6, 0.4)), Vector3(0, 1.05, 0.4))
			for lx in [-0.18, 0.18]:
				for lz in [-0.28, 0.28]:
					_part(n, _cyl(0.06, 0.06, 0.25, 6), _mat(Color(0.85, 0.7, 0.3)), Vector3(lx, 0.1, lz))
		"gumiho", "cheonnyeon":
			var b2 := BoxMesh.new(); b2.size = Vector3(0.4, 0.38, 0.7)
			_part(n, b2, _mat(Color(0.97, 0.9, 0.8)), Vector3(0, 0.4, 0))
			_part(n, _sph(0.22), _mat(Color(0.97, 0.92, 0.85)), Vector3(0, 0.7, 0.35))
			_part(n, _cyl(0.0, 0.07, 0.2, 4), _mat(Color(0.97, 0.9, 0.8)), Vector3(0.1, 0.95, 0.35))
			_part(n, _cyl(0.0, 0.07, 0.2, 4), _mat(Color(0.97, 0.9, 0.8)), Vector3(-0.1, 0.95, 0.35))
			var tails := 9 if t == "cheonnyeon" else 3
			for k in range(tails):
				var a := (k - (tails - 1) / 2.0) * 0.28
				_part(n, _cyl(0.02, 0.08, 0.55, 5), _mat(Color(1, 0.95, 0.9), Color(1, 0.5, 0.2), 0.6), Vector3(sin(a) * 0.25, 0.65, -0.4), Vector3(-0.9, a, 0))
	var tc: Color = TIER_COLORS[tier]
	var ring := TorusMesh.new(); ring.inner_radius = 0.48; ring.outer_radius = 0.58
	_part(n, ring, _mat(tc, tc, 1.0 + tier * 1.2), Vector3(0, 0.03, 0))
	var kin_dot := _part(n, _sph(0.08), _mat(kc, kc, 2.0), Vector3(0, 1.5, 0))
	if UNITS[t].get("hero", false):
		var crown := TorusMesh.new(); crown.inner_radius = 0.2; crown.outer_radius = 0.26
		_part(n, crown, _mat(Color(1, 0.85, 0.3), Color(1, 0.75, 0.2), 3.0), Vector3(0, 1.45, 0))
		kin_dot.visible = false
	if tier >= 2:
		var l := OmniLight3D.new(); l.light_color = tc; l.omni_range = 2.2; l.light_energy = 0.8 + tier * 0.4; l.position = Vector3(0, 1.0, 0)
		n.add_child(l)
	var sc := 1.0 + tier * 0.15
	n.scale = Vector3(sc, sc, sc)
	add_child(n)
	return n


# ---------------- units & pool ----------------
func unit_at(s: int) -> int:
	for i in range(units.size()):
		if units[i]["slot"] == s: return i
	return -1


func free_slot() -> int:
	for s in range(COLS * ROWS):
		if unit_at(s) < 0: return s
	return -1


func _add_unit(t: String, tier: int, s: int) -> void:
	var u := {"type": t, "tier": tier, "slot": s, "cd": 0.0, "node": _make_unit_node(t, tier)}
	u["node"].position = slot_pos(s) + Vector3(0, 0.12, 0)
	units.append(u)


func summon() -> bool:
	if over or choosing or gold < cost(): return false
	var s := free_slot()
	if s < 0:
		msg = "자리가 꽉 찼습니다. 합성하거나 판매하세요."
		return false
	gold -= cost()
	var t: String = pool[rng.randi() % pool.size()]
	_add_unit(t, 0, s)
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
	_float("합성!", slot_pos(s) + Vector3(0, 2, 0), TIER_COLORS[ntier])
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
	return true


func sell(i: int) -> void:
	if i < 0 or i >= units.size(): return
	var refund := int(cost() * pow(3, units[i]["tier"]) * 0.5)
	gold += refund
	_remove_units([i])
	selected = -1
	msg = "판매: +%d 골드" % refund


func move_selected(s: int) -> void:
	if selected < 0 or selected >= units.size(): return
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
	msg = "%s 계열 강화 Lv%d (+15%%)" % [KINS[kin][0], upgrades[kin]]
	return true


func unit_damage(i: int) -> float:
	var u: Dictionary = units[i]
	var U: Dictionary = UNITS[u["type"]]
	var dmg: float = U["dmg"] * pow(3.2, u["tier"]) * (1.0 + 0.15 * upgrades[U["kin"]])
	dmg *= 1.0 + (0.20 if relics.has("bujeok") else 0.12) * synergy(i)
	if u["tier"] == 3 and relics.has("yeouiju"): dmg *= 1.25
	return dmg


# ---------------- cards (pool building) ----------------
func make_cards() -> void:
	cards.clear()
	var opts := []
	for t in BASE_KEYS:
		if not pool.has(t): opts.append({"kind": "add", "key": t})
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
		"add": return ["소환 풀에 추가", UNITS[c["key"]]["n"], UNITS[c["key"]]["d"]]
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
	start_wave()


# ---------------- waves ----------------
func start_wave() -> void:
	wave += 1
	wave_t = WAVE_TIME
	if wave % 10 == 0:
		_spawn_enemy(true)
		boss_alive = true
		boss_timer = WAVE_TIME * (2.4 if wave < LAST_WAVE else 3.2)
		to_spawn = 0
		msg = ("이무기" if wave < LAST_WAVE else "불가사리") + " 등장! %d초 안에 처치하세요." % int(boss_timer)
	else:
		to_spawn = PER_WAVE
		spawn_t = 0.0


func enemy_hp() -> float:
	return 28.0 * pow(hp_growth, wave - 1)


func _spawn_enemy(boss: bool) -> void:
	var hp := enemy_hp() * ((22.0 if wave < LAST_WAVE else 11.0) if boss else 1.0)
	var e := {"hp": hp, "maxhp": hp, "d": 0.0, "speed": (1.6 if boss else 2.4) * (0.88 if relics.has("jangseung") else 1.0), "slow_t": 0.0, "boss": boss, "node": null, "bar": null, "segs": []}
	var n := Node3D.new()
	if boss:
		var col := Color(0.25, 0.45, 0.35) if wave < LAST_WAVE else Color(0.35, 0.35, 0.4)
		_part(n, _sph(0.7), _mat(col), Vector3(0, 0.7, 0))
		_part(n, _sph(0.12), _mat(Color(1, 0.8, 0.1), Color(1, 0.7, 0.1), 3.0), Vector3(0.25, 0.95, 0.55))
		_part(n, _sph(0.12), _mat(Color(1, 0.8, 0.1), Color(1, 0.7, 0.1), 3.0), Vector3(-0.25, 0.95, 0.55))
		add_child(n)
		for k in range(6):
			var seg := MeshInstance3D.new()
			seg.mesh = _sph(0.55 - k * 0.05)
			seg.material_override = _mat(col.darkened(0.1 * k))
			add_child(seg)
			e["segs"].append(seg)
	else:
		var sc := 0.75 + 0.02 * wave
		_part(n, _sph(0.33), _mat(Color(0.3, 0.12, 0.35)), Vector3(0, 0.3, 0))
		_part(n, _cyl(0.0, 0.06, 0.22, 4), _mat(Color(0.9, 0.85, 0.7)), Vector3(0, 0.66, 0))
		_part(n, _sph(0.06), _mat(Color(1, 0.2, 0.2), Color(1, 0.1, 0.1), 3.0), Vector3(0.12, 0.4, 0.27))
		_part(n, _sph(0.06), _mat(Color(1, 0.2, 0.2), Color(1, 0.1, 0.1), 3.0), Vector3(-0.12, 0.4, 0.27))
		n.scale = Vector3(sc, sc, sc)
		add_child(n)
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.8 if not boss else 1.8, 0.08, 0.08)
	bar.mesh = bm
	bar.material_override = _mat(Color(0.3, 1, 0.3), Color(0.2, 1, 0.2), 1.0)
	n.add_child(bar)
	bar.position = Vector3(0, 1.0 if not boss else 1.7, 0)
	e["node"] = n; e["bar"] = bar
	enemies.append(e)


func _float(text: String, pos: Vector3, c: Color) -> void:
	floaters.append({"text": text, "pos": pos, "t": 1.0, "color": c})


func _shot(a: Vector3, b: Vector3, c: Color) -> void:
	if headless or shots.size() > 90: return
	var mi := MeshInstance3D.new()
	mi.mesh = _sph(0.09)
	mi.material_override = _mat(c, c, 3.0)
	add_child(mi)
	mi.position = a
	shots.append({"node": mi, "from": a, "to": b, "t": 0.0})


# ---------------- simulation step ----------------
func step(dt: float) -> void:
	if over or choosing: return
	if wave == 0: start_wave()
	wave_t -= dt
	if to_spawn > 0:
		spawn_t -= dt
		if spawn_t <= 0:
			_spawn_enemy(false); to_spawn -= 1; spawn_t = SPAWN_GAP
	if wave_t <= 0 and wave < LAST_WAVE:
		gold += 15 + wave * 2 + (12 if relics.has("yeopjeon") else 0)
		if wave % 2 == 0:
			make_cards()
			return
		start_wave()
	if boss_alive:
		boss_timer -= dt
		if boss_timer <= 0:
			over = true; lose_reason = "보스를 시간 안에 처치하지 못했습니다."; msg = "패배: " + lose_reason
			return
	for e in enemies:
		var sp: float = e["speed"] * (0.55 if e["slow_t"] > 0 else 1.0)
		e["slow_t"] = maxf(0.0, e["slow_t"] - dt)
		e["d"] += sp * dt
		e["node"].position = path_pos(e["d"])
		var nxt := path_pos(e["d"] + 0.3)
		if nxt.distance_to(e["node"].position) > 0.01: e["node"].look_at(nxt, Vector3.UP, true)
		for k in range(e["segs"].size()):
			e["segs"][k].position = path_pos(e["d"] - 0.75 * (k + 1)) + Vector3(0, 0.55, 0)
		e["bar"].scale = Vector3(clampf(e["hp"] / e["maxhp"], 0, 1), 1, 1)
	if enemies.size() > MAX_ALIVE:
		over = true; lose_reason = "요괴가 %d마리를 넘었습니다." % MAX_ALIVE; msg = "패배: " + lose_reason
		return
	for i in range(units.size()):
		var u: Dictionary = units[i]
		u["cd"] -= dt
		if u["cd"] > 0: continue
		var U: Dictionary = UNITS[u["type"]]
		var up: Vector3 = slot_pos(u["slot"])
		var cands := []
		for k in range(enemies.size()):
			var ep: Vector3 = enemies[k]["node"].position
			if Vector2(ep.x - up.x, ep.z - up.z).length() <= U["rng"]: cands.append(k)
		if cands.is_empty(): continue
		cands.sort_custom(func(a, b): return enemies[a]["d"] > enemies[b]["d"])
		var ntarget := 2 if U["sp"] == "multi" else 1
		u["cd"] = U["int"]
		var dmg := unit_damage(i)
		for ti in range(mini(ntarget, cands.size())):
			var tgt: Dictionary = enemies[cands[ti]]
			var tp: Vector3 = tgt["node"].position
			var hit := []
			if U["spl"] > 0.0:
				for e2 in enemies:
					if e2["node"].position.distance_to(tp) <= U["spl"]: hit.append(e2)
			else:
				hit.append(tgt)
			for e3 in hit:
				var dd := dmg
				if e3["boss"]:
					if U["sp"] == "boss": dd *= 1.5
					if relics.has("haetae_stone"): dd *= 1.3
				e3["hp"] -= dd
				if U["slow"] > 0.0: e3["slow_t"] = 1.5
				if not e3["boss"] and e3["hp"] > 0:
					if (U["sp"] == "exec" and e3["hp"] < e3["maxhp"] * 0.15) or (U["sp"] == "exec30" and e3["hp"] < e3["maxhp"] * 0.30):
						e3["hp"] = 0
			if U["sp"] == "gold" and rng.randf() < (0.25 if U.get("hero", false) else 0.08):
				gold += 1
				_float("+1 뚝딱", up + Vector3(0, 1.8, 0), Color(1, 0.85, 0.2))
			_shot(up + Vector3(0, 1.0, 0), tp + Vector3(0, 0.4, 0), KINS[U["kin"]][1])
			u["node"].rotation.y = atan2(tp.x - up.x, tp.z - up.z)
	for k in range(enemies.size() - 1, -1, -1):
		var e4: Dictionary = enemies[k]
		if e4["hp"] <= 0:
			var g := 40 if e4["boss"] else 3
			gold += g
			kills += 1
			_float("+%d" % g, e4["node"].position + Vector3(0, 1.2, 0), Color(1, 0.9, 0.3))
			if e4["boss"]:
				boss_alive = false; msg = "보스 처치! +40골드"
				for sgm in e4["segs"]: sgm.queue_free()
				if wave >= LAST_WAVE:
					over = true; won = true; msg = "승리! 불가사리를 물리쳤습니다."
			e4["node"].queue_free()
			enemies.remove_at(k)
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


func _process(delta: float) -> void:
	t_acc += delta
	for k in range(speed): step(delta)
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
		if show_codex:
			show_codex = false; return
		if choosing or hp.x > 430: return
		var o := cam.project_ray_origin(e.position)
		var d := cam.project_ray_normal(e.position)
		var p := o + d * ((0.3 - o.y) / d.y)
		var hit_slot := -1
		for s in range(COLS * ROWS):
			var sp := slot_pos(s)
			if absf(p.x - sp.x) < 0.9 and absf(p.z - sp.z) < 0.9: hit_slot = s
		if hit_slot < 0:
			selected = -1; return
		var ui := unit_at(hit_slot)
		if ui >= 0 and ui != selected:
			selected = ui
		elif ui < 0 and selected >= 0:
			move_selected(hit_slot)
		else:
			selected = -1
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_Q: summon()
			KEY_W:
				if not merge(selected): craft(selected)
			KEY_E: craft(selected)
			KEY_C: show_codex = not show_codex
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
	if choosing:
		for k in range(cards.size()):
			_btn("", Rect2(20 + k * 136, 110, 128, 150), pick_card.bind(k), true)
		_btn("건너뛰기 (+20골드)", Rect2(160, 270, 120, 18), pick_card.bind(-1), true)
		return
	var x := 434.0
	var y := 66.0
	_btn("소환  (골드 %d)  [Q]" % cost(), Rect2(x, y, 200, 22), summon, gold >= cost() and not over, true, "소환 풀에서 랜덤 유닛 1개 (일반 등급).\n현재 풀: " + _pool_text())
	y += 26
	var mt := "합성  [W]"
	var sel_ok := selected >= 0 and selected < units.size()
	if sel_ok:
		mt = "합성: %s %s (%d/3)  [W]" % [TIER_NAMES[units[selected]["tier"]], UNITS[units[selected]["type"]]["n"], same_count(units[selected]["type"], units[selected]["tier"])]
	_btn(mt, Rect2(x, y, 200, 18), func(): merge(selected), can_merge(selected), false, "같은 유닛·같은 등급 3개 → 한 등급 높은 유닛 1개.\n결과는 내 소환 풀에서 랜덤으로 나옵니다.")
	y += 21
	var h := recipe_for(selected)
	_btn(("레시피: %s  [E]" % UNITS[h]["n"]) if h != "" else "레시피 (조건 미충족)  [E]", Rect2(x, y, 200, 18), func(): craft(selected), h != "", h != "", "특정 3개 유닛(각각 희귀 이상)을 모으면 전설 영웅이 됩니다.\n레시피 목록은 도감(C)에서 확인.")
	y += 21
	_btn("판매 (선택 유닛)", Rect2(x, y, 98, 16), func(): sell(selected), sel_ok)
	_btn("도감 (C)", Rect2(x + 102, y, 98, 16), func(): show_codex = not show_codex, true, show_codex)
	y += 22
	for kin in KINS:
		_btn("%s 계열 강화 Lv%d (%d골드)" % [KINS[kin][0], upgrades[kin], upgrade_cost(kin)], Rect2(x, y, 200, 15), upgrade.bind(kin), gold >= upgrade_cost(kin) and not over, false, "%s 계열 모든 유닛 공격력 +15%%." % KINS[kin][0])
		y += 17
	y += 5
	for s in range(4):
		var lab: String = ["일시정지", "1배속", "2배속", "3배속"][s]
		_btn(lab, Rect2(x + s * 50, y, 48, 16), func(): speed = s, true, speed == s)
	y += 20
	_btn("다시 시작 (R)", Rect2(x, y, 98, 16), func(): get_tree().reload_current_scene(), true)
	_btn("메뉴 (M)", Rect2(x + 102, y, 98, 16), func(): get_tree().change_scene_to_file("res://scenes/main.tscn"), true)


func _pool_text() -> String:
	var names := []
	for t in pool: names.append(UNITS[t]["n"])
	return ", ".join(names)


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
	# top-left: pool & relics
	c.draw_rect(Rect2(4, 4, 420, 34), Color(0.03, 0.04, 0.08, 0.75))
	c.draw_string(font, Vector2(10, 18), "소환 풀: " + _pool_text(), HORIZONTAL_ALIGNMENT_LEFT, 410, 10, Color(0.95, 0.9, 0.75))
	var rn := []
	for r in relics: rn.append(RELICS[r][0])
	c.draw_string(font, Vector2(10, 32), "유물: " + (", ".join(rn) if not rn.is_empty() else "없음"), HORIZONTAL_ALIGNMENT_LEFT, 410, 9, Color(0.8, 0.85, 1.0))
	# synergy lines between same-kin neighbours
	for i in range(units.size()):
		var ki: String = UNITS[units[i]["type"]]["kin"]
		for s in neighbours(units[i]["slot"]):
			var j := unit_at(s)
			if j > i and UNITS[units[j]["type"]]["kin"] == ki:
				var a := _hud_pos(cam.unproject_position(slot_pos(units[i]["slot"]) + Vector3(0, 0.2, 0)))
				var b := _hud_pos(cam.unproject_position(slot_pos(units[j]["slot"]) + Vector3(0, 0.2, 0)))
				c.draw_line(a, b, Color(KINS[ki][1], 0.85), 3.0)
	# right panel
	c.draw_rect(Rect2(430, 0, 210, 360), Color(0.03, 0.04, 0.08, 0.85))
	c.draw_string(font, Vector2(434, 18), "웨이브 %d / %d" % [wave, LAST_WAVE], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
	c.draw_string(font, Vector2(434, 36), "골드 %d" % gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.3))
	var danger := float(enemies.size()) / MAX_ALIVE
	c.draw_string(font, Vector2(434, 54), "요괴 %d / %d" % [enemies.size(), MAX_ALIVE], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1 - danger, 1 - danger))
	c.draw_rect(Rect2(530, 46, 100, 8), Color(0.2, 0.2, 0.25))
	c.draw_rect(Rect2(530, 46, 100 * minf(1, danger), 8), Color(1, 0.3, 0.2))
	c.draw_string(font, Vector2(530, 30), "다음 웨이브 %.0f초" % maxf(0, wave_t), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.8, 0.8, 0.9))
	if boss_alive:
		c.draw_string(font, Vector2(10, 56), "보스 제한시간 %.0f초" % boss_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.3, 0.3))
	if not choosing:
		for i in range(btns.size()): _draw_btn(i)
	# selected unit info
	if selected >= 0 and selected < units.size() and not choosing:
		var u: Dictionary = units[selected]
		var U: Dictionary = UNITS[u["type"]]
		var info := "%s %s  [%s 계열]\n%s\n공격력 %.0f  (시너지 이웃 %d)" % [TIER_NAMES[u["tier"]], U["n"], KINS[U["kin"]][0], U["d"], unit_damage(selected), synergy(selected)]
		c.draw_rect(Rect2(434, 300, 202, 56), Color(0.08, 0.09, 0.14, 0.95))
		c.draw_multiline_string(font, Vector2(438, 312), info, HORIZONTAL_ALIGNMENT_LEFT, 196, 9, 5, Color(0.92, 0.92, 0.97))
		var spos := _hud_pos(cam.unproject_position(slot_pos(u["slot"]) + Vector3(0, 2.0, 0)))
		c.draw_colored_polygon(PackedVector2Array([spos, spos + Vector2(-6, -9), spos + Vector2(6, -9)]), Color(1, 1, 0.3))
	c.draw_rect(Rect2(4, 334, 420, 22), Color(0.03, 0.04, 0.08, 0.8))
	c.draw_string(font, Vector2(10, 349), msg, HORIZONTAL_ALIGNMENT_LEFT, 410, 10, Color(1, 1, 1))
	for f in floaters:
		if cam.is_position_behind(f["pos"]): continue
		var lp := _hud_pos(cam.unproject_position(f["pos"]))
		c.draw_string(font, lp, f["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(f["color"].r, f["color"].g, f["color"].b, f["t"]))
	if choosing:
		c.draw_rect(Rect2(10, 70, 420, 228), Color(0.02, 0.02, 0.05, 0.92))
		c.draw_string(font, Vector2(20, 92), "웨이브 보상: 카드 1장을 고르세요", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.88, 0.5))
		for k in range(cards.size()):
			var r2 := Rect2(20 + k * 136, 110, 128, 150)
			var ct := card_text(cards[k])
			var col := Color(0.3, 0.55, 0.35) if cards[k]["kind"] == "add" else (Color(0.55, 0.3, 0.3) if cards[k]["kind"] == "remove" else Color(0.6, 0.48, 0.18))
			c.draw_rect(r2, Color(0.08, 0.09, 0.14) if _btn_at(_hud_pos(get_viewport().get_mouse_position())) != k else Color(0.14, 0.15, 0.22))
			c.draw_rect(Rect2(r2.position, Vector2(r2.size.x, 22)), col)
			c.draw_rect(r2, Color(1, 0.85, 0.4), false, 1.5)
			c.draw_string(font, r2.position + Vector2(6, 15), ct[0], HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color(1, 1, 1))
			c.draw_string(font, r2.position + Vector2(6, 42), ct[1], HORIZONTAL_ALIGNMENT_LEFT, 120, 13, Color(1, 0.92, 0.7))
			c.draw_multiline_string(font, r2.position + Vector2(6, 62), ct[2], HORIZONTAL_ALIGNMENT_LEFT, 116, 9, 7, Color(0.9, 0.9, 0.95))
		for i in range(btns.size()):
			if btns[i]["t"] != "": _draw_btn(i)
	if show_codex:
		c.draw_rect(Rect2(10, 42, 416, 290), Color(0.02, 0.02, 0.05, 0.96))
		c.draw_rect(Rect2(10, 42, 416, 290), Color(1, 0.85, 0.4), false, 1.5)
		var yy := 58.0
		c.draw_string(font, Vector2(18, yy), "도감 (아무 곳이나 클릭하면 닫힘)   시너지: 같은 계열 이웃 1명당 공격력 +12%", HORIZONTAL_ALIGNMENT_LEFT, 400, 10, Color(1, 0.88, 0.5))
		yy += 16
		for t in BASE_KEYS:
			var U2: Dictionary = UNITS[t]
			c.draw_string(font, Vector2(18, yy), "%s [%s]%s" % [U2["n"], KINS[U2["kin"]][0], "  (풀에 있음)" if pool.has(t) else ""], HORIZONTAL_ALIGNMENT_LEFT, 150, 9, KINS[U2["kin"]][1].lightened(0.3))
			c.draw_string(font, Vector2(150, yy), U2["d"], HORIZONTAL_ALIGNMENT_LEFT, 270, 9, Color(0.88, 0.88, 0.93))
			yy += 14
		yy += 6
		c.draw_string(font, Vector2(18, yy), "레시피 (각 재료는 희귀 등급 이상) — 발견 %d/%d" % [discovered.size(), HERO_KEYS.size()], HORIZONTAL_ALIGNMENT_LEFT, 400, 10, Color(1, 0.88, 0.5))
		yy += 15
		for hk in HERO_KEYS:
			var H: Dictionary = UNITS[hk]
			var rec_names := []
			for r3 in H["rec"]: rec_names.append(UNITS[r3]["n"])
			c.draw_string(font, Vector2(18, yy), "%s%s = %s" % ["★ " if discovered.has(hk) else "", H["n"], " + ".join(rec_names)], HORIZONTAL_ALIGNMENT_LEFT, 400, 9, Color(1, 0.85, 0.4) if discovered.has(hk) else Color(0.85, 0.85, 0.9))
			yy += 13
			c.draw_string(font, Vector2(30, yy), H["d"], HORIZONTAL_ALIGNMENT_LEFT, 390, 8, Color(0.7, 0.7, 0.78))
			yy += 13
	if over:
		c.draw_rect(Rect2(60, 140, 320, 60), Color(0, 0, 0, 0.8))
		c.draw_string(font, Vector2(60, 168), "승리!" if won else "패배", HORIZONTAL_ALIGNMENT_CENTER, 320, 22, Color(1, 0.9, 0.4))
		c.draw_string(font, Vector2(60, 190), lose_reason if not won else "처치 %d마리 · 영웅 %d명 발견" % [kills, discovered.size()], HORIZONTAL_ALIGNMENT_CENTER, 320, 10, Color(1, 1, 1))
	if hover_btn >= 0 and hover_btn < btns.size() and String(btns[hover_btn]["tip"]) != "" and not choosing:
		var tip: String = btns[hover_btn]["tip"]
		var sz := font.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, 196, 10)
		var r4: Rect2 = btns[hover_btn]["r"]
		var box := Rect2(r4.position.x - 216, clampf(r4.position.y, 4, 350 - sz.y), 210, sz.y + 14)
		c.draw_rect(box, Color(0.05, 0.06, 0.10, 0.97))
		c.draw_rect(box, Color(1, 0.85, 0.4), false, 1.2)
		c.draw_multiline_string(font, box.position + Vector2(7, 15), tip, HORIZONTAL_ALIGNMENT_LEFT, 196, 10, -1, Color(0.95, 0.95, 1))
