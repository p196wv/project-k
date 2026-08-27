class_name PixelStyle
extends RefCounted

const ICE := Color("58d8e8")
const GOLD := Color("e7bd67")

static func palette_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float color_steps = 7.0; void fragment(){ vec4 c=texture(TEXTURE,UV); c.rgb=floor(c.rgb*color_steps+0.5)/color_steps; COLOR=c*COLOR; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

static func box(fill: Color, border: Color, width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func style_button(button: Button, accent: Color = ICE) -> void:
	button.add_theme_stylebox_override("normal", box(Color("151d1a"), Color("3d5244"), 3))
	button.add_theme_stylebox_override("hover", box(Color("1d2b25"), accent, 4))
	button.add_theme_stylebox_override("pressed", box(Color("0d1412"), Color.WHITE, 4))
	button.add_theme_stylebox_override("disabled", box(Color("101511"), Color("29342d"), 2))
	button.add_theme_color_override("font_color", Color("e8f4ee"))
	button.add_theme_color_override("font_hover_color", accent)
	button.add_theme_color_override("font_disabled_color", Color("52616a"))

static func outline(label: Label, size: int = 5) -> void:
	label.add_theme_color_override("font_outline_color", Color("030609"))
	label.add_theme_constant_override("outline_size", size)
