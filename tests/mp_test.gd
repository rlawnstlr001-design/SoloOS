extends SceneTree
# Two-process co-op test on localhost. Run the host and the client in separate Godot processes:
#   godot --headless --path . -s tests/mp_test.gd -- host [waves] [bot]
#   godot --headless --path . -s tests/mp_test.gd -- client [waves] [bot]
# bot: "play" (summon + merge every frame) or "idle" (never summons, should lose early and end the run for both).
# Prints the rolled act rosters (must match), wave sync, snapshot traffic and the final result of each side.
var t: Node
var role := "host"
var target := 12
var bot := "play"
var f := 0
var max_lead := 0
var snaps := 0
var last_wave := -1


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: role = a[0]
	if a.size() > 1: target = int(a[1])
	if a.size() > 2: bot = a[2]
	t = load("res://scenes/toy2.tscn").instantiate()
	t.auto_start = false
	root.add_child(t)


func _process(_d: float) -> bool:
	f += 1
	if f == 3:
		t.no_save = true
		t.rng.seed = 11 if role == "host" else 22
		if role == "host": t.net.host()
		else: t.net.join("127.0.0.1")
	if f > 3 and role == "host" and t.net.active() and not t.started:
		t.set_difficulty("normal")
		t.net.send_difficulty("normal")
		t.start_game()
		t.set_speed(3)
	if t.started and not t.over:
		if t.choosing: t.pick_card(0)
		if bot == "play":
			while t.summon(): pass
			for i in range(t.units.size()):
				if t.recipe_for(i) != "": t.craft(i); break
				if t.can_merge(i): t.merge(i); break
	if t.started and t.wave != last_wave:
		last_wave = t.wave
		var ps: Dictionary = t.net.partner_snap
		var pw := int(ps.get("wave", 0))
		max_lead = maxi(max_lead, absi(t.wave - pw))
		print("[%s] wave %d  partner wave %d  alive %d  gold %d" % [role, t.wave, pw, t.enemies.size(), t.gold])
	if not t.net.partner_snap.is_empty(): snaps += 1
	var done: bool = t.over or (t.started and t.wave > target) or f > 400000
	if f == 2 + 1 and role == "host": print("[host] hosting on port ", t.net.PORT)
	if t.started and f % 2000 == 0 and t.wave == 1 and f < 4000:
		print("[%s] acts: %s | bosses: %s" % [role, str(t.act_roster), str(t.act_boss)])
	if done:
		print("[%s] acts: %s | bosses: %s" % [role, str(t.act_roster), str(t.act_boss)])
		print("[%s] RESULT over=%s won=%s reason='%s' wave=%d mp=%s max_wave_gap=%d frames_with_partner=%d partner_result='%s'" % [role, t.over, t.won, t.lose_reason, t.wave, t.mp, max_lead, snaps, t.net.partner_result])
		# give the last reliable messages a moment to flush before quitting
		if t.net.peer != null:
			for k in range(30): t.net.peer.poll()
		quit(0)
		return true
	return false
