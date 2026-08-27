extends Node2D

signal enemy_hit(enemy: Node2D, damage: int, position: Vector2)

const SPEED := 430.0
const DAMAGE := 18
const MAX_LIFE := 1.45

var direction := Vector2.RIGHT
var source_position := Vector2.ZERO
var life := MAX_LIFE
var impact_left := 0.0
var trail_time := 0.0
var damage := DAMAGE

func setup(cast_direction: Vector2, source: Vector2, damage_override := DAMAGE) -> void:
	direction = cast_direction.normalized()
	source_position = source
	damage = damage_override
	z_index = 2800
	rotation = direction.angle()

func _process(delta: float) -> void:
	if impact_left > 0.0:
		impact_left -= delta
		if impact_left <= 0.0:
			queue_free()
		queue_redraw()
		return
	position += direction * SPEED * delta
	life -= delta
	trail_time += delta
	for enemy in get_tree().get_nodes_in_group("field_enemies"):
		if is_instance_valid(enemy) and not enemy.dead and global_position.distance_to(enemy.global_position - Vector2(0,12)) < 31.0:
			enemy.take_damage(damage,source_position)
			enemy_hit.emit(enemy,damage,enemy.global_position)
			impact_left = 0.18
			break
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if impact_left > 0.0:
		var progress := 1.0 - impact_left / 0.18
		for i in range(12):
			var angle := TAU * i / 12.0
			var point := Vector2.from_angle(angle) * (12.0 + progress * 38.0)
			draw_rect(Rect2(point - Vector2(4,4),Vector2(8,8)),Color(0.55,0.94,1.0,1.0-progress))
		return
	# 元气弹：像素核心、旋转外环与反向拖尾。
	draw_rect(Rect2(-13,-13,26,26),Color("4b9fff"))
	draw_rect(Rect2(-8,-8,16,16),Color("b8f8ff"))
	draw_rect(Rect2(-3,-3,6,6),Color.WHITE)
	for offset in [Vector2(-20,-7),Vector2(-28,3),Vector2(-38,-3)]:
		draw_rect(Rect2(offset,Vector2(8,8)),Color(0.35,0.75,1.0,0.78))
	draw_arc(Vector2.ZERO,18,trail_time * 8.0,trail_time * 8.0 + 4.6,12,Color("75e9ff"),4.0)
