extends Node2D

signal detonated(position: Vector2)

const FRAME_ROOT := "res://assets/cc0_boss_fx/starsteel/"

var target: Node2D
var delay_left := 0.82
var total_delay := 0.82
var radius := 58.0
var damage := 11
var exploded := false

func setup(target_value: Node2D, delay_value: float, phase_two := false) -> void:
	target = target_value
	delay_left = delay_value
	total_delay = delay_value
	radius = 68.0 if phase_two else 56.0
	damage = 12 if phase_two else 9
	z_index = 3000

func _process(delta: float) -> void:
	if exploded:
		return
	delay_left -= delta
	if delay_left <= 0.0:
		explode()
	queue_redraw()

func explode() -> void:
	exploded = true
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= radius:
		target.take_damage(damage)
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("explode")
	frames.set_animation_speed("explode",20.0)
	frames.set_animation_loop("explode",false)
	for index in range(1,9):
		frames.add_frame("explode",load(FRAME_ROOT + "Thundersphere" + str(index) + ".png"))
	sprite.sprite_frames = frames
	sprite.scale = Vector2(2,2)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.animation_finished.connect(func(): queue_free())
	sprite.play("explode")
	detonated.emit(global_position)
	queue_redraw()

func _draw() -> void:
	if exploded:
		return
	var progress := clampf(1.0 - delay_left / total_delay,0.0,1.0)
	draw_circle(Vector2.ZERO,radius,Color(0.55,0.12,0.9,0.10 + progress * 0.22))
	draw_arc(Vector2.ZERO,radius,0,TAU,32,Color("d66cff"),3.0 + progress * 3.0)
	draw_arc(Vector2.ZERO,radius * (1.0 - progress * 0.72),0,TAU,24,Color("fff2a1"),3.0)
	for index in range(4):
		var offset := Vector2.from_angle(index * TAU / 4.0) * radius * 0.72
		draw_rect(Rect2(offset - Vector2(4,4),Vector2(8,8)),Color("e980ff"))
