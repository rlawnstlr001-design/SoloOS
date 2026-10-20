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
	"tongjesa": "bullet", "hogukryong": "water", "yeonggam": "foxfire", "cheongryong": "foxfire", "baekho": "roar",
	"jujak": "foxfire", "girin": "roar", "bonghwang": "foxfire", "uibyeong": "arrow", "singijeon": "arrow", "gaema": "club",
	"uinyeo": "talisman", "samsin": "talisman", "jacheongbi": "water", "sasin": "foxfire", "seungjang": "bell",
}

var root: Node3D
var headless := false
var mats := {}
var meshes := {}
var vrng := RandomNumberGenerator.new()
var anims: Array = []    # ambient loops: {node, kind, base, ph, sp, amp}
var slot_nodes: Array = []  # [base, top] per board cell
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
	_toon(m)
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
	_toon(m)
	mats[key] = m
	return m


# ---------------- style: cel shading, outlines, chibi heads ----------------
# Style pass (docs/design/14_style_pass.md): banded toon light + soft rim on everything, an inverted-hull outline on
# characters, and bigger heads on humanoid units so they read at gameplay zoom.
const OUTLINE_W := 0.018
const CHIBI := ["dokkaebi", "dokkaebi_king", "gungsa", "chakho", "posu", "mudang", "jeoseung", "yeomra", "mulgwisin", "ssireum",
	"bihyeong", "gwigyo", "hwarang", "seungbyeong", "agijangsu", "cheoyong", "cheoyongrang", "pansu", "bari", "jeonuchi", "honggildong",
	"hwalbin", "baksi", "mago", "tongjesa", "yongwang", "yeonggam", "uibyeong", "uinyeo", "samsin", "jacheongbi", "seungjang"]
var outline_pass: StandardMaterial3D = null
var outlined := {}


func _toon(m: StandardMaterial3D) -> void:
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.6


func _outline_of(m: Material) -> Material:
	var sm := m as StandardMaterial3D
	if sm == null or sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return m
	var id := sm.get_instance_id()
	if outlined.has(id): return outlined[id]
	if outline_pass == null:
		outline_pass = StandardMaterial3D.new()
		outline_pass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline_pass.cull_mode = BaseMaterial3D.CULL_FRONT
		outline_pass.grow = true
		outline_pass.grow_amount = OUTLINE_W
		outline_pass.albedo_color = Color(0.05, 0.04, 0.08)
	var d := sm.duplicate() as StandardMaterial3D
	d.next_pass = outline_pass
	outlined[id] = d
	return d


func style_tree(n: Node) -> void:
	# outlines on every opaque part big enough to carry one (tiny eyes and strings stay clean)
	for ch in n.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_aabb().size.length() * mi.scale.length() / 1.732 > 0.13:
				mi.material_override = _outline_of(mi.material_override)
		if ch is Node3D and not (ch is Light3D): style_tree(ch)


func _chibi(cont: Node3D, hc: Vector3, thr: float, k: float) -> void:
	# scale everything above the neck around the head centre: bigger head, hat and face
	for ch in cont.get_children():
		if not (ch is Node3D): continue
		var c3 := ch as Node3D
		if c3.position.y < thr: continue
		c3.position = hc + (c3.position - hc) * k
		c3.scale *= k


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
func build_world(corners: Array, slots: Array, open: Array) -> void:
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
	var c2: Vector3 = corners[2]
	part(root, box(Vector3(absf(c2.x) * 2.0 - 1.4, 0.02, absf(c2.z) * 2.0 - 1.4)), mat(Color(0.42, 0.36, 0.27)), Vector3(0, 0.005, 0))
	for k in range(4):
		var a: Vector3 = corners[k]; var b: Vector3 = corners[(k + 1) % 4]
		part(root, box(Vector3(absf(b.x - a.x) + 1.4, 0.04, absf(b.z - a.z) + 1.4)), mat(Color(0.31, 0.26, 0.21)), (a + b) / 2.0 + Vector3(0, 0.02, 0))
	_track_stones(corners)
	_grass(corners)
	for i in range(slots.size()):
		_slot_stone(slots[i])
		set_slot_locked(i, not open[i])
	_gate(corners[0])
	_portal(corners[0])
	# village dressing (kept off the track and away from the HUD panel)
	_giwa_house(Vector3(-11.5, 0, -10.6), 0.0)
	_choga_house(Vector3(-6.4, 0, -10.9), 0.15)
	_choga_house(Vector3(-1.6, 0, -10.7), -0.1)
	_giwa_house(Vector3(3.6, 0, -10.8), 0.05)
	_choga_house(Vector3(8.8, 0, -10.6), 0.2)
	for p in [Vector3(-14.0, 0, -5.5), Vector3(-14.8, 0, 2.4), Vector3(-13.2, 0, 6.8), Vector3(-16.2, 0, -1.6), Vector3(13.6, 0, -8.6), Vector3(-9.0, 0, -14.0), Vector3(1.0, 0, -14.4), Vector3(14.5, 0, 6.5)]:
		_pine(p, 0.9 + vrng.randf() * 0.4)
	_stone_wall(Vector3(-13.0, 0, 9.4), Vector3(12.5, 0, 9.4))
	for p in [Vector3(10.4, 0, -7.4), Vector3(10.4, 0, 7.4), Vector3(-10.4, 0, 7.4), Vector3(0.0, 0, -7.3), Vector3(0.0, 0, 7.3)]:
		_cheongsa_lantern(p)
	_fireflies(28)


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
		if absf(p.x) < 10.0 and absf(p.z) < 7.0: continue
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
	var b := part(root, box(Vector3(1.66, 0.12, 1.66)), mat(Color(0.2, 0.21, 0.21)), p + Vector3(0, 0.06, 0))
	var t := part(root, box(Vector3(1.48, 0.05, 1.48)), mat(Color(0.3, 0.31, 0.29)), p + Vector3(0, 0.14, 0))
	slot_nodes.append([b, t])


