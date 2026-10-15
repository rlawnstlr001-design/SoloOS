extends SceneTree
# Parity test: GDScript dusk() must match the Python reference (sim_proto/duskhold.py) on exported snapshots.
# Run: godot --headless --path . -s tests/parity_test.gd

const GS := preload("res://sim/game_state.gd")


func _init() -> void:
	var f := FileAccess.open("res://tests/parity_cases.json", FileAccess.READ)
	var cases: Array = JSON.parse_string(f.get_as_text())
	var bad := 0
	var fields := ["inten", "var", "struct", "hp", "lit", "scar", "terrain", "was3"]
	for c in cases:
		var g := GS.new()
		g.load_snapshot(c["pre"])
		g.dusk()
		var post: Dictionary = c["post"]
		var mism := []
		var got := {"inten": g.inten, "var": g.var_, "struct": g.structs, "hp": g.hp, "lit": g.lit, "scar": g.scar, "terrain": g.terrain, "was3": g.was3}
		for k in fields:
			var exp: Array = post[k]
			for i in range(exp.size()):
				var e = exp[i]
				if k == "var" or k == "struct":
					e = "" if e == null else e
				elif k == "inten" or k == "hp":
					e = int(e)
				if got[k][i] != e:
					mism.append("%s[%d] got %s exp %s" % [k, i, str(got[k][i]), str(e)])
					break
		for cl in ["light", "flame", "ward"]:
			if g.resist[cl] != int(post["resist"][cl]): mism.append("resist." + cl)
		if g.window.size() != post["window"].size(): mism.append("window size")
		if g.over != post["over"]: mism.append("over")
		if not mism.is_empty():
			bad += 1
			if bad <= 8: print("MISMATCH ", c["name"], mism)
	print("cases=%d mismatches=%d" % [cases.size(), bad])
	print("PARITY ", "PASS" if bad == 0 else "FAIL")
	quit(0 if bad == 0 else 1)
