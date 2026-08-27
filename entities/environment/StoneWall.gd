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
	draw_rect(Rect2(rect.position + Vector2(8,8),rect.size),Color(0.03,0.05,0.025,0.38))
	draw_rect(rect,Color("3d493b"))
	# 顶面、正面和砖块使用固定 16px 网格，避免旧版整墙纵线形成栅栏感。
	draw_rect(Rect2(rect.position,Vector2(wall_size.x,10)),Color("899461"))
	draw_rect(Rect2(rect.position + Vector2(0,10),Vector2(wall_size.x,4)),Color("a3aa72"))
	var row := 0
	for y in range(int(rect.position.y + 14),int(rect.end.y - 3),14):
		var offset := -16 if row % 2 == 1 else 0
		for x in range(int(rect.position.x) + offset,int(rect.end.x),32):
			var brick_rect := Rect2(x + 2,y + 2,28,minf(10.0,rect.end.y - y - 3.0))
			var shade := Color("59634d") if (floori(float(x) / 32.0) + row) % 3 != 0 else Color("667057")
			draw_rect(brick_rect,shade)
			draw_rect(Rect2(brick_rect.position,Vector2(brick_rect.size.x,2)),shade.lightened(0.12))
		row += 1
	draw_rect(Rect2(Vector2(rect.position.x,rect.end.y - 5),Vector2(wall_size.x,5)),Color("313a31"))
	# 苔藓只出现在部分顶砖，提供不规则轮廓但不改变实体范围。
	for x in range(int(rect.position.x) + 12,int(rect.end.x - 8),64):
		draw_rect(Rect2(x,rect.position.y + 3,20,4),Color("a9b66d"))
		draw_rect(Rect2(x + 5,rect.position.y + 7,10,3),Color("748451"))