func set_slot_locked(i: int, locked: bool) -> void:
	# closed cells: sunken dark stone with a dashed rim; open cells: raised slab
	var b: MeshInstance3D = slot_nodes[i][0]
	var t: MeshInstance3D = slot_nodes[i][1]
	t.visible = not locked
	b.material_override = mat(Color(0.13, 0.13, 0.15)) if locked else mat(Color(0.2, 0.21, 0.21))
	b.scale = Vector3(1, 0.4 if locked else 1.0, 1)


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
		var p := Vector3(vrng.randf_range(-17, 12), vrng.randf_range(0.4, 1.8), vrng.randf_range(-12, 9))
		if absf(p.x) < 9.5 and absf(p.z) < 6.5: p.z = -8.0 - vrng.randf() * 4.0
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
	var custom := load_model("units", t)
	if custom != null:
		_style_model(custom)
		rig.add_child(_fit_model(custom, 1.65 if hero else 1.45))
	else:
		_build_unit(rig, t)
	if hero:
		var halo := part(n, torus(0.26, 0.32), mat(GOLD, GOLD, 3.0), Vector3(0, 1.95, 0))
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if tier >= 2:
		var l := OmniLight3D.new(); l.light_color = tier_c; l.omni_range = 2.2; l.light_energy = 0.8 + tier * 0.4; l.position = Vector3(0, 1.0, 0)
		n.add_child(l)
	var sc := 1.0 + tier * 0.12
	n.scale = Vector3(sc, sc, sc)
	root.add_child(n)
	return n


func _m_dokkaebi(r: Node3D, king: bool) -> void:
	# Korean-leaning dokkaebi: ruddy skin, 바지저고리, huge shaggy mane, big eyes and grin, knobbly wooden club.
	# No horn and no tiger-skin loincloth (that look is criticised as Japanese oni influence).
	var skin := Color(0.66, 0.34, 0.24) if king else Color(0.74, 0.4, 0.27)
	var jacket := Color(0.62, 0.12, 0.14) if king else Color(0.25, 0.33, 0.55)
	var pants := Color(0.92, 0.9, 0.84)
	for sx in [-1.0, 1.0]:
		part(r, cyl(0.08, 0.1, 0.28, 6), mat(pants), Vector3(sx * 0.13, 0.15, 0))
		part(r, torus(0.06, 0.09), mat(jacket.darkened(0.2)), Vector3(sx * 0.13, 0.06, 0))
		part(r, box(Vector3(0.14, 0.06, 0.24)), mat(Color(0.75, 0.65, 0.42)), Vector3(sx * 0.13, 0.02, 0.04))
	part(r, cyl(0.25, 0.33, 0.24, 10), mat(pants), Vector3(0, 0.36, 0))
	part(r, sph(0.32), mat(jacket), Vector3(0, 0.64, 0), Vector3.ZERO, Vector3(1.05, 1.0, 0.92))
	part(r, box(Vector3(0.08, 0.3, 0.04)), mat(Color(0.97, 0.97, 0.95)), Vector3(-0.06, 0.74, 0.27), Vector3(0, 0, 0.5))
	part(r, torus(0.27, 0.31), mat(jacket.darkened(0.25)), Vector3(0, 0.46, 0))
	part(r, sph(0.27), mat(skin), Vector3(0, 1.02, 0.02))
	for k in range(9):
		var a := k * TAU / 9.0
		part(r, sph(0.12), mat(Color(0.16, 0.14, 0.18)), Vector3(cos(a) * 0.24, 1.1 + 0.08 * sin(a * 2.0), sin(a) * 0.2 - 0.07))
	part(r, sph(0.16), mat(Color(0.16, 0.14, 0.18)), Vector3(0, 1.24, -0.08), Vector3.ZERO, Vector3(1.4, 0.8, 1.2))
	eyes(r, 1.08, 0.22, 0.1, 0.08)
	for sx in [-1.0, 1.0]: part(r, box(Vector3(0.12, 0.035, 0.04)), mat(Color(0.12, 0.1, 0.1)), Vector3(sx * 0.1, 1.17, 0.22), Vector3(0, 0, -sx * 0.25))
	part(r, sph(0.07), mat(skin.darkened(0.12)), Vector3(0, 1.0, 0.27))
	part(r, box(Vector3(0.26, 0.07, 0.04)), mat(Color(0.25, 0.06, 0.06)), Vector3(0, 0.91, 0.23))
	for sx in [-1.0, 1.0]: part(r, cyl(0.03, 0.0, 0.07, 4), mat(Color(0.98, 0.96, 0.88)), Vector3(sx * 0.08, 0.91, 0.25))
	if king:
		part(r, cyl(0.2, 0.2, 0.08, 12), mat(GOLD, GOLD, 0.8), Vector3(0, 1.3, 0))
		for k in range(5):
			var a := k * TAU / 5.0
			part(r, box(Vector3(0.05, 0.2, 0.02)), mat(GOLD, GOLD, 0.8), Vector3(cos(a) * 0.19, 1.42, sin(a) * 0.19), Vector3(0, -a, 0))
		part(r, box(Vector3(0.62, 0.78, 0.05)), mat(Color(0.28, 0.08, 0.32)), Vector3(0, 0.66, -0.3), Vector3(0.15, 0, 0))
	part(r, cyl(0.07, 0.08, 0.36, 6), mat(jacket), Vector3(0.33, 0.66, 0.05), Vector3(0, 0, 0.9))
	var club := node(r, Vector3(0.48, 0.62, 0.12), Vector3(0.5, 0, -0.5))
	var cm := mat(GOLD, GOLD, 0.7) if king else mat(Color(0.52, 0.34, 0.2))
	part(club, cyl(0.14, 0.06, 0.62, 8), cm, Vector3(0, 0.31, 0))
	for k in range(6):
		var a := k * TAU / 6.0
		part(club, sph(0.055), cm, Vector3(cos(a) * 0.12, 0.38 + 0.08 * (k % 2), sin(a) * 0.12))


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
	var custom := load_model("yokai", look)
	if custom != null:
		_style_model(custom)
		rig.add_child(_fit_model(custom, 2.2 if boss else 1.1))
	else:
		segs = _build_enemy(rig, look)
	var flash := part(n, sph(0.5), fx_mat(Color(1, 1, 1), 0.55), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3.ONE * (2.0 if boss else 1.0))
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	root.add_child(n)
	return {"node": n, "rig": rig, "segs": segs, "flash": flash}


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
		"spear":
			part(w, cyl(0.02, 0.02, 1.1, 5), mat(Color(0.45, 0.3, 0.18)), Vector3(0, 0.3, 0))
			part(w, cyl(0.0, 0.05, 0.18, 4), metal(Color(0.85, 0.87, 0.9)), Vector3(0, 0.92, 0))
		"book":
			part(w, box(Vector3(0.22, 0.28, 0.05)), mat(o.get("w_c", Color(0.85, 0.75, 0.45))), Vector3(-0.05, 0.0, 0.08), Vector3(0, -0.4, 0))
		"torch":
			part(w, cyl(0.025, 0.03, 0.6, 5), mat(Color(0.45, 0.3, 0.18)), Vector3(0, 0.2, 0))
			part(w, cyl(0.0, 0.08, 0.2, 6), mat(Color(1, 0.55, 0.15), Color(1, 0.5, 0.1), 2.5, 0.85), Vector3(0, 0.6, 0))


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


