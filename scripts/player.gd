extends Node2D
# Placeholder player: moves with WASD/arrows, auto-fires at the nearest enemy.

signal died

const AREA := Rect2(8, 8, 304, 164)

var speed := 70.0
var hp := 5
var fire_interval := 0.5
var input_override = null  # Vector2, set by tests to bypass keyboard
var _cooldown := 0.0


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if input_override != null:
		dir = input_override
	else:
		dir.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) \
			- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		dir.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) \
			- float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	position += dir.normalized() * speed * delta
	position = position.clamp(AREA.position, AREA.end)

	_cooldown -= delta
	if _cooldown <= 0.0:
		var target = get_parent().nearest_enemy(position)
		if target != null:
			get_parent().spawn_bullet(position, (target.position - position).normalized())
			_cooldown = fire_interval


func hit() -> void:
	hp -= 1
	if hp <= 0:
		died.emit()


func _draw() -> void:
	draw_rect(Rect2(-4, -4, 8, 8), Color(0.3, 0.9, 1.0))
