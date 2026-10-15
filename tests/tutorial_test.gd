extends SceneTree
# Walks through the whole tutorial using the real handlers. godot --headless --path . -s tests/tutorial_test.gd
var m: Node
var step := 0
var fails := 0

func _init() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)

func _check(c: bool, what: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", what)
	else:
		print("ok: ", what)

func _click(i: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = m.hex_pos(i)
	m._unhandled_input(ev)

func _id() -> String:
	return m.TUT[m.tut]["id"]

func _process(_d: float) -> bool:
	step += 1
	if step < 2: return false
	m._start_tutorial()
	var g = m.g
	var pr: Array = m.fc[2]; var gd: Array = m.fc[3]
	_check(pr[m.tut_a] > gd[m.tut_a] and pr[m.tut_b] > gd[m.tut_b], "both threatened hexes show danger (pressure > defense)")
	_check(_id() == "intro", "starts at intro")
	m._on_build("lantern")
	_check(_id() == "intro", "actions are blocked during info steps")
	m._tut_next(); m._tut_next(); m._tut_next()
	_check(_id() == "build", "reached the build step after 3 NEXT")
	m._on_build("lantern")
	_check(m.mode == "", "only palisade is allowed in the build step")
	m._on_build("palisade")
	_check(m.mode == "build" and m.build_name == "palisade", "palisade button accepted")
	_click(g.NEI[g.HEARTH][3])  # a non-target hex
	_check(g.structs[g.NEI[g.HEARTH][3]] == "", "building elsewhere is blocked")
	_click(m.tut_a)
	_check(_id() == "build" and g.structs[m.tut_a] == "palisade", "first palisade built, still on build step")
	_click(m.tut_b)
	_check(_id() == "safe", "second palisade advances to the safe step")
	pr = m.fc[2]; gd = m.fc[3]
	_check(pr[m.tut_a] <= gd[m.tut_a] and pr[m.tut_b] <= gd[m.tut_b], "both hexes are now safe (pressure <= defense)")
	m._tut_next()
	_check(_id() == "expand", "expand step")
	m._on_card(0)
	_click(g.frontier()[0])
	_check(_id() == "endday", "placing a tile advances to end day")
	var lit_before: int = g.lit_count()
	var a_lit_before: bool = g.lit[m.tut_a]
	m._end_day()
	_check(g.lit[m.tut_a] and g.lit[m.tut_b] and a_lit_before, "after the night both defended hexes are still lit")
	_check(g.lit_count() >= lit_before, "no land lost in the tutorial night")
	_check(_id() == "result", "result step after end day")
	m._tut_next(); m._tut_next()
	_check(m.scr == "play", "final NEXT starts free play")
	print("TUTORIAL TEST ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
	return true