func _build_unit(rig: Node3D, t: String) -> void:
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
		"yeonggam": _m_yeonggam(rig)
		"cheongryong": _m_cheongryong(rig, false)
		"baekho": _m_baekho(rig)
		"jujak": _m_jujak(rig)
		"girin": _m_girin(rig)
		"bonghwang": _m_bonghwang(rig)
		"uibyeong": _human(rig, {"robe": Color(0.92, 0.9, 0.84), "hat": "headband", "hat_c": Color(0.95, 0.95, 0.92), "weapon": "spear"})
		"singijeon": _m_singijeon(rig)
		"gaema": _m_gaema(rig)
		"uinyeo": _human(rig, {"robe": Color(0.3, 0.45, 0.55), "top": Color(0.9, 0.85, 0.75), "hat": "bun", "weapon": "book", "w_c": Color(0.5, 0.3, 0.2)})
		"samsin": _human(rig, {"robe": Color(0.95, 0.95, 0.92), "top": Color(0.85, 0.85, 0.82), "hat": "bun", "hat_c": Color(0.92, 0.92, 0.9), "weapon": "flower", "scale": 0.95})
		"jacheongbi": _human(rig, {"robe": Color(0.35, 0.55, 0.35), "top": Color(0.9, 0.8, 0.4), "hat": "gat", "weapon": "flower"})
		"sasin":
			_m_cheongryong(rig, true)
			var halo2 := part(rig, torus(0.65, 0.75), fx_mat(Color(1, 0.6, 0.3), 0.5), Vector3(0, 0.1, 0))
			halo2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"seungjang": _human(rig, {"robe": Color(0.5, 0.48, 0.45), "top": Color(0.7, 0.35, 0.2), "sash": GOLD, "hat": "satgat", "weapon": "staff", "cape": Color(0.6, 0.3, 0.15), "scale": 1.1})
	if CHIBI.has(t):
		var cont: Node3D = rig
		if rig.get_child_count() == 1 and not (rig.get_child(0) is MeshInstance3D): cont = rig.get_child(0)
		_chibi(cont, Vector3(0, 1.02, 0), 0.9, 1.32)
	style_tree(rig)


func _build_enemy(rig: Node3D, look: String) -> Array:
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
		"songaksi": _e_songaksi(rig)
		"mongdal": _e_mongdal(rig)
		"haeryong": _serpent(rig, Color(0.2, 0.45, 0.8), 6, 0.24)
		"judungi": _e_judungi(rig)
		"gangcheol": segs = _e_gangcheol(rig)
		"dokryong": segs = _e_dokryong(rig)
		"goldpig": _e_goldpig(rig)
		_: _jabgwi(rig)
	style_tree(rig)
	for sg in segs: style_tree(sg)
	return segs


# ---------------- external models (.glb) — docs/design/15_model_pipeline.md ----------------
# assets/models/units/<unit key>.glb and assets/models/yokai/<look key>.glb replace the procedural model when present.
# Loaded at runtime with GLTFDocument (no editor import needed), fitted to a target height, stood on the floor,
# and given the same toon shading + outline as everything else.
var model_dir := "res://assets/models"
var model_cache := {}


func load_model(kind: String, key: String) -> Node3D:
	var path := "%s/%s/%s.glb" % [model_dir, kind, key]
	if not model_cache.has(path):
		var tpl: Node3D = null
		if FileAccess.file_exists(path):
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(path, st) == OK:
				tpl = doc.generate_scene(st) as Node3D
		model_cache[path] = tpl
	var t = model_cache[path]
	if t == null: return null
	var inst: Node3D = t.duplicate()
	var ap := _find_anim(inst)
	if ap != null:
		var names := ap.get_animation_list()
		var pick := ""
		for nm in names:
			if String(nm).to_lower().contains("idle"): pick = nm
		if pick == "" and names.size() > 0: pick = names[0]
		if pick != "":
			ap.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
			ap.autoplay = pick
	return inst


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for ch in n.get_children():
		var r := _find_anim(ch)
		if r != null: return r
	return null


