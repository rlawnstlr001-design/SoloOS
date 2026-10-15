extends SceneTree
# Random-play smoke test of the simulation across all variant sets. No crashes, always terminates.
# godot --headless --path . -s tests/smoke_test.gd
const GS := preload("res://sim/game_state.gd")
const VSETS := [["murk"], ["murk", "spore"], ["rime", "spore"], ["rust", "murk"], ["rime", "hollow"], ["murk", "rime", "spore", "rust", "hollow"]]

func _init() -> void:
	var wins := 0
	var total := 0
	for vs in VSETS:
		for s in range(40):
			var g := GS.new()
			g.setup(100 + s, vs)
			var rng := RandomNumberGenerator.new()
			rng.seed = s
			while not g.over:
				g.dawn()
				var fr: Array = g.frontier()
				if not fr.is_empty(): g.place_tile(fr[rng.randi() % fr.size()], 0)
				for k in range(8):
					var n: String = GS.BUILD_ORDER[rng.randi() % GS.BUILD_ORDER.size()]
					var i: int = rng.randi() % GS.N
					if g.can_build(n, i): g.build(n, i)
					elif g.can_burst(i): g.burst(i)
					elif g.can_pyre(i): g.pyre_fire(i)
					else:
						var t: Array = g.seal_targets(i)
						if not t.is_empty(): g.seal(i, t[0])
					if g.over: break
				if g.over: break
				g.end_day()
			total += 1
			if g.won: wins += 1
	print("games=%d random-bot wins=%d" % [total, wins])
	print("SMOKE PASS")
	quit(0)
