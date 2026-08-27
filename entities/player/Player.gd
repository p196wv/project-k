extends CharacterBody2D

signal attacked(position: Vector2, direction: Vector2, reach: float)
signal spell_cast(position: Vector2, direction: Vector2)
signal weapon_fired(position: Vector2, direction: Vector2, weapon_id: String)
signal weapon_changed(weapon_id: String)
signal weapon_time_changed(seconds_left: float)
signal damaged(amount: int, position: Vector2)
signal hp_changed(current: int, maximum: int)
signal mana_changed(current: float, maximum: float)
signal died

const PixelMagicBurst = preload("res://entities/effects/PixelMagicBurst.gd")
const ComboCrescent = preload("res://entities/effects/ComboCrescent.gd")
const SHEET := "res://assets/puny_characters/Puny-Characters/Mage-Cyan.png"
const DIRECTIONS := ["down","down_right","right","up_right","up","up_left","left","down_left"]
const SPEED := 210.0
const ROLL_SPEED := 430.0
const ROLL_TIME := 0.24
const ATTACK_TIME := 0.34
const ATTACK_ACTIVE_AT := 0.22
const ATTACK_REACH := 72.0
const MAX_MANA := 100.0
const SPELL_COST := 30.0
const MANA_REGEN := 13.0
const SPELL_COOLDOWN := 0.72
const CORNER_ASSIST_DELAY := 0.14
const STAFF_SHOT_COST := 5.0
const TEMP_WEAPON_DURATION := 10.0

var facing := Vector2.DOWN
var attack_direction := Vector2.DOWN
var attack_left := 0.0
var attack_pending := false
var attack_kind := "melee"
var attack_active_at := ATTACK_ACTIVE_AT
var roll_left := 0.0
var spell_cooldown_left := 0.0
var mana := MAX_MANA
var mana_regen := MANA_REGEN
var spell_cost := SPELL_COST
var spell_cooldown_duration := SPELL_COOLDOWN
var invincible_left := 0.0
var hit_flash_left := 0.0
var hit_stop_left := 0.0
var sprite: AnimatedSprite2D
var camera: Camera2D
var body_shape: CapsuleShape2D
var corner_stuck_time := 0.0
var current_weapon := "basic"
var owned_weapons := {"basic":true,"arcane_staff":false,"bow":false}
var temporary_weapon_id := ""
var temporary_weapon_left := 0.0
var combo_step := 0
var combo_window_left := 0.0
var combo_buffered := false

func _ready() -> void:
	owned_weapons = GameState.unlocked_weapons.duplicate()
	current_weapon = GameState.equipped_weapon if bool(owned_weapons.get(GameState.equipped_weapon,false)) else "basic"
	temporary_weapon_id = GameState.temporary_weapon_id
	temporary_weapon_left = GameState.weapon_time_left
	if temporary_weapon_id.is_empty() or temporary_weapon_left <= 0.0:
		clear_temporary_weapon()
		current_weapon = "basic"
		GameState.equipped_weapon = "basic"
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	body_shape = CapsuleShape2D.new()
	body_shape.radius = 11
	body_shape.height = 22
	shape.shape = body_shape
	shape.position = Vector2(0,12)
	add_child(shape)
	create_sprite()
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.limit_left = 0
	camera.limit_right = 2400
	camera.limit_top = 0
	camera.limit_bottom = 1440
	add_child(camera)

func create_sprite() -> void:
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in range(8):
		var direction: String = DIRECTIONS[row]
		add_sheet_animation(frames,"idle_" + direction,row,[0,1],4.0,true)
		add_sheet_animation(frames,"walk_" + direction,row,[0,1,2,3],10.0,true)
		# 同一角色表提供真正的弓箭与法杖动作，可按装备即时切换。
		add_sheet_animation(frames,"attack_bow_" + direction,row,[8,9,10,11],17.0,false)
		add_sheet_animation(frames,"attack_staff_" + direction,row,[12,13,14,15],12.0,false)
	sprite.sprite_frames = frames
	sprite.scale = Vector2(3,3)
	sprite.position = Vector2(0,-20)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.play("idle_down")

func add_sheet_animation(frames: SpriteFrames, name: String, row: int, columns: Array, fps: float, looped: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name,fps)
	frames.set_animation_loop(name,looped)
	var texture: Texture2D = load(SHEET)
	for column in columns:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(int(column) * 32,row * 32,32,32)
		frames.add_frame(name,atlas)