func _model_aabb(n: Node, xf: Transform3D) -> AABB:
	var box_out := AABB()
	var first := true
	var x2 := xf
	if n is Node3D: x2 = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		box_out = x2 * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for ch in n.get_children():
		var cb := _model_aabb(ch, x2)
		if cb.size == Vector3.ZERO: continue
		if first:
			box_out = cb; first = false
		else: box_out = box_out.merge(cb)
	return box_out


func _fit_model(m: Node3D, height: float) -> Node3D:
	# wrap the model and fit the wrapper: uniform scale to the target height, centred on x/z, feet on y = 0
	var fit := Node3D.new()
	fit.add_child(m)
	var bb := _model_aabb(m, Transform3D.IDENTITY)
	if bb.size.y <= 0.0001: return fit
	var k := height / bb.size.y
	var c := bb.get_center()
	fit.scale = Vector3.ONE * k
	fit.position = Vector3(-c.x * k, -bb.position.y * k, -c.z * k)
	return fit


func _style_model(n: Node) -> void:
	# toon + rim on every surface material, outline on opaque ones
	for ch in n.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			if mi.mesh != null:
				for i in range(mi.mesh.get_surface_count()):
					var src := mi.get_active_material(i)
					var bm := src as BaseMaterial3D
					var d: BaseMaterial3D
					if bm == null:
						d = StandardMaterial3D.new()
						d.albedo_color = Color(0.85, 0.85, 0.85)
					else:
						d = bm.duplicate() as BaseMaterial3D
					d.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
					d.specular_mode = BaseMaterial3D.SPECULAR_TOON
					d.rim_enabled = true
					d.rim = 0.3
					d.rim_tint = 0.6
					d.metallic = minf(d.metallic, 0.3)
					if d.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
						if outline_pass == null: _outline_of(mat(Color.WHITE))
						d.next_pass = outline_pass
					mi.set_surface_override_material(i, d)
		_style_model(ch)


# ---------------- co-op: partner stage (mirrored from network snapshots) ----------------
func build_partner_stage(ofs: Vector3, corners: Array, nslots: int, slot_pos: Callable) -> void:
	var c2: Vector3 = corners[2]
	part(root, box(Vector3(absf(c2.x) * 2.0 + 6.0, 0.3, absf(c2.z) * 2.0 + 6.0)), mat(Color(0.15, 0.24, 0.17)), ofs + Vector3(0, -0.15, 0))
	part(root, box(Vector3(absf(c2.x) * 2.0 - 1.4, 0.02, absf(c2.z) * 2.0 - 1.4)), mat(Color(0.4, 0.34, 0.26)), ofs + Vector3(0, 0.005, 0))
	for k in range(4):
		var a: Vector3 = corners[k]; var b: Vector3 = corners[(k + 1) % 4]
		part(root, box(Vector3(absf(b.x - a.x) + 1.4, 0.04, absf(b.z - a.z) + 1.4)), mat(Color(0.31, 0.26, 0.21)), ofs + (a + b) / 2.0 + Vector3(0, 0.02, 0))
	for i in range(nslots):
		var p: Vector3 = slot_pos.call(i)
		part(root, box(Vector3(1.6, 0.1, 1.6)), mat(Color(0.22, 0.23, 0.24)), ofs + p + Vector3(0, 0.05, 0))
	_portal(corners[0] + ofs)
	var g := node(root, ofs + Vector3(0, 0, absf(c2.z) + 2.2))
	var flag := part(g, box(Vector3(2.4, 0.6, 0.05)), mat(Color(0.3, 0.8, 0.6), Color(0.3, 0.8, 0.6), 0.6), Vector3(0, 2.2, 0))
	_anim(flag, "sway", 1.0, 0.05)
	for sx in [-1.2, 1.2]: part(g, cyl(0.05, 0.06, 2.6, 6), mat(Color(0.4, 0.3, 0.2)), Vector3(sx, 1.3, 0))
	var l := OmniLight3D.new(); l.light_color = Color(0.6, 1.0, 0.8); l.omni_range = 18.0; l.light_energy = 0.6; l.position = ofs + Vector3(0, 6, 0)
	root.add_child(l)


# ---------------- village decorations (마을 꾸미기) ----------------
func build_deco_spots(spots: Array) -> Array:
	var out: Array = []
	for p in spots:
		var m := node(root, p + Vector3(0, 0.03, 0))
		var ring := part(m, torus(0.85, 1.0), fx_mat(Color(0.5, 1.0, 0.6), 0.55), Vector3.ZERO)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.name = "ring"
		_anim(m, "bob", 1.5, 0.04)
		out.append(m)
	return out


func set_spot_state(m: Node3D, open: bool, used: bool) -> void:
	var ring: MeshInstance3D = m.get_node("ring")
	if not open: ring.material_override = fx_mat(Color(0.45, 0.45, 0.5), 0.25)
	elif used: ring.material_override = fx_mat(Color(1.0, 0.85, 0.4), 0.35)
	else: ring.material_override = fx_mat(Color(0.5, 1.0, 0.6), 0.6)


