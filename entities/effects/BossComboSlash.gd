extends Node2D

const SHEET := "res://assets/cc0_combo_fx/boss-slash-256.png"

var direction := Vector2.RIGHT
var combo_step := 1

func setup(direction_value: Vector2, step_value: int) -> void:
	direction = direction_value.normalized()
	combo_step = clampi(step_value,1,3)
	rotation = direction.angle()
	z_index = 3300

func _ready() -> void:
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("slash")
	frames.set_animation_speed("slash",24.0)
	frames.set_animation_loop("slash",false)
	var texture: Texture2D = load(SHEET)
	var source_row := 0 if combo_step < 3 else 5
	for index in range(8):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * 256,source_row * 256,256,256)
		frames.add_frame("slash",atlas)
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * 0.5
	sprite.modulate = [Color("ffbd75"),Color("ff865e"),Color("ff5548")][combo_step - 1]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.animation_finished.connect(queue_free)
	sprite.play("slash")
