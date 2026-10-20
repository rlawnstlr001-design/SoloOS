extends SceneTree
# Screenshots of toy 2 mid-game, card choice and codex (needs xvfb-run). Usage: -s tests/shot_toy2.gd -- out_dir
var t: Node
var f := 0
var out := "/tmp"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	t = load("res://scenes/toy2.tscn").instantiate()
	root.add_child(t)
func _save(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
	print("saved ", n, " wave ", t.wave)
func _process(_d: float) -> bool:
	f += 1
	if f == 3:
		t.no_save = true
		t.rng.seed = 7
		t.start_game()
		var k := 0
		while k < 6000 and not (t.choosing and t.wave >= 8):
			k += 1
			if t.choosing: t.pick_card(0)
			while t.summon(): pass
			for i in range(t.units.size()):
				if t.recipe_for(i) != "": t.craft(i); break
				if t.can_merge(i): t.merge(i); break
			t.step(0.05)
	if f == 20: _save("toy2_cards")
	if f == 21:
		t.pick_card(0)
		for k in range(200): t.step(0.05)
		t.selected = 0
	if f == 40: _save("toy2_play")
	if f == 41: t.show_codex = true
	if f == 60: _save("toy2_codex"); quit(0)
	return false
