extends SceneTree
# Headless smoke test: godot --headless --fixed-fps 60 -s tests/smoke_test.gd

var _main: Node2D
var _frames := 0


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_main.rng.seed = 12345


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 1800:  # 30 simulated seconds
		return false
	var ok: bool = _main.enemies_spawned > 0 and _main.score > 0
	print("spawned=%d score=%d hp=%d game_over=%s" % [_main.enemies_spawned, _main.score, _main.player.hp, _main.game_over])
	print("SMOKE TEST ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
