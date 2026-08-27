extends Node2D

const SHEET := "res://assets/cc0_boss_fx/devwizard/Pixelart Spells/PNG Files/Firebomb.png"

func setup(color_override := Color.WHITE) -> void:
	modulate = color_override
	z_index = 3150

func _ready() -> void:
	var sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("cast")
	frames.set_animation_speed("cast",16.0)
	frames.set_animation_loop("cast",false)
	var texture: Texture2D = load(SHEET)
	for index in range(6):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * 16,0,16,16)
		frames.add_frame("cast",atlas)
	sprite.sprite_frames = frames
	sprite.scale = Vector2(3,3)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.animation_finished.connect(queue_free)
	sprite.play("cast")
