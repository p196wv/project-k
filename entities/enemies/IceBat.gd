extends CharacterBody2D

signal died(enemy: Node2D, rare: bool)
signal attack_hit(damage: int)
signal ranged_attack(position: Vector2, direction: Vector2, damage: int)
signal hit_received(enemy: Node2D, amount: int, position: Vector2)

const MAX_HP := 30
const MOVE_SPEED := 82.0
const ATTACK_RANGE := 54.0
const TELEGRAPH_TIME := 0.48
const ATTACK_COOLDOWN := 1.55
const DIRECTIONS := ["down","down_right","right","up_right","up","up_left","left","down_left"]
const AGGRO_RANGE := 315.0
const DEAGGRO_RANGE := 520.0

var hp := MAX_HP
var max_hp := MAX_HP
var move_speed := MOVE_SPEED
var attack_damage := 7
var attack_cooldown_value := ATTACK_COOLDOWN
var telegraph_duration := TELEGRAPH_TIME
var role := "normal"
var role_name := "战"
var role_color := Color("ffe067")
var sprite_scale := 3.0
var target: Node2D
var sheet_path := "res://assets/puny_characters/Puny-Characters/Orc-Grunt.png"
var cooldown := 0.4
var telegraph := 0.0
var hit_flash_left := 0.0
var stun_left := 0.0
var knockback := Vector2.ZERO
var dead := false
var sprite: AnimatedSprite2D
var aggro := false
var home_position := Vector2.ZERO
var patrol_direction := Vector2.ZERO
var patrol_timer := 0.0
var avoid_direction := Vector2.ZERO
var avoid_timer := 0.0
var enemy_facing := "down"
var pending_facing := "down"
var pending_facing_time := 0.0
var attack_direction := Vector2.DOWN

func setup(player: Node2D, texture_path := "", difficulty_rank := 0, role_id := "normal") -> void:
	target = player
	if texture_path != "":
		sheet_path = texture_path
	max_hp = MAX_HP + difficulty_rank * 4
	hp = max_hp
	move_speed = MOVE_SPEED + minf(difficulty_rank * 2.5,30.0)
	attack_damage = 7 + floori(difficulty_rank / 3.0)
	role = role_id
	match role:
		"runner":
			max_hp = maxi(18,roundi(max_hp * 0.72))
			hp = max_hp
			move_speed *= 1.35
			telegraph_duration = 0.32
			attack_cooldown_value = 1.15
			role_name = "疾"
			role_color = Color("79eaff")
		"brute":
			max_hp = roundi(max_hp * 1.65)
			hp = max_hp
			move_speed *= 0.72
			attack_damage += 4
			telegraph_duration = 0.72
			attack_cooldown_value = 1.9
			sprite_scale = 3.0
			role_name = "重"
			role_color = Color("ff9a68")
		"ranger":
			max_hp = maxi(20,roundi(max_hp * 0.82))
			hp = max_hp
			move_speed *= 0.92
			attack_damage = maxi(5,attack_damage - 1)
			telegraph_duration = 0.58
			attack_cooldown_value = 1.85
			role_name = "弓"
			role_color = Color("b8ef72")

func _ready() -> void:
	home_position = global_position
	add_to_group("field_enemies")
	collision_layer = 4
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14
	collision.shape = circle
	collision.position = Vector2(0,8)
	add_child(collision)
	create_sprite()

