extends CharacterBody2D

signal defeated
signal hp_changed(current: int, maximum: int)
signal damage_taken(amount: int, position: Vector2)
signal physical_started(position: Vector2, direction: Vector2, combo_step: int)
signal magic_cast(position: Vector2, direction: Vector2, phase_two: bool)
signal meteor_cast(target_position: Vector2, phase_two: bool)
signal intent_changed(text: String, color: Color)
signal phase_transition_requested(next_phase: int)

const DIRECTIONS := ["down","down_right","right","up_right","up","up_left","left","down_left"]
const SHEET := "res://assets/puny_characters/Puny-Characters/Orc-Soldier-Red.png"
const MAX_HP := 260

var target: Node2D
var hp := MAX_HP
var max_hp := MAX_HP
var dead := false
var ai_enabled := true
var state := "chase"
var state_left := 0.0
var cooldown := 1.0
var attack_cycle := 0
var attack_direction := Vector2.LEFT
var physical_hit := false
var hit_flash_left := 0.0
var phase_two := false
var sprite: AnimatedSprite2D
var phase_index := 1
var transitioning := false
var combo_hits_left := 0
var physical_combo_step := 0

func setup(target_value: Node2D) -> void:
	target = target_value
	ai_enabled = "--smoke-test" not in OS.get_cmdline_user_args()

func _ready() -> void:
	add_to_group("field_enemies")
	collision_layer = 4
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 23.0
	collision.shape = shape
	collision.position = Vector2(0,9)
	add_child(collision)
	create_sprite()

func create_sprite() -> void:
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var texture: Texture2D = load(SHEET)
	for row in range(8):
		var direction: String = DIRECTIONS[row]
		frames.add_animation("idle_" + direction)
		frames.set_animation_speed("idle_" + direction,3.0)
		frames.set_animation_loop("idle_" + direction,true)
		for column in [0,1]:
			var idle_atlas := AtlasTexture.new()
			idle_atlas.atlas = texture
			idle_atlas.region = Rect2(column * 32,row * 32,32,32)
			frames.add_frame("idle_" + direction,idle_atlas)
		frames.add_animation("walk_" + direction)
		frames.set_animation_speed("walk_" + direction,9.0)
		frames.set_animation_loop("walk_" + direction,true)
		for column in [0,1,2,3]:
			var walk_atlas := AtlasTexture.new()
			walk_atlas.atlas = texture
			walk_atlas.region = Rect2(column * 32,row * 32,32,32)
			frames.add_frame("walk_" + direction,walk_atlas)
	sprite.sprite_frames = frames
	sprite.scale = Vector2(4,4)
	sprite.position = Vector2(0,-27)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.play("idle_left")

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target) or transitioning:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	hit_flash_left = maxf(0.0,hit_flash_left - delta)
	phase_two = phase_index >= 2
	match state:
		"physical_telegraph":
			velocity = Vector2.ZERO
			state_left -= delta
			if state_left <= 0.0:
				state = "physical_dash"
				state_left = [0.25,0.27,0.30][phase_index - 1]
				physical_hit = false
				physical_combo_step += 1
				physical_started.emit(global_position,attack_direction,physical_combo_step)
		"physical_dash":
			state_left -= delta
			velocity = attack_direction * [570.0,640.0,710.0][phase_index - 1]
			if not physical_hit and global_position.distance_to(target.global_position) <= 82.0:
				physical_hit = true
				target.take_damage([10,11,13][phase_index - 1])
			if state_left <= 0.0:
				combo_hits_left -= 1
				if combo_hits_left > 0:
					state = "combo_gap"
					state_left = 0.15
				else:
					start_recover(0.58)
		"combo_gap":
			velocity = Vector2.ZERO
			state_left -= delta
			attack_direction = global_position.direction_to(target.global_position)
			if state_left <= 0.0:
				state = "physical_telegraph"
				state_left = 0.28 if phase_index == 2 else 0.22
				intent_changed.emit("连续斩击 %d/%d · 不要过早结束翻滚" % [physical_combo_step + 1,phase_index],Color("ff9368"))
		"magic_telegraph":
			velocity = Vector2.ZERO
			state_left -= delta
			attack_direction = global_position.direction_to(target.global_position)
			if state_left <= 0.0:
				magic_cast.emit(global_position - Vector2(0,12),attack_direction,phase_two)
				start_recover(0.72)
		"meteor_telegraph":
			velocity = Vector2.ZERO
			state_left -= delta
			if state_left <= 0.0:
				meteor_cast.emit(target.global_position,phase_two)
				start_recover(0.85)
		"recover":
			velocity = Vector2.ZERO
			state_left -= delta
			if state_left <= 0.0:
				state = "chase"
				cooldown = [0.76,0.55,0.40][phase_index - 1]
				intent_changed.emit("观察 BOSS 动作，红色预警可翻滚规避",Color("d9e6cf"))
		_:
			cooldown -= delta
			var distance := global_position.distance_to(target.global_position)
			if ai_enabled and cooldown <= 0.0:
				choose_attack(distance)
			elif distance > 170.0:
				attack_direction = global_position.direction_to(target.global_position)
				velocity = attack_direction * [88.0,102.0,118.0][phase_index - 1]
			else:
				velocity = global_position.direction_to(target.global_position).orthogonal() * 42.0
	move_and_slide()
	z_index = int(global_position.y)
	update_animation()
	var phase_color: Color = [Color.WHITE,Color("ffd0a8"),Color("ff8c82")][phase_index - 1]
	sprite.modulate = Color(1.8,1.8,1.8,1.0) if hit_flash_left > 0.0 else phase_color
	queue_redraw()

