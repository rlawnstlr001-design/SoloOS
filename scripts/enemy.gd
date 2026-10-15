extends Node2D
# Placeholder enemy: walks toward the player, damages on contact.

signal killed

var hp := 2
var speed := 25.0


func _ready() -> void:
	add_to_group("enemies")


func _process(delta: float) -> void:
	var player = get_parent().player
	var to_player: Vector2 = player.position - position
	if to_player.length() < 7.0:
		player.hit()
		queue_free()
		return
	position += to_player.normalized() * speed * delta


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0 and not is_queued_for_deletion():
		killed.emit()
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-3, -3, 6, 6), Color(1.0, 0.35, 0.3))
