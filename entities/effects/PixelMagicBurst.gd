extends Node2D

const SLASH_SHEET := "res://assets/combat_fx/pixel_art_sword_slash_sprites.png"
const FRAME_SIZE := Vector2(64,47)
const FRAME_COUNT := 9

var direction := Vector2.RIGHT
var sprite: AnimatedSprite2D
var effect_color := Color(0.48,0.92,1.0,0.94)

func setup(attack_direction: Vector2, color_override := Color(0.48,0.92,1.0,0.94)) -> void:
	direction = attack_direction.normalized()
	effect_color = color_override
	rotation = direction.angle()
	z_index = 40

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("slash")
	frames.set_animation_speed("slash",24.0)
	frames.set_animation_loop("slash",false)
	var texture: Texture2D = load(SLASH_SHEET)
	for frame_index in range(FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((frame_index % 3) * FRAME_SIZE.x,floori(frame_index / 3.0) * FRAME_SIZE.y,FRAME_SIZE.x,FRAME_SIZE.y)
		frames.add_frame("slash",atlas)
	sprite.sprite_frames = frames
	sprite.position = Vector2(28,0)
	sprite.scale = Vector2(2,2)
	sprite.modulate = effect_color
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.animation_finished.connect(queue_free)
	sprite.play("slash")
