extends Node2D

var direction := Vector2.RIGHT
var speed := 160.0
var _life := 2.0


func _process(delta: float) -> void:
	position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_queued_for_deletion() and e.position.distance_to(position) < 6.0:
			e.take_damage(1)
			queue_free()
			return


func _draw() -> void:
	draw_rect(Rect2(-1, -1, 2, 2), Color(1.0, 0.95, 0.5))
