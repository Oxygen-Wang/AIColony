extends Node2D
## Damage is applied only after the projectile reaches its target.
var target: Node2D
var damage := 0.0
var velocity := 280.0
var lifetime := 3.0
var tint := Color("f3cf83")

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0 or not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var offset := target.position - position
	rotation = offset.angle()
	if offset.length() <= velocity * delta + 3.0:
		target.take_damage(damage)
		queue_free()
		return
	position += offset.normalized() * velocity * delta
	queue_redraw()
	pass

func _draw() -> void:
	draw_line(Vector2(-8, 0), Vector2(3, 0), tint, 2.0)
	draw_line(Vector2(0, -2), Vector2(3, 0), tint, 1.0)
	draw_line(Vector2(0, 2), Vector2(3, 0), tint, 1.0)
	pass
