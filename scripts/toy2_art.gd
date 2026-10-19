extends RefCounted
# Procedural low-poly art for toy 2 (도깨비 디펜스): moonlit Joseon village, units, yokai, projectiles, effects.
# Visual only: never reads or writes game state and uses its own RNG, so headless balance tests are unaffected.
# Direction: docs/design/11_dokkaebi_develop.md (cold moonlight vs warm lanterns, silhouettes read from above).

const SKIN := Color(0.96, 0.84, 0.72)
const INK := Color(0.06, 0.06, 0.07)
const GOLD := Color(1.0, 0.78, 0.25)
const PROJ := {
	"dokkaebi": "club", "dokkaebi_king": "club", "gungsa": "arrow", "chakho": "arrow", "posu": "bullet",
	"mudang": "bell", "mulgwisin": "water", "haetae": "roar", "gumiho": "foxfire", "cheonnyeon": "foxfire",
	"jeoseung": "talisman", "yeomra": "talisman", "dokkaebibul": "foxfire", "ssireum": "club", "bihyeong": "talisman",
	"gwigyo": "talisman", "samjogo": "roar", "hyeonmu": "water", "hwarang": "arrow", "seungbyeong": "bell", "agijangsu": "arrow",
	"cheoyong": "bell", "pansu": "talisman", "bari": "water", "cheoyongrang": "bell", "jeonuchi": "talisman", "honggildong": "arrow",
	"baksi": "talisman", "mago": "roar", "hwalbin": "arrow", "panokseon": "bullet", "geobukseon": "bullet", "yongwang": "water",
	"tongjesa": "bullet", "hogukryong": "water",
}

var root: Node3D
var headless := false
var mats := {}
var meshes := {}
var vrng := RandomNumberGenerator.new()
var anims: Array = []    # ambient loops: {node, kind, base, ph, sp, amp}
var effects: Array = []  # short-lived: {node, kind, t, life, vel}


func _init(r: Node3D, hl: bool) -> void:
	root = r
	headless = hl
	vrng.seed = 9137


# ---------------- primitives ----------------
func mat(c: Color, emis: Color = Color.BLACK, e: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "%s%s%.2f%.2f" % [c.to_html(), emis.to_html(), e, alpha]
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = 0.85
	if e > 0:
		m.emission_enabled = true; m.emission = emis; m.emission_energy_multiplier = e
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats[key] = m
	return m


func fx_mat(c: Color, alpha: float = 0.8) -> StandardMaterial3D:
	var key := "fx%s%.2f" % [c.to_html(), alpha]
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mats[key] = m
	return m


func metal(c: Color) -> StandardMaterial3D:
	var key := "metal%s" % c.to_html()
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.8
	m.roughness = 0.35
	mats[key] = m
	return m


func cyl(top: float, bot: float, h: float, seg: int = 8) -> CylinderMesh:
	var key := "c%.3f_%.3f_%.3f_%d" % [top, bot, h, seg]
	if meshes.has(key): return meshes[key]
	var c := CylinderMesh.new()
	c.top_radius = top; c.bottom_radius = bot; c.height = h; c.radial_segments = seg; c.rings = 1
	meshes[key] = c
	return c


func sph(r: float) -> SphereMesh:
	var key := "s%.3f" % r
	if meshes.has(key): return meshes[key]
	var s := SphereMesh.new()
	s.radius = r; s.height = r * 2.0; s.radial_segments = 10; s.rings = 6
	meshes[key] = s
	return s


func box(size: Vector3) -> BoxMesh:
	var key := "b%s" % str(size)
	if meshes.has(key): return meshes[key]
	var b := BoxMesh.new()
	b.size = size
	meshes[key] = b
	return b


func torus(inner: float, outer: float) -> TorusMesh:
	var key := "t%.3f_%.3f" % [inner, outer]
	if meshes.has(key): return meshes[key]
	var t := TorusMesh.new()
	t.inner_radius = inner; t.outer_radius = outer; t.rings = 14; t.ring_segments = 6
	meshes[key] = t
	return t


func prism(size: Vector3) -> PrismMesh:
	var key := "p%s" % str(size)
	if meshes.has(key): return meshes[key]
	var p := PrismMesh.new()
	p.size = size
	meshes[key] = p
	return p


func part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = m; mi.position = pos; mi.rotation = rot; mi.scale = scl
	parent.add_child(mi)
	return mi


func node(parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos; n.rotation = rot
	parent.add_child(n)
	return n


func eyes(p: Node3D, y: float, z: float, dx: float, r: float) -> void:
	for sx in [-1.0, 1.0]:
		part(p, sph(r), mat(Color(0.97, 0.97, 0.95)), Vector3(sx * dx, y, z))
		part(p, sph(r * 0.5), mat(INK), Vector3(sx * dx, y, z + r * 0.75))


func glow_eyes(p: Node3D, y: float, z: float, dx: float, r: float, c: Color) -> void:
	for sx in [-1.0, 1.0]:
		part(p, sph(r), mat(c, c, 3.0), Vector3(sx * dx, y, z))


func _anim(n: Node3D, kind: String, sp: float, amp: float) -> void:
	anims.append({"node": n, "kind": kind, "base": n.position, "ph": vrng.randf() * TAU, "sp": sp, "amp": amp})


# ---------------- world ----------------
func build_world(corners: Array, slots: Array) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.52, 0.8)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.12, 0.22)
	env.fog_density = 0.012
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.shadow_enabled = true
	moon.light_color = Color(0.72, 0.8, 1.0)
	moon.light_energy = 0.95
	moon.rotation = Vector3(deg_to_rad(-55), deg_to_rad(25), 0)
	root.add_child(moon)
	# ground: grass outside, packed-earth yard (마당) inside the track
	part(root, box(Vector3(70, 0.4, 50)), mat(Color(0.16, 0.26, 0.17)), Vector3(0, -0.21, -3))
	part(root, box(Vector3(14.6, 0.02, 8.6)), mat(Color(0.42, 0.36, 0.27)), Vector3(0, 0.005, 0))
	for k in range(4):
		var a: Vector3 = corners[k]; var b: Vector3 = corners[(k + 1) % 4]
		part(root, box(Vector3(absf(b.x - a.x) + 1.4, 0.04, absf(b.z - a.z) + 1.4)), mat(Color(0.31, 0.26, 0.21)), (a + b) / 2.0 + Vector3(0, 0.02, 0))
	_track_stones(corners)
	_grass(corners)
	for s in slots: _slot_stone(s)
	_gate(corners[0])
	_portal(corners[0])
	# village dressing (kept off the track and away from the HUD panel)
	_giwa_house(Vector3(-10.5, 0, -9.0), 0.0)
	_choga_house(Vector3(-5.6, 0, -9.4), 0.15)
	_choga_house(Vector3(-1.2, 0, -9.2), -0.1)
	_giwa_house(Vector3(4.0, 0, -9.3), 0.05)
	_choga_house(Vector3(9.0, 0, -9.0), 0.2)
	for p in [Vector3(-12.5, 0, -4.5), Vector3(-13.2, 0, 1.0), Vector3(-11.6, 0, 4.6), Vector3(-14.5, 0, -1.8), Vector3(11.8, 0, -6.6), Vector3(-7.8, 0, -12.0), Vector3(1.6, 0, -12.4)]:
		_pine(p, 0.9 + vrng.randf() * 0.4)
	_jangdok(Vector3(-11.2, 0, -1.4))
	_stone_wall(Vector3(-11.5, 0, 7.4), Vector3(10.5, 0, 7.4))
	_stone_lantern(Vector3(-3.0, 0, 7.0))
	_stone_lantern(Vector3(3.0, 0, 7.0))
	for p in [Vector3(9.0, 0, -6.0), Vector3(9.0, 0, 6.0), Vector3(-9.0, 0, 6.0), Vector3(0.0, 0, -6.1), Vector3(0.0, 0, 6.1)]:
		_cheongsa_lantern(p)
	_fireflies(26)


