extends Node3D
# DIMHOLD 3D real-time prototype. Same rules as the 2D prototype (sim/game_state.gd, rules v0.2),
# driven by a clock: every PULSE seconds the blight spreads once (one "dusk"). Pause / 1x / 2x / 3x.
# All visuals are procedural low-poly primitives (no hand-made art).

const GS := preload("res://sim/game_state.gd")
const TX := preload("res://scripts/texts.gd")

const HEX := 1.0
const HEX_ROT := 0.0
const PULSE := 15.0
const VSETS := [["murk"], ["murk", "spore"], ["rime", "spore"], ["rust", "murk"], ["rime", "hollow"], ["murk", "rime", "spore", "rust", "hollow"]]
const VNAMES_KO := ["머크", "머크+포자", "서리+포자", "녹+머크", "서리+공허", "5종 전부"]
const T_COLOR := {
	"meadow": Color(0.42, 0.66, 0.33), "woodland": Color(0.24, 0.48, 0.27), "hill": Color(0.62, 0.56, 0.38),
	"marsh": Color(0.33, 0.47, 0.40), "ruins": Color(0.56, 0.54, 0.56), "crystal": Color(0.50, 0.78, 0.86),
	"shore": Color(0.32, 0.52, 0.78), "salt": Color(0.86, 0.85, 0.80), "frost": Color(0.74, 0.86, 0.94),
	"cinder": Color(0.36, 0.29, 0.27),
}
const T_HEIGHT := {"meadow": 0.30, "woodland": 0.34, "hill": 0.70, "marsh": 0.18, "ruins": 0.32, "crystal": 0.42, "shore": 0.12, "salt": 0.26, "frost": 0.28, "cinder": 0.22}
const V_COLOR := {"murk": Color(0.30, 0.10, 0.45), "rime": Color(0.45, 0.80, 0.95), "spore": Color(0.75, 0.62, 0.12), "rust": Color(0.65, 0.30, 0.10), "hollow": Color(0.04, 0.03, 0.08)}

var g: RefCounted
var vset_idx := 0
var seed_n := 11
var tiles: Array = []          # MeshInstance3D
var tile_key: Array = []       # String: "terrain|lit|scar" to avoid rebuilding
var caps: Array = []           # blight cap MeshInstance3D
var cap_h: Array = []          # displayed blight height
var snodes: Dictionary = {}    # tile -> Node3D (structure)
var markers: Dictionary = {}   # tile -> Node3D (danger)
var rift_nodes: Dictionary = {}
var cam: Camera3D
var cam_target := Vector3.ZERO
var cam_dist := 15.0
var cam_yaw := 0.0
var cam_pitch := deg_to_rad(52.0)
var sun: DirectionalLight3D
var env: Environment
var speed := 1
var pulse_t := 0.0
var placed := false
var mode := ""
var card_idx := -1
var build_name := ""
var selected := -1
var hover := -1
var msg := ""
var fc: Array = []
var hud: Control
var font: Font
var btns: Array = []
var hover_btn := -1
var mouse := Vector2.ZERO
var show_guide := true
var dragging := false
var mats: Dictionary = {}
var flash: Dictionary = {}
var flash_t := 0.0
var t_acc := 0.0


func T(en: String, kr: String) -> String:
	return kr


func N(k: String) -> String:
	return TX.STRUCT_KO[k][0] if TX.STRUCT_KO.has(k) else k


# ---------------- setup ----------------
func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Apple SD Gothic Neo", "NanumGothic", "WenQuanYi Zen Hei", "sans-serif"])
	sf.fallbacks = [ThemeDB.fallback_font]
	sf.multichannel_signed_distance_field = true
	font = sf
	_setup_world()
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.draw.connect(_draw_hud)
	_new_game()


func _setup_world() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.62)
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.08, 0.16)
	env.fog_density = 0.012
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 45
	cam.h_offset = 2.4
	add_child(cam)
	_update_cam()
	# ground plate under the board
	var ground := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 9.5; gm.bottom_radius = 10.5; gm.height = 0.3; gm.radial_segments = 6
	ground.mesh = gm
	ground.position = Vector3(0, -0.16, 0)
	ground.material_override = _mat(Color(0.10, 0.10, 0.14))
	add_child(ground)


