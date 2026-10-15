extends Node2D
# Prototype arena: survive, auto-kill enemies, score goes up. Placeholder art only.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const BulletScript := preload("res://scripts/bullet.gd")

var rng := RandomNumberGenerator.new()
var player: Node2D
var score := 0
var enemies_spawned := 0
var elapsed := 0.0
var game_over := false
var _spawn_timer := 0.0


func _ready() -> void:
	rng.randomize()
	_start_run()


func _start_run() -> void:
	for c in get_children():
		c.queue_free()
	score = 0
	enemies_spawned = 0
	elapsed = 0.0
	game_over = false
	_spawn_timer = 0.0
	player = PlayerScript.new()
	player.position = Vector2(160, 90)
	player.died.connect(_on_player_died)
	add_child(player)


func _process(delta: float) -> void:
	if game_over:
		if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_SPACE):
			_start_run()
		queue_redraw()
		return
	elapsed += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_enemy()
		# Spawn rate ramps from 1.2s down to 0.25s over ~2 minutes.
		_spawn_timer = lerpf(1.2, 0.25, clampf(elapsed / 120.0, 0.0, 1.0))
	queue_redraw()


func _spawn_enemy() -> void:
	var e := EnemyScript.new()
	var side := rng.randi_range(0, 3)
	match side:
		0: e.position = Vector2(rng.randf_range(0, 320), -4)
		1: e.position = Vector2(rng.randf_range(0, 320), 184)
		2: e.position = Vector2(-4, rng.randf_range(0, 180))
		_: e.position = Vector2(324, rng.randf_range(0, 180))
	e.killed.connect(func(): score += 1)
	add_child(e)
	enemies_spawned += 1


func spawn_bullet(pos: Vector2, dir: Vector2) -> void:
	var b := BulletScript.new()
	b.position = pos
	b.direction = dir
	add_child(b)


func nearest_enemy(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_queued_for_deletion():
			continue
		var d := from.distance_squared_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _on_player_died() -> void:
	game_over = true


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(4, 12), "HP %d  SCORE %d  TIME %d" % [player.hp, score, int(elapsed)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	if game_over:
		draw_string(font, Vector2(0, 90), "GAME OVER - press SPACE", HORIZONTAL_ALIGNMENT_CENTER, 320, 10)
