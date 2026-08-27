extends Node2D

const SHEET := "res://assets/cc0_combo_fx/simplefx-alpha.png"

var direction := Vector2.RIGHT
var combo_step := 2

func setup(direction_value: Vector2, step_value: int) -> void:
	direction = direction_value.normalized()
	combo_step = clampi(step_value,2,3)
	rotation = direction.angle()
	z_index = 2850

func _ready() -> void:
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("crescent")
	frames.set_animation_speed("crescent",22.0)
	frames.set_animation_loop("crescent",false)
	var texture: Texture2D = load(SHEET)
	# 图集的 96~128 行是一组 7 帧横向月牙斩击；最右列是武器图标，不纳入动画。
	for index in range(7):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * 32,96,32,32)
		frames.add_frame("crescent",atlas)
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * (2.0 if combo_step == 2 else 3.0)
	sprite.modulate = Color("a9f4ff") if combo_step == 2 else Color("ffd477")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.animation_finished.connect(queue_free)
	sprite.play("crescent")