func _new_game() -> void:
	for n in tiles: n.queue_free()
	for n in caps: n.queue_free()
	for k in snodes: snodes[k].queue_free()
	for k in markers: markers[k].queue_free()
	for k in rift_nodes: rift_nodes[k].queue_free()
	tiles.clear(); caps.clear(); cap_h.clear(); tile_key.clear(); snodes.clear(); markers.clear(); rift_nodes.clear()
	g = GS.new()
	g.setup(seed_n, VSETS[vset_idx])
	g.dawn()
	g.lp = 99
	placed = false; mode = ""; card_idx = -1; build_name = ""; selected = -1; pulse_t = 0.0; speed = 1
	for i in range(GS.N):
		var mi := MeshInstance3D.new()
		mi.rotation.y = deg_to_rad(HEX_ROT)
		add_child(mi)
		tiles.append(mi); tile_key.append("")
		var cap := MeshInstance3D.new()
		cap.mesh = _hex_mesh(HEX * 0.86, 1.0)
		cap.rotation.y = deg_to_rad(HEX_ROT)
		cap.visible = false
		add_child(cap)
		caps.append(cap); cap_h.append(0.0)
	msg = "실시간으로 오염이 번집니다. Space = 일시정지. 오른쪽 '카드'로 땅을 넓히고 건물을 지으세요."
	_sync_all()


# ---------------- helpers ----------------
func _mat(c: Color, emis: Color = Color.BLACK, e: float = 0.0, rough: float = 0.85) -> StandardMaterial3D:
	var key := "%s|%s|%.2f|%.2f" % [c.to_html(), emis.to_html(), e, rough]
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if e > 0.0:
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = e
	mats[key] = m
	return m