func _physics_process(delta: float) -> void:
	update_temporary_weapon(delta)
	invincible_left = maxf(0.0,invincible_left - delta)
	hit_flash_left = maxf(0.0,hit_flash_left - delta)
	hit_stop_left = maxf(0.0,hit_stop_left - delta)
	roll_left = maxf(0.0,roll_left - delta)
	spell_cooldown_left = maxf(0.0,spell_cooldown_left - delta)
	if attack_left <= 0.0:
		combo_window_left = maxf(0.0,combo_window_left - delta)
		if combo_window_left <= 0.0:
			combo_step = 0
	var previous_mana := mana
	mana = minf(MAX_MANA,mana + mana_regen * delta)
	if int(previous_mana) != int(mana):
		mana_changed.emit(mana,MAX_MANA)
	if hit_stop_left > 0.0:
		velocity = Vector2.ZERO
		update_visuals(Vector2.ZERO)
		return
	var input_vector := Input.get_vector("move_left","move_right","move_up","move_down")
	if input_vector.length_squared() > 0.01:
		facing = input_vector.normalized()
	if Input.is_action_just_pressed("roll") and roll_left <= 0.0 and attack_left <= 0.0:
		roll_left = ROLL_TIME
		invincible_left = 0.42
		combo_step = 0
		combo_window_left = 0.0
		combo_buffered = false
	if Input.is_action_just_pressed("attack"):
		if attack_left <= 0.0 and roll_left <= 0.0:
			start_attack()
		elif current_weapon == "basic" and attack_kind == "melee" and attack_left <= 0.19:
			combo_buffered = true
	elif Input.is_action_just_pressed("spell") and attack_left <= 0.0 and roll_left <= 0.0:
		start_spell()
	if attack_left > 0.0:
		attack_left = maxf(0.0,attack_left - delta)
		velocity = attack_direction * (95.0 if attack_left > ATTACK_ACTIVE_AT else 0.0)
		if attack_pending and attack_left <= attack_active_at:
			attack_pending = false
			play_attack_fx()
			if attack_kind == "spell":
				spell_cast.emit(global_position - Vector2(0,18),attack_direction)
			elif attack_kind == "melee":
				attacked.emit(global_position,attack_direction,ATTACK_REACH + (combo_step - 1) * 8.0)
			else:
				weapon_fired.emit(global_position + Vector2(0,8),attack_direction,current_weapon)
		if attack_left <= 0.0 and attack_kind == "melee":
			combo_window_left = 0.38
			if combo_buffered:
				combo_buffered = false
				start_attack()
	elif roll_left > 0.0:
		velocity = facing * ROLL_SPEED
	else:
		velocity = input_vector * SPEED
	if Input.is_action_just_pressed("weapon_basic"):
		equip_weapon("basic")
	elif Input.is_action_just_pressed("weapon_staff"):
		equip_weapon("arcane_staff")
	elif Input.is_action_just_pressed("weapon_bow"):
		equip_weapon("bow")
	var movement_start := global_position
	var intended_velocity := velocity
	move_and_slide()
	apply_corner_assist(delta,movement_start,intended_velocity)
	global_position.x = clampf(global_position.x,55.0,2345.0)
	global_position.y = clampf(global_position.y,90.0,1375.0)
	z_index = int(global_position.y)
	update_visuals(input_vector)
	queue_redraw()

func apply_corner_assist(delta: float, movement_start: Vector2, intended_velocity: Vector2) -> void:
	# 只处理两个不同碰撞面组成的凹角；正常顶着单面墙移动时不会被自动推走。
	var expected_distance := intended_velocity.length() * delta
	var actual_distance := global_position.distance_to(movement_start)
	if expected_distance < 1.0 or actual_distance > maxf(0.8,expected_distance * 0.22) or get_slide_collision_count() < 2:
		corner_stuck_time = 0.0
		return
	var first_normal := get_slide_collision(0).get_normal()
	var escape_normal := first_normal
	var has_corner := false
	for index in range(1,get_slide_collision_count()):
		var other_normal := get_slide_collision(index).get_normal()
		if absf(first_normal.dot(other_normal)) < 0.82:
			escape_normal += other_normal
			has_corner = true
	if not has_corner or escape_normal.length_squared() < 0.1:
		corner_stuck_time = 0.0
		return
	corner_stuck_time += delta
	if corner_stuck_time < CORNER_ASSIST_DELAY:
		return
	var escape_step := escape_normal.normalized() * minf(5.0,expected_distance)
	if not test_move(global_transform,escape_step):
		global_position += escape_step