func _track_stones(corners: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sph(0.12)
	var xs: Array = []
	for k in range(4):
		var a: Vector3 = corners[k]; var b: Vector3 = corners[(k + 1) % 4]
		var d := (b - a).normalized()
		var side := Vector3(-d.z, 0, d.x)
		var L := a.distance_to(b)
		var t := 0.0
		while t < L + 0.7:
			for sgn in [-1.0, 1.0]:
				var p: Vector3 = a + d * (t - 0.35) + side * sgn * (0.78 + vrng.randf() * 0.06)
				var s := 0.6 + vrng.randf() * 0.6
				xs.append(Transform3D(Basis(Vector3.UP, vrng.randf() * TAU).scaled(Vector3(s * 1.3, s * 0.55, s)), p + Vector3(0, 0.03, 0)))
			t += 0.34
	mm.instance_count = xs.size()
	for i in range(xs.size()): mm.set_instance_transform(i, xs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat(Color(0.48, 0.47, 0.46))
	root.add_child(mi)


func _grass(corners: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cyl(0.0, 0.07, 0.22, 4)
	var xs: Array = []
	var tries := 0
	while xs.size() < 420 and tries < 4000:
		tries += 1
		var p := Vector3(vrng.randf_range(-20, 20), 0, vrng.randf_range(-15, 9))
		if absf(p.x) < 9.0 and absf(p.z) < 6.0: continue
		var s := 0.7 + vrng.randf() * 0.9
		xs.append(Transform3D(Basis(Vector3(vrng.randf() - 0.5, 0, vrng.randf() - 0.5).normalized(), vrng.randf() * 0.4).scaled(Vector3(s, s, s)), p + Vector3(0, 0.1 * s, 0)))
	mm.instance_count = xs.size()
	for i in range(xs.size()): mm.set_instance_transform(i, xs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat(Color(0.22, 0.38, 0.2))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _slot_stone(p: Vector3) -> void:
	part(root, box(Vector3(1.66, 0.12, 1.66)), mat(Color(0.2, 0.21, 0.21)), p + Vector3(0, 0.06, 0))
	part(root, box(Vector3(1.48, 0.05, 1.48)), mat(Color(0.3, 0.31, 0.29)), p + Vector3(0, 0.14, 0))


func _gate(c: Vector3) -> void:
	# 홍살문 (red arrow gate) over the yokai entrance, with a 장승 pair
	var g := node(root, c + Vector3(0, 0, -1.0))
	var red := mat(Color(0.78, 0.14, 0.12))
	for sx in [-1.3, 1.3]:
		part(g, cyl(0.1, 0.12, 2.8), red, Vector3(sx, 1.4, 0))
	part(g, box(Vector3(3.0, 0.14, 0.14)), red, Vector3(0, 2.55, 0))
	part(g, box(Vector3(2.7, 0.1, 0.1)), red, Vector3(0, 2.1, 0))
	for k in range(9):
		part(g, cyl(0.02, 0.02, 0.5, 4), red, Vector3(-1.1 + k * 0.275, 2.33, 0))
		part(g, cyl(0.0, 0.05, 0.12, 4), red, Vector3(-1.1 + k * 0.275, 2.66, 0))
	part(g, cyl(0.16, 0.16, 0.04, 12), mat(Color(0.8, 0.15, 0.15)), Vector3(0, 2.75, 0.02), Vector3(PI / 2, 0, 0))
	part(g, cyl(0.08, 0.08, 0.05, 10), mat(Color(0.15, 0.25, 0.75)), Vector3(0.04, 2.73, 0.05), Vector3(PI / 2, 0, 0))
	for k in range(2):
		var j := node(root, c + Vector3(-1.9 if k == 0 else 1.9, 0, -0.4))
		var wood := mat(Color(0.55, 0.4, 0.27))
		part(j, cyl(0.17, 0.2, 1.7, 8), wood, Vector3(0, 0.85, 0))
		part(j, sph(0.22), wood, Vector3(0, 1.75, 0))
		eyes(j, 1.78, 0.17, 0.08, 0.06)
		part(j, cyl(0.0, 0.05, 0.14, 4), wood, Vector3(0, 1.66, 0.2), Vector3(PI / 2, 0, 0))
		part(j, box(Vector3(0.22, 0.05, 0.04)), mat(Color(0.95, 0.92, 0.85)), Vector3(0, 1.52, 0.19))
		if k == 0: part(j, cyl(0.16, 0.2, 0.25, 8), mat(INK), Vector3(0, 2.02, 0))
		else: part(j, cyl(0.0, 0.22, 0.3, 8), mat(Color(0.75, 0.2, 0.18)), Vector3(0, 2.05, 0))
		part(j, box(Vector3(0.12, 0.7, 0.02)), mat(Color(0.85, 0.82, 0.75)), Vector3(0, 0.75, 0.19))


func _portal(c: Vector3) -> void:
	var p := node(root, c + Vector3(0, 0.03, 0))
	part(p, cyl(0.95, 0.95, 0.02, 20), mat(Color(0.02, 0.0, 0.04)), Vector3.ZERO)
	for k in range(3):
		var r := 0.45 + k * 0.25
		var ring := part(p, torus(r - 0.05, r), mat(Color(0.5, 0.1, 0.6), Color(0.75, 0.25, 1.0), 2.5 - k * 0.6), Vector3(0, 0.03 + k * 0.03, 0), Vector3(0, 0, 0), Vector3(1, 0.3, 1))
		_anim(ring, "spin", 1.2 - k * 0.5, 0.0)
	for k in range(5):
		var w := part(p, sph(0.08), fx_mat(Color(0.7, 0.3, 1.0), 0.6), Vector3(vrng.randf_range(-0.5, 0.5), 0.2, vrng.randf_range(-0.5, 0.5)))
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_anim(w, "rise", 0.6 + vrng.randf() * 0.4, 1.6)
	var l := OmniLight3D.new(); l.light_color = Color(0.7, 0.3, 1.0); l.omni_range = 3.5; l.light_energy = 1.4; l.position = Vector3(0, 0.6, 0)
	p.add_child(l)


func _house_base(h: Node3D, w: float, d: float) -> void:
	part(h, box(Vector3(w + 0.3, 0.25, d + 0.3)), mat(Color(0.5, 0.49, 0.47)), Vector3(0, 0.12, 0))
	part(h, box(Vector3(w, 1.0, d)), mat(Color(0.86, 0.82, 0.72)), Vector3(0, 0.75, 0))
	var wood := mat(Color(0.4, 0.26, 0.16))
	for sx in [-0.5, 0.0, 0.5]:
		part(h, box(Vector3(0.1, 1.0, 0.1)), wood, Vector3(sx * w, 0.75, d / 2.0 + 0.02))
	part(h, box(Vector3(w, 0.1, 0.1)), wood, Vector3(0, 1.22, d / 2.0 + 0.02))
	# lit paper doors (창호지)
	for sx in [-0.25, 0.25]:
		part(h, box(Vector3(w * 0.38, 0.62, 0.03)), mat(Color(1, 0.86, 0.55), Color(1, 0.7, 0.35), 1.4), Vector3(sx * w, 0.72, d / 2.0 + 0.03))


func _choga_house(p: Vector3, rot: float) -> void:
	var h := node(root, p, Vector3(0, rot, 0))
	_house_base(h, 2.4, 1.6)
	part(h, sph(1.0), mat(Color(0.62, 0.52, 0.32)), Vector3(0, 1.35, 0), Vector3.ZERO, Vector3(1.6, 0.55, 1.15))
	part(h, torus(0.95, 1.05), mat(Color(0.5, 0.42, 0.26)), Vector3(0, 1.45, 0), Vector3.ZERO, Vector3(1.5, 1.0, 1.05))


func _giwa_house(p: Vector3, rot: float) -> void:
	var h := node(root, p, Vector3(0, rot, 0))
	_house_base(h, 3.0, 1.8)
	var roof := mat(Color(0.2, 0.22, 0.27))
	part(h, prism(Vector3(3.9, 0.9, 2.7)), roof, Vector3(0, 1.72, 0))
	part(h, box(Vector3(4.0, 0.14, 0.16)), mat(Color(0.12, 0.13, 0.16)), Vector3(0, 2.2, 0))
	for sx in [-1.0, 1.0]:
		part(h, cyl(0.0, 0.1, 0.35, 5), roof, Vector3(sx * 2.05, 2.25, 0), Vector3(0, 0, -sx * 0.9))
	part(h, box(Vector3(3.2, 0.12, 0.12)), mat(Color(0.25, 0.55, 0.45)), Vector3(0, 1.32, 0.96))


func _pine(p: Vector3, s: float) -> void:
	var t := node(root, p)
	t.scale = Vector3(s, s, s)
	var lean := vrng.randf_range(-0.25, 0.25)
	part(t, cyl(0.1, 0.16, 1.6, 6), mat(Color(0.45, 0.26, 0.18)), Vector3(lean * 0.6, 0.8, 0), Vector3(0, 0, -lean))
	var green := mat(Color(0.13, 0.3, 0.2))
	part(t, sph(0.7), green, Vector3(lean * 1.4, 1.75, 0), Vector3.ZERO, Vector3(1.3, 0.45, 1.1))
	part(t, sph(0.55), green, Vector3(lean * 1.4 + 0.45, 2.2, 0.15), Vector3.ZERO, Vector3(1.2, 0.42, 1.0))
	part(t, sph(0.45), green, Vector3(lean * 1.4 - 0.3, 2.55, -0.1), Vector3.ZERO, Vector3(1.2, 0.42, 1.0))


func _jangdok(p: Vector3) -> void:
	var j := node(root, p)
	part(j, box(Vector3(1.8, 0.2, 1.3)), mat(Color(0.5, 0.49, 0.47)), Vector3(0, 0.1, 0))
	var jar := mat(Color(0.35, 0.2, 0.12))
	var pos := [Vector3(-0.5, 0, -0.3), Vector3(0.1, 0, -0.35), Vector3(0.6, 0, -0.25), Vector3(-0.3, 0, 0.3), Vector3(0.35, 0, 0.32)]
	for k in range(pos.size()):
		var s := 0.8 + 0.25 * (k % 3)
		part(j, sph(0.28), jar, pos[k] + Vector3(0, 0.2 + 0.25 * s, 0), Vector3.ZERO, Vector3(s, s * 1.15, s))
		part(j, cyl(0.17, 0.2, 0.06, 10), jar, pos[k] + Vector3(0, 0.2 + 0.55 * s, 0), Vector3.ZERO, Vector3(s, 1, s))


func _stone_wall(a: Vector3, b: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sph(0.22)
	var xs: Array = []
	var L := a.distance_to(b)
	var d := (b - a).normalized()
	var t := 0.0
	while t < L:
		for row in range(3):
			var s := 0.75 + vrng.randf() * 0.5
			xs.append(Transform3D(Basis(Vector3.UP, vrng.randf() * TAU).scaled(Vector3(s * 1.2, s * 0.7, s)), a + d * (t + (0.18 if row == 1 else 0.0)) + Vector3(0, 0.15 + row * 0.24, 0)))
		t += 0.36
	mm.instance_count = xs.size()
	for i in range(xs.size()): mm.set_instance_transform(i, xs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat(Color(0.45, 0.44, 0.42))
	root.add_child(mi)


func _stone_lantern(p: Vector3) -> void:
	var s := node(root, p)
	var stone := mat(Color(0.55, 0.54, 0.5))
	part(s, cyl(0.25, 0.3, 0.15, 6), stone, Vector3(0, 0.08, 0))
	part(s, cyl(0.08, 0.1, 0.7, 6), stone, Vector3(0, 0.5, 0))
	part(s, box(Vector3(0.36, 0.3, 0.36)), mat(Color(1, 0.8, 0.45), Color(1, 0.7, 0.3), 2.0), Vector3(0, 0.98, 0))
	part(s, cyl(0.0, 0.34, 0.25, 6), stone, Vector3(0, 1.26, 0))


func _cheongsa_lantern(p: Vector3) -> void:
	# 청사초롱: blue silk on top, red below, on a wooden pole
	var s := node(root, p)
	var wood := mat(Color(0.3, 0.2, 0.14))
	part(s, cyl(0.04, 0.05, 2.0, 6), wood, Vector3(0, 1.0, 0))
	part(s, box(Vector3(0.6, 0.04, 0.04)), wood, Vector3(0.28, 1.98, 0))
	var hang := node(s, Vector3(0.52, 1.95, 0))
	part(hang, cyl(0.01, 0.01, 0.2, 4), wood, Vector3(0, -0.1, 0))
	part(hang, cyl(0.16, 0.16, 0.18, 8), mat(Color(0.2, 0.3, 0.8), Color(0.3, 0.45, 1.0), 1.2), Vector3(0, -0.29, 0))
	part(hang, cyl(0.16, 0.16, 0.22, 8), mat(Color(0.9, 0.2, 0.2), Color(1, 0.45, 0.3), 2.2), Vector3(0, -0.49, 0))
	part(hang, cyl(0.0, 0.03, 0.15, 4), mat(Color(0.9, 0.2, 0.2)), Vector3(0, -0.68, 0), Vector3(PI, 0, 0))
	_anim(hang, "sway", 1.4, 0.12)
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.65, 0.4); l.omni_range = 4.2; l.light_energy = 1.3; l.position = Vector3(0, -0.5, 0)
	hang.add_child(l)


func _fireflies(n: int) -> void:
	for k in range(n):
		var p := Vector3(vrng.randf_range(-16, 10), vrng.randf_range(0.4, 1.8), vrng.randf_range(-11, 8))
		if absf(p.x) < 8.5 and absf(p.z) < 5.5: p.z = -7.0 - vrng.randf() * 4.0
		var f := part(root, sph(0.035), fx_mat(Color(0.8, 1.0, 0.45), 0.9), p)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_anim(f, "drift", 0.4 + vrng.randf() * 0.5, 0.4)


# ---------------- units ----------------
func make_unit(t: String, tier: int, kin_c: Color, tier_c: Color, hero: bool) -> Node3D:
	var n := Node3D.new()
	part(n, cyl(0.52, 0.56, 0.08, 12), mat(kin_c.darkened(0.35), kin_c, 0.35), Vector3(0, 0.04, 0))
	part(n, torus(0.5, 0.6), mat(tier_c, tier_c, 0.6 + tier * 0.7), Vector3(0, 0.09, 0))
	var rig := Node3D.new()
	rig.name = "rig"
	rig.position = Vector3(0, 0.08, 0)
	n.add_child(rig)
	match t:
		"dokkaebi": _m_dokkaebi(rig, false)
		"dokkaebi_king": _m_dokkaebi(rig, true)
		"gungsa": _m_gungsa(rig, false)
		"chakho": _m_gungsa(rig, true)
		"posu": _m_posu(rig)
		"mudang": _m_mudang(rig)
		"mulgwisin": _m_mulgwisin(rig)
		"haetae": _m_haetae(rig)
		"gumiho": _m_gumiho(rig, false)
		"cheonnyeon": _m_gumiho(rig, true)
		"jeoseung": _m_jeoseung(rig)
		"yeomra": _m_yeomra(rig)
		"dokkaebibul": _m_dokkaebibul(rig)
		"ssireum": _m_ssireum(rig)
		"bihyeong":
			_human(rig, {"robe": Color(0.45, 0.3, 0.6), "sash": GOLD, "hat": "feather", "hat_c": Color(0.3, 0.2, 0.4), "weapon": "talisman"})
			_ghost_wisps(rig, Color(0.6, 0.5, 0.9), 2)
		"gwigyo":
			_human(rig, {"robe": Color(0.3, 0.15, 0.45), "sash": GOLD, "hat": "feather", "hat_c": GOLD, "weapon": "talisman", "cape": Color(0.15, 0.1, 0.2), "scale": 1.1})
			_ghost_wisps(rig, Color(0.6, 0.5, 0.9), 4)
		"samjogo": _m_samjogo(rig)
		"hyeonmu": _m_hyeonmu(rig)
		"hwarang": _human(rig, {"robe": Color(0.75, 0.3, 0.25), "sash": GOLD, "hat": "feather", "hat_c": Color(0.2, 0.18, 0.15), "weapon": "sword"})
		"seungbyeong": _human(rig, {"robe": Color(0.55, 0.53, 0.5), "top": Color(0.65, 0.4, 0.25), "hat": "satgat", "weapon": "staff"})
		"agijangsu": _human(rig, {"robe": Color(0.95, 0.95, 0.9), "sash": Color(0.85, 0.2, 0.2), "hat": "headband", "hat_c": Color(0.85, 0.2, 0.2), "weapon": "sword", "wings": true, "scale": 0.9})
		"cheoyong": _human(rig, {"robe": Color(0.2, 0.45, 0.6), "sash": Color(0.85, 0.2, 0.2), "face": "mask_red", "hat": "samo", "weapon": "fan"})
		"cheoyongrang": _human(rig, {"robe": Color(0.15, 0.3, 0.55), "sash": GOLD, "face": "mask_red", "hat": "samo", "weapon": "fan", "cape": Color(0.75, 0.15, 0.15), "scale": 1.1})
		"pansu": _human(rig, {"robe": Color(0.82, 0.8, 0.72), "sash": Color(0.3, 0.3, 0.6), "hat": "gat", "weapon": "drum"})
		"bari": _human(rig, {"robe": Color(0.25, 0.55, 0.45), "top": Color(0.95, 0.85, 0.3), "sash": Color(0.85, 0.2, 0.3), "hat": "jokduri", "weapon": "flower", "cape": Color(0.85, 0.25, 0.3)})
		"jeonuchi": _human(rig, {"robe": Color(0.85, 0.9, 0.95), "sash": Color(0.3, 0.6, 0.8), "hat": "gat", "weapon": "fan", "beard": true})
		"honggildong": _human(rig, {"robe": Color(0.15, 0.15, 0.2), "sash": Color(0.6, 0.15, 0.15), "face": "masked", "hat": "gat", "weapon": "sword"})
		"hwalbin": _human(rig, {"robe": Color(0.12, 0.12, 0.18), "sash": GOLD, "face": "masked", "hat": "headband", "hat_c": Color(0.85, 0.2, 0.2), "weapon": "sword", "cape": Color(0.6, 0.12, 0.12), "scale": 1.1})
		"baksi": _human(rig, {"robe": Color(0.6, 0.25, 0.35), "hat": "hood", "hat_c": Color(0.25, 0.5, 0.4), "weapon": "talisman"})
		"mago": _human(rig, {"robe": Color(0.5, 0.4, 0.3), "top": Color(0.6, 0.5, 0.38), "hat": "bun", "hat_c": Color(0.92, 0.92, 0.9), "weapon": "rock", "scale": 1.2})
		"panokseon": _m_boat(rig, false)
		"geobukseon": _m_boat(rig, true)
		"tongjesa": _human(rig, {"robe": Color(0.55, 0.12, 0.12), "top": Color(0.3, 0.28, 0.25), "sash": GOLD, "hat": "helmet", "weapon": "sword", "cape": Color(0.75, 0.1, 0.1), "scale": 1.1})
		"yongwang": _human(rig, {"robe": Color(0.2, 0.5, 0.45), "sash": GOLD, "hat": "myeon", "hat_c": Color(0.12, 0.25, 0.3), "weapon": "talisman", "beard": true})
		"hogukryong": _m_hogukryong(rig)
	if hero:
		var halo := part(n, torus(0.26, 0.32), mat(GOLD, GOLD, 3.0), Vector3(0, 1.8, 0))
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if tier >= 2:
		var l := OmniLight3D.new(); l.light_color = tier_c; l.omni_range = 2.2; l.light_energy = 0.8 + tier * 0.4; l.position = Vector3(0, 1.0, 0)
		n.add_child(l)
	var sc := 1.0 + tier * 0.12
	n.scale = Vector3(sc, sc, sc)
	root.add_child(n)
	return n


func _m_dokkaebi(r: Node3D, king: bool) -> void:
	var red := Color(0.7, 0.13, 0.12) if king else Color(0.86, 0.27, 0.2)
	for sx in [-1.0, 1.0]:
		part(r, cyl(0.07, 0.09, 0.3, 6), mat(red.darkened(0.15)), Vector3(sx * 0.13, 0.15, 0))
	part(r, cyl(0.3, 0.33, 0.2, 10), mat(Color(0.95, 0.68, 0.2)), Vector3(0, 0.36, 0))
	for k in range(3):
		part(r, box(Vector3(0.05, 0.2, 0.04)), mat(INK), Vector3(-0.15 + k * 0.15, 0.36, 0.3))
	part(r, sph(0.32), mat(red), Vector3(0, 0.63, 0), Vector3.ZERO, Vector3(1, 1.05, 0.9))
	part(r, sph(0.2), mat(red.lightened(0.15)), Vector3(0, 0.58, 0.15))
	part(r, sph(0.27), mat(red.lightened(0.05)), Vector3(0, 1.02, 0.02))
	for k in range(6):
		part(r, sph(0.09), mat(Color(0.12, 0.08, 0.06)), Vector3(cos(k * 1.05) * 0.2, 1.2, sin(k * 1.05) * 0.18 - 0.06))
	eyes(r, 1.07, 0.22, 0.1, 0.075)
	part(r, sph(0.05), mat(red.darkened(0.2)), Vector3(0, 0.99, 0.27))
	part(r, box(Vector3(0.24, 0.06, 0.04)), mat(Color(0.98, 0.96, 0.88)), Vector3(0, 0.91, 0.24))
	if king:
		for sx in [-1.0, 1.0]:
			part(r, cyl(0.0, 0.07, 0.34, 6), mat(GOLD, GOLD, 0.8), Vector3(sx * 0.14, 1.32, 0), Vector3(0, 0, -sx * 0.35))
		part(r, box(Vector3(0.62, 0.78, 0.05)), mat(Color(0.28, 0.08, 0.32)), Vector3(0, 0.66, -0.3), Vector3(0.15, 0, 0))
		part(r, torus(0.18, 0.22), mat(GOLD, GOLD, 1.0), Vector3(0, 0.66, 0), Vector3.ZERO, Vector3(1.7, 1, 1.5))
	else:
		part(r, cyl(0.0, 0.08, 0.3, 6), mat(Color(0.97, 0.92, 0.75)), Vector3(0, 1.37, 0.02))
	part(r, cyl(0.06, 0.07, 0.36, 6), mat(red), Vector3(0.33, 0.66, 0.05), Vector3(0, 0, 0.9))
	var club := node(r, Vector3(0.48, 0.62, 0.12), Vector3(0.5, 0, -0.5))
	var cm := mat(GOLD, GOLD, 0.7) if king else mat(Color(0.5, 0.32, 0.18))
	part(club, cyl(0.13, 0.05, 0.6, 8), cm, Vector3(0, 0.3, 0))
	for k in range(5):
		var a := k * TAU / 5.0
		part(club, sph(0.04), mat(Color(0.85, 0.85, 0.8)), Vector3(cos(a) * 0.12, 0.48, sin(a) * 0.12))


func _m_gungsa(r: Node3D, hero: bool) -> void:
	var robe := Color(0.16, 0.22, 0.45) if hero else Color(0.25, 0.43, 0.8)
	part(r, cyl(0.2, 0.36, 0.72, 10), mat(robe), Vector3(0, 0.36, 0))
	part(r, torus(0.19, 0.24), mat(Color(0.8, 0.2, 0.2)), Vector3(0, 0.56, 0))
	part(r, cyl(0.16, 0.2, 0.22, 10), mat(robe.lightened(0.1)), Vector3(0, 0.8, 0))
	part(r, sph(0.19), mat(SKIN), Vector3(0, 1.02, 0))
	for sx in [-1.0, 1.0]:
		part(r, sph(0.03), mat(INK), Vector3(sx * 0.07, 1.04, 0.17))
	part(r, cyl(0.33, 0.33, 0.03, 14), mat(INK), Vector3(0, 1.16, 0))
	part(r, sph(0.15), mat(INK), Vector3(0, 1.2, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	var red := mat(Color(0.9, 0.15, 0.15))
	if hero:
		part(r, cyl(0.02, 0.1, 0.4, 6), red, Vector3(0, 1.45, -0.05), Vector3(-0.3, 0, 0))
		for k in range(3):
			part(r, box(Vector3(0.12, 0.1, 0.04)), mat(GOLD), Vector3(-0.12 + k * 0.12, 0.78, 0.2))
		var cape := node(r, Vector3(0, 0.75, -0.25), Vector3(0.2, 0, 0))
		part(cape, box(Vector3(0.55, 0.7, 0.04)), mat(Color(0.95, 0.6, 0.15)), Vector3.ZERO)
		for k in range(3):
			part(cape, box(Vector3(0.5, 0.05, 0.05)), mat(INK), Vector3(0, -0.2 + k * 0.2, -0.01))
	else:
		part(r, sph(0.05), red, Vector3(0, 1.34, 0))
		part(r, cyl(0.06, 0.0, 0.18, 6), red, Vector3(0, 1.25, -0.14))
	var bow := node(r, Vector3(-0.32, 0.75, 0.12))
	part(bow, torus(0.3, 0.34), mat(GOLD, GOLD, 0.6) if hero else mat(Color(0.5, 0.3, 0.15)), Vector3.ZERO, Vector3(0, 0, PI / 2), Vector3(1, 1, 0.55))
	part(r, cyl(0.07, 0.07, 0.45, 8), mat(Color(0.45, 0.28, 0.16)), Vector3(0.12, 0.78, -0.24), Vector3(0.3, 0, 0))
	for k in range(3):
		part(r, box(Vector3(0.04, 0.1, 0.02)), mat(Color(0.95, 0.95, 0.9)), Vector3(0.08 + k * 0.04, 1.06, -0.32), Vector3(0.3, 0, 0))


func _m_posu(r: Node3D) -> void:
	part(r, cyl(0.2, 0.33, 0.7, 10), mat(Color(0.82, 0.78, 0.68)), Vector3(0, 0.35, 0))
	part(r, cyl(0.22, 0.28, 0.4, 10), mat(Color(0.88, 0.56, 0.18)), Vector3(0, 0.63, 0))
	for k in range(3):
		part(r, box(Vector3(0.05, 0.3, 0.04)), mat(INK), Vector3(-0.13 + k * 0.13, 0.63, 0.25))
	part(r, sph(0.19), mat(SKIN), Vector3(0, 1.0, 0))
	for sx in [-1.0, 1.0]:
		part(r, sph(0.03), mat(INK), Vector3(sx * 0.07, 1.03, 0.17))
	part(r, box(Vector3(0.18, 0.1, 0.06)), mat(Color(0.12, 0.1, 0.08)), Vector3(0, 0.88, 0.15))
	part(r, cyl(0.1, 0.3, 0.18, 10), mat(Color(0.75, 0.62, 0.35)), Vector3(0, 1.2, 0))
	var gun := node(r, Vector3(0.24, 0.72, 0.1), Vector3(-0.25, 0, 0))
	part(gun, cyl(0.025, 0.03, 1.1, 6), metal(Color(0.25, 0.24, 0.24)), Vector3(0, 0, 0.35), Vector3(PI / 2, 0, 0))
	part(gun, box(Vector3(0.07, 0.1, 0.35)), mat(Color(0.45, 0.28, 0.16)), Vector3(0, -0.02, -0.15))
	part(gun, sph(0.03), mat(Color(1, 0.5, 0.1), Color(1, 0.45, 0.1), 3.0), Vector3(0.04, 0.04, 0.05))


func _m_mudang(r: Node3D) -> void:
	part(r, cyl(0.18, 0.42, 0.78, 10), mat(Color(0.82, 0.16, 0.22)), Vector3(0, 0.39, 0))
	part(r, cyl(0.19, 0.25, 0.3, 10), mat(Color(0.2, 0.3, 0.75)), Vector3(0, 0.72, 0))
	var stripes := [Color(0.85, 0.15, 0.2), Color(0.98, 0.85, 0.2), Color(0.2, 0.45, 0.85), Color(0.25, 0.65, 0.35), Color(0.97, 0.97, 0.95)]
	for sx in [-1.0, 1.0]:
		var arm := node(r, Vector3(sx * 0.22, 0.78, 0.05), Vector3(0, 0, sx * 1.1))
		for k in range(stripes.size()):
			part(arm, cyl(0.07, 0.07, 0.07, 8), mat(stripes[k]), Vector3(0, 0.04 + k * 0.07, 0))
	part(r, sph(0.19), mat(SKIN), Vector3(0, 1.03, 0))
	for sx in [-1.0, 1.0]:
		part(r, sph(0.03), mat(INK), Vector3(sx * 0.07, 1.05, 0.17))
	part(r, box(Vector3(0.06, 0.02, 0.02)), mat(Color(0.85, 0.1, 0.15)), Vector3(0, 0.96, 0.18))
	part(r, cyl(0.2, 0.15, 0.26, 10), mat(INK), Vector3(0, 1.25, 0))
	part(r, torus(0.17, 0.2), mat(GOLD, GOLD, 0.8), Vector3(0, 1.18, 0))
	part(r, cyl(0.0, 0.05, 0.42, 6), mat(Color(0.15, 0.6, 0.6)), Vector3(0.05, 1.55, 0), Vector3(0, 0, -0.2))
	part(r, sph(0.05), mat(Color(0.2, 0.35, 0.95), Color(0.3, 0.5, 1.0), 1.5), Vector3(0.1, 1.76, 0))
	var fan := node(r, Vector3(0.55, 0.98, 0.12), Vector3(PI / 2, 0, 0.3))
	part(fan, cyl(0.26, 0.26, 0.02, 12), mat(Color(0.95, 0.85, 0.3)), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.55))
	part(fan, cyl(0.16, 0.16, 0.025, 12), mat(Color(0.85, 0.15, 0.2)), Vector3(0, 0, 0), Vector3.ZERO, Vector3(1, 1, 0.55))
	var bell := node(r, Vector3(-0.55, 0.95, 0.12))
	part(bell, cyl(0.015, 0.015, 0.3, 4), mat(Color(0.4, 0.28, 0.16)), Vector3(0, 0.1, 0))
	for k in range(3):
		part(bell, sph(0.05), mat(GOLD, GOLD, 0.8), Vector3(-0.05 + k * 0.05, 0.28 + (k % 2) * 0.04, 0))


func _m_mulgwisin(r: Node3D) -> void:
	var f := node(r, Vector3(0, 0.1, 0))
	_anim(f, "bob", 1.8, 0.07)
	var ghost := mat(Color(0.75, 0.88, 0.98), Color(0.3, 0.7, 1.0), 0.5, 0.78)
	part(f, cyl(0.24, 0.06, 0.85, 10), ghost, Vector3(0, 0.5, 0))
	for sx in [-1.0, 1.0]:
		part(f, cyl(0.05, 0.08, 0.4, 6), ghost, Vector3(sx * 0.15, 0.78, 0.2), Vector3(PI / 2, 0, 0))
	part(f, sph(0.2), mat(Color(0.85, 0.92, 0.98)), Vector3(0, 1.06, 0))
	part(f, box(Vector3(0.42, 0.78, 0.12)), mat(INK), Vector3(0, 0.84, -0.12))
	for sx in [-1.0, 1.0]:
		part(f, box(Vector3(0.16, 0.48, 0.04)), mat(INK), Vector3(sx * 0.11, 0.96, 0.19))
	part(f, sph(0.035), mat(Color(0.5, 1.0, 1.0), Color(0.4, 1.0, 1.0), 4.0), Vector3(0, 1.07, 0.2))
	for k in range(3):
		part(f, sph(0.04), mat(Color(0.4, 0.7, 1.0), Color(0.3, 0.6, 1.0), 1.0, 0.7), Vector3(-0.08 + k * 0.08, 0.02 - k * 0.03, 0.02))


func _m_haetae(r: Node3D) -> void:
	var stone := mat(Color(0.88, 0.75, 0.42))
	var mane := mat(Color(0.2, 0.47, 0.4))
	part(r, sph(0.36), stone, Vector3(0, 0.42, -0.05), Vector3.ZERO, Vector3(0.9, 0.8, 1.2))
	for lx in [-0.18, 0.18]:
		for lz in [-0.25, 0.25]:
			part(r, cyl(0.08, 0.09, 0.3, 6), stone, Vector3(lx, 0.15, lz))
			part(r, sph(0.08), stone, Vector3(lx, 0.04, lz + 0.04))
	part(r, sph(0.27), stone, Vector3(0, 0.82, 0.3))
	for k in range(8):
		var a := k * TAU / 8.0
		part(r, sph(0.09), mane, Vector3(cos(a) * 0.27, 0.84 + sin(a) * 0.26, 0.18))
	part(r, cyl(0.0, 0.07, 0.3, 6), mane, Vector3(0, 1.17, 0.28))
	eyes(r, 0.9, 0.52, 0.1, 0.07)
	part(r, sph(0.12), mat(Color(0.95, 0.85, 0.55)), Vector3(0, 0.75, 0.5))
	part(r, box(Vector3(0.18, 0.04, 0.04)), mat(Color(0.98, 0.96, 0.9)), Vector3(0, 0.67, 0.56))
	part(r, sph(0.06), mat(GOLD, GOLD, 1.0), Vector3(0, 0.58, 0.48))
	for k in range(3):
		part(r, sph(0.08 - k * 0.012), mane, Vector3(0, 0.55 + k * 0.12, -0.5 - k * 0.05))


func _m_gumiho(r: Node3D, nine: bool) -> void:
	var fur := mat(Color(0.97, 0.95, 0.92))
	part(r, sph(0.3), fur, Vector3(0, 0.42, 0), Vector3.ZERO, Vector3(0.9, 0.85, 1.4))
	for lx in [-0.13, 0.13]:
		for lz in [-0.25, 0.25]:
			part(r, cyl(0.04, 0.05, 0.3, 6), fur, Vector3(lx, 0.15, lz))
	part(r, sph(0.19), fur, Vector3(0, 0.68, 0.36))
	part(r, cyl(0.0, 0.09, 0.22, 6), fur, Vector3(0, 0.64, 0.56), Vector3(PI / 2, 0, 0))
	part(r, sph(0.035), mat(INK), Vector3(0, 0.64, 0.67))
	for sx in [-1.0, 1.0]:
		part(r, cyl(0.0, 0.07, 0.2, 4), fur, Vector3(sx * 0.09, 0.88, 0.33))
		part(r, box(Vector3(0.06, 0.02, 0.02)), mat(Color(1, 0.6, 0.1), Color(1, 0.5, 0.1), 3.0), Vector3(sx * 0.08, 0.72, 0.53))
	var tails := 9 if nine else 3
	for k in range(tails):
		var a := (k - (tails - 1) / 2.0) * (0.26 if nine else 0.45)
		var tp := node(r, Vector3(0, 0.45, -0.35), Vector3(-0.75, 0, a))
		part(tp, cyl(0.06, 0.1, 0.4, 6), fur, Vector3(0, 0.2, 0))
		part(tp, sph(0.09), mat(Color(1, 0.95, 0.9), Color(1, 0.5, 0.2), 1.2), Vector3(0, 0.44, 0))
	for k in range(3 if nine else 1):
		var orb := part(r, sph(0.07), fx_mat(Color(0.4, 0.75, 1.0), 0.9), Vector3(0.55, 1.0, 0))
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var e := {"node": orb, "kind": "orbit", "base": Vector3(0, 1.0, 0), "ph": k * TAU / 3.0, "sp": 2.0, "amp": 0.55}
		anims.append(e)


func _m_jeoseung(r: Node3D) -> void:
	part(r, cyl(0.22, 0.38, 0.85, 10), mat(Color(0.07, 0.07, 0.09)), Vector3(0, 0.43, 0))
	part(r, torus(0.17, 0.2), mat(Color(0.9, 0.9, 0.92)), Vector3(0, 0.84, 0.02))
	part(r, sph(0.19), mat(Color(0.86, 0.88, 0.93)), Vector3(0, 1.0, 0))
	for sx in [-1.0, 1.0]:
		part(r, box(Vector3(0.06, 0.02, 0.02)), mat(INK), Vector3(sx * 0.07, 1.03, 0.18))
	part(r, cyl(0.46, 0.46, 0.025, 16), mat(INK, Color.BLACK, 0.0, 0.88), Vector3(0, 1.13, 0))
	part(r, cyl(0.13, 0.15, 0.26, 12), mat(INK), Vector3(0, 1.27, 0))
	for sx in [-1.0, 1.0]:
		for k in range(3):
			part(r, sph(0.025), mat(Color(0.15, 0.12, 0.1)), Vector3(sx * 0.17, 1.06 - k * 0.07, 0.04))
	part(r, box(Vector3(0.22, 0.28, 0.05)), mat(Color(0.35, 0.05, 0.05)), Vector3(0.25, 0.66, 0.18), Vector3(0, -0.4, 0))
	var mist := part(r, cyl(0.5, 0.5, 0.02, 14), fx_mat(Color(0.45, 0.25, 0.7), 0.35), Vector3(0, 0.03, 0))
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _m_yeomra(r: Node3D) -> void:
	part(r, cyl(0.24, 0.42, 0.9, 10), mat(Color(0.66, 0.12, 0.12)), Vector3(0, 0.45, 0))
	part(r, torus(0.38, 0.43), mat(GOLD, GOLD, 0.6), Vector3(0, 0.05, 0))
	part(r, torus(0.2, 0.24), mat(GOLD, GOLD, 0.6), Vector3(0, 0.88, 0.02))
	part(r, sph(0.2), mat(Color(0.9, 0.75, 0.62)), Vector3(0, 1.05, 0))
	for sx in [-1.0, 1.0]:
		part(r, box(Vector3(0.08, 0.02, 0.02)), mat(INK), Vector3(sx * 0.08, 1.08, 0.18))
		part(r, box(Vector3(0.1, 0.03, 0.03)), mat(INK), Vector3(sx * 0.08, 1.13, 0.17), Vector3(0, 0, sx * 0.3))
	part(r, box(Vector3(0.2, 0.32, 0.08)), mat(Color(0.08, 0.07, 0.07)), Vector3(0, 0.84, 0.16))
	part(r, cyl(0.15, 0.15, 0.18, 10), mat(INK), Vector3(0, 1.26, 0))
	part(r, box(Vector3(0.52, 0.035, 0.36)), mat(INK), Vector3(0, 1.37, 0))
	for zz in [-0.17, 0.17]:
		for k in range(5):
			var x := -0.2 + k * 0.1
			part(r, cyl(0.006, 0.006, 0.22, 4), mat(Color(0.2, 0.2, 0.2)), Vector3(x, 1.25, zz))
			part(r, sph(0.022), mat(Color(0.3, 0.75, 0.55)), Vector3(x, 1.15, zz))
	part(r, box(Vector3(0.07, 0.32, 0.02)), mat(Color(0.95, 0.92, 0.82)), Vector3(0.12, 0.82, 0.26), Vector3(-0.3, 0, 0))


# ---------------- enemies ----------------
func make_enemy(look: String, boss: bool) -> Dictionary:
	var n := Node3D.new()
	var rig := Node3D.new()
	rig.name = "rig"
	n.add_child(rig)
	var segs: Array = []
	match look:
		"imugi": segs = _imugi(rig)
		"bulgasari": _bulgasari(rig)
		"centipede": segs = _e_centipede(rig)
		"egg": _egg_ghost(rig)
		"wisp": _will_o_wisp(rig)
		"shadow": _shadow(rig)
		"gaekgwi": _e_gaekgwi(rig)
		"rat": _e_rat(rig)
		"yagwang": _e_yagwang(rig)
		"fox": _quad(rig, {"c": Color(0.9, 0.55, 0.22), "len": 1.25})
		"changgwi": _e_changgwi(rig)
		"brute": _e_brute(rig)
		"tiger": _quad(rig, {"c": Color(0.92, 0.6, 0.2), "len": 1.4, "stripes": true, "eye": Color(1, 0.9, 0.2)})
		"snake": _serpent(rig, Color(0.2, 0.3, 0.25), 6, 0.2)
		"isimi": _serpent(rig, Color(0.25, 0.45, 0.5), 5, 0.17)
		"swarm": _e_swarm(rig)
		"onelegged": _e_onelegged(rig)
		"yogwi": _e_yogwi(rig)
		"daegwi": _e_daegwi(rig)
		"sogwi": _e_sogwi(rig)
		"agwi": _e_agwi(rig)
		"gildal": _e_gildal(rig)
		"jigwi": _e_jigwi(rig)
		"yeoksin": _e_yeoksin(rig)
		"yeongno": _e_yeongno(rig)
		"foxsister": _e_foxsister(rig)
		"segment": _e_segment(rig)
		"daejeok": _e_daejeok(rig)
		_: _jabgwi(rig)
	root.add_child(n)
	return {"node": n, "rig": rig, "segs": segs}


func _jabgwi(r: Node3D) -> void:
	var c := Color(0.32, 0.12, 0.38)
	part(r, sph(0.33), mat(c), Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(1, 0.95, 1))
	part(r, cyl(0.0, 0.07, 0.24, 5), mat(Color(0.9, 0.85, 0.7)), Vector3(0, 0.72, 0))
	glow_eyes(r, 0.42, 0.27, 0.12, 0.06, Color(1, 0.2, 0.2))
	part(r, box(Vector3(0.2, 0.04, 0.04)), mat(Color(0.95, 0.92, 0.85)), Vector3(0, 0.3, 0.31))
	for sx in [-1.0, 1.0]:
		part(r, sph(0.08), mat(c.darkened(0.2)), Vector3(sx * 0.33, 0.3, 0.05))
		part(r, sph(0.09), mat(c.darkened(0.3)), Vector3(sx * 0.14, 0.04, 0.05))


func _egg_ghost(r: Node3D) -> void:
	part(r, sph(0.3), mat(Color(0.95, 0.95, 0.98), Color(0.6, 0.7, 1.0), 0.6), Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1, 1.35, 1))
	part(r, sph(0.2), mat(Color(0.85, 0.9, 1.0), Color(0.5, 0.6, 1.0), 0.4, 0.5), Vector3(0, 0.15, -0.15), Vector3.ZERO, Vector3(1, 0.6, 1.4))
	for sx in [-1.0, 1.0]:
		part(r, cyl(0.03, 0.05, 0.3, 5), mat(Color(0.9, 0.92, 1.0)), Vector3(sx * 0.3, 0.42, 0.1), Vector3(0.8, 0, sx * 0.4))


func _will_o_wisp(r: Node3D) -> void:
	part(r, sph(0.24), mat(Color(0.3, 0.6, 1.0), Color(0.25, 0.65, 1.0), 2.5), Vector3(0, 0.55, 0))
	part(r, cyl(0.0, 0.2, 0.5, 7), mat(Color(0.4, 0.8, 1.0), Color(0.35, 0.8, 1.0), 2.0, 0.8), Vector3(0, 0.9, -0.05))
	part(r, sph(0.12), mat(Color(0.98, 0.98, 0.95)), Vector3(0, 0.58, 0.18))
	part(r, sph(0.06), mat(INK), Vector3(0, 0.58, 0.28))


func _imugi(r: Node3D) -> Array:
	var c := Color(0.2, 0.45, 0.38)
	part(r, sph(0.6), mat(c), Vector3(0, 0.7, 0), Vector3.ZERO, Vector3(1, 0.85, 1.3))
	part(r, sph(0.32), mat(c.lightened(0.1)), Vector3(0, 0.6, 0.65), Vector3.ZERO, Vector3(1, 0.7, 1.2))
	part(r, box(Vector3(0.5, 0.06, 0.06)), mat(Color(0.95, 0.92, 0.85)), Vector3(0, 0.45, 0.95))
	glow_eyes(r, 0.98, 0.55, 0.28, 0.12, Color(1, 0.8, 0.1))
	for sx in [-1.0, 1.0]:
		part(r, cyl(0.0, 0.08, 0.3, 5), mat(Color(0.85, 0.82, 0.65)), Vector3(sx * 0.25, 1.3, 0.2), Vector3(-0.4, 0, -sx * 0.4))
		part(r, cyl(0.01, 0.02, 0.9, 4), mat(Color(0.85, 0.8, 0.5)), Vector3(sx * 0.45, 0.55, 0.85), Vector3(0, 0, sx * 1.2))
	var segs: Array = []
	for k in range(6):
		var s := Node3D.new()
		part(s, sph(0.55 - k * 0.05), mat(c.darkened(0.08 * k)), Vector3.ZERO)
		part(s, cyl(0.0, 0.12, 0.3, 4), mat(Color(0.75, 0.6, 0.3)), Vector3(0, 0.5 - k * 0.04, 0))
		root.add_child(s)
		segs.append(s)
	return segs


func _bulgasari(r: Node3D) -> void:
	var iron := metal(Color(0.42, 0.42, 0.46))
	part(r, sph(0.75), iron, Vector3(0, 0.85, 0), Vector3.ZERO, Vector3(1.1, 0.9, 1.3))
	for lx in [-0.45, 0.45]:
		for lz in [-0.5, 0.5]:
			part(r, cyl(0.16, 0.2, 0.6, 8), iron, Vector3(lx, 0.3, lz))
	part(r, sph(0.42), iron, Vector3(0, 1.0, 0.9))
	part(r, cyl(0.08, 0.15, 0.7, 8), iron, Vector3(0, 0.65, 1.25), Vector3(0.5, 0, 0))
	for sx in [-1.0, 1.0]:
		part(r, cyl(0.0, 0.05, 0.35, 5), mat(Color(0.95, 0.92, 0.85)), Vector3(sx * 0.2, 0.75, 1.15), Vector3(1.2, 0, 0))
	glow_eyes(r, 1.15, 1.22, 0.2, 0.08, Color(1, 0.15, 0.1))
	for k in range(7):
		part(r, cyl(0.0, 0.12, 0.45, 5), metal(Color(0.3, 0.3, 0.33)), Vector3(0, 1.55 - absf(k - 3) * 0.08, -0.7 + k * 0.22))
	part(r, cyl(0.03, 0.06, 0.7, 5), iron, Vector3(0, 0.85, -1.05), Vector3(-0.9, 0, 0))


# ---------------- shared templates (new roster) ----------------
func _human(r: Node3D, o: Dictionary) -> void:
	# generic Joseon-era figure: robe, head, hat, weapon. o keys are optional.
	var s: float = o.get("scale", 1.0)
	var h := node(r, Vector3.ZERO)
	h.scale = Vector3(s, s, s)
	var robe: Color = o.get("robe", Color(0.85, 0.85, 0.8))
	part(h, cyl(0.2, o.get("robe_w", 0.36), 0.74, 10), mat(robe), Vector3(0, 0.37, 0))
	part(h, cyl(0.16, 0.21, 0.24, 10), mat(o.get("top", robe.lightened(0.08))), Vector3(0, 0.8, 0))
	if o.has("sash"): part(h, torus(0.18, 0.23), mat(o["sash"]), Vector3(0, 0.6, 0))
	var skin: Color = o.get("skin", SKIN)
	part(h, sph(0.19), mat(skin), Vector3(0, 1.02, 0))
	match o.get("face", "eyes"):
		"mask_red":
			part(h, sph(0.17), mat(Color(0.82, 0.18, 0.15)), Vector3(0, 1.03, 0.06), Vector3.ZERO, Vector3(1.05, 1.1, 0.8))
			for sx in [-1.0, 1.0]: part(h, sph(0.035), mat(INK), Vector3(sx * 0.07, 1.07, 0.19))
			part(h, box(Vector3(0.1, 0.03, 0.02)), mat(Color(0.98, 0.95, 0.88)), Vector3(0, 0.96, 0.2))
		"masked":
			part(h, box(Vector3(0.36, 0.08, 0.04)), mat(INK), Vector3(0, 1.05, 0.15))
			for sx in [-1.0, 1.0]: part(h, sph(0.025), mat(Color(1, 1, 1)), Vector3(sx * 0.07, 1.05, 0.18))
		_:
			for sx in [-1.0, 1.0]: part(h, sph(0.03), mat(INK), Vector3(sx * 0.07, 1.04, 0.17))
	if o.get("beard", false): part(h, box(Vector3(0.16, 0.2, 0.06)), mat(Color(0.1, 0.09, 0.08)), Vector3(0, 0.88, 0.15))
	var hc: Color = o.get("hat_c", INK)
	match o.get("hat", ""):
		"gat":
			part(h, cyl(0.42, 0.42, 0.025, 16), mat(hc, Color.BLACK, 0.0, 0.88), Vector3(0, 1.14, 0))
			part(h, cyl(0.12, 0.14, 0.24, 12), mat(hc), Vector3(0, 1.27, 0))
		"satgat":
			part(h, cyl(0.04, 0.46, 0.2, 12), mat(Color(0.78, 0.66, 0.4)), Vector3(0, 1.2, 0))
		"feather":
			part(h, cyl(0.13, 0.16, 0.14, 10), mat(hc), Vector3(0, 1.18, 0))
			for sx in [-1.0, 1.0]: part(h, cyl(0.0, 0.04, 0.42, 5), mat(Color(0.95, 0.92, 0.85)), Vector3(sx * 0.09, 1.38, -0.04), Vector3(0, 0, -sx * 0.35))
		"samo":
			part(h, cyl(0.14, 0.16, 0.2, 10), mat(INK), Vector3(0, 1.2, 0))
			for sx in [-1.0, 1.0]: part(h, box(Vector3(0.2, 0.08, 0.02)), mat(INK), Vector3(sx * 0.22, 1.22, -0.05))
		"myeon":
			part(h, cyl(0.15, 0.15, 0.18, 10), mat(hc), Vector3(0, 1.22, 0))
			part(h, box(Vector3(0.5, 0.035, 0.34)), mat(hc), Vector3(0, 1.33, 0))
			for zz in [-0.16, 0.16]:
				for k in range(5): part(h, sph(0.022), mat(Color(0.3, 0.75, 0.55)), Vector3(-0.2 + k * 0.1, 1.2, zz))
		"bun":
			part(h, sph(0.2), mat(hc), Vector3(0, 1.08, -0.04), Vector3.ZERO, Vector3(1.05, 1.0, 1.05))
			part(h, sph(0.11), mat(hc), Vector3(0, 1.0, -0.2))
			part(h, cyl(0.012, 0.012, 0.3, 4), mat(GOLD), Vector3(0, 1.0, -0.2), Vector3(0, 0, PI / 2))
		"jokduri":
			part(h, sph(0.2), mat(INK), Vector3(0, 1.08, -0.04), Vector3.ZERO, Vector3(1.05, 1.0, 1.05))
			part(h, cyl(0.1, 0.13, 0.12, 6), mat(Color(0.2, 0.15, 0.4)), Vector3(0, 1.26, 0))
			part(h, sph(0.04), mat(GOLD, GOLD, 1.0), Vector3(0, 1.34, 0))
		"headband":
			part(h, torus(0.17, 0.21), mat(hc), Vector3(0, 1.08, 0))
			part(h, sph(0.08), mat(INK), Vector3(0, 1.2, -0.02))
		"helmet":
			part(h, sph(0.21), metal(Color(0.35, 0.33, 0.3)), Vector3(0, 1.12, 0), Vector3.ZERO, Vector3(1, 0.9, 1))
			part(h, cyl(0.3, 0.3, 0.02, 14), metal(Color(0.35, 0.33, 0.3)), Vector3(0, 1.08, 0))
			part(h, cyl(0.01, 0.06, 0.3, 6), mat(Color(0.9, 0.15, 0.15)), Vector3(0, 1.4, 0))
		"hood":
			part(h, sph(0.24), mat(hc), Vector3(0, 1.06, -0.04), Vector3.ZERO, Vector3(1.0, 1.1, 1.05))
			part(h, cyl(0.24, 0.34, 0.5, 10), mat(hc), Vector3(0, 0.82, -0.06))
	if o.has("cape"):
		part(h, box(Vector3(0.55, 0.72, 0.04)), mat(o["cape"]), Vector3(0, 0.6, -0.27), Vector3(0.18, 0, 0))
	if o.get("wings", false):
		for sx in [-1.0, 1.0]: part(h, box(Vector3(0.36, 0.22, 0.03)), mat(Color(0.97, 0.97, 0.95)), Vector3(sx * 0.26, 0.86, -0.18), Vector3(0, sx * 0.5, sx * 0.4))
	var w := node(h, Vector3(0.32, 0.7, 0.1))
	match o.get("weapon", ""):
		"sword":
			part(w, box(Vector3(0.05, 0.62, 0.03)), metal(Color(0.85, 0.87, 0.9)), Vector3(0, 0.25, 0.08), Vector3(0.5, 0, 0))
			part(w, torus(0.04, 0.06), mat(GOLD), Vector3(0, -0.03, -0.06), Vector3(PI / 2, 0, 0))
		"staff":
			part(w, cyl(0.025, 0.03, 1.1, 6), mat(Color(0.5, 0.36, 0.22)), Vector3(0, 0.3, 0))
			part(w, torus(0.05, 0.07), mat(GOLD), Vector3(0, 0.86, 0), Vector3(PI / 2, 0, 0))
		"fan":
			part(w, cyl(0.24, 0.24, 0.02, 12), mat(Color(0.95, 0.95, 0.9)), Vector3(0.05, 0.2, 0.05), Vector3(PI / 2, 0, 0.3), Vector3(1, 1, 0.55))
		"drum":
			part(w, cyl(0.15, 0.15, 0.16, 12), mat(Color(0.75, 0.2, 0.18)), Vector3(-0.1, -0.1, 0.12), Vector3(PI / 2, 0, 0))
			part(w, cyl(0.12, 0.12, 0.17, 12), mat(Color(0.95, 0.9, 0.78)), Vector3(-0.1, -0.1, 0.12), Vector3(PI / 2, 0, 0))
		"flower":
			part(w, cyl(0.012, 0.015, 0.55, 4), mat(Color(0.35, 0.55, 0.25)), Vector3(0, 0.2, 0))
			for k in range(4): part(w, sph(0.05), mat(Color(0.95, 0.55, 0.7), Color(1, 0.5, 0.7), 0.8), Vector3(cos(k * 1.6) * 0.06, 0.48 + k * 0.03, sin(k * 1.6) * 0.06))
		"rock":
			part(w, sph(0.22), mat(Color(0.5, 0.48, 0.45)), Vector3(0, 0.35, 0), Vector3.ZERO, Vector3(1.1, 0.9, 1.0))
		"talisman":
			part(w, box(Vector3(0.14, 0.22, 0.01)), mat(Color(0.98, 0.88, 0.4), Color(1, 0.8, 0.3), 0.6), Vector3(0, 0.2, 0.1))


func _ghost_wisps(r: Node3D, c: Color, n: int) -> void:
	for k in range(n):
		var g := part(r, sph(0.1), mat(c, c, 1.2, 0.6), Vector3(0.6, 0.9, 0))
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		anims.append({"node": g, "kind": "orbit", "base": Vector3(0, 0.9 + k * 0.12, 0), "ph": k * TAU / n, "sp": 1.6, "amp": 0.6})


func _m_dokkaebibul(r: Node3D) -> void:
	for k in range(3):
		var f := node(r, Vector3(cos(k * TAU / 3) * 0.22, 0.45 + k * 0.15, sin(k * TAU / 3) * 0.22))
		_anim(f, "bob", 2.0 + k * 0.4, 0.08)
		part(f, sph(0.17), mat(Color(0.3, 0.6, 1.0), Color(0.25, 0.65, 1.0), 2.5, 0.85), Vector3.ZERO)
		part(f, cyl(0.0, 0.14, 0.32, 7), mat(Color(0.45, 0.8, 1.0), Color(0.35, 0.8, 1.0), 2.0, 0.7), Vector3(0, 0.2, 0))
		for sx in [-1.0, 1.0]: part(f, sph(0.03), mat(INK), Vector3(sx * 0.05, 0.03, 0.15))


func _m_ssireum(r: Node3D) -> void:
	var skin := Color(0.3, 0.45, 0.75)
	for sx in [-1.0, 1.0]: part(r, cyl(0.09, 0.11, 0.3, 6), mat(skin.darkened(0.15)), Vector3(sx * 0.15, 0.15, 0))
	part(r, sph(0.36), mat(skin), Vector3(0, 0.62, 0), Vector3.ZERO, Vector3(1.1, 1.05, 0.95))
	part(r, torus(0.3, 0.36), mat(Color(0.97, 0.97, 0.92)), Vector3(0, 0.4, 0))
	part(r, cyl(0.06, 0.06, 0.34, 6), mat(Color(0.97, 0.97, 0.92)), Vector3(0, 0.3, 0.2), Vector3(0.3, 0, 0))
	part(r, sph(0.24), mat(skin.lightened(0.08)), Vector3(0, 1.05, 0.02))
	eyes(r, 1.1, 0.2, 0.09, 0.07)
	part(r, box(Vector3(0.22, 0.05, 0.04)), mat(Color(0.98, 0.96, 0.88)), Vector3(0, 0.95, 0.22))
	for k in range(5): part(r, sph(0.08), mat(Color(0.12, 0.1, 0.1)), Vector3(cos(k * 1.25) * 0.17, 1.22, sin(k * 1.25) * 0.15 - 0.05))
	for sx in [-1.0, 1.0]: part(r, sph(0.12), mat(skin), Vector3(sx * 0.4, 0.72, 0.12))


func _m_samjogo(r: Node3D) -> void:
	var b := node(r, Vector3(0, 0.15, 0))
	part(b, sph(0.5), mat(GOLD, Color(1, 0.6, 0.15), 1.5, 0.75), Vector3(0, 0.95, -0.25), Vector3(PI / 2, 0, 0), Vector3(1, 0.15, 1))
	part(b, sph(0.26), mat(Color(0.08, 0.08, 0.1)), Vector3(0, 0.75, 0), Vector3.ZERO, Vector3(1, 0.9, 1.3))
	part(b, sph(0.15), mat(Color(0.08, 0.08, 0.1)), Vector3(0, 1.0, 0.22))
	part(b, cyl(0.0, 0.05, 0.16, 5), mat(GOLD), Vector3(0, 0.98, 0.42), Vector3(PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		part(b, sph(0.03), mat(Color(1, 0.6, 0.1), Color(1, 0.6, 0.1), 3.0), Vector3(sx * 0.07, 1.04, 0.33))
		part(b, box(Vector3(0.42, 0.06, 0.24)), mat(Color(0.1, 0.1, 0.13)), Vector3(sx * 0.32, 0.82, -0.02), Vector3(0, 0, sx * 0.35))
	for k in range(3): part(b, cyl(0.025, 0.025, 0.4, 5), mat(GOLD), Vector3(-0.08 + k * 0.08, 0.38, 0.02))


func _m_hyeonmu(r: Node3D) -> void:
	part(r, sph(0.42), mat(Color(0.2, 0.32, 0.3)), Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1, 0.55, 1.15))
	for k in range(6):
		var a := k * TAU / 6.0
		part(r, cyl(0.1, 0.1, 0.05, 6), mat(Color(0.3, 0.45, 0.4)), Vector3(cos(a) * 0.22, 0.56, sin(a) * 0.24), Vector3(0.3 * sin(a), 0, -0.3 * cos(a)))
	for lx in [-0.3, 0.3]:
		for lz in [-0.3, 0.3]: part(r, sph(0.1), mat(Color(0.35, 0.5, 0.4)), Vector3(lx, 0.12, lz))
	part(r, sph(0.15), mat(Color(0.35, 0.5, 0.4)), Vector3(0, 0.38, 0.5))
	eyes(r, 0.44, 0.62, 0.06, 0.04)
	var sn := mat(Color(0.12, 0.3, 0.22))
	for k in range(8):
		var a := k * 0.8
		part(r, sph(0.08), sn, Vector3(cos(a) * 0.36, 0.55 + k * 0.06, sin(a) * 0.36))
	part(r, sph(0.11), sn, Vector3(0.1, 1.08, 0.2))
	glow_eyes(r, 1.12, 0.3, 0.05, 0.025, Color(1, 0.8, 0.2))


func _m_boat(r: Node3D, turtle: bool) -> void:
	var wood := mat(Color(0.45, 0.3, 0.18))
	part(r, box(Vector3(0.7, 0.28, 1.25)), wood, Vector3(0, 0.22, 0))
	part(r, prism(Vector3(0.7, 0.3, 0.3)), wood, Vector3(0, 0.22, 0.75), Vector3(PI / 2, 0, 0))
	part(r, box(Vector3(0.8, 0.06, 1.3)), mat(Color(0.32, 0.2, 0.12)), Vector3(0, 0.38, 0))
	if turtle:
		part(r, sph(0.45), mat(Color(0.3, 0.33, 0.3)), Vector3(0, 0.45, -0.05), Vector3.ZERO, Vector3(0.85, 0.5, 1.35))
		for k in range(9): part(r, cyl(0.0, 0.03, 0.1, 4), metal(Color(0.6, 0.6, 0.62)), Vector3(-0.2 + (k % 3) * 0.2, 0.66, -0.4 + (k / 3) * 0.28))
		part(r, sph(0.13), mat(Color(0.8, 0.25, 0.2)), Vector3(0, 0.5, 0.72))
		glow_eyes(r, 0.56, 0.82, 0.05, 0.03, Color(1, 0.8, 0.2))
	else:
		part(r, box(Vector3(0.62, 0.3, 0.9)), mat(Color(0.75, 0.62, 0.42)), Vector3(0, 0.56, -0.05))
		part(r, box(Vector3(0.7, 0.05, 1.0)), mat(Color(0.6, 0.2, 0.15)), Vector3(0, 0.74, -0.05))
		part(r, cyl(0.025, 0.03, 0.9, 6), wood, Vector3(0, 1.15, 0.05))
		part(r, box(Vector3(0.5, 0.45, 0.02)), mat(Color(0.95, 0.92, 0.85)), Vector3(0, 1.2, 0.08))
		for sx in [-1.0, 1.0]: part(r, cyl(0.035, 0.035, 0.16, 6), metal(Color(0.25, 0.25, 0.25)), Vector3(sx * 0.33, 0.56, 0.2), Vector3(0, 0, PI / 2))


func _m_hogukryong(r: Node3D) -> void:
	var c := Color(0.2, 0.5, 0.65)
	for k in range(7):
		var a := k * 0.9
		part(r, sph(0.15 - k * 0.008), mat(c.darkened(0.04 * k)), Vector3(cos(a) * 0.35, 0.25 + k * 0.1, sin(a) * 0.35))
	part(r, sph(0.22), mat(c.lightened(0.1)), Vector3(0.1, 1.05, 0.25), Vector3.ZERO, Vector3(1, 0.85, 1.3))
	part(r, sph(0.12), mat(c.lightened(0.2)), Vector3(0.1, 1.0, 0.48))
	glow_eyes(r, 1.12, 0.42, 0.1, 0.035, Color(1, 0.85, 0.2))
	for sx in [-1.0, 1.0]:
		part(r, cyl(0.0, 0.04, 0.3, 5), mat(GOLD), Vector3(0.1 + sx * 0.1, 1.3, 0.15), Vector3(-0.5, 0, -sx * 0.3))
		part(r, cyl(0.008, 0.012, 0.5, 4), mat(GOLD), Vector3(0.1 + sx * 0.18, 0.98, 0.5), Vector3(0, 0, sx * 1.2))
	var pearl := part(r, sph(0.09), mat(Color(0.8, 0.95, 1.0), Color(0.6, 0.9, 1.0), 2.5), Vector3(0.5, 1.2, 0))
	anims.append({"node": pearl, "kind": "orbit", "base": Vector3(0, 1.15, 0), "ph": 0.0, "sp": 1.4, "amp": 0.5})


# ---------------- new yokai ----------------
func _ghost(r: Node3D, o: Dictionary) -> void:
	var c: Color = o.get("c", Color(0.88, 0.9, 0.95))
	var a: float = o.get("alpha", 0.85)
	var g := node(r, Vector3.ZERO, Vector3(o.get("lean", 0.0), 0, 0))
	part(g, cyl(0.22, o.get("bottom", 0.12), o.get("h", 0.8), 10), mat(c, c.darkened(0.3), 0.3, a), Vector3(0, 0.45, 0))
	part(g, sph(0.19), mat(o.get("skin", Color(0.85, 0.88, 0.93)), Color.BLACK, 0.0, a), Vector3(0, 1.0, 0))
	if o.get("hair", true): part(g, box(Vector3(0.36, 0.6, 0.1)), mat(INK), Vector3(0, 0.85, -0.12))
	if o.has("eye"): glow_eyes(g, 1.02, 0.17, 0.07, 0.03, o["eye"])
	for sx in [-1.0, 1.0]: part(g, cyl(0.04, 0.06, 0.36, 5), mat(c, Color.BLACK, 0.0, a), Vector3(sx * 0.2, 0.72, 0.14), Vector3(1.0, 0, sx * 0.3))


func _quad(r: Node3D, o: Dictionary) -> void:
	var c: Color = o.get("c", Color(0.6, 0.5, 0.4))
	var m := mat(c)
	var L: float = o.get("len", 1.3)
	part(r, sph(0.3), m, Vector3(0, 0.42, 0), Vector3.ZERO, Vector3(0.85, 0.75, L))
	for lx in [-0.14, 0.14]:
		for lz in [-0.22 * L, 0.22 * L]: part(r, cyl(0.05, 0.06, 0.3, 6), m, Vector3(lx, 0.15, lz))
	part(r, sph(0.19), m, Vector3(0, 0.62, 0.34 * L))
	part(r, cyl(0.0, 0.08, 0.18, 6), m, Vector3(0, 0.58, 0.34 * L + 0.18), Vector3(PI / 2, 0, 0))
	for sx in [-1.0, 1.0]: part(r, cyl(0.0, 0.06, 0.16, 4), m, Vector3(sx * 0.09, 0.8, 0.32 * L))
	glow_eyes(r, 0.66, 0.34 * L + 0.15, 0.07, 0.03, o.get("eye", Color(1, 0.7, 0.1)))
	if o.get("stripes", false):
		for k in range(4): part(r, box(Vector3(0.52, 0.06, 0.05)), mat(INK), Vector3(0, 0.5, -0.24 + k * 0.16))
	part(r, cyl(0.04, 0.07, 0.5, 6), m, Vector3(0, 0.55, -0.42 * L), Vector3(-0.8, 0, 0))


func _serpent(r: Node3D, c: Color, n: int, head_r: float) -> void:
	for k in range(n):
		part(r, sph(head_r * (0.9 - k * 0.06)), mat(c.darkened(0.05 * k)), Vector3(sin(k * 1.1) * 0.12, head_r * 0.8, -k * head_r * 1.3))
	part(r, sph(head_r), mat(c.lightened(0.08)), Vector3(0, head_r * 1.1, head_r * 0.9), Vector3.ZERO, Vector3(1, 0.8, 1.3))
	glow_eyes(r, head_r * 1.4, head_r * 1.7, head_r * 0.45, head_r * 0.18, Color(1, 0.85, 0.1))


func _e_gaekgwi(r: Node3D) -> void:
	_ghost(r, {"lean": 0.35, "c": Color(0.8, 0.82, 0.78), "eye": Color(0.6, 1, 1)})
	part(r, sph(0.16), mat(Color(0.55, 0.42, 0.28)), Vector3(0, 0.85, -0.3))


func _e_rat(r: Node3D) -> void:
	_quad(r, {"c": Color(0.5, 0.48, 0.48), "len": 1.1, "eye": Color(1, 0.2, 0.2)})
	part(r, cyl(0.3, 0.3, 0.02, 14), mat(INK, Color.BLACK, 0.0, 0.85), Vector3(0, 0.82, 0.38))
	part(r, cyl(0.09, 0.1, 0.16, 10), mat(INK), Vector3(0, 0.9, 0.38))


func _e_yagwang(r: Node3D) -> void:
	part(r, sph(0.24), mat(Color(0.25, 0.35, 0.3)), Vector3(0, 0.42, 0))
	for sx in [-1.0, 1.0]: part(r, box(Vector3(0.14, 0.06, 0.34)), mat(Color(0.25, 0.35, 0.3)), Vector3(sx * 0.12, 0.04, 0.08))
	glow_eyes(r, 0.5, 0.2, 0.08, 0.06, Color(1, 1, 0.5))
	part(r, box(Vector3(0.12, 0.08, 0.28)), mat(Color(0.8, 0.7, 0.45)), Vector3(0.22, 0.4, 0.12), Vector3(0, 0.4, 0))


func _e_changgwi(r: Node3D) -> void:
	_ghost(r, {"c": Color(0.95, 0.75, 0.4), "alpha": 0.6, "eye": Color(1, 0.6, 0.1), "hair": false})
	for k in range(3): part(r, box(Vector3(0.46, 0.05, 0.05)), mat(INK, Color.BLACK, 0.0, 0.7), Vector3(0, 0.3 + k * 0.2, 0.16))


func _e_brute(r: Node3D) -> void:
	var c := Color(0.55, 0.15, 0.12)
	part(r, sph(0.42), mat(c), Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1.1, 1.1, 0.95))
	part(r, sph(0.24), mat(c.lightened(0.08)), Vector3(0, 1.05, 0.06))
	glow_eyes(r, 1.1, 0.26, 0.09, 0.045, Color(1, 0.85, 0.2))
	for sx in [-1.0, 1.0]:
		part(r, cyl(0.0, 0.04, 0.16, 5), mat(Color(0.95, 0.92, 0.85)), Vector3(sx * 0.08, 0.92, 0.24))
		part(r, sph(0.14), mat(c), Vector3(sx * 0.45, 0.62, 0.1))
		part(r, cyl(0.08, 0.1, 0.26, 6), mat(c.darkened(0.2)), Vector3(sx * 0.17, 0.12, 0))


func _shadow(r: Node3D) -> void:
	var sh := mat(Color(0.05, 0.04, 0.08), Color.BLACK, 0.0, 0.92)
	part(r, cyl(0.12, 0.3, 1.1, 8), sh, Vector3(0, 0.55, 0))
	part(r, sph(0.18), sh, Vector3(0, 1.22, 0))
	for sx in [-1.0, 1.0]:
		part(r, box(Vector3(0.07, 0.02, 0.02)), mat(Color(1, 1, 0.9), Color(1, 1, 0.8), 4.0), Vector3(sx * 0.07, 1.24, 0.16))
		part(r, cyl(0.025, 0.04, 0.8, 5), sh, Vector3(sx * 0.25, 0.6, 0.05), Vector3(0, 0, sx * 0.15))


func _e_swarm(r: Node3D) -> void:
	for k in range(9):
		var a := k * 2.4
		part(r, sph(0.08), mat(Color(0.55, 0.12, 0.1)), Vector3(cos(a) * (0.1 + k * 0.03), 0.08, sin(a) * (0.1 + k * 0.03)), Vector3.ZERO, Vector3(1, 0.6, 1.3))


func _e_onelegged(r: Node3D) -> void:
	part(r, cyl(0.05, 0.07, 0.6, 6), mat(Color(0.35, 0.3, 0.45)), Vector3(0, 0.3, 0))
	part(r, cyl(0.16, 0.24, 0.6, 8), mat(Color(0.9, 0.88, 0.8)), Vector3(0, 0.85, 0))
	part(r, sph(0.18), mat(Color(0.45, 0.4, 0.6)), Vector3(0, 1.28, 0))
	part(r, sph(0.07), mat(Color(1, 0.9, 0.2), Color(1, 0.85, 0.1), 3.0), Vector3(0, 1.32, 0.15))
	part(r, cyl(0.0, 0.06, 0.2, 5), mat(Color(0.9, 0.85, 0.7)), Vector3(0, 1.5, 0))


func _e_yogwi(r: Node3D) -> void:
	var c := Color(0.35, 0.42, 0.25)
	part(r, sph(0.42), mat(c), Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1.1, 1.0, 1.0))
	part(r, box(Vector3(0.5, 0.12, 0.1)), mat(Color(0.25, 0.05, 0.05)), Vector3(0, 0.55, 0.38))
	for k in range(5): part(r, cyl(0.0, 0.03, 0.08, 4), mat(Color(0.95, 0.92, 0.85)), Vector3(-0.2 + k * 0.1, 0.6, 0.42), Vector3(PI, 0, 0))
	glow_eyes(r, 0.8, 0.3, 0.14, 0.06, Color(1, 0.85, 0.1))
	part(r, sph(0.08), mat(GOLD, GOLD, 1.5), Vector3(0, 0.35, 0.4))


func _e_daegwi(r: Node3D) -> void:
	_ghost(r, {"c": Color(0.35, 0.3, 0.55), "h": 1.0, "bottom": 0.3, "eye": Color(1, 0.3, 0.3)})
	part(r, cyl(0.0, 0.08, 0.3, 5), mat(Color(0.9, 0.85, 0.7)), Vector3(0, 1.28, 0))
	var aura := part(r, torus(0.6, 0.7), fx_mat(Color(0.6, 0.4, 1.0), 0.5), Vector3(0, 0.08, 0))
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _e_sogwi(r: Node3D) -> void:
	part(r, sph(0.22), mat(Color(0.45, 0.35, 0.6)), Vector3(0, 0.3, 0))
	glow_eyes(r, 0.38, 0.18, 0.07, 0.04, Color(1, 0.3, 0.3))
	part(r, cyl(0.02, 0.02, 0.4, 5), mat(Color(0.4, 0.3, 0.2)), Vector3(0.22, 0.4, 0.05), Vector3(0, 0, -0.4))
	part(r, sph(0.08), metal(Color(0.5, 0.5, 0.52)), Vector3(0.3, 0.58, 0.05))


func _e_agwi(r: Node3D) -> void:
	var c := Color(0.55, 0.5, 0.45)
	part(r, sph(0.34), mat(c), Vector3(0, 0.38, 0))
	part(r, cyl(0.03, 0.04, 0.45, 6), mat(c), Vector3(0, 0.88, 0))
	part(r, sph(0.15), mat(c.lightened(0.1)), Vector3(0, 1.15, 0))
	glow_eyes(r, 1.18, 0.13, 0.06, 0.035, Color(1, 0.9, 0.3))
	for sx in [-1.0, 1.0]: part(r, cyl(0.02, 0.03, 0.4, 5), mat(c), Vector3(sx * 0.3, 0.5, 0.1), Vector3(0.6, 0, sx * 0.4))


func _e_gildal(r: Node3D) -> void:
	_ghost(r, {"c": Color(0.2, 0.3, 0.55), "alpha": 0.9, "hair": false, "eye": Color(1, 0.8, 0.2)})
	part(r, cyl(0.14, 0.16, 0.2, 10), mat(INK), Vector3(0, 1.2, 0))
	for sx in [-1.0, 1.0]: part(r, cyl(0.0, 0.06, 0.18, 4), mat(Color(0.9, 0.55, 0.25)), Vector3(sx * 0.1, 1.36, 0))
	part(r, cyl(0.04, 0.08, 0.4, 6), mat(Color(0.9, 0.55, 0.25)), Vector3(0, 0.4, -0.3), Vector3(-0.9, 0, 0))


func _e_jigwi(r: Node3D) -> void:
	_ghost(r, {"c": Color(0.6, 0.35, 0.2), "alpha": 0.9, "eye": Color(1, 0.9, 0.3)})
	for k in range(4):
		var f := part(r, cyl(0.0, 0.1, 0.35, 6), mat(Color(1, 0.5, 0.1), Color(1, 0.45, 0.1), 2.5, 0.8), Vector3(cos(k * 1.6) * 0.18, 1.2, sin(k * 1.6) * 0.15))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _e_yeoksin(r: Node3D) -> void:
	_ghost(r, {"c": Color(0.8, 0.75, 0.6), "skin": Color(0.9, 0.75, 0.65), "eye": Color(0.5, 1, 0.5)})
	for k in range(6): part(r, sph(0.03), mat(Color(0.8, 0.1, 0.1)), Vector3(cos(k) * 0.15, 0.95 + (k % 3) * 0.05, 0.14))
	var mist := part(r, cyl(0.6, 0.6, 0.02, 14), fx_mat(Color(0.3, 0.7, 0.5), 0.35), Vector3(0, 0.05, 0))
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _e_yeongno(r: Node3D) -> void:
	var c := Color(0.3, 0.45, 0.35)
	part(r, sph(0.38), mat(c), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1, 1, 1.15))
	part(r, sph(0.24), mat(c.lightened(0.1)), Vector3(0, 0.9, 0.3))
	part(r, cyl(0.0, 0.1, 0.35, 5), mat(GOLD), Vector3(0, 0.86, 0.6), Vector3(PI / 2, 0, 0))
	glow_eyes(r, 0.98, 0.48, 0.1, 0.045, Color(1, 0.3, 0.2))
	for k in range(4): part(r, cyl(0.0, 0.07, 0.28, 4), mat(Color(0.85, 0.2, 0.2)), Vector3(0, 1.0 - k * 0.05, 0.1 - k * 0.15), Vector3(-0.5, 0, 0))


func _e_foxsister(r: Node3D) -> void:
	_human(r, {"robe": Color(0.85, 0.2, 0.3), "top": Color(0.95, 0.85, 0.3), "hat": "bun", "scale": 1.5})
	glow_eyes(r, 1.56, 0.27, 0.1, 0.035, Color(1, 0.6, 0.1))
	for k in range(5):
		var tp := node(r, Vector3(0, 0.5, -0.35), Vector3(-0.7, 0, (k - 2) * 0.35))
		part(tp, cyl(0.07, 0.12, 0.55, 6), mat(Color(0.95, 0.6, 0.25)), Vector3(0, 0.27, 0))
		part(tp, sph(0.11), mat(Color(1, 0.95, 0.9)), Vector3(0, 0.58, 0))


func _e_centipede(r: Node3D) -> Array:
	var c := Color(0.7, 0.18, 0.12)
	part(r, sph(0.45), mat(c), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1.2, 0.7, 1.2))
	glow_eyes(r, 0.68, 0.42, 0.18, 0.08, Color(1, 0.9, 0.2))
	for sx in [-1.0, 1.0]: part(r, cyl(0.0, 0.06, 0.45, 5), mat(Color(0.95, 0.85, 0.3)), Vector3(sx * 0.2, 0.45, 0.6), Vector3(PI / 2, 0, -sx * 0.4))
	var segs: Array = []
	for k in range(7):
		var s := Node3D.new()
		part(s, sph(0.36), mat(c.darkened(0.06 * (k % 2))), Vector3.ZERO, Vector3.ZERO, Vector3(1.3, 0.6, 1.0))
		for sx in [-1.0, 1.0]: part(s, cyl(0.02, 0.03, 0.5, 4), mat(Color(0.95, 0.85, 0.3)), Vector3(sx * 0.42, -0.2, 0), Vector3(0, 0, sx * 0.9))
		root.add_child(s)
		segs.append(s)
	return segs


func _e_segment(r: Node3D) -> void:
	part(r, sph(0.32), mat(Color(0.7, 0.18, 0.12)), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.3, 0.6, 1.0))
	for sx in [-1.0, 1.0]:
		for k in range(2): part(r, cyl(0.02, 0.03, 0.42, 4), mat(Color(0.95, 0.85, 0.3)), Vector3(sx * 0.38, 0.15, -0.1 + k * 0.2), Vector3(0, 0, sx * 0.9))
	glow_eyes(r, 0.38, 0.28, 0.1, 0.04, Color(1, 0.9, 0.2))


func _e_daejeok(r: Node3D) -> void:
	var c := Color(0.25, 0.22, 0.3)
	part(r, sph(0.7), mat(c), Vector3(0, 0.8, 0), Vector3.ZERO, Vector3(1.1, 1.0, 1.0))
	for k in range(3):
		var a := (k - 1) * 0.6
		var hp := Vector3(sin(a) * 0.55, 1.45, cos(a) * 0.35)
		part(r, cyl(0.1, 0.16, 0.45, 6), mat(c), (hp + Vector3(0, 0.8, 0)) * 0.5 + Vector3(0, 0.35, 0), Vector3(0.3, 0, -a))
		part(r, sph(0.24), mat(c.lightened(0.1)), hp)
		for sx in [-1.0, 1.0]: part(r, sph(0.04), mat(Color(1, 0.2, 0.2), Color(1, 0.2, 0.2), 3.0), hp + Vector3(sx * 0.08, 0.05, 0.2))
		part(r, cyl(0.0, 0.05, 0.2, 5), mat(Color(0.9, 0.85, 0.7)), hp + Vector3(0, 0.25, 0))
	for sx in [-1.0, 1.0]: part(r, cyl(0.12, 0.16, 0.55, 6), mat(c.darkened(0.2)), Vector3(sx * 0.35, 0.25, 0))


# ---------------- projectiles & effects ----------------
func make_projectile(t: String, c: Color) -> Dictionary:
	var n := Node3D.new()
	var kind: String = PROJ.get(t, "orb")
	var spin := false
	match kind:
		"arrow":
			part(n, box(Vector3(0.03, 0.03, 0.5)), mat(Color(0.55, 0.38, 0.22)), Vector3.ZERO)
			part(n, cyl(0.0, 0.04, 0.1, 4), mat(Color(0.8, 0.8, 0.82)), Vector3(0, 0, 0.29), Vector3(PI / 2, 0, 0))
			part(n, box(Vector3(0.08, 0.01, 0.1)), mat(Color(0.95, 0.95, 0.9)), Vector3(0, 0, -0.22))
		"bullet":
			part(n, sph(0.06), fx_mat(Color(1, 0.9, 0.5), 1.0), Vector3.ZERO)
			part(n, box(Vector3(0.03, 0.03, 0.45)), fx_mat(Color(1, 0.8, 0.4), 0.5), Vector3(0, 0, -0.22))
		"club":
			part(n, cyl(0.07, 0.03, 0.32, 6), mat(Color(0.55, 0.35, 0.2)), Vector3.ZERO, Vector3(0, 0, PI / 2))
			spin = true
		"bell":
			part(n, torus(0.1, 0.14), fx_mat(Color(1, 0.85, 0.3), 0.9), Vector3.ZERO, Vector3(PI / 2, 0, 0))
			spin = true
		"water":
			part(n, sph(0.1), mat(Color(0.4, 0.7, 1.0), Color(0.3, 0.6, 1.0), 1.0, 0.75), Vector3.ZERO, Vector3.ZERO, Vector3(0.8, 0.8, 1.3))
		"roar":
			part(n, sph(0.16), fx_mat(Color(1, 0.8, 0.35), 0.9), Vector3.ZERO)
		"foxfire":
			part(n, sph(0.09), fx_mat(Color(0.75, 0.9, 1.0), 1.0), Vector3.ZERO)
			part(n, sph(0.15), fx_mat(Color(0.3, 0.55, 1.0), 0.45), Vector3(0, 0, -0.06))
		"talisman":
			part(n, box(Vector3(0.14, 0.2, 0.01)), mat(Color(0.98, 0.88, 0.4), Color(1, 0.8, 0.3), 0.6), Vector3.ZERO)
			part(n, box(Vector3(0.03, 0.14, 0.015)), mat(Color(0.8, 0.1, 0.1)), Vector3.ZERO)
			spin = true
		_:
			part(n, sph(0.09), fx_mat(c, 1.0), Vector3.ZERO)
	for ch in n.get_children():
		(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(n)
	return {"node": n, "spin": spin}


func _effect(n: Node3D, kind: String, life: float, vel: Vector3 = Vector3.ZERO) -> void:
	if effects.size() > 120:
		if is_instance_valid(effects[0]["node"]): effects[0]["node"].queue_free()
		effects.remove_at(0)
	effects.append({"node": n, "kind": kind, "t": 0.0, "life": life, "vel": vel})


func puff(pos: Vector3, c: Color, count: int = 6, size: float = 0.18) -> void:
	if headless: return
	for k in range(count):
		var a := k * TAU / count + vrng.randf() * 0.5
		var mi := part(root, sph(size), fx_mat(c, 0.55), pos + Vector3(0, 0.3, 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_effect(mi, "puff", 0.45, Vector3(cos(a) * 1.4, 1.2 + vrng.randf(), sin(a) * 1.4))


func ring(pos: Vector3, c: Color, r: float) -> void:
	if headless: return
	var mi := part(root, torus(0.8, 1.0), fx_mat(c, 0.7), pos + Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(0.2, 1, 0.2))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effect(mi, "ring", 0.3, Vector3(r, 0, 0))


func pillar(pos: Vector3, c: Color, big: bool) -> void:
	if headless: return
	var mi := part(root, cyl(0.5, 0.5, 1.0, 12), fx_mat(c, 0.45), pos + Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 0.1, 1))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effect(mi, "pillar", 0.9 if big else 0.6, Vector3(1.6 if big else 1.0, 7.0 if big else 4.0, 0))
	if big:
		ring(pos, c, 3.0)
		puff(pos, c, 10, 0.22)


func update(dt: float, t: float) -> void:
	for k in range(anims.size() - 1, -1, -1):
		var a: Dictionary = anims[k]
		if not is_instance_valid(a["node"]):
			anims.remove_at(k)
			continue
		var n: Node3D = a["node"]
		var ph: float = a["ph"] + t * a["sp"]
		match a["kind"]:
			"spin": n.rotation.y = ph
			"sway": n.rotation.z = sin(ph) * a["amp"]
			"bob": n.position = a["base"] + Vector3(0, sin(ph) * a["amp"], 0)
			"drift": n.position = a["base"] + Vector3(sin(ph) * a["amp"], sin(ph * 1.7) * a["amp"] * 0.5, cos(ph * 0.8) * a["amp"])
			"orbit": n.position = a["base"] + Vector3(cos(ph) * a["amp"], sin(ph * 2.0) * 0.08, sin(ph) * a["amp"])
			"rise":
				var f := fposmod(ph, 1.0)
				n.position = a["base"] + Vector3(0, f * a["amp"], 0)
				n.scale = Vector3.ONE * (1.0 - f)
	for k in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[k]
		e["t"] += dt
		var f: float = e["t"] / e["life"]
		if f >= 1.0 or not is_instance_valid(e["node"]):
			if is_instance_valid(e["node"]): e["node"].queue_free()
			effects.remove_at(k)
			continue
		var n2: Node3D = e["node"]
		var v: Vector3 = e["vel"]
		match e["kind"]:
			"puff":
				n2.position += v * dt
				n2.scale = Vector3.ONE * (1.0 - f)
			"ring":
				var r: float = lerpf(0.2, v.x, f)
				n2.scale = Vector3(r, 1.0 - f, r)
			"pillar":
				var w: float = v.x * (1.0 - f * f)
				n2.scale = Vector3(w, v.y * minf(1.0, f * 4.0), w)
				n2.position.y = 0.1 + n2.scale.y * 0.5
