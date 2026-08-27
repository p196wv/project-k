extends Node2D

const PLANT_SHEET := preload("res://assets/cc0_foliage/idylwilds/foliage_pack.png")
const VARIANT_RECTS := [
	Rect2(64,0,32,32),
	Rect2(64,32,48,32),
	Rect2(208,272,32,32),
	Rect2(224,240,32,48)
]

var plant_variant := 0
var visual_radius := 11.0

func setup(variant_value: int, scale_value: float) -> void:
	plant_variant = clampi(variant_value,0,VARIANT_RECTS.size() - 1)
	# 环境图块统一采用整数倍率，避免像素边缘在移动镜头下闪烁。
	var crisp_scale := 2.0
	visual_radius = 16.0
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = PLANT_SHEET
	var region: Rect2 = VARIANT_RECTS[plant_variant]
	atlas.region = region
	sprite.texture = atlas
	sprite.scale = Vector2(crisp_scale,crisp_scale)
	# 装饰物只按脚底锚点参与 Y 排序，不创建任何碰撞体积。
	# 不同高度的图块统一贴地，避免高草看起来穿进地面或悬空。
	sprite.position = Vector2(0,-region.size.y * crisp_scale * 0.5 + 8.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	queue_redraw()

func _ready() -> void:
	z_index = int(global_position.y)

func _draw() -> void:
	draw_ellipse_shadow(Vector2(0,7),Vector2(visual_radius + 3.0,visual_radius * 0.42))

func draw_ellipse_shadow(center: Vector2, radius: Vector2) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radius.x,sin(angle) * radius.y))
	draw_colored_polygon(points,Color(0.02,0.05,0.02,0.34))
