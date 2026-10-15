extends SceneTree
# Render the prototype and save screenshots (needs a display, e.g. xvfb-run). Usage: -s tests/shot.gd -- out_dir
var m: Node
var frames := 0
var out := "/tmp"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		_save("day1")
		# play a few scripted days with the real UI methods
		var g = m.g
		m.show_fc = true
		g.place_tile(g.frontier()[0], 0); m.placed_today = true
		g.build("lantern", g.NEI[g.HEARTH][0]); g.build("camp", g.NEI[g.HEARTH][2])
		m._refresh()
	if frames == 8: _save("day1_built")
	if frames == 9:
		for k in range(6):
			m._end_day()
			var gg = m.g
			if gg.over: break
			var fr = gg.frontier()
			if fr.size() > 0 and not m.placed_today:
				gg.place_tile(fr[0], 0); m.placed_today = true
		m._refresh()
	if frames == 12:
		_save("day7")
		quit(0)
	return false

func _save(n: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, n])
	print("saved ", n, " ", img.get_size())
