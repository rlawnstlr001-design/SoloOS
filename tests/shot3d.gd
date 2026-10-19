extends SceneTree
# Screenshots of the 3D real-time prototype. xvfb-run godot --path . --rendering-driver opengl3 -s tests/shot3d.gd -- out_dir
var w: Node
var f := 0
var out := "/tmp"

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	w = load("res://scenes/world3d.tscn").instantiate()
	root.add_child(w)

func _process(_d: float) -> bool:
	f += 1
	match f:
		10: _save("3d_1_guide")
		11:
			w.show_guide = false
			var g = w.g
			var ring: Array = g.NEI[g.HEARTH]
			g.M += 40; g.L += 30
			w._on_build("lantern"); w._click_tile(ring[0])
			w._on_build("brazier"); w._click_tile(ring[2])
			w._on_build("beacon"); w._click_tile(ring[4])
			w._on_build("palisade"); w._click_tile(ring[1])
			w._on_build("camp"); w._click_tile(ring[3])
			w._on_build("cottage"); w._click_tile(ring[5])
			w._on_card(0); w._click_tile(g.frontier()[0])
			w.speed = 0
		40: _save("3d_2_day1")
		41:
			for k in range(5): w._pulse()
		90: _save("3d_3_after5")
		91:
			w.pulse_t = 13.0
			w.cam_dist = 10.0; w.cam_yaw = 0.8; w._update_cam()
		120: _save("3d_4_closeup_dusk")
		121: quit(0)
	return false

func _save(n: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, n])
	print("saved ", n)