func create_sprite() -> void:
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var texture: Texture2D = load(sheet_path)
	for row in range(8):
		var name: String = DIRECTIONS[row]
		frames.add_animation("idle_" + name)
		frames.set_animation_speed("idle_" + name,1.0)
		var idle_atlas := AtlasTexture.new()
		idle_atlas.atlas = texture
		idle_atlas.region = Rect2(0,row * 32,32,32)
		frames.add_frame("idle_" + name,idle_atlas)
		frames.add_animation("walk_" + name)
		frames.set_animation_speed("walk_" + name,8.0)
		for column in [0,1,2,3]:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * 32,row * 32,32,32)
			frames.add_frame("walk_" + name,atlas)
	sprite.sprite_frames = frames
	sprite.scale = Vector2(sprite_scale,sprite_scale)
	sprite.position = Vector2(0,-18)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.play("idle_down")

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target):
		return
	hit_flash_left = maxf(0.0,hit_flash_left - delta)
	stun_left = maxf(0.0,stun_left - delta)
	avoid_timer = maxf(0.0,avoid_timer - delta)
	if knockback.length_squared() > 1.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO,620.0 * delta)
	elif stun_left > 0.0:
		velocity = Vector2.ZERO
	elif not aggro:
		if global_position.distance_to(target.global_position) <= AGGRO_RANGE:
			aggro = true
		else:
			patrol(delta)
	elif global_position.distance_to(target.global_position) > DEAGGRO_RANGE:
		aggro = false
		telegraph = 0.0
		cooldown = 0.4
		velocity = global_position.direction_to(home_position) * move_speed
	elif telegraph > 0.0:
		telegraph -= delta
		velocity = Vector2.ZERO
		if telegraph <= 0.0:
			if role == "ranger":
				ranged_attack.emit(global_position + Vector2(0,8),attack_direction,attack_damage)
			elif global_position.distance_to(target.global_position) <= ATTACK_RANGE + 18.0:
				attack_hit.emit(attack_damage)
			cooldown = attack_cooldown_value
	elif role == "ranger":
		ranged_combat(delta)
	elif cooldown > 0.0:
		cooldown -= delta
		move_toward_target(0.55)
	else:
		var distance := global_position.distance_to(target.global_position)
		if distance <= ATTACK_RANGE:
			attack_direction = global_position.direction_to(target.global_position)
			telegraph = telegraph_duration
		else:
			move_toward_target(1.0)
	move_and_slide()
	if get_slide_collision_count() > 0:
		var normal := get_slide_collision(0).get_normal()
		if aggro:
			var tangent := normal.orthogonal()
			if tangent.dot(global_position.direction_to(target.global_position)) < 0.0:
				tangent = -tangent
			avoid_direction = tangent
			avoid_timer = 0.55
		else:
			# 只在首次撞墙时反射方向；连续接触墙面时反复 bounce 会造成抽搐。
			if avoid_timer <= 0.0:
				patrol_direction = patrol_direction.bounce(normal).normalized()
				patrol_timer = 0.7
				avoid_timer = 0.42
	global_position.x = clampf(global_position.x,45.0,2355.0)
	global_position.y = clampf(global_position.y,75.0,1390.0)
	z_index = int(global_position.y)
	var base_color := Color.WHITE if role == "normal" else role_color.lerp(Color.WHITE,0.64)
	sprite.modulate = base_color if hit_flash_left <= 0.0 else Color(1.7,1.7,1.7,1.0)
	if velocity.length_squared() < 4.0 and not sprite.animation.begins_with("idle_"):
		sprite.play("idle_" + enemy_facing)
	queue_redraw()

func ranged_combat(delta: float) -> void:
	var distance := global_position.distance_to(target.global_position)
	if cooldown > 0.0:
		cooldown -= delta
	if distance < 165.0:
		move_in_direction(target.global_position.direction_to(global_position),move_speed * 0.9)
	elif distance > 305.0:
		move_toward_target(0.85)
	elif cooldown <= 0.0:
		velocity = Vector2.ZERO
		attack_direction = global_position.direction_to(target.global_position)
		telegraph = telegraph_duration
	else:
		var strafe := global_position.direction_to(target.global_position).orthogonal()
		if int(home_position.x + home_position.y) % 2 == 0:
			strafe = -strafe
		move_in_direction(strafe,move_speed * 0.32)

func move_toward_target(multiplier: float) -> void:
	var direction := avoid_direction if avoid_timer > 0.0 else global_position.direction_to(target.global_position)
	move_in_direction(direction,move_speed * multiplier)

