extends CharacterBody2D

var direction := Vector2.RIGHT
var speed := 430.0
var damage := 6
var life_left := 2.2

func setup(direction_value: Vector2, damage_value: int) -> void:
	direction = direction_value.normalized()
	damage = damage_value
	rotation = direction.angle()
	collision_layer = 0
	collision_mask = 3
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	collision.shape = shape
	add_child(collision)
	z_index = 2600
	queue_redraw()

func _physics_process(delta: float) -> void:
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
		return
	var collision := move_and_collide(direction * speed * delta)
	if collision:
		var body := collision.get_collider()
		if body and body.has_method("take_damage") and body.collision_layer & 2:
			body.take_damage(damage)
		queue_free()

func _draw() -> void:
	draw_line(Vector2(-15,0),Vector2(10,0),Color("ffb05e"),4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(13,0),Vector2(5,-6),Vector2(5,6)]),Color("fff0a6"))
	draw_line(Vector2(-13,-6),Vector2(-13,6),Color("9b5138"),3.0)