func make_deco(k: String, p: Vector3) -> Node3D:
	var n := node(root, p)
	var wood := mat(Color(0.5, 0.35, 0.22))
	var stone := mat(Color(0.55, 0.54, 0.5))
	match k:
		"jangseung":
			for sx in [-0.45, 0.45]:
				var j := node(n, Vector3(sx, 0, 0))
				part(j, cyl(0.15, 0.18, 1.5, 8), wood, Vector3(0, 0.75, 0))
				part(j, sph(0.2), wood, Vector3(0, 1.55, 0))
				eyes(j, 1.58, 0.16, 0.07, 0.05)
				part(j, box(Vector3(0.2, 0.05, 0.04)), mat(Color(0.95, 0.92, 0.85)), Vector3(0, 1.36, 0.17))
				part(j, cyl(0.14, 0.18, 0.22, 8), mat(INK) if sx < 0 else mat(Color(0.75, 0.2, 0.18)), Vector3(0, 1.8, 0))
		"sotdae":
			part(n, cyl(0.04, 0.05, 2.4, 6), wood, Vector3(0, 1.2, 0))
			for k2 in range(3):
				var b := node(n, Vector3(0, 2.42 - k2 * 0.02, 0), Vector3(0, k2 * 2.1, 0))
				part(b, sph(0.1), wood, Vector3(0.15, 0, 0), Vector3.ZERO, Vector3(1.6, 0.8, 0.8))
				part(b, cyl(0.0, 0.03, 0.12, 4), wood, Vector3(0.33, 0.02, 0), Vector3(0, 0, -PI / 2))
		"seonang":
			for k2 in range(9):
				var a := k2 * 2.1
				part(n, sph(0.2 - k2 * 0.01), stone, Vector3(cos(a) * 0.25 * (1.0 - k2 * 0.08), 0.15 + k2 * 0.1, sin(a) * 0.25 * (1.0 - k2 * 0.08)))
			part(n, cyl(0.06, 0.09, 1.6, 6), wood, Vector3(0.6, 0.8, 0))
			var cols := [Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.3), Color(0.2, 0.4, 0.85), Color(0.95, 0.95, 0.95), Color(0.25, 0.65, 0.35)]
			for k2 in range(5): part(n, box(Vector3(0.05, 0.4, 0.02)), mat(cols[k2]), Vector3(0.6 + (k2 - 2) * 0.12, 1.2, 0.1), Vector3(0, 0, (k2 - 2) * 0.2))
		"seokdeung":
			part(n, cyl(0.3, 0.36, 0.15, 6), stone, Vector3(0, 0.08, 0))
			part(n, cyl(0.1, 0.12, 0.8, 6), stone, Vector3(0, 0.55, 0))
			part(n, box(Vector3(0.42, 0.34, 0.42)), mat(Color(1, 0.8, 0.45), Color(1, 0.7, 0.3), 2.0), Vector3(0, 1.1, 0))
			part(n, cyl(0.0, 0.4, 0.3, 6), stone, Vector3(0, 1.42, 0))
			var l := OmniLight3D.new(); l.light_color = Color(1, 0.7, 0.4); l.omni_range = 3.0; l.light_energy = 0.8; l.position = Vector3(0, 1.1, 0)
			n.add_child(l)
		"chorong":
			for sx in [-0.6, 0.6]:
				var s2 := node(n, Vector3(sx, 0, 0))
				part(s2, cyl(0.03, 0.04, 1.6, 6), wood, Vector3(0, 0.8, 0))
				part(s2, cyl(0.13, 0.13, 0.14, 8), mat(Color(0.2, 0.3, 0.8), Color(0.3, 0.45, 1.0), 1.2), Vector3(0, 1.5, 0.12))
				part(s2, cyl(0.13, 0.13, 0.18, 8), mat(Color(0.9, 0.2, 0.2), Color(1, 0.45, 0.3), 2.2), Vector3(0, 1.34, 0.12))
		"jangdok":
			part(n, box(Vector3(1.6, 0.18, 1.1)), stone, Vector3(0, 0.09, 0))
			var jar := mat(Color(0.35, 0.2, 0.12))
			for k2 in range(5):
				var jp := Vector3(-0.5 + (k2 % 3) * 0.5, 0, -0.2 + (k2 / 3) * 0.45)
				var sc := 0.8 + 0.2 * (k2 % 2)
				part(n, sph(0.25), jar, jp + Vector3(0, 0.18 + 0.23 * sc, 0), Vector3.ZERO, Vector3(sc, sc * 1.15, sc))
				part(n, cyl(0.15, 0.18, 0.05, 10), jar, jp + Vector3(0, 0.18 + 0.5 * sc, 0), Vector3.ZERO, Vector3(sc, 1, sc))
		"geumjul":
			for sx in [-0.8, 0.8]: part(n, cyl(0.04, 0.05, 1.3, 6), wood, Vector3(sx, 0.65, 0))
			part(n, cyl(0.025, 0.025, 1.6, 6), mat(Color(0.85, 0.75, 0.5)), Vector3(0, 1.15, 0), Vector3(0, 0, PI / 2))
			for k2 in range(6):
				var c2 := Color(0.85, 0.15, 0.1) if k2 % 2 == 0 else Color(0.15, 0.12, 0.1)
				part(n, cyl(0.03, 0.01, 0.16, 4), mat(c2), Vector3(-0.6 + k2 * 0.24, 1.02, 0))
		"haetaesang":
			part(n, box(Vector3(0.7, 0.3, 0.9)), stone, Vector3(0, 0.15, 0))
			var h := node(n, Vector3(0, 0.3, 0))
			h.scale = Vector3(0.9, 0.9, 0.9)
			_m_haetae(h)
		"ssireumpan":
			part(n, cyl(0.95, 0.95, 0.06, 16), mat(Color(0.82, 0.74, 0.52)), Vector3(0, 0.03, 0))
			part(n, torus(0.9, 1.0), mat(Color(0.55, 0.42, 0.28)), Vector3(0, 0.05, 0))
		"sindansu":
			part(n, cyl(0.14, 0.24, 1.8, 7), mat(Color(0.4, 0.3, 0.2)), Vector3(0, 0.9, 0))
			part(n, sph(0.8), mat(Color(0.2, 0.4, 0.22)), Vector3(0, 2.1, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1.2))
			var cols2 := [Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.3), Color(0.2, 0.4, 0.85), Color(0.95, 0.95, 0.95)]
			for k2 in range(4): part(n, box(Vector3(0.05, 0.5, 0.02)), mat(cols2[k2]), Vector3(cos(k2 * 1.6) * 0.25, 1.3, sin(k2 * 1.6) * 0.25))
			part(n, torus(0.2, 0.25), mat(Color(0.85, 0.75, 0.5)), Vector3(0, 1.1, 0))
		"hwalteo":
			part(n, box(Vector3(1.0, 1.3, 0.1)), mat(Color(0.95, 0.92, 0.85)), Vector3(0, 0.75, 0))
			for k2 in range(3): part(n, cyl(0.38 - k2 * 0.12, 0.38 - k2 * 0.12, 0.11, 14), mat(Color(0.85, 0.15, 0.15) if k2 % 2 == 0 else Color(0.2, 0.3, 0.75)), Vector3(0, 0.8, 0.01 * k2), Vector3(PI / 2, 0, 0))
			for sx in [-0.45, 0.45]: part(n, cyl(0.04, 0.04, 0.4, 5), wood, Vector3(sx, 0.2, 0))
		"gutdang":
			part(n, box(Vector3(1.2, 0.8, 0.9)), mat(Color(0.86, 0.82, 0.72)), Vector3(0, 0.4, 0))
			part(n, prism(Vector3(1.5, 0.5, 1.1)), mat(Color(0.25, 0.25, 0.3)), Vector3(0, 1.05, 0))
			var cols3 := [Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.3), Color(0.2, 0.4, 0.85)]
			for k2 in range(3): part(n, box(Vector3(0.18, 0.35, 0.02)), mat(cols3[k2]), Vector3(-0.35 + k2 * 0.35, 0.5, 0.46))
		"jeongja":
			for cx in [-0.55, 0.55]:
				for cz in [-0.55, 0.55]: part(n, cyl(0.05, 0.05, 1.2, 6), mat(Color(0.6, 0.2, 0.15)), Vector3(cx, 0.6, cz))
			part(n, box(Vector3(1.3, 0.08, 1.3)), wood, Vector3(0, 0.25, 0))
			part(n, cyl(0.0, 1.05, 0.55, 6), mat(Color(0.25, 0.3, 0.35)), Vector3(0, 1.45, 0))
		"yeonmot":
			part(n, cyl(1.0, 1.0, 0.03, 16), mat(Color(0.2, 0.4, 0.55), Color(0.2, 0.4, 0.6), 0.4), Vector3(0, 0.02, 0))
			part(n, torus(0.95, 1.08), stone, Vector3(0, 0.03, 0))
			for k2 in range(3):
				part(n, cyl(0.16, 0.16, 0.02, 8), mat(Color(0.25, 0.55, 0.3)), Vector3(cos(k2 * 2.1) * 0.45, 0.05, sin(k2 * 2.1) * 0.45))
				part(n, sph(0.06), mat(Color(1, 0.6, 0.75), Color(1, 0.5, 0.7), 0.8), Vector3(cos(k2 * 2.1) * 0.45, 0.1, sin(k2 * 2.1) * 0.45))
		"obanggi":
			var cols4 := [Color(0.2, 0.4, 0.85), Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.3), Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.14)]
			for k2 in range(5):
				var fpos := Vector3((k2 - 2) * 0.35, 0, absf(k2 - 2) * 0.12)
				part(n, cyl(0.025, 0.03, 1.6, 5), wood, fpos + Vector3(0, 0.8, 0))
				var flag := part(n, box(Vector3(0.3, 0.4, 0.02)), mat(cols4[k2]), fpos + Vector3(0.16, 1.4, 0))
				_anim(flag, "sway", 1.2 + k2 * 0.2, 0.15)
	return n


