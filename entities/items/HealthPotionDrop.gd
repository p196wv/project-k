extends Area2D

signal picked(amount: int)

var heal_amount := 16
var base_y := 0.0
var time_alive := 0.0
var collected := false

func setup(amount := 16) -> void:
	heal_amount = amount
	collision_layer = 0
	collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 25.0
	collision.shape = shape
	add_child(collision)
	body_entered.connect(on_body_entered)
	z_index = 3000
	queue_redraw()

func _ready() -> void:
	base_y = position.y

func _process(delta: float) -> void:
	time_alive += delta
	position.y = base_y + sin(time_alive * 3.4) * 4.0
	if time_alive > 18.0:
		queue_free()
	queue_redraw()

func on_body_entered(body: Node2D) -> void:
	if collected or not body.has_method("heal") or GameState.player_hp >= GameState.player_max_hp:
		return
	collected = true
	body.heal(heal_amount)
	picked.emit(heal_amount)
	queue_free()

func _draw() -> void:
	# 代码绘制的低色阶药瓶，与现有 16px 像素素材保持一致。
	draw_circle(Vector2(0,5),27,Color(0.35,0.95,0.55,0.12))
	draw_arc(Vector2(0,5),24,0,TAU,20,Color("6df08b"),3.0)
	draw_rect(Rect2(-7,-25,14,8),Color("d8ebd1"))
	draw_rect(Rect2(-5,-31,10,7),Color("91a58c"))
	draw_rect(Rect2(-13,-18,26,28),Color("eff7df"))
	draw_rect(Rect2(-10,-13,20,20),Color("d94d55"))
	draw_rect(Rect2(-3,-10,6,14),Color("fff0db"))
	draw_rect(Rect2(-7,-6,14,6),Color("fff0db"))
	draw_string(ThemeDB.fallback_font,Vector2(-42,-40),"回血 +%d" % heal_amount,HORIZONTAL_ALIGNMENT_CENTER,84,15,Color("b9ffc2"))
