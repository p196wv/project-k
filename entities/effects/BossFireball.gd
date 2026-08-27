extends CharacterBody2D

signal finished(position: Vector2)

const FRAME_ROOT := "res://assets/cc0_boss_fx/starsteel/"

var direction := Vector2.RIGHT
var target: Node2D
var speed := 350.0
var damage := 9
var life_left := 3.2
var exploding := false
var sprite: AnimatedSprite2D
var collision: CollisionShape2D

func setup(direction_value: Vector2, target_value: Node2D, phase_two := false) -> void:
	direction = direction_value.normalized()
	target = target_value
	speed = 410.0 if phase_two else 350.0
	damage = 10 if phase_two else 8
	rotation = direction.angle()

func _ready() -> void:
	z_index = 3200
	collision_layer = 0
	collision_mask = 1
	collision = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	collision.shape = shape
	add_child(collision)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = make_frames("Fireball",9,18.0)
	sprite.scale = Vector2(1,1)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.play("effect")

func make_frames(prefix: String, count: int, fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("effect")
	frames.set_animation_speed("effect",fps)
	frames.set_animation_loop("effect",true)
	for index in range(1,count + 1):
		frames.add_frame("effect",load(FRAME_ROOT + prefix + str(index) + ".png"))
	return frames

func _physics_process(delta: float) -> void:
	if exploding:
		return
	life_left -= delta
	if is_instance_valid(target) and global_position.distance_to(target.global_position) < 27.0:
		target.take_damage(damage)
		explode()
		return
	var hit := move_and_collide(direction * speed * delta)
	if hit or life_left <= 0.0:
		explode()

func explode() -> void:
	if exploding:
		return
	exploding = true
	velocity = Vector2.ZERO
	collision.set_deferred("disabled",true)
	rotation = 0.0
	sprite.sprite_frames = make_frames("Thundersphere",8,22.0)
	sprite.scale = Vector2(2,2)
	sprite.sprite_frames.set_animation_loop("effect",false)
	sprite.animation_finished.connect(func():
		finished.emit(global_position)
		queue_free()
	)
	sprite.play("effect")