func _hex_mesh(r: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 6; cm.rings = 1
	return cm


func _cone(r: float, h: float, seg: int = 6) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0; cm.bottom_radius = r; cm.height = h; cm.radial_segments = seg; cm.rings = 1
	return cm


func _cyl(r: float, h: float, seg: int = 8) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = seg; cm.rings = 1
	return cm


func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = m; mi.position = pos; mi.rotation = rot
	parent.add_child(mi)
	return mi


func _light(parent: Node3D, c: Color, rng: float, energy: float, y: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c; l.omni_range = rng; l.light_energy = energy; l.position = Vector3(0, y, 0)
	l.set_meta("base_energy", energy)
	parent.add_child(l)
	return l


func hex_world(i: int) -> Vector3:
	var c: Vector2i = GS.COORDS[i]
	return Vector3(HEX * sqrt(3.0) * (c.x + c.y / 2.0), 0, HEX * 1.5 * c.y)


func top_y(i: int) -> float:
	if g.scar[i]: return 0.06
	return T_HEIGHT[g.terrain[i]]


func world_to_tile(p: Vector3) -> int:
	var q := (sqrt(3.0) / 3.0 * p.x - p.z / 3.0) / HEX
	var r := (2.0 / 3.0 * p.z) / HEX
	var x := q; var z := r; var y := -x - z
	var rx := roundf(x); var ry := roundf(y); var rz := roundf(z)
	var dx := absf(rx - x); var dy := absf(ry - y); var dz := absf(rz - z)
	if dx > dy and dx > dz: rx = -ry - rz
	elif dy > dz: ry = -rx - rz
	else: rz = -rx - ry
	var k := Vector2i(int(rx), int(rz))
	return GS.IDX.get(k, -1)


func pick_tile(sp: Vector2) -> int:
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if absf(d.y) < 0.001: return -1
	var t := (0.3 - o.y) / d.y
	if t < 0: return -1
	return world_to_tile(o + d * t)


# ---------------- visuals sync ----------------
func _sync_all() -> void:
	fc = g.forecast()
	var frontier: Array = g.frontier() if mode == "card" and not placed else []
	for i in range(GS.N):
		_sync_tile(i, frontier.has(i))
		_sync_struct(i)
		_sync_rift(i)
	_sync_markers()
	hud.queue_redraw()


func _sync_tile(i: int, is_frontier: bool) -> void:
	var mi: MeshInstance3D = tiles[i]
	var key := "%s|%s|%s|%s|%s" % [g.terrain[i], g.lit[i], g.scar[i], is_frontier, i == selected]
	if tile_key[i] == key: return
	tile_key[i] = key
	var h := top_y(i)
	mi.mesh = _hex_mesh(HEX * 0.96, h)
	var p := hex_world(i)
	mi.position = Vector3(p.x, h / 2.0, p.z)
	var c: Color = T_COLOR[g.terrain[i]]
	var m: StandardMaterial3D
	if g.scar[i]:
		m = _mat(Color(0.05, 0.04, 0.05))
	elif g.lit[i]:
		m = _mat(c, c, 0.08) if i != selected else _mat(c.lightened(0.25), Color(1, 1, 0.8), 0.25)
	else:
		m = _mat(c.darkened(0.55).lerp(Color(0.2, 0.2, 0.3), 0.35))
	if is_frontier:
		m = _mat(c.darkened(0.3), Color(1, 0.85, 0.25), 0.9)
	mi.material_override = m
	for ch in mi.get_children(): ch.queue_free()
	if not g.scar[i]: _decorate(mi, i, h)


func _decorate(mi: MeshInstance3D, i: int, h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 7919 + 13
	var t: String = g.terrain[i]
	var dim := 1.0 if g.lit[i] else 0.45
	if t == "woodland":
		for k in range(3):
			var off := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
			_part(mi, _cyl(0.05, 0.18), _mat(Color(0.35, 0.22, 0.12) * dim), off + Vector3(0, h / 2 + 0.09, 0))
			_part(mi, _cone(0.22, 0.5), _mat(Color(0.16, 0.42, 0.22) * dim), off + Vector3(0, h / 2 + 0.42, 0))
	elif t == "hill":
		_part(mi, _cone(0.42, 0.32, 5), _mat(Color(0.55, 0.50, 0.36) * dim), Vector3(0.15, h / 2 + 0.16, -0.1))
	elif t == "crystal":
		for k in range(2):
			var off2 := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
			_part(mi, _cone(0.12, 0.5, 4), _mat(Color(0.6, 0.9, 1.0), Color(0.4, 0.9, 1.0), 1.2 * dim), off2 + Vector3(0, h / 2 + 0.25, 0))
	elif t == "ruins":
		_part(mi, _cyl(0.09, 0.4), _mat(Color(0.6, 0.6, 0.62) * dim), Vector3(0.3, h / 2 + 0.2, 0.1))
		_part(mi, BoxMesh.new(), _mat(Color(0.55, 0.55, 0.58) * dim), Vector3(-0.2, h / 2 + 0.05, -0.2))
	elif t == "shore":
		_part(mi, _hex_mesh(0.7, 0.02), _mat(Color(0.3, 0.55, 0.85), Color(0.2, 0.4, 0.8), 0.3, 0.1), Vector3(0, h / 2 + 0.01, 0))


func _sync_struct(i: int) -> void:
	var name: String = g.structs[i]
	var cur: Node3D = snodes.get(i, null)
	if cur != null and (String(cur.get_meta("kind")) != name or name == ""):
		cur.queue_free(); snodes.erase(i); cur = null
	if name != "" and cur == null:
		cur = _make_struct(name)
		cur.set_meta("kind", name)
		add_child(cur)
		snodes[i] = cur
	if cur != null:
		var p := hex_world(i)
		cur.position = Vector3(p.x, top_y(i), p.z)
		var off: bool = g.disabled(i) or g.dark.has(i)
		for ch in cur.get_children():
			if ch is OmniLight3D:
				ch.light_energy = 0.0 if off else float(ch.get_meta("base_energy"))


func _make_struct(n: String) -> Node3D:
	var s := Node3D.new()
	var wood := _mat(Color(0.42, 0.28, 0.16))
	var stone := _mat(Color(0.58, 0.58, 0.62))
	var iron := _mat(Color(0.22, 0.22, 0.25))
	var warm := Color(1.0, 0.75, 0.35)
	match n:
		"hearth":
			_part(s, _hex_mesh(0.55, 0.18), stone, Vector3(0, 0.09, 0))
			_part(s, _cone(0.32, 1.1, 4), _mat(Color(1, 0.85, 0.45), Color(1, 0.75, 0.3), 2.5), Vector3(0, 0.75, 0))
			_part(s, _cone(0.32, 0.5, 4), _mat(Color(1, 0.85, 0.45), Color(1, 0.75, 0.3), 2.5), Vector3(0, 0.0 + 0.2, 0), Vector3(PI, 0, 0))
			_light(s, warm, 5.0, 2.2, 1.0)
		"lantern":
			_part(s, _cyl(0.05, 0.75), iron, Vector3(0, 0.37, 0))
			_part(s, SphereMesh.new(), _mat(Color(1, 0.85, 0.5), warm, 3.0), Vector3(0, 0.82, 0)).scale = Vector3(0.26, 0.26, 0.26)
			_light(s, warm, 2.8, 1.3, 0.9)
		"brazier":
			_part(s, _cyl(0.06, 0.3), iron, Vector3(0, 0.15, 0))
			var bowl := CylinderMesh.new(); bowl.top_radius = 0.3; bowl.bottom_radius = 0.12; bowl.height = 0.22; bowl.radial_segments = 8
			_part(s, bowl, iron, Vector3(0, 0.4, 0))
			_part(s, _cone(0.2, 0.45, 5), _mat(Color(1, 0.5, 0.1), Color(1, 0.45, 0.05), 4.0), Vector3(0, 0.72, 0))
			_light(s, Color(1, 0.55, 0.2), 2.8, 1.5, 0.9)
		"beacon":
			_part(s, _cyl(0.22, 1.4, 6), stone, Vector3(0, 0.7, 0))
			_part(s, _cone(0.3, 0.35, 6), stone, Vector3(0, 1.57, 0))
			_part(s, SphereMesh.new(), _mat(Color(1, 0.95, 0.7), Color(1, 0.85, 0.45), 5.0), Vector3(0, 1.3, 0)).scale = Vector3(0.3, 0.3, 0.3)
			_light(s, Color(1, 0.85, 0.5), 4.5, 2.2, 1.4)
		"palisade":
			for k in range(9):
				var a := TAU * k / 9.0
				_part(s, _cone(0.06, 0.55, 4), wood, Vector3(cos(a) * 0.62, 0.27, sin(a) * 0.62))
		"rampart":
			for k in range(6):
				var a2 := TAU * k / 6.0 + PI / 6.0
				var b := BoxMesh.new(); b.size = Vector3(0.7, 0.45, 0.16)
				_part(s, b, stone, Vector3(cos(a2) * 0.66, 0.22, sin(a2) * 0.66), Vector3(0, -a2 + PI / 2, 0))
		"pyre":
			for k in range(3):
				var lg := _cyl(0.06, 0.6, 6)
				_part(s, lg, wood, Vector3(0, 0.1 + k * 0.08, 0), Vector3(PI / 2, TAU * k / 3.0, 0))
			_part(s, _cone(0.28, 0.7, 5), _mat(Color(0.9, 0.2, 0.1), Color(1, 0.2, 0.05), 3.0), Vector3(0, 0.6, 0))
			_light(s, Color(1, 0.3, 0.1), 2.2, 1.0, 0.7)
		"sunwell":
			var tor := TorusMesh.new(); tor.inner_radius = 0.28; tor.outer_radius = 0.45
			_part(s, tor, stone, Vector3(0, 0.12, 0))
			_part(s, _hex_mesh(0.28, 0.05), _mat(Color(1, 0.95, 0.6), Color(1, 0.9, 0.5), 3.0, 0.1), Vector3(0, 0.15, 0))
			_light(s, Color(1, 0.95, 0.6), 2.5, 1.2, 0.6)
		"camp":
			var tent := CylinderMesh.new(); tent.top_radius = 0.0; tent.bottom_radius = 0.35; tent.height = 0.45; tent.radial_segments = 3
			_part(s, tent, _mat(Color(0.75, 0.62, 0.42)), Vector3(-0.15, 0.22, 0))
			var lb := BoxMesh.new(); lb.size = Vector3(0.4, 0.12, 0.12)
			_part(s, lb, wood, Vector3(0.25, 0.06, 0.2))
		"cottage":
			var bx := BoxMesh.new(); bx.size = Vector3(0.55, 0.35, 0.45)
			_part(s, bx, _mat(Color(0.82, 0.76, 0.62)), Vector3(0, 0.17, 0))
			_part(s, _cone(0.45, 0.35, 4), _mat(Color(0.55, 0.25, 0.18)), Vector3(0, 0.52, 0), Vector3(0, PI / 4, 0))
		"press":
			_part(s, _cyl(0.22, 0.5, 8), wood, Vector3(0, 0.25, 0))
			_part(s, _cyl(0.12, 0.1, 8), _mat(Color(1, 0.9, 0.5), warm, 2.0), Vector3(0, 0.55, 0))
	return s


func _sync_rift(i: int) -> void:
	var is_rift: bool = g.rift.has(i)
	if is_rift and not rift_nodes.has(i):
		var r := Node3D.new()
		var vc: Color = V_COLOR.get(g.var_[i], Color(0.4, 0.1, 0.6))
		for k in range(5):
			var a := TAU * k / 5.0
			_part(r, _cone(0.16, 0.9 + 0.2 * (k % 2), 4), _mat(Color(0.05, 0.03, 0.07)), Vector3(cos(a) * 0.3, 0.45, sin(a) * 0.3), Vector3(cos(a) * 0.35, 0, -sin(a) * 0.35))
		_part(r, SphereMesh.new(), _mat(vc, Color(1, 0.15, 0.3), 3.0), Vector3(0, 0.35, 0)).scale = Vector3(0.45, 0.45, 0.45)
		_light(r, Color(1, 0.2, 0.35), 3.0, 1.6, 0.6)
		var p := hex_world(i)
		r.position = Vector3(p.x, top_y(i) + 0.2, p.z)
		add_child(r)
		rift_nodes[i] = r
	elif not is_rift and rift_nodes.has(i):
		rift_nodes[i].queue_free(); rift_nodes.erase(i)


func _sync_markers() -> void:
	var pr: Array = fc[2]; var gd: Array = fc[3]
	for i in range(GS.N):
		var danger: bool = g.lit[i] and not g.scar[i] and pr[i] > gd[i]
		if danger and not markers.has(i):
			var mk := Node3D.new()
			_part(mk, _cone(0.22, 0.45, 4), _mat(Color(1, 0.15, 0.15), Color(1, 0.1, 0.1), 3.0), Vector3.ZERO, Vector3(PI, 0, 0))
			add_child(mk)
			markers[i] = mk
		elif not danger and markers.has(i):
			markers[i].queue_free(); markers.erase(i)
		if markers.has(i):
			var p := hex_world(i)
			markers[i].position = Vector3(p.x, top_y(i) + 1.6, p.z)


# ---------------- real-time loop ----------------
func _process(delta: float) -> void:
	t_acc += delta
	if not g.over and speed > 0:
		pulse_t += delta * speed
		if pulse_t >= PULSE:
			pulse_t -= PULSE
			_pulse()
	# blight caps grow smoothly toward their target height
	for i in range(GS.N):
		var target: float = 0.0 if (g.inten[i] == 0 or g.scar[i]) else 0.10 + 0.17 * g.inten[i]
		cap_h[i] = lerpf(cap_h[i], target, clampf(delta * 2.5, 0, 1))
		var cap: MeshInstance3D = caps[i]
		if cap_h[i] < 0.01:
			cap.visible = false
			continue
		cap.visible = true
		var wob := 1.0 + 0.04 * sin(t_acc * 2.0 + i)
		cap.scale = Vector3(wob, cap_h[i], wob)
		var p := hex_world(i)
		cap.position = Vector3(p.x, top_y(i) + cap_h[i] / 2.0, p.z)
		var vc: Color = V_COLOR.get(g.var_[i], Color(0.4, 0.1, 0.6))
		cap.material_override = _mat(vc.darkened(0.35 - 0.08 * g.inten[i]), vc, 0.12 + 0.12 * g.inten[i], 0.3)
	for i in markers:
		var mk: Node3D = markers[i]
		mk.rotation.y = t_acc * 2.0
		var p2 := hex_world(i)
		mk.position.y = top_y(i) + 1.5 + 0.12 * sin(t_acc * 4.0)
	for i in rift_nodes:
		rift_nodes[i].rotation.y = t_acc * 0.4
	# dusk mood: light reddens and dims as the next spread approaches
	var k := pulse_t / PULSE
	sun.light_energy = lerpf(1.15, 0.45, k * k)
	sun.light_color = Color(1, 0.97, 0.9).lerp(Color(1, 0.45, 0.35), k * k)
	env.ambient_light_energy = lerpf(0.6, 0.3, k)
	if flash_t > 0: flash_t -= delta
	_update_cam_keys(delta)
	hud.queue_redraw()


func _pulse() -> void:
	var prev_lit: Array = g.lit.duplicate()
	g.end_day()
	var lost := 0
	for i in range(GS.N):
		if prev_lit[i] and not g.lit[i]: lost += 1
	if g.over:
		msg = "승리! 끝까지 버텼습니다. R = 새 게임" if g.won else "패배... 본진이 먹혔습니다. R = 새 게임"
		speed = 0
	else:
		g.dawn()
		g.lp = 99
		placed = false
		if mode == "card": mode = ""
		msg = "오염이 번졌습니다. %s" % ("땅 %d칸을 잃었습니다!" % lost if lost > 0 else "땅을 지켰습니다.")
	flash_t = 1.5
	_sync_all()


# ---------------- camera ----------------
func _update_cam() -> void:
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * cam_dist
	cam.position = cam_target + off
	cam.look_at(cam_target, Vector3.UP)


func _update_cam_keys(delta: float) -> void:
	var mv := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): mv.z -= 1
	if Input.is_key_pressed(KEY_S): mv.z += 1
	if Input.is_key_pressed(KEY_A): mv.x -= 1
	if Input.is_key_pressed(KEY_D): mv.x += 1
	if Input.is_key_pressed(KEY_Q): cam_yaw -= delta * 1.5
	if Input.is_key_pressed(KEY_E): cam_yaw += delta * 1.5
	if mv != Vector3.ZERO or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E):
		cam_target += mv.normalized().rotated(Vector3.UP, cam_yaw) * delta * 8.0
		cam_target = cam_target.limit_length(9.0)
		_update_cam()


# ---------------- actions ----------------
func _on_card(k: int) -> void:
	if placed: return
	mode = "card"; card_idx = k; build_name = ""
	msg = "노란색으로 빛나는 칸을 클릭해 %s 타일을 놓으세요." % TX.TERR_KO[g.cards[k]].split(":")[0]
	_sync_all()


func _on_build(n: String) -> void:
	mode = "build"; build_name = n; card_idx = -1
	msg = "%s: 밝은 내 땅의 빈 칸을 클릭하세요. (Esc 취소)" % N(n)
	_sync_all()


func _click_tile(i: int) -> void:
	if g.over: return
	if mode == "card" and card_idx >= 0 and not placed:
		if g.frontier().has(i):
			g.place_tile(i, card_idx); placed = true; mode = ""; card_idx = -1
			msg = "영토를 넓혔습니다. 다음 확산 때 새 카드가 나옵니다."
		else:
			msg = "노란색으로 빛나는 칸만 놓을 수 있습니다."
	elif mode == "build" and build_name != "":
		if g.can_build(build_name, i):
			g.build(build_name, i); g.lp = 99
			msg = "%s 건설 완료." % N(build_name)
		else:
			msg = "여기엔 지을 수 없습니다 (자원 부족, 오염 강도 2 이상, 이미 건물 있음, 또는 내 땅이 아님)."
	else:
		selected = i
		for k in tile_key.size(): tile_key[k] = ""
	_sync_all()


func _ability(kind: String) -> void:
	if selected < 0 or g.over: return
	if kind == "burst" and g.can_burst(selected):
		g.burst(selected); msg = "봉화 정화! 주변 오염 -1"
	elif kind == "pyre" and g.can_pyre(selected):
		g.pyre_fire(selected); msg = "화염 발사! 주변 약한 오염 제거"
	elif kind == "seal":
		var t: Array = g.seal_targets(selected)
		if not t.is_empty():
			g.seal(selected, t[0]); msg = "균열 봉인!"
	g.lp = 99
	_sync_all()


func _set_speed(s: int) -> void:
	speed = s
	hud.queue_redraw()


# ---------------- input ----------------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = e.position
		var hp := _hud_pos(e.position)
		hover_btn = _btn_at(hp)
		if dragging:
			cam_yaw -= e.relative.x * 0.006
			cam_pitch = clampf(cam_pitch + e.relative.y * 0.004, deg_to_rad(25), deg_to_rad(80))
			_update_cam()
		var h := -1 if hover_btn >= 0 or hp.x > 388 else pick_tile(e.position)
		if h != hover:
			hover = h
		hud.queue_redraw()
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			cam_dist = clampf(cam_dist - 1.0, 6.0, 26.0); _update_cam()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			cam_dist = clampf(cam_dist + 1.0, 6.0, 26.0); _update_cam()
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			if show_guide:
				show_guide = false; hud.queue_redraw(); return
			var hp2 := _hud_pos(e.position)
			var bi := _btn_at(hp2)
			if bi >= 0:
				if btns[bi]["on"]: btns[bi]["cb"].call()
				return
			if hp2.x > 388: return
			var i := pick_tile(e.position)
			if i >= 0: _click_tile(i)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE: _set_speed(0 if speed > 0 else 1)
			KEY_1: _set_speed(1)
			KEY_2: _set_speed(2)
			KEY_3: _set_speed(3)
			KEY_R: _new_game()
			KEY_H: show_guide = not show_guide
			KEY_ESCAPE:
				mode = ""; card_idx = -1; build_name = ""; selected = -1
				for k in tile_key.size(): tile_key[k] = ""
				_sync_all()
			KEY_M: get_tree().change_scene_to_file("res://scenes/main.tscn")


func _hud_pos(p: Vector2) -> Vector2:
	# HUD is laid out in 640x360 logical units (canvas_items stretch)
	return hud.get_global_transform_with_canvas().affine_inverse() * p


# ---------------- HUD ----------------
func _btn(t: String, r: Rect2, cb: Callable, on: bool, act: bool, tip: String = "") -> void:
	btns.append({"r": r, "t": t, "cb": cb, "on": on, "act": act, "tip": tip})


func _btn_at(p: Vector2) -> int:
	for i in range(btns.size()):
		if btns[i]["r"].has_point(p): return i
	return -1


func _build_buttons() -> void:
	btns.clear()
	var x := 392.0
	var y := 64.0
	for s in range(4):
		var lab: String = ["일시정지", "1배속", "2배속", "3배속"][s]
		_btn(lab, Rect2(8 + s * 58, 40, 55, 15), _set_speed.bind(s), true, speed == s, "시간 흐름. Space = 일시정지/재개, 숫자 1·2·3 = 배속.\n일시정지 중에도 건설할 수 있습니다.")
	if not g.over:
		for k in range(g.cards.size()):
			var tdesc: String = TX.TERR_KO[g.cards[k]]
			_btn("카드 %d: %s%s" % [k + 1, tdesc.split(":")[0], "  (사용됨)" if placed else ""], Rect2(x, y, 236, 14), _on_card.bind(k), not placed, mode == "card" and card_idx == k, "이 지형으로 영토를 한 칸 넓힙니다. 오염이 한 번 번질 때마다 1번.\n\n" + tdesc)
			y += 16
		y += 4
		var col := 0
		for n in GS.BUILD_ORDER:
			var c: Array = GS.STRUCT[n]
			var d: Array = TX.STRUCT_KO[n]
			_btn("%s  자재%d 빛%d" % [d[0], c[0], c[1]], Rect2(x + col * 120.0, y, 116, 14), _on_build.bind(n), g.M >= c[0] and g.L >= c[1], mode == "build" and build_name == n, "%s\n%s\n\n%s\n\n비용: 자재 %d, 빛 %d" % [d[0], d[1], d[2], c[0], c[1]])
			col += 1
			if col == 2:
				col = 0; y += 16
		y += 4
		_btn("정화 (봉화 선택)", Rect2(x, y, 116, 14), _ability.bind("burst"), selected >= 0 and g.can_burst(selected), false, TX.STRUCT_KO["beacon"][2])
		_btn("화염 발사 (화염탑)", Rect2(x + 120, y, 116, 14), _ability.bind("pyre"), selected >= 0 and g.can_pyre(selected), false, TX.STRUCT_KO["pyre"][2])
		y += 16
		_btn("균열 봉인 (태양우물)", Rect2(x, y, 116, 14), _ability.bind("seal"), selected >= 0 and not g.seal_targets(selected).is_empty(), false, TX.STRUCT_KO["sunwell"][2])
	_btn("오염: %s" % VNAMES_KO[vset_idx], Rect2(x + 120, y, 116, 14), _next_vset, true, false, "오염 종류를 바꾸고 새로 시작합니다.")
	y += 18
	_btn("도움말 (H)", Rect2(x, y, 76, 14), func(): show_guide = not show_guide, true, show_guide)
	_btn("새 게임 (R)", Rect2(x + 80, y, 76, 14), _new_game, true, false)
	_btn("2D 메뉴 (M)", Rect2(x + 160, y, 76, 14), func(): get_tree().change_scene_to_file("res://scenes/main.tscn"), true, false, "이전 2D 턴제 프로토타입 메뉴로 돌아갑니다.")


func _next_vset() -> void:
	vset_idx = (vset_idx + 1) % VSETS.size()
	seed_n += 1
	_new_game()


func _draw_hud() -> void:
	_build_buttons()
	var c := hud
	# status
	c.draw_rect(Rect2(4, 4, 236, 54), Color(0.03, 0.04, 0.08, 0.82))
	c.draw_string(font, Vector2(10, 17), "확산 %d/%d회   균열 %d   봉인 %d" % [g.day, g.days, g.rift.size(), g.sealed], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1))
	c.draw_string(font, Vector2(10, 31), "자재 %d   빛 %d   점등 %d칸" % [g.M, g.L, g.lit_count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.92, 0.7))
	var k := pulse_t / PULSE
	c.draw_rect(Rect2(244, 6, 140, 16), Color(0.1, 0.1, 0.15, 0.85))
	c.draw_rect(Rect2(244, 6, 140 * k, 16), Color(0.55, 0.2, 0.3).lerp(Color(0.9, 0.12, 0.18), k))
	var left := (PULSE - pulse_t) / maxf(1, speed)
	c.draw_string(font, Vector2(250, 18), ("일시정지" if speed == 0 else "다음 확산까지 %.1f초" % left), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1))
	# right panel background
	c.draw_rect(Rect2(388, 0, 252, 360), Color(0.03, 0.04, 0.08, 0.78))
	c.draw_string(font, Vector2(392, 16), "건설하려면 버튼 → 지도 클릭", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.45))
	c.draw_string(font, Vector2(392, 32), "카드로 땅 넓히기 · 빨간 피라미드 = 위험", HORIZONTAL_ALIGNMENT_LEFT, 244, 9, Color(0.85, 0.85, 0.95))
	c.draw_string(font, Vector2(392, 46), "우클릭 드래그 회전 · 휠 확대 · WASD 이동", HORIZONTAL_ALIGNMENT_LEFT, 244, 9, Color(0.7, 0.7, 0.8))
	for i in range(btns.size()):
		var b: Dictionary = btns[i]
		var r: Rect2 = b["r"]
		var bg := Color(0.20, 0.24, 0.34, 0.95)
		if not b["on"]: bg = Color(0.11, 0.12, 0.16, 0.9)
		elif b["act"]: bg = Color(0.55, 0.45, 0.15, 0.95)
		elif i == hover_btn: bg = Color(0.32, 0.38, 0.55, 0.95)
		c.draw_rect(r, bg)
		c.draw_rect(r, Color(0.5, 0.55, 0.7) if b["on"] else Color(0.25, 0.26, 0.32), false, 1.0)
		c.draw_string(font, r.position + Vector2(4, r.size.y - 3.5), b["t"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 9, Color(1, 1, 1) if b["on"] else Color(0.45, 0.45, 0.5))
	# message + hover info
	var info := msg
	if hover >= 0:
		var pr: Array = fc[2]; var gd: Array = fc[3]
		info += "\n\n[%s]%s%s" % [TX.TERR_KO[g.terrain[hover]].split(":")[0], "  내 땅" if g.lit[hover] else "  야생", "  파괴됨" if g.scar[hover] else ""]
		if g.structs[hover] != "": info += "\n%s: %s" % [TX.STRUCT_KO[g.structs[hover]][0], TX.STRUCT_KO[g.structs[hover]][1]]
		if g.inten[hover] > 0 and g.var_[hover] != "": info += "\n오염 강도 %d - %s" % [g.inten[hover], TX.VAR_KO[g.var_[hover]][1]]
		if g.lit[hover]: info += "\n압력 %d / 방어 %d  →  %s" % [pr[hover], gd[hover], "다음 확산 때 위험!" if pr[hover] > gd[hover] else "안전"]
	var ih := font.get_multiline_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, 368, 9).y + 10
	c.draw_rect(Rect2(4, 356 - ih, 380, ih), Color(0.03, 0.04, 0.08, 0.78))
	c.draw_multiline_string(font, Vector2(10, 356 - ih + 12), info, HORIZONTAL_ALIGNMENT_LEFT, 368, 9, 6, Color(0.92, 0.92, 0.97))
	if g.over:
		c.draw_rect(Rect2(60, 140, 270, 50), Color(0, 0, 0, 0.8))
		c.draw_string(font, Vector2(60, 172), "승리!" if g.won else "패배", HORIZONTAL_ALIGNMENT_CENTER, 270, 24, Color(1, 0.9, 0.4))
	if show_guide:
		c.draw_rect(Rect2(20, 64, 360, 226), Color(0.02, 0.02, 0.06, 0.95))
		c.draw_rect(Rect2(20, 64, 360, 226), Color(1, 0.85, 0.4), false, 1.5)
		var lines := [
			"3D 실시간 프로토타입 (아무 곳이나 클릭하면 닫힘, H로 다시 열기)",
			"",
			"목표: 확산 12번 동안 가운데 빛나는 '본진'을 지키기.",
			"균열(빨간 빛)에서 오염이 나와 위의 막대가 찰 때마다 번집니다.",
			"Space로 언제든 일시정지하고 생각할 수 있습니다.",
			"",
			"1) 오른쪽 '카드'를 누르고 노랗게 빛나는 칸 클릭 = 땅 넓히기",
			"2) 건물 버튼을 누르고 내 땅 클릭 = 건설 (버튼에 마우스를 올리면 설명)",
			"3) 빨간 피라미드가 뜬 칸 = 다음 확산 때 먹힐 칸. 등불·목책으로 막기",
			"",
			"조작: 우클릭 드래그 회전 · 휠 확대 · WASD/QE 이동 · 1/2/3 배속",
		]
		var yy := 84.0
		for ln in lines:
			c.draw_string(font, Vector2(30, yy), ln, HORIZONTAL_ALIGNMENT_LEFT, 344, 9 if yy > 84 else 10, Color(1, 0.9, 0.5) if yy < 85 else Color(0.92, 0.92, 0.97))
			yy += 18
	# tooltip
	if hover_btn >= 0 and hover_btn < btns.size() and String(btns[hover_btn]["tip"]) != "":
		var tip: String = btns[hover_btn]["tip"]
		var w := 230.0
		var sz := font.get_multiline_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, w - 14, 9)
		var r2: Rect2 = btns[hover_btn]["r"]
		var bx := r2.position.x - w - 6 if r2.position.x > 300 else r2.position.x
		var by := clampf(r2.position.y + (0 if r2.position.x > 300 else 20), 4, 356 - sz.y - 14)
		var box := Rect2(bx, by, w, sz.y + 14)
		c.draw_rect(box, Color(0.05, 0.06, 0.10, 0.97))
		c.draw_rect(box, Color(1, 0.85, 0.4), false, 1.2)
		c.draw_multiline_string(font, box.position + Vector2(7, 14), tip, HORIZONTAL_ALIGNMENT_LEFT, w - 14, 9, -1, Color(0.95, 0.95, 1))
