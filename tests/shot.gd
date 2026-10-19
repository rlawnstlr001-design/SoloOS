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

func _click(i: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = m.hex_pos(i)
	m._unhandled_input(ev)

func _process(_d: float) -> bool:
	frames += 1
	match frames:
		4: _save("1_menu")
		5: m._start_tutorial()
		8: _save("2_tut_intro")
		9: m._tut_next(); m._tut_next()
		12: _save("3_tut_danger")
		13: m._tut_next(); m._on_build("palisade")
		15: _save("4_tut_build")
		16: _click(m.tut_a); _click(m.tut_b)
		19: _save("5_tut_safe")
		20: m._tut_next(); m._on_card(0); _click(m.g.frontier()[0])
		22: m._end_day()
		24: _save("6_tut_after_night")
		25:
			m._start_free()
			for k in range(m.btns.size()):
				if String(m.btns[k]["t"]).begins_with(m.N("beacon")): m.hover_btn = k
			m.queue_redraw()
		27: _save("7_tooltip")
		28: m._toggle_codex()
		30: _save("8_codex")
		31: quit(0)
	return false

func _save(n: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, n])
	print("saved ", n, " ", img.get_size())
