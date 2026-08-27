extends StaticBody2D

var wall_size := Vector2(256,48)
var collision_size := Vector2(232,32)

func setup(size_value: Vector2) -> void:
	wall_size = size_value
	collision_layer = 1
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	# 墙体的可见范围与碰撞完全一致，端点不再允许角色穿入。
	collision_size = wall_size
	shape.size = collision_size
	collision.shape = shape
	add_child(collision)
	queue_redraw()

func _ready() -> void:
	z_index = int(global_position.y + wall_size.y * 0.5)

func _draw() -> void:
	var rect := Rect2(-wall_size * 0.5,wall_size)
	# 所有可见像素都收在碰撞矩形内；旧版右下 8px 外扩阴影会被误认为可穿越的墙体。
	draw_rect(rect,Color("202820"))
	var face := rect.grow(-4.0)
	draw_rect(face,Color("3d493b"))
	# 顶面、正面和砖块使用固定 16px 网格，避免旧版整墙纵线形成栅栏感。
	draw_rect(Rect2(face.position,Vector2(face.size.x,8)),Color("899461"))
	draw_rect(Rect2(face.position + Vector2(0,8),Vector2(face.size.x,3)),Color("a3aa72"))
	var row := 0
	for y in range(int(face.position.y + 11),int(face.end.y - 3),14):
		var offset := -16 if row % 2 == 1 else 0
		for x in range(int(face.position.x) + offset,int(face.end.x),32):
			var brick_rect := Rect2(x + 2,y + 2,minf(28.0,face.end.x - x - 3.0),minf(10.0,face.end.y - y - 3.0))
			if brick_rect.size.x <= 0.0 or brick_rect.size.y <= 0.0:
				continue
			var shade := Color("59634d") if (floori(float(x) / 32.0) + row) % 3 != 0 else Color("667057")
			draw_rect(brick_rect,shade)
			draw_rect(Rect2(brick_rect.position,Vector2(brick_rect.size.x,2)),shade.lightened(0.12))
		row += 1
	draw_rect(Rect2(Vector2(rect.position.x,rect.end.y - 5),Vector2(wall_size.x,5)),Color("313a31"))
	# 苔藓只出现在部分顶砖，提供不规则轮廓但不改变实体范围。
	for x in range(int(face.position.x) + 8,int(face.end.x - 8),64):
		draw_rect(Rect2(x,face.position.y + 2,20,3),Color("a9b66d"))
		draw_rect(Rect2(x + 5,face.position.y + 5,10,3),Color("748451"))