func start_attack() -> void:
	if current_weapon == "arcane_staff" and mana < STAFF_SHOT_COST:
		return
	if current_weapon == "arcane_staff":
		mana -= STAFF_SHOT_COST
		mana_changed.emit(mana,MAX_MANA)
	if current_weapon == "basic":
		combo_step = combo_step % 3 + 1 if combo_window_left > 0.0 or combo_buffered else 1
		combo_window_left = 0.0
		attack_left = [0.31,0.29,0.40][combo_step - 1]
		attack_active_at = [0.18,0.16,0.22][combo_step - 1]
	else:
		combo_step = 0
		combo_buffered = false
		attack_left = 0.27 if current_weapon == "bow" else 0.42
		attack_active_at = 0.11 if current_weapon == "bow" else 0.19
	attack_pending = true
	attack_kind = "melee" if current_weapon == "basic" else "weapon"
	attack_direction = facing.normalized()
	var animation_weapon := "bow" if current_weapon == "bow" else "staff"
	sprite.play("attack_%s_%s" % [animation_weapon,direction_name(attack_direction)])

func start_spell() -> void:
	if mana < spell_cost or spell_cooldown_left > 0.0:
		return
	mana -= spell_cost
	mana_changed.emit(mana,MAX_MANA)
	spell_cooldown_left = spell_cooldown_duration
	attack_left = ATTACK_TIME
	attack_active_at = ATTACK_ACTIVE_AT
	attack_pending = true
	attack_kind = "spell"
	combo_step = 0
	combo_window_left = 0.0
	combo_buffered = false
	attack_direction = facing.normalized()
	sprite.play("attack_staff_" + direction_name(attack_direction))

func unlock_weapon(weapon_id: String) -> bool:
	var was_new := temporary_weapon_id != weapon_id
	activate_temporary_weapon(weapon_id,TEMP_WEAPON_DURATION)
	return was_new

func activate_temporary_weapon(weapon_id: String, duration := TEMP_WEAPON_DURATION) -> void:
	if weapon_id == "basic" or weapon_id not in ["arcane_staff","bow"]:
		return
	if not temporary_weapon_id.is_empty() and temporary_weapon_id != weapon_id:
		owned_weapons[temporary_weapon_id] = false
		GameState.unlocked_weapons[temporary_weapon_id] = false
	temporary_weapon_id = weapon_id
	temporary_weapon_left = duration
	owned_weapons[weapon_id] = true
	GameState.unlocked_weapons[weapon_id] = true
	current_weapon = weapon_id
	GameState.equipped_weapon = weapon_id
	GameState.temporary_weapon_id = weapon_id
	GameState.weapon_time_left = duration
	weapon_changed.emit(current_weapon)
	weapon_time_changed.emit(temporary_weapon_left)

func update_temporary_weapon(delta: float) -> void:
	if temporary_weapon_id.is_empty():
		return
	var previous_second := ceili(temporary_weapon_left)
	temporary_weapon_left = maxf(0.0,temporary_weapon_left - delta)
	GameState.weapon_time_left = temporary_weapon_left
	if ceili(temporary_weapon_left) != previous_second:
		weapon_time_changed.emit(temporary_weapon_left)
	if temporary_weapon_left <= 0.0 and (current_weapon != temporary_weapon_id or attack_left <= 0.0):
		expire_temporary_weapon()

func expire_temporary_weapon() -> void:
	var expired_id := temporary_weapon_id
	clear_temporary_weapon()
	if current_weapon == expired_id:
		current_weapon = "basic"
		GameState.equipped_weapon = "basic"
		weapon_changed.emit(current_weapon)
	weapon_time_changed.emit(0.0)

func clear_temporary_weapon() -> void:
	if not temporary_weapon_id.is_empty():
		owned_weapons[temporary_weapon_id] = false
		GameState.unlocked_weapons[temporary_weapon_id] = false
	temporary_weapon_id = ""
	temporary_weapon_left = 0.0
	GameState.temporary_weapon_id = ""
	GameState.weapon_time_left = 0.0

func has_weapon(weapon_id: String) -> bool:
	return bool(owned_weapons.get(weapon_id,false))