# ---------------- unlockable units ----------------
func _m_baekho(r: Node3D) -> void:
	_quad(r, {"c": Color(0.95, 0.95, 0.93), "len": 1.4, "stripes": true, "eye": Color(0.4, 0.8, 1.0)})


func _m_cheongryong(r: Node3D, big: bool) -> void:
	var c := Color(0.2, 0.55, 0.75)
	var s := 1.2 if big else 1.0
	var b := node(r, Vector3.ZERO)
	b.scale = Vector3(s, s, s)
	for k in range(7):
		var a := k * 0.9
		part(b, sph(0.14 - k * 0.008), mat(c.darkened(0.04 * k)), Vector3(cos(a) * 0.32, 0.25 + k * 0.1, sin(a) * 0.32))
	part(b, sph(0.2), mat(c.lightened(0.1)), Vector3(0.1, 1.0, 0.25), Vector3.ZERO, Vector3(1, 0.85, 1.3))
	glow_eyes(b, 1.06, 0.42, 0.09, 0.03, Color(1, 1, 0.6))
	for sx in [-1.0, 1.0]: part(b, cyl(0.0, 0.035, 0.28, 5), mat(Color(0.95, 0.92, 0.8)), Vector3(0.1 + sx * 0.09, 1.24, 0.15), Vector3(-0.5, 0, -sx * 0.3))
	var bolt := part(b, sph(0.06), fx_mat(Color(0.7, 0.9, 1.0), 1.0), Vector3(0.4, 1.0, 0))
	anims.append({"node": bolt, "kind": "orbit", "base": Vector3(0, 1.0, 0), "ph": 0.0, "sp": 3.0, "amp": 0.45})


