extends SceneTree
# Headless balance check for toy 2 (pool cards + recipes + synergy): bots of different skill play full games.
var f := 0

func _merge_all(t) -> void:
	var merged := true
	while merged:
		merged = false
		for i in range(t.units.size()):
			if t.recipe_for(i) != "":
				t.craft(i); merged = true; break
			if t.can_merge(i):
				t.merge(i); merged = true; break

func _pick(t, policy: String) -> void:
	if policy == "skip" or policy == "idle":
		t.pick_card(-1); return
	if policy == "random":
		t.pick_card(t.rng.randi() % t.cards.size()); return
	# smart: relic > remove (keep pool small) > add
	var best := 0
	var score := -1
	for k in range(t.cards.size()):
		var c: Dictionary = t.cards[k]
		var s := 0
		if c["kind"] == "relic": s = 3
		elif c["kind"] == "remove" and t.pool.size() > 4: s = 2
		elif c["kind"] == "add" and t.pool.size() < 5: s = 1
		if s > score: score = s; best = k
	t.pick_card(best)

func _cluster(t) -> void:
	# smart bot: sort units by kin so neighbours share kin
	var order: Array = t.units.duplicate()
	order.sort_custom(func(a, b): return t.UNITS[a["type"]]["kin"] < t.UNITS[b["type"]]["kin"])
	for k in range(order.size()): order[k]["slot"] = k

func _play(policy: String, seed: int) -> Array:
	var t = load("res://scenes/toy2.tscn").instantiate()
	root.add_child(t)
	t.rng.seed = seed
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: t.hp_growth = float(a[0])
	seed(seed)
	var steps := 0
	var heroes := 0
	while not t.over and steps < 60000:
		steps += 1
		if t.choosing: _pick(t, policy)
		if policy != "idle":
			while t.summon(): pass
			_merge_all(t)
			if policy == "smart":
				_cluster(t)
				var best := ""
				var bestn := 0
				for k in t.KINS:
					var n := 0
					for u in t.units:
						if t.UNITS[u["type"]]["kin"] == k: n += 1 + u["tier"] * 3
					if n > bestn: bestn = n; best = k
				if best != "" and t.gold >= t.upgrade_cost(best) + t.cost(): t.upgrade(best)
		t.step(0.05)
	var r := [t.won, t.wave, t.kills, t.lose_reason, t.discovered.size(), t.relics.size(), t.pool.size()]
	t.queue_free()
	return r

func _process(_d: float) -> bool:
	f += 1
	if f < 2: return false
	var pols := ["idle", "skip", "random", "smart"]
	if OS.get_cmdline_user_args().size() > 1: pols = ["skip", "random", "smart"]
	for pol in pols:
		var wins := 0; var waves := 0.0; var reasons := {}; var heroes := 0.0
		for s in range(8):
			var r := _play(pol, 100 + s)
			if r[0]: wins += 1
			waves += r[1]
			heroes += r[4]
			reasons[r[3]] = reasons.get(r[3], 0) + 1
		print("%-7s wins %d/8  avg wave %.1f  heroes found %.1f  %s" % [pol, wins, waves / 8.0, heroes / 8.0, str(reasons)])
	print("TOY2 BALANCE DONE")
	quit(0)
	return true
