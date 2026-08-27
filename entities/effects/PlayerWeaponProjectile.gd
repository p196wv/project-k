extends CharacterBody2D

signal enemy_hit(enemy: Node2D, damage: int, position: Vector2, weapon_id: String)

var direction := Vector2.RIGHT
var weapon_id := "staff"
var damage := 10
var speed := 540.0
var life_left := 2.0

func setup(direction_value: Vector2, weapon_value: String, damage_value: int) -> void:
	direction = direction_value.normalized()
	weapon_id = weapon_value
	damage = damage_value
	speed = 760.0 if weapon_id == "bow" else 520.0
	rotation = direction.angle()
	collision_layer = 0
	collision_mask = 5
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0 if weapon_id == "bow" else 9.0
	collision.shape = shape
	add_child(collision)
	z_index = 2700
	queue_redraw()

func _physics_process(delta: float) -> void:
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
		return
	var collision := move_and_collide(direction * speed * delta)
	if not collision:
		queue_redraw()
		return
	var body := collision.get_collider()
	if body and body.is_in_group("field_enemies"):
		body.take_damage(damage,global_position - direction * 24.0)
		enemy_hit.emit(body,damage,global_position,weapon_id)
	queue_free()

func _draw() -> void:
	if weapon_id == "bow":
		draw_line(Vector2(-18,0),Vector2(10,0),Color("e7bd67"),3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(14,0),Vector2(6,-5),Vector2(6,5)]),Color("e9f1d0"))
		draw_line(Vector2(-15,-5),Vector2(-15,5),Color("a96845"),2.0)
	else:
		draw_circle(Vector2.ZERO,11,Color(0.25,0.82,1.0,0.3))
		draw_circle(Vector2.ZERO,7,Color("76e6ff"))
		draw_circle(Vector2(2,-2),3,Color.WHITE)
		for index in range(4):
			var angle := Time.get_ticks_msec() * 0.008 + index * TAU / 4.0
			draw_rect(Rect2(Vector2.from_angle(angle) * 14.0 - Vector2(2,2),Vector2(4,4)),Color("b38cff"))