func _m_jujak(r: Node3D) -> void:
	var b := node(r, Vector3(0, 0.2, 0))
	part(b, sph(0.24), mat(Color(0.85, 0.2, 0.15)), Vector3(0, 0.7, 0), Vector3.ZERO, Vector3(1, 0.9, 1.3))
	part(b, sph(0.14), mat(Color(0.9, 0.3, 0.15)), Vector3(0, 0.95, 0.2))
	part(b, cyl(0.0, 0.05, 0.14, 5), mat(GOLD), Vector3(0, 0.93, 0.36), Vector3(PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		part(b, box(Vector3(0.5, 0.05, 0.28)), mat(Color(1, 0.45, 0.15), Color(1, 0.4, 0.1), 1.2), Vector3(sx * 0.36, 0.8, -0.02), Vector3(0, 0, sx * 0.45))
		part(b, sph(0.03), mat(Color(1, 0.9, 0.3), Color(1, 0.9, 0.3), 3.0), Vector3(sx * 0.06, 0.99, 0.31))
	for k in range(3): part(b, box(Vector3(0.06, 0.04, 0.5)), mat(Color(1, 0.6, 0.15), Color(1, 0.5, 0.1), 1.0), Vector3((k - 1) * 0.08, 0.66, -0.45), Vector3(0.3, (k - 1) * 0.3, 0))


func _m_girin(r: Node3D) -> void:
	_quad(r, {"c": Color(0.95, 0.82, 0.45), "len": 1.25, "eye": Color(0.4, 0.8, 1.0)})
	part(r, cyl(0.0, 0.05, 0.3, 5), mat(GOLD, GOLD, 1.0), Vector3(0, 0.95, 0.43))
	for k in range(4): part(r, sph(0.07), mat(Color(0.3, 0.6, 0.5)), Vector3(0, 0.62, -0.2 + k * 0.14))


func _m_bonghwang(r: Node3D) -> void:
	var b := node(r, Vector3(0, 0.2, 0))
	part(b, sph(0.22), mat(Color(0.95, 0.75, 0.3)), Vector3(0, 0.72, 0), Vector3.ZERO, Vector3(1, 0.9, 1.25))
	part(b, sph(0.13), mat(Color(0.95, 0.4, 0.3)), Vector3(0, 0.96, 0.18))
	part(b, cyl(0.0, 0.08, 0.2, 5), mat(Color(0.9, 0.2, 0.2)), Vector3(0, 1.12, 0.14))
	var cols := [Color(0.2, 0.4, 0.85), Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.3), Color(0.95, 0.95, 0.95), Color(0.25, 0.65, 0.35)]
	for k in range(5): part(b, box(Vector3(0.07, 0.03, 0.7)), mat(cols[k], cols[k], 0.6), Vector3((k - 2) * 0.09, 0.7 - absf(k - 2) * 0.04, -0.55), Vector3(0.35, (k - 2) * 0.22, 0))
	for sx in [-1.0, 1.0]: part(b, box(Vector3(0.4, 0.04, 0.24)), mat(Color(0.95, 0.75, 0.3)), Vector3(sx * 0.3, 0.8, 0), Vector3(0, 0, sx * 0.4))


func _m_singijeon(r: Node3D) -> void:
	var wood := mat(Color(0.5, 0.35, 0.22))
	part(r, box(Vector3(0.6, 0.12, 0.9)), wood, Vector3(0, 0.3, 0))
	for sx in [-1.0, 1.0]: part(r, cyl(0.22, 0.22, 0.06, 12), wood, Vector3(sx * 0.34, 0.22, 0.1), Vector3(0, 0, PI / 2))
	var hive := node(r, Vector3(0, 0.72, 0.05), Vector3(-0.5, 0, 0))
	part(hive, box(Vector3(0.55, 0.5, 0.35)), mat(Color(0.6, 0.45, 0.28)), Vector3.ZERO)
	for k in range(15): part(hive, cyl(0.025, 0.025, 0.05, 6), mat(Color(0.1, 0.08, 0.06)), Vector3(-0.2 + (k % 5) * 0.1, -0.16 + (k / 5) * 0.16, 0.18), Vector3(PI / 2, 0, 0))
	part(r, box(Vector3(0.05, 0.05, 0.6)), wood, Vector3(0, 0.3, -0.7))


func _m_gaema(r: Node3D) -> void:
	_quad(r, {"c": Color(0.35, 0.3, 0.3), "len": 1.45, "eye": Color(1, 0.9, 0.5)})
	for k in range(5): part(r, box(Vector3(0.62, 0.07, 0.16)), metal(Color(0.5, 0.5, 0.52)), Vector3(0, 0.55, -0.3 + k * 0.15))
	var rider := node(r, Vector3(0, 0.45, -0.05))
	rider.scale = Vector3(0.75, 0.75, 0.75)
	_human(rider, {"robe": Color(0.45, 0.45, 0.5), "top": Color(0.4, 0.4, 0.45), "hat": "helmet", "weapon": "spear"})


func _m_yeonggam(r: Node3D) -> void:
	_human(r, {"robe": Color(0.45, 0.35, 0.3), "skin": Color(0.85, 0.35, 0.28), "hat": "satgat", "weapon": "torch"})
	part(r, box(Vector3(0.5, 0.4, 0.04)), mat(Color(0.75, 0.68, 0.5), Color.BLACK, 0.0, 0.8), Vector3(-0.3, 0.55, -0.15), Vector3(0, 0.5, 0))


# ---------------- new yokai ----------------
func _e_songaksi(r: Node3D) -> void:
	_ghost(r, {"c": Color(0.96, 0.96, 0.98), "eye": Color(1, 0.3, 0.3)})
	part(r, box(Vector3(0.06, 0.35, 0.02)), mat(Color(0.85, 0.12, 0.15)), Vector3(0, 0.62, -0.18))


func _e_mongdal(r: Node3D) -> void:
	_ghost(r, {"c": Color(0.45, 0.6, 0.8), "hair": false, "eye": Color(0.6, 1, 1)})
	part(r, cyl(0.04, 0.05, 0.5, 5), mat(INK), Vector3(0, 0.75, -0.2), Vector3(0.3, 0, 0))


func _e_judungi(r: Node3D) -> void:
	var c := Color(0.4, 0.35, 0.3)
	part(r, sph(0.3), mat(c), Vector3(0, 0.4, 0), Vector3.ZERO, Vector3(1, 0.9, 1.2))
	part(r, cyl(0.02, 0.07, 0.9, 5), mat(Color(0.8, 0.65, 0.3)), Vector3(0, 0.5, 0.75), Vector3(PI / 2, 0, 0))
	part(r, cyl(0.02, 0.07, 0.9, 5), mat(c), Vector3(0, 0.5, -0.75), Vector3(-PI / 2, 0, 0))
	glow_eyes(r, 0.58, 0.28, 0.1, 0.04, Color(1, 0.6, 0.1))


func _e_gangcheol(r: Node3D) -> Array:
	var c := Color(0.75, 0.3, 0.12)
	part(r, sph(0.55), mat(c), Vector3(0, 0.7, 0), Vector3.ZERO, Vector3(1, 0.85, 1.3))
	part(r, sph(0.28), mat(c.lightened(0.1)), Vector3(0, 0.62, 0.62), Vector3.ZERO, Vector3(1, 0.7, 1.2))
	glow_eyes(r, 0.95, 0.55, 0.25, 0.1, Color(1, 0.9, 0.2))
	for sx in [-1.0, 1.0]: part(r, cyl(0.0, 0.08, 0.4, 5), mat(Color(0.25, 0.2, 0.18)), Vector3(sx * 0.25, 1.25, 0.2), Vector3(-0.4, 0, -sx * 0.4))
	for k in range(4):
		var f := part(r, cyl(0.0, 0.14, 0.5, 6), mat(Color(1, 0.5, 0.1), Color(1, 0.45, 0.1), 2.5, 0.8), Vector3(cos(k * 1.6) * 0.35, 1.25, sin(k * 1.6) * 0.35 - 0.1))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var segs: Array = []
	for k in range(5):
		var s := Node3D.new()
		part(s, sph(0.48 - k * 0.06), mat(c.darkened(0.08 * k)), Vector3.ZERO)
		part(s, cyl(0.0, 0.12, 0.35, 4), mat(Color(1, 0.55, 0.15), Color(1, 0.5, 0.1), 1.5), Vector3(0, 0.45 - k * 0.04, 0))
		root.add_child(s)
		segs.append(s)
	return segs


func _e_dokryong(r: Node3D) -> Array:
	var c := Color(0.14, 0.16, 0.14)
	part(r, sph(0.55), mat(c), Vector3(0, 0.7, 0), Vector3.ZERO, Vector3(1, 0.85, 1.3))
	part(r, sph(0.28), mat(c.lightened(0.1)), Vector3(0, 0.6, 0.62), Vector3.ZERO, Vector3(1, 0.7, 1.2))
	glow_eyes(r, 0.95, 0.55, 0.25, 0.1, Color(0.5, 1, 0.3))
	for k in range(6): part(r, box(Vector3(0.03, 0.6, 0.03)), mat(Color(0.4, 0.6, 0.3)), Vector3(cos(k) * 0.3, 0.9, sin(k) * 0.3 - 0.2), Vector3(0.3 * sin(k), 0, 0.3 * cos(k)))
	var segs: Array = []
	for k in range(6):
		var s := Node3D.new()
		part(s, sph(0.5 - k * 0.05), mat(c.lightened(0.04 * k)), Vector3.ZERO)
		root.add_child(s)
		segs.append(s)
	return segs


func _e_goldpig(r: Node3D) -> void:
	var gold := metal(Color(0.95, 0.75, 0.25))
	part(r, sph(0.65), gold, Vector3(0, 0.75, 0), Vector3.ZERO, Vector3(1.0, 0.85, 1.35))
	for lx in [-0.35, 0.35]:
		for lz in [-0.45, 0.45]: part(r, cyl(0.12, 0.14, 0.4, 7), gold, Vector3(lx, 0.2, lz))
	part(r, sph(0.38), gold, Vector3(0, 0.95, 0.75))
	part(r, cyl(0.16, 0.16, 0.12, 10), gold, Vector3(0, 0.88, 1.12), Vector3(PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		part(r, sph(0.03), mat(INK), Vector3(sx * 0.06, 0.88, 1.19))
		part(r, cyl(0.0, 0.12, 0.2, 4), gold, Vector3(sx * 0.22, 1.32, 0.7))
	glow_eyes(r, 1.05, 1.05, 0.16, 0.05, Color(1, 0.2, 0.1))
	part(r, torus(0.06, 0.09), gold, Vector3(0, 0.95, -0.95), Vector3(PI / 2, 0, 0))


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
		var old: Dictionary = effects[0]
		if is_instance_valid(old["node"]):
			if old["kind"] == "pop": old["node"].scale = old["vel"]
			else: old["node"].queue_free()
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


func pop(n: Node3D) -> void:
	# summon pop-in: scale up from small with a little overshoot
	if headless: return
	_effect(n, "pop", 0.28, n.scale)
	n.scale = n.scale * 0.2


func die(n: Node3D) -> void:
	# death: shrink, sink and spin instead of vanishing
	if headless:
		n.queue_free()
		return
	_effect(n, "die", 0.35, n.scale)


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
			if is_instance_valid(e["node"]):
				if e["kind"] == "pop": e["node"].scale = e["vel"]
				else: e["node"].queue_free()
			effects.remove_at(k)
			continue
		var n2: Node3D = e["node"]
		var v: Vector3 = e["vel"]
		match e["kind"]:
			"pop":
				var o := sin(f * PI) * 0.18
				n2.scale = v * (0.2 + 0.8 * minf(1.0, f * 1.4) + o)
			"die":
				n2.scale = v * maxf(0.01, 1.0 - f)
				n2.position.y -= dt * 1.5
				n2.rotation.y += dt * 10.0
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