func equip_weapon(weapon_id: String) -> bool:
	if not has_weapon(weapon_id) or (weapon_id != "basic" and temporary_weapon_left <= 0.0) or attack_left > 0.0 or roll_left > 0.0:
		return false
	current_weapon = weapon_id
	GameState.equipped_weapon = weapon_id
	weapon_changed.emit(current_weapon)
	return true

func weapon_name() -> String:
	return weapon_name_for(current_weapon)

func weapon_name_for(weapon_id: String) -> String:
	match weapon_id:
		"bow": return "疾风弓"
		"arcane_staff": return "潮汐法杖"
		_: return "基础法杖"

func update_visuals(input_vector: Vector2) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.modulate = Color(1.0,0.35,0.35,1.0) if hit_flash_left > 0.0 else Color.WHITE
	if invincible_left > 0.0 and int(invincible_left * 24.0) % 2 == 0:
		sprite.modulate.a = 0.4
	if attack_left > 0.0:
		return
	var prefix := "walk_" if input_vector.length_squared() > 0.01 else "idle_"
	var wanted := prefix + direction_name(facing)
	if sprite.animation != wanted:
		sprite.play(wanted)

func direction_name(vector: Vector2) -> String:
	var sector := int(round(wrapf(vector.angle(),0.0,TAU) / (PI / 4.0))) % 8
	return ["right","down_right","down","down_left","left","up_left","up","up_right"][sector]

func take_damage(amount: int) -> void:
	if invincible_left > 0.0 or GameState.player_hp <= 0:
		return
	GameState.player_hp = maxi(0,GameState.player_hp - amount)
	invincible_left = 0.62
	hit_flash_left = 0.22
	hit_stop_left = 0.055
	velocity = -facing * 160.0
	shake_camera(6.0)
	damaged.emit(amount,global_position)
	hp_changed.emit(GameState.player_hp,GameState.player_max_hp)
	if GameState.player_hp <= 0:
		died.emit()

func confirm_hit() -> void:
	hit_stop_left = 0.045
	shake_camera(4.0)

func restore_mana(amount: float) -> void:
	mana = minf(MAX_MANA,mana + amount)
	mana_changed.emit(mana,MAX_MANA)

func heal(amount: int) -> void:
	if GameState.player_hp <= 0:
		return
	GameState.player_hp = mini(GameState.player_max_hp,GameState.player_hp + amount)
	hp_changed.emit(GameState.player_hp,GameState.player_max_hp)

func play_attack_fx() -> void:
	if current_weapon == "bow" and attack_kind == "weapon":
		return
	var effect := PixelMagicBurst.new()
	effect.global_position = global_position + attack_direction * 25.0 - Vector2(0,12)
	var combo_color: Color = [Color("8de9ff"),Color("ffe083"),Color("ff9f68")][clampi(combo_step - 1,0,2)] if attack_kind == "melee" else Color(0.48,0.92,1.0,0.94)
	effect.setup(attack_direction,combo_color)
	get_parent().add_child(effect)
	if attack_kind == "melee" and combo_step >= 2:
		var crescent := ComboCrescent.new()
		crescent.global_position = global_position + attack_direction * 39.0 - Vector2(0,12)
		crescent.setup(attack_direction,combo_step)
		get_parent().add_child(crescent)

func shake_camera(strength: float) -> void:
	if not is_instance_valid(camera):
		return
	camera.offset = Vector2(RNG.generator.randf_range(-strength,strength),RNG.generator.randf_range(-strength,strength))
	create_tween().tween_property(camera,"offset",Vector2.ZERO,0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var points := PackedVector2Array()
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		points.append(Vector2(cos(angle) * 24.0,13 + sin(angle) * 10.0))
	draw_colored_polygon(points,Color(0.02,0.04,0.03,0.48))
	# 世界空间双条让玩家不必一直看屏幕角落。
	draw_rect(Rect2(-30,-66,60,5),Color("172217"))
	draw_rect(Rect2(-30,-66,60 * float(GameState.player_hp) / GameState.player_max_hp,5),Color("67dc78"))
	draw_rect(Rect2(-30,-59,60,4),Color("141c2c"))
	draw_rect(Rect2(-30,-59,60 * mana / MAX_MANA,4),Color("5bc8ff"))
	if attack_left > 0.0:
		var attack_color := Color("ffe477") if current_weapon == "bow" and attack_kind != "spell" else Color(0.72,0.97,1.0,0.55)
		draw_line(attack_direction * 18.0,attack_direction * 32.0,attack_color,4.0)
