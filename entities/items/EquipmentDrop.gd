extends Area2D

signal picked(weapon_id: String)

const STAFF_ICON := preload("res://assets/cc0_items/toml_weapon_icons/staff_water.png")
const BOW_ICON := preload("res://assets/cc0_items/toml_weapon_icons/bow_bronze_arrow.png")

var weapon_id := "arcane_staff"
var base_y := 0.0
var time_alive := 0.0
var collected := false

func setup(id_value: String) -> void:
	weapon_id = id_value
	collision_layer = 0
	collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	collision.shape = shape
	add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = BOW_ICON if weapon_id == "bow" else STAFF_ICON
	sprite.scale = Vector2(2,2)
	sprite.position = Vector2(0,-18)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var label := Label.new()
	label.text = "疾风弓" if weapon_id == "bow" else "潮汐法杖"
	label.position = Vector2(-58,-58)
	label.size = Vector2(116,28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",Color("ffe990") if weapon_id == "bow" else Color("8eeaff"))
	PixelStyle.outline(label,4)
	add_child(label)
	body_entered.connect(_on_body_entered)
	z_index = 2500
	queue_redraw()

func _ready() -> void:
	base_y = position.y

func _process(delta: float) -> void:
	time_alive += delta
	position.y = base_y + sin(time_alive * 3.2) * 4.0
	if time_alive > 18.0:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if collected or not body.has_method("unlock_weapon"):
		return
	collected = true
	picked.emit(weapon_id)
	queue_free()

func _draw() -> void:
	var color := Color("ffe477") if weapon_id == "bow" else Color("73ddff")
	draw_circle(Vector2.ZERO,28,Color(color,0.14))
	draw_arc(Vector2.ZERO,25,0,TAU,20,color,3.0)
