extends SceneTree
# Headless: run the 3D real-time scene through whole games (pulses + builds) to catch runtime errors.
var w: Node
var f := 0

func _init() -> void:
	w = load("res://scenes/world3d.tscn").instantiate()
	root.add_child(w)

func _process(_d: float) -> bool:
	f += 1
	if f < 3: return false
	var games := 0
	for vs in range(6):
		w.vset_idx = vs
		w._new_game()
		var g = w.g
		var guard := 0
		while not g.over and guard < 20:
			guard += 1
			if not w.placed and g.frontier().size() > 0:
				w._on_card(0); w._click_tile(g.frontier()[0])
			for n in ["lantern", "palisade", "brazier", "beacon"]:
				for i in g.NEI[g.HEARTH]:
					if g.can_build(n, i):
						w._on_build(n); w._click_tile(i); break
			for i in range(g.N):
				if g.can_burst(i):
					w.selected = i; w._ability("burst")
			w._process(0.016)
			w._pulse()
			g = w.g
		games += 1
	print("3D games=%d" % games)
	print("SMOKE3D PASS")
	quit(0)
	return true