func choose_attack(distance: float) -> void:
	attack_cycle += 1
	if distance < 210.0 or attack_cycle % 3 == 1:
		start_physical()
	elif attack_cycle % 3 == 2:
		start_magic()
	elif phase_index >= 2:
		start_meteor()
	else:
		start_magic()

func start_physical() -> void:
	if dead:
		return
	state = "physical_telegraph"
	state_left = [0.68,0.56,0.46][phase_index - 1]
	attack_direction = global_position.direction_to(target.global_position)
	combo_hits_left = phase_index
	physical_combo_step = 0
	intent_changed.emit("物理：%d 段烈焰连斩 · 横向翻滚" % phase_index,Color("ff765f"))

func start_magic() -> void:
	if dead:
		return
	state = "magic_telegraph"
	state_left = [0.82,0.70,0.58][phase_index - 1]
	attack_direction = global_position.direction_to(target.global_position)
	intent_changed.emit("魔法：扇形火球 · 从弹幕缝隙穿过",Color("ffb25f"))

func start_meteor() -> void:
	if dead:
		return
	state = "meteor_telegraph"
	state_left = 0.70 if phase_index == 2 else 0.56
	intent_changed.emit("魔法：雷暴落点 · 离开紫色警戒圈",Color("db79ff"))

func start_recover(duration: float) -> void:
	state = "recover"
	state_left = duration

func apply_frost_stagger() -> void:
	if dead:
		return
	velocity = Vector2.ZERO
	start_recover(0.72)
	intent_changed.emit("寒霜符文打断成功 · 趁硬直输出",Color("8feaff"))

func take_damage(amount: int, _source := Vector2.ZERO) -> void:
	if dead or transitioning:
		return
	var previous_hp := hp
	var proposed_hp := maxi(0,hp - amount)
	var threshold := floori(float(max_hp) * 2.0 / 3.0) if phase_index == 1 else (floori(float(max_hp) / 3.0) if phase_index == 2 else 0)
	if phase_index < 3 and proposed_hp <= threshold:
		hp = threshold
		transitioning = true
		state = "phase_transition"
		velocity = Vector2.ZERO
		hit_flash_left = 0.0
		hp_changed.emit(hp,max_hp)
		damage_taken.emit(previous_hp - hp,global_position)
		phase_transition_requested.emit(phase_index + 1)
		return
	hp = proposed_hp
	hit_flash_left = 0.16
	hp_changed.emit(hp,max_hp)
	damage_taken.emit(previous_hp - hp,global_position)
	if hp <= 0:
		dead = true
		velocity = Vector2.ZERO
		collision_layer = 0
		intent_changed.emit("炎魔核心崩解",Color("ffe083"))
		defeated.emit()

func complete_phase_transition(card_damage: int) -> void:
	if not transitioning or dead:
		return
	phase_index = mini(3,phase_index + 1)
	phase_two = phase_index >= 2
	hp = maxi(1,hp - card_damage)
	transitioning = false
	state = "recover"
	state_left = 1.0
	cooldown = 1.0
	hp_changed.emit(hp,max_hp)
	intent_changed.emit("阶段 %d 开始 · 连斩提升为 %d 段" % [phase_index,phase_index],Color("ffe083"))

func update_animation() -> void:
	if not is_instance_valid(sprite):
		return
	var direction := attack_direction if velocity.length_squared() < 4.0 else velocity.normalized()
	var animation := ("walk_" if velocity.length_squared() >= 4.0 else "idle_") + direction_name(direction)
	if sprite.animation != animation:
		sprite.play(animation)

func direction_name(vector: Vector2) -> String:
	var sector := int(round(wrapf(vector.angle(),0.0,TAU) / (PI / 4.0))) % 8
	return ["right","down_right","down","down_left","left","up_left","up","up_right"][sector]

func _draw() -> void:
	var shadow := PackedVector2Array()
	for index in range(16):
		var angle := TAU * index / 16.0
		shadow.append(Vector2(cos(angle) * 35.0,18 + sin(angle) * 12.0))
	draw_colored_polygon(shadow,Color(0.03,0.01,0.02,0.52))
	if state == "physical_telegraph":
		draw_circle(Vector2(0,8),48,Color(1.0,0.12,0.06,0.18))
		draw_arc(Vector2(0,8),48,0,TAU,24,Color("ff584a"),5.0)
		draw_line(Vector2(0,8),attack_direction * 165.0 + Vector2(0,8),Color(1.0,0.25,0.12,0.76),16.0)
	elif state == "magic_telegraph":
		draw_circle(Vector2(0,5),52,Color(1.0,0.42,0.08,0.17))
		draw_arc(Vector2(0,5),52,0,TAU,28,Color("ffb248"),5.0)
		for offset in [-0.32,0.0,0.32]:
			draw_line(Vector2(0,5),attack_direction.rotated(offset) * 135.0,Color(1.0,0.64,0.22,0.54),3.0)
	elif state == "meteor_telegraph":
		draw_circle(Vector2(0,5),54,Color(0.7,0.16,1.0,0.18))
		draw_arc(Vector2(0,5),54,0,TAU,28,Color("dd79ff"),5.0)
	if phase_index >= 2:
		draw_arc(Vector2(0,7),42 + phase_index * 2,0,TAU,24,Color(1.0,0.2,0.08,0.32 + phase_index * 0.08),4.0)
	if transitioning:
		draw_circle(Vector2(0,5),58,Color(0.55,0.75,1.0,0.18))
		draw_arc(Vector2(0,5),58,0,TAU,32,Color("a9e9ff"),6.0)
