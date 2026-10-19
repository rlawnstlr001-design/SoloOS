extends SceneTree
var t: Node
var f := 0
var out := "/tmp"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	t = load("res://scenes/toy_random.tscn").instantiate()
	root.add_child(t)
func _process(_d: float) -> bool:
	f += 1
	if f == 3:
		t.rng.seed = 7
		for k in range(3150):
			while t.summon(): pass
			for i in range(t.units.size()):
				if t.can_merge(i): t.merge(i); break
			t.step(0.05)
		t.selected = 0
	if f == 30:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out + "/toy1.png"); print("saved toy1 wave ", t.wave)
		quit(0)
	return false
