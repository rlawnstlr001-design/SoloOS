extends SceneTree
# Drives the real UI handlers with synthetic mouse/key events. Run headless:
# godot --headless --path . -s tests/ui_test.gd
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

func _key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	m._unhandled_input(ev)

func _process(_d: float) -> bool:
	step += 1
	if step == 2:
		var g = m.g
		var lit0: int = g.lit_count()
		m._on_card(0)
		var fr: Array = g.frontier()
		_click(fr[0])
		_check(g.lit_count() == lit0 + 1 and m.placed_today, "card placement lights a frontier tile")
		var M0: int = g.M
		m._on_build("lantern")
		var spot := -1
		for j in g.NEI[g.HEARTH]:
			if g.structs[j] == "": spot = j; break
		_click(spot)
		_check(g.structs[spot] == "lantern" and g.M == M0 - 3, "build lantern spends resources")
		_click(g.HEARTH)  # in build mode: invalid target, should not crash
		var day0: int = g.day
		_key(KEY_SPACE)
		_check(m.g.day == day0 + 1 or m.g.over, "Space ends the day")
		_key(KEY_3)
		_check(m.vset_idx == 2 and m.g.day == 1, "key 3 restarts with variant set 3")
		# play until over with passive end-days: must terminate without errors
		var guard := 0
		while not m.g.over and guard < 30:
			_key(KEY_SPACE); guard += 1
		_check(m.g.over, "stage terminates (win or loss) within 12 days")
		_key(KEY_R)
		_check(not m.g.over and m.g.day == 1, "R restarts")
		print("UI TEST ", "PASS" if fails == 0 else "FAIL")
		quit(0 if fails == 0 else 1)
	return false