func move_in_direction(direction: Vector2, speed: float) -> void:
	velocity = direction.normalized() * speed
	var wanted := direction_name(direction)
	# 方向必须稳定数帧才换朝向，避免在八方向分界线上左右闪烁。
	if wanted == enemy_facing:
		pending_facing = wanted
		pending_facing_time = 0.0
	elif wanted != pending_facing:
		pending_facing = wanted
		pending_facing_time = 0.0
	else:
		pending_facing_time += get_physics_process_delta_time()
		if pending_facing_time >= 0.10:
			enemy_facing = pending_facing
			pending_facing_time = 0.0
	var walk_animation := "walk_" + enemy_facing
	if sprite.animation != walk_animation:
		sprite.play(walk_animation)

func patrol(delta: float) -> void:
	if global_position.distance_to(home_position) > 115.0:
		# 记住返程方向，回到半径内后不会立刻恢复旧的向外方向。
		patrol_direction = global_position.direction_to(home_position)
		patrol_timer = 0.9
		move_in_direction(patrol_direction,move_speed * 0.48)
		return
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		if patrol_direction == Vector2.ZERO:
			patrol_direction = Vector2.from_angle(RNG.generator.randf_range(0.0,TAU))
			patrol_timer = RNG.generator.randf_range(0.85,1.7)
		else:
			patrol_direction = Vector2.ZERO
			patrol_timer = RNG.generator.randf_range(0.35,0.8)
	if patrol_direction == Vector2.ZERO:
		velocity = Vector2.ZERO
	else:
		move_in_direction(patrol_direction,move_speed * 0.42)

func direction_name(vector: Vector2) -> String:
	var sector := int(round(wrapf(vector.angle(),0.0,TAU) / (PI / 4.0))) % 8
	return ["right","down_right","down","down_left","left","up_left","up","up_right"][sector]

func take_damage(amount: int, source := Vector2.ZERO) -> void:
	if dead:
		return
	hp -= amount
	aggro = true
	hit_flash_left = 0.18
	stun_left = 0.16
	var source_position: Vector2 = source
	knockback = source_position.direction_to(global_position) * 245.0
	hit_received.emit(self,amount,global_position)
	if hp <= 0:
		dead = true
		died.emit(self,RNG.chance(0.26))
		queue_free()

func _draw() -> void:
	var shadow := PackedVector2Array()
	for i in range(16):
		var angle := TAU * i / 16.0
		shadow.append(Vector2(cos(angle) * 22.0,12 + sin(angle) * 8.0))
	draw_colored_polygon(shadow,Color(0.02,0.04,0.02,0.45))
	if telegraph > 0.0:
		draw_circle(Vector2(0,5),34,Color(1.0,0.18,0.12,0.18))
		draw_arc(Vector2(0,5),34,0,TAU,20,Color("ff695c"),4.0)
		if role == "ranger":
			draw_line(Vector2(0,5),attack_direction * 78.0 + Vector2(0,5),Color(1.0,0.42,0.22,0.62),3.0)
	draw_rect(Rect2(-24,-48,48,5),Color("172217"))
	draw_rect(Rect2(-24,-48,48 * maxf(0.0,float(hp) / max_hp),5),Color("78e58a"))
	# 橙色能量条表示下一次攻击的准备度；红圈阶段保持满格。
	var energy_ratio := 1.0 if telegraph > 0.0 else clampf(1.0 - cooldown / attack_cooldown_value,0.0,1.0)
	draw_rect(Rect2(-24,-41,48,4),Color("241b15"))
	draw_rect(Rect2(-24,-41,48 * energy_ratio,4),Color("f2a24d"))
	if aggro and telegraph <= 0.0:
		draw_string(ThemeDB.fallback_font,Vector2(-4,-54),"!",HORIZONTAL_ALIGNMENT_LEFT,12,14,Color("ffe067"))
	draw_string(ThemeDB.fallback_font,Vector2(13,-52),role_name,HORIZONTAL_ALIGNMENT_LEFT,18,13,role_color)
