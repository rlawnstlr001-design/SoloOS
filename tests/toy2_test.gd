extends SceneTree
# Headless balance check for 도깨비 디펜스 (50 waves): bots of different skill play full games.
# Policies: idle, skip (never picks cards), random (random cards), smart (cards + clustering + upgrades), noup (smart, never upgrades).
# Design target: smart clears most runs, noup must fail in the later acts (upgrades are required).
# Args: [difficulty key (normal/hard/hell) or hp_growth] [policy list, comma separated] [seeds]
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
	var open: Array = t.open_slots()
	for k in range(order.size()): order[k]["slot"] = open[k]

func _play(policy: String, seed: int) -> Array:
	var t = load("res://scenes/toy2.tscn").instantiate()
	root.add_child(t)
	t.rng.seed = seed
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		if t.D.DIFFS.has(a[0]): t.set_difficulty(a[0])
		else: t.hp_growth = float(a[0])
	seed(seed)
	var steps := 0
	var heroes := 0
	while not t.over and steps < 120000:
		steps += 1
		if t.choosing: _pick(t, policy)
		if policy != "idle":
			while t.summon(): pass
			_merge_all(t)
			if policy == "smart" or policy == "noup":
				_cluster(t)
				# board expansion: open the next cell when the board is full and gold allows
				if t.free_slot() < 0 and t.gold >= t.slot_cost() + 60:
					for c in t.EXTRA_SLOTS:
						if not t.unlocked[c]:
							t.unlock_slot(c); break
			if policy == "smart":
				var best := ""
				var bestn := 0
				for k in t.KINS:
					var n := 0
					for u in t.units:
						if t.UNITS[u["type"]]["kin"] == k: n += 1 + u["tier"] * 3
					if n > bestn: bestn = n; best = k
				if best != "" and t.gold >= t.upgrade_cost(best) + t.cost(): t.upgrade(best)
		t.step(0.05)
	var r := [t.won, t.wave, t.kills, t.lose_reason, t.discovered.size(), t.relics.size(), t.pool.size(), t.casts]
	t.queue_free()
	return r

func _process(_d: float) -> bool:
	f += 1
	if f < 2: return false
	var a := OS.get_cmdline_user_args()
	var pols := ["idle", "skip", "random", "smart", "noup"]
	if a.size() > 1: pols = a[1].split(",")
	var seeds := 8 if a.size() < 3 else int(a[2])
	for pol in pols:
		var wins := 0; var waves := 0.0; var reasons := {}; var heroes := 0.0; var casts := 0.0
		for s in range(seeds):
			var r := _play(pol, 100 + s)
			if r[0]: wins += 1
			waves += r[1]
			heroes += r[4]
			casts += r[7]
			reasons[r[3]] = reasons.get(r[3], 0) + 1
		print("%-7s wins %d/%d  avg wave %.1f  heroes %.1f  casts %.0f  %s" % [pol, wins, seeds, waves / seeds, heroes / seeds, casts / seeds, str(reasons)])
	print("TOY2 BALANCE DONE")
	quit(0)
	return true
