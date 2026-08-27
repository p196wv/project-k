extends Node2D

var world_size := Vector2(2400,1440)
var river_points := PackedVector2Array()
var river_width := 128.0
var bridge_indices: Array[int] = []
var map_seed := 0

func setup(size_value: Vector2, points: PackedVector2Array, width_value: float, bridges_value: Array[int], seed_value: int) -> void:
	world_size = size_value
	river_points = points
	river_width = width_value
	bridge_indices = bridges_value
	map_seed = seed_value
	z_index = -1000
	queue_redraw()

func _draw() -> void:
	# 统一 16px 网格的低饱和草地；不再拉伸小图集造成模糊色块。
	draw_rect(Rect2(Vector2.ZERO,world_size),Color("66854d"))
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = map_seed
	# 大块地表色差全部对齐 32px，边缘保持硬像素。
	for _i in range(110):
		var patch_cell := Vector2(floorf(local_rng.randf_range(0.0,world_size.x) / 32.0) * 32.0,floorf(local_rng.randf_range(0.0,world_size.y) / 32.0) * 32.0)
		var patch_width := local_rng.randi_range(1,4) * 32
		var patch_height := local_rng.randi_range(1,3) * 32
		var patch_color := Color("617f49") if local_rng.randf() < 0.58 else Color("6d8d51")
		draw_rect(Rect2(patch_cell,Vector2(patch_width,patch_height)),patch_color)
	# 草叶、碎石和小花只占数个像素，不影响碰撞或寻路。
	for _i in range(360):
		var cell := Vector2(floorf(local_rng.randf_range(0.0,world_size.x) / 16.0) * 16.0,floorf(local_rng.randf_range(0.0,world_size.y) / 16.0) * 16.0)
		var detail_roll := local_rng.randf()
		if detail_roll < 0.72:
			var blade_color := Color("8eae60") if detail_roll < 0.38 else Color("4f6f3f")
			draw_rect(Rect2(cell + Vector2(3,8),Vector2(3,7)),blade_color)
			draw_rect(Rect2(cell + Vector2(8,5),Vector2(3,10)),blade_color)
			draw_rect(Rect2(cell + Vector2(12,10),Vector2(2,5)),blade_color.darkened(0.08))
		elif detail_roll < 0.90:
			draw_rect(Rect2(cell + Vector2(4,10),Vector2(5,3)),Color("4d5f43"))
			draw_rect(Rect2(cell + Vector2(9,8),Vector2(4,4)),Color("849075"))
		else:
			var flower_color := Color("e6cf78") if local_rng.randf() < 0.55 else Color("b8d7df")
			draw_rect(Rect2(cell + Vector2(7,6),Vector2(3,3)),flower_color)
			draw_rect(Rect2(cell + Vector2(8,9),Vector2(2,6)),Color("456b3f"))
	if river_points.size() < 2:
		return
	# 四层硬边色带组成泥岸、浅水、主水面和深水，颜色与 UI 降低饱和度。
	draw_polyline(river_points,Color("3d5941"),river_width + 34.0,false)
	draw_polyline(river_points,Color("397f86"),river_width + 18.0,false)
	draw_polyline(river_points,Color("3199a3"),river_width - 4.0,false)
	draw_polyline(river_points,Color("287986"),river_width - 44.0,false)
	# 水面短高光按河段方向排列，保持像素硬边而非渐变。
	for index in range(river_points.size() - 1):
		var start := river_points[index]
		var finish := river_points[index + 1]
		var tangent := start.direction_to(finish)
		var across := tangent.orthogonal()
		for marker in range(1,4):
			var center := start.lerp(finish,float(marker) / 4.0) + across * (-18.0 if marker % 2 == 0 else 22.0)
			draw_line(center - tangent * 11.0,center + tangent * 11.0,Color("75c5be"),3.0)
	for index in bridge_indices:
		if index < 0 or index >= river_points.size() - 1:
			continue
		draw_bridge(river_points[index],river_points[index + 1])

func draw_bridge(start: Vector2, end: Vector2) -> void:
	var midpoint := (start + end) * 0.5
	var tangent := start.direction_to(end)
	var across := tangent.orthogonal()
	var half_length := river_width * 0.5 + 24.0
	var half_width := 42.0
	var corners := PackedVector2Array([
		midpoint - across * half_length - tangent * half_width,
		midpoint + across * half_length - tangent * half_width,
		midpoint + across * half_length + tangent * half_width,
		midpoint - across * half_length + tangent * half_width
	])
	draw_colored_polygon(corners,Color("5a3e2b"))
	for plank in range(-4,5):
		var offset := tangent * plank * 10.0
		var plank_color := Color("b17a45") if plank % 2 == 0 else Color("9c683d")
		draw_line(midpoint - across * half_length + offset,midpoint + across * half_length + offset,plank_color,8.0)
		draw_line(midpoint - across * half_length + offset + tangent * 3.0,midpoint + across * half_length + offset + tangent * 3.0,Color("70492f"),2.0)
	draw_line(midpoint - across * half_length - tangent * half_width,midpoint + across * half_length - tangent * half_width,Color("392b23"),7.0)
	draw_line(midpoint - across * half_length + tangent * half_width,midpoint + across * half_length + tangent * half_width,Color("392b23"),7.0)
