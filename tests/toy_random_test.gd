extends SceneTree
# Headless balance check for the random-defense toy: bots of different skill play full games.
var f := 0

func _play(policy: String, seed: int) -> Array:
	var t = load("res://scenes/toy_random.tscn").instantiate()
	root.add_child(t)
	t.rng.seed = seed
	var steps := 0
	while not t.over and steps < 40000:
		steps += 1
		if policy != "idle":
			while t.summon(): pass
			if policy != "nomerge":
				var merged := true
				while merged:
					merged = false
					for i in range(t.units.size()):
						if t.can_merge(i):
							t.merge(i); merged = true; break
			if policy == "smart":
				var best := ""
				var bestn := 0
				for k in t.TYPE_KEYS:
					var n := 0
					for u in t.units:
						if u["type"] == k: n += 1 + u["tier"] * 3
					if n > bestn: bestn = n; best = k
				if best != "" and t.gold >= t.upgrade_cost(best) + t.SUMMON_COST: t.upgrade(best)
		t.step(0.05)
	var r := [t.won, t.wave, t.kills, t.lose_reason]
	t.queue_free()
	return r

func _process(_d: float) -> bool:
	f += 1
	if f < 2: return false
	for pol in ["idle", "nomerge", "merge", "smart"]:
		var wins := 0; var waves := 0.0; var reasons := {}
		for s in range(8):
			var r := _play(pol, 100 + s)
			if r[0]: wins += 1
			waves += r[1]
			reasons[r[3]] = reasons.get(r[3], 0) + 1
		print("%-8s wins %d/8  avg wave %.1f  %s" % [pol, wins, waves / 8.0, str(reasons)])
	print("TOY BALANCE DONE")
	quit(0)
	return true
