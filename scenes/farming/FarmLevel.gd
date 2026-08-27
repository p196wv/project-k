extends Node2D

signal boss_door_entered
signal player_defeated

const PlayerScript = preload("res://entities/player/Player.gd")
const EnemyScript = preload("res://entities/enemies/IceBat.gd")
const ArcaneOrbScript = preload("res://entities/effects/ArcaneOrb.gd")
const PixelMagicBurst = preload("res://entities/effects/PixelMagicBurst.gd")
const PlayerWeaponProjectileScript = preload("res://entities/effects/PlayerWeaponProjectile.gd")
const EnemyProjectileScript = preload("res://entities/effects/EnemyProjectile.gd")
const EquipmentDropScript = preload("res://entities/items/EquipmentDrop.gd")
const StoneWallScript = preload("res://entities/environment/StoneWall.gd")
const PlantObstacleScript = preload("res://entities/environment/PlantObstacle.gd")
const ProceduralTerrainScript = preload("res://entities/environment/ProceduralTerrain.gd")
const WORLD_SIZE := Vector2(2400,1440)
const ASSET_ROOT := "res://assets/puny_characters/Puny-Characters/"
const MAX_ACTIVE_ENEMIES := 30
const WAVE_CLEAR_REMAINDER := 2
const PRESSURE_ENEMIES_PER_WAVE := 1
const CARD_DROP_CHANCE := 0.40
const HIT_SOUNDS := [
	"res://assets/audio/kenney_impact/Audio/impactSoft_medium_000.ogg",
	"res://assets/audio/kenney_impact/Audio/impactSoft_medium_001.ogg",
	"res://assets/audio/kenney_impact/Audio/impactSoft_medium_002.ogg"
]

var player: CharacterBody2D
var enemies: Array[Node] = []
var hud_hp: Label
var hud_mana: Label
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var hud_cards: Label
var prompt: Label
var toast: Label
var portal_hint: Label
var portal_position := Vector2(2160,390)
var walls: Array[Node] = []
var plants: Array[Node] = []
var river_segments: Array[Node] = []
var river_points := PackedVector2Array()
var river_width := 128.0
var bridges: Array[int] = []
var map_seed := 0
var hit_audio_pool: Array[AudioStreamPlayer2D] = []
var hit_audio_index := 0
var combo_count := 0
var combo_left := 0.0
var combo_label: Label
var wave_label: Label
var hud_layer: CanvasLayer
var hud_weapon: Label
var wave := 1
var wave_time_left := 16.0
var total_kills := 0
var elapsed_time := 0.0
var damage_taken := 0
var highest_combo := 0
var portal_unlocked := false
var upgrade_overlay: Control
var equipment_drops := 0
var equipment_history: Array[String] = []
var kill_heal := 0
var combo_window_bonus := 0.0
var upgrade_history: Array[String] = []
var card_drop_attempts := 0
var card_drops := 0

func _ready() -> void:
	create_environment()
	create_audio_pool()
	create_player()
	create_enemies()
	create_hud()
	GameState.card_added.connect(update_card_hud)
	update_card_hud("",0)
	toast.text = "清理兽潮推进波次 · 怪物约 40% 概率掉落 BOSS 对策牌"
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(toast) and toast.text.begins_with("清理兽潮"):
			toast.text = ""
	)
	queue_redraw()

func _exit_tree() -> void:
	get_tree().paused = false

func create_environment() -> void:
	map_seed = RNG.seed_value
	create_procedural_river()
	create_random_walls(12)
	create_flora(18)
	portal_position = find_safe_landmark(Vector2(2160,330),105.0)

func create_procedural_river() -> void:
	var horizontal := RNG.generator.randf() < 0.5
	river_width = RNG.generator.randf_range(112.0,142.0)
	river_points.clear()
	if horizontal:
		var center_y := RNG.generator.randf_range(430.0,1010.0)
		for x in range(-120,2521,120):
			center_y = clampf(center_y + RNG.generator.randf_range(-54.0,54.0),250.0,1190.0)
			river_points.append(Vector2(x,roundf(center_y / 8.0) * 8.0))
	else:
		var center_x := RNG.generator.randf_range(620.0,1780.0)
		for y in range(-120,1561,120):
			center_x = clampf(center_x + RNG.generator.randf_range(-58.0,58.0),300.0,2100.0)
			river_points.append(Vector2(roundf(center_x / 8.0) * 8.0,y))
	bridges.clear()
	for fraction in [0.25,0.5,0.75]:
		var index := clampi(roundi((river_points.size() - 2) * fraction) + RNG.generator.randi_range(-1,1),1,river_points.size() - 3)
		while index in bridges:
			index = mini(index + 1,river_points.size() - 3)
		bridges.append(index)
	var terrain = ProceduralTerrainScript.new()
	terrain.setup(WORLD_SIZE,river_points,river_width,bridges,map_seed)
	add_child(terrain)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for index in range(river_points.size() - 1):
		if index in bridges:
			continue
		add_river_segment(body,river_points[index],river_points[index + 1])

func add_river_segment(body: StaticBody2D, start: Vector2, end: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(start.distance_to(end) + 30.0,river_width)
	collision.position = (start + end) * 0.5
	collision.rotation = start.angle_to_point(end)
	collision.shape = shape
	body.add_child(collision)
	river_segments.append(collision)

func create_random_walls(target_count: int) -> void:
	var attempts := 0
	while walls.size() < target_count and attempts < 360:
		attempts += 1
		var horizontal := RNG.generator.randf() < 0.55
		var size := Vector2(RNG.generator.randf_range(160.0,300.0),48.0) if horizontal else Vector2(48.0,RNG.generator.randf_range(150.0,260.0))
		size = Vector2(roundf(size.x / 8.0) * 8.0,roundf(size.y / 8.0) * 8.0)
		var position_value := Vector2(RNG.generator.randf_range(150.0,WORLD_SIZE.x - 150.0),RNG.generator.randf_range(170.0,WORLD_SIZE.y - 150.0))
		position_value = Vector2(roundf(position_value.x / 16.0) * 16.0,roundf(position_value.y / 16.0) * 16.0)
		if can_place_wall(position_value,size):
			add_wall(position_value,size)

func can_place_wall(position_value: Vector2, size_value: Vector2) -> bool:
	if position_value.distance_to(Vector2(280,1120)) < 230.0 or position_value.distance_to(Vector2(2160,330)) < 210.0:
		return false
	var radius := size_value.length() * 0.5 + river_width * 0.5 + 28.0
	for index in range(river_points.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(position_value,river_points[index],river_points[index + 1])
		if closest.distance_to(position_value) < radius:
			return false
	var candidate_bounds := Rect2(position_value - size_value * 0.5,size_value).grow(72.0)
	for wall in walls:
		if candidate_bounds.intersects(Rect2(wall.global_position - wall.wall_size * 0.5,wall.wall_size)):
			return false
	return true

func find_safe_landmark(preferred: Vector2, clearance: float) -> Vector2:
	if is_environment_position_open(preferred,clearance):
		return preferred
	for radius in range(80,721,80):
		for index in range(24):
			var candidate := preferred + Vector2.from_angle(TAU * index / 24.0) * radius
			if is_environment_position_open(candidate,clearance):
				return candidate
	return Vector2(2100,260)

func debug_has_river_collision_at(world_point: Vector2) -> bool:
	for collision in river_segments:
		var rectangle := collision.shape as RectangleShape2D
		var local_point: Vector2 = collision.to_local(world_point)
		if Rect2(-rectangle.size * 0.5,rectangle.size).has_point(local_point):
			return true
	return false

func create_audio_pool() -> void:
	for i in range(4):
		var audio := AudioStreamPlayer2D.new()
		audio.volume_db = -7.0
		audio.max_distance = 760.0
		add_child(audio)
		hit_audio_pool.append(audio)

func play_hit_sound(world_pos: Vector2, heavy := false) -> void:
	if hit_audio_pool.is_empty():
		return
	var audio := hit_audio_pool[hit_audio_index % hit_audio_pool.size()]
	hit_audio_index += 1
	audio.global_position = world_pos
	audio.stream = load(HIT_SOUNDS[RNG.generator.randi_range(0,HIT_SOUNDS.size() - 1)])
	audio.pitch_scale = RNG.generator.randf_range(0.92,1.08) if not heavy else RNG.generator.randf_range(0.78,0.88)
	audio.play()

func add_wall(position_value: Vector2, size_value: Vector2) -> void:
	var wall = StoneWallScript.new()
	wall.position = position_value
	wall.setup(size_value)
	add_child(wall)
	walls.append(wall)

func create_flora(target_count: int) -> void:
	var attempts := 0
	while plants.size() < target_count and attempts < 420:
		attempts += 1
		var position_value := Vector2(RNG.generator.randf_range(110.0,WORLD_SIZE.x - 110.0),RNG.generator.randf_range(140.0,WORLD_SIZE.y - 100.0))
		position_value = Vector2(roundf(position_value.x / 16.0) * 16.0,roundf(position_value.y / 16.0) * 16.0)
		if position_value.distance_to(Vector2(280,1120)) < 190.0 or position_value.distance_to(Vector2(2160,330)) < 165.0:
			continue
		if not is_environment_position_open(position_value,30.0):
			continue
		var separated := true
		for existing_plant in plants:
			if existing_plant.global_position.distance_to(position_value) < 82.0:
				separated = false
				break
		if not separated:
			continue
		var plant = PlantObstacleScript.new()
		plant.position = position_value
		plant.setup(RNG.generator.randi_range(0,3),2.0)
		add_child(plant)
		plants.append(plant)

func create_player() -> void:
	player = PlayerScript.new()
	player.position = find_safe_player_start(Vector2(280,1120))
	add_child(player)
	player.attacked.connect(on_player_attack)
	player.spell_cast.connect(on_player_spell)
	player.weapon_fired.connect(on_player_weapon_fired)
	player.weapon_changed.connect(on_weapon_changed)
	player.weapon_time_changed.connect(func(_seconds_left: float): update_weapon_hud())
	player.damaged.connect(on_player_damaged)
	player.hp_changed.connect(func(_hp,_maximum): update_hp())
	player.mana_changed.connect(update_mana)
	player.died.connect(func():
		GameState.run_stats = build_run_summary()
		player_defeated.emit()
	)

func find_safe_player_start(preferred: Vector2) -> Vector2:
	return find_safe_landmark(preferred,18.0)

func create_enemies() -> void:
	spawn_wave(14,0,"mixed")

func spawn_wave(count: int, difficulty_rank: int, pattern: String) -> void:
	var sheets := ["Orc-Grunt.png","Orc-Peon-Red.png","Orc-Peon-Cyan.png","Orc-Soldier-Red.png"]
	for i in range(count):
		var spawn_position := find_pressure_spawn_position() if i < PRESSURE_ENEMIES_PER_WAVE else find_safe_spawn_position(390.0)
		if spawn_position == Vector2.ZERO:
			break
		var enemy = EnemyScript.new()
		enemy.position = spawn_position
		var role := enemy_role_for(pattern,i)
		enemy.setup(player,ASSET_ROOT + sheets[(i + difficulty_rank) % sheets.size()],difficulty_rank,role)
		add_child(enemy)
		enemy.died.connect(on_enemy_died)
		enemy.attack_hit.connect(func(damage: int): player.take_damage(damage))
		enemy.ranged_attack.connect(on_enemy_ranged_attack)
		enemy.hit_received.connect(on_enemy_hit)
		enemies.append(enemy)

func enemy_role_for(pattern: String, index: int) -> String:
	match pattern:
		"swarm": return "ranger" if index % 6 == 4 else ("runner" if index % 4 != 0 else "normal")
		"brute": return "ranger" if index % 5 == 3 else ("brute" if index % 3 != 0 else "normal")
		_: return "ranger" if index % 6 == 3 else ("runner" if index % 5 == 1 else ("brute" if index % 7 == 2 else "normal"))

func find_safe_spawn_position(minimum_player_distance: float) -> Vector2:
	for _attempt in range(120):
		var candidate := Vector2(RNG.generator.randf_range(90.0,WORLD_SIZE.x - 90.0),RNG.generator.randf_range(120.0,WORLD_SIZE.y - 90.0))
		if candidate.distance_to(player.global_position) < minimum_player_distance or not is_spawn_position_open(candidate):
			continue
		var separated := true
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(candidate) < 62.0:
				separated = false
				break
		if separated:
			return candidate
	return Vector2.ZERO

func find_pressure_spawn_position() -> Vector2:
	# 少量先锋进入初始警戒范围，防止挂机推进；其余敌人仍保持分散巡逻。
	for _attempt in range(80):
		var angle := RNG.generator.randf_range(0.0,TAU)
		var candidate := player.global_position + Vector2.from_angle(angle) * RNG.generator.randf_range(225.0,295.0)
		if not is_environment_position_open(candidate,28.0):
			continue
		if not is_route_clear(player.global_position,candidate,24.0):
			continue
		var separated := true
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(candidate) < 62.0:
				separated = false
				break
		if separated:
			return candidate
	return find_safe_spawn_position(320.0)

func is_route_clear(start: Vector2, finish: Vector2, clearance: float) -> bool:
	for step in range(1,7):
		if not is_environment_position_open(start.lerp(finish,float(step) / 6.0),clearance):
			return false
	return true

func is_spawn_position_open(candidate: Vector2) -> bool:
	return is_environment_position_open(candidate,24.0)

func is_environment_position_open(candidate: Vector2, clearance: float) -> bool:
	if candidate.x < 55.0 + clearance or candidate.x > WORLD_SIZE.x - 55.0 - clearance or candidate.y < 90.0 + clearance or candidate.y > WORLD_SIZE.y - 65.0 - clearance:
		return false
	for collision in river_segments:
		var rectangle := collision.shape as RectangleShape2D
		var local_point: Vector2 = collision.to_local(candidate)
		var expanded_size := rectangle.size + Vector2.ONE * clearance * 2.0
		if Rect2(-expanded_size * 0.5,expanded_size).has_point(local_point):
			return false
	for wall in walls:
		if Rect2(wall.global_position - wall.collision_size * 0.5,wall.collision_size).grow(clearance).has_point(candidate):
			return false
	return true

func create_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var top_bg := ColorRect.new()
	top_bg.color = Color(0.04,0.07,0.05,0.92)
	top_bg.size = Vector2(1280,88)
	hud_layer.add_child(top_bg)
	hud_hp = Label.new()
	hud_hp.position = Vector2(24,15)
	hud_hp.add_theme_font_size_override("font_size",24)
	PixelStyle.outline(hud_hp)
	hud_layer.add_child(hud_hp)
	hud_mana = Label.new()
	hud_mana.position = Vector2(300,15)
	hud_mana.add_theme_font_size_override("font_size",22)
	hud_mana.add_theme_color_override("font_color",Color("73d9ff"))
	PixelStyle.outline(hud_mana)
	hud_layer.add_child(hud_mana)
	hp_bar = make_status_bar(Vector2(24,54),Vector2(250,12),Color("63d878"))
	mana_bar = make_status_bar(Vector2(300,54),Vector2(210,12),Color("54bfff"))
	hud_layer.add_child(hp_bar)
	hud_layer.add_child(mana_bar)
	wave_label = Label.new()
	wave_label.position = Vector2(650,14)
	wave_label.size = Vector2(600,54)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.add_theme_font_size_override("font_size",21)
	wave_label.add_theme_color_override("font_color",Color("9ee879"))
	PixelStyle.outline(wave_label)
	hud_layer.add_child(wave_label)
	prompt = Label.new()
	prompt.text = "J 攻击 · Q 元气弹 · K 翻滚 · 1基础 / 2远程法杖 / 3弓"
	prompt.position = Vector2(260,102)
	prompt.size = Vector2(760,42)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size",20)
	PixelStyle.outline(prompt,4)
	hud_layer.add_child(prompt)
	get_tree().create_timer(7.0).timeout.connect(func():
		if is_instance_valid(prompt):
			prompt.visible = false
	)
	toast = Label.new()
	toast.position = Vector2(340,150)
	toast.size = Vector2(600,90)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size",25)
	toast.add_theme_color_override("font_color",Color("bdf7ff"))
	PixelStyle.outline(toast,5)
	hud_layer.add_child(toast)
	hud_cards = Label.new()
	hud_cards.position = Vector2(1015,620)
	hud_cards.size = Vector2(245,82)
	hud_cards.add_theme_font_size_override("font_size",16)
	hud_cards.add_theme_stylebox_override("normal",PixelStyle.box(Color(0.03,0.08,0.05,0.92),Color("709b57"),3))
	hud_layer.add_child(hud_cards)
	hud_weapon = Label.new()
	hud_weapon.position = Vector2(20,620)
	hud_weapon.size = Vector2(360,82)
	hud_weapon.add_theme_font_size_override("font_size",16)
	hud_weapon.add_theme_stylebox_override("normal",PixelStyle.box(Color(0.03,0.07,0.08,0.92),Color("6bacc5"),3))
	hud_layer.add_child(hud_weapon)
	portal_hint = Label.new()
	portal_hint.position = Vector2(365,610)
	portal_hint.size = Vector2(550,45)
	portal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portal_hint.add_theme_font_size_override("font_size",22)
	portal_hint.add_theme_color_override("font_color",Color("ffe477"))
	PixelStyle.outline(portal_hint)
	hud_layer.add_child(portal_hint)
	combo_label = Label.new()
	combo_label.position = Vector2(500,190)
	combo_label.size = Vector2(280,54)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size",27)
	combo_label.add_theme_color_override("font_color",Color("79eaff"))
	PixelStyle.outline(combo_label,5)
	hud_layer.add_child(combo_label)
	update_hp()
	update_mana(player.mana,player.MAX_MANA)
	update_weapon_hud()

func make_status_bar(position_value: Vector2, size_value: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = position_value
	bar.size = size_value
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = 100
	bar.add_theme_stylebox_override("background",PixelStyle.box(Color("172217"),Color("0d130e"),2))
	bar.add_theme_stylebox_override("fill",PixelStyle.box(fill_color,fill_color,1))
	return bar

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	elapsed_time += delta
	if combo_left > 0.0:
		combo_left = maxf(0.0,combo_left - delta)
		if combo_left <= 0.0:
			combo_count = 0
	update_combo_hud()
	update_infinite_waves(delta)
	refresh_portal_unlock()
	var near_portal := player.global_position.distance_to(portal_position) < 105.0
	if near_portal:
		portal_hint.text = "E / Enter：携带当前卡库挑战炎魔" if portal_unlocked else "祭坛封印中：清理前两波并获取冰系控制牌"
	elif portal_unlocked:
		var portal_distance := roundi(player.global_position.distance_to(portal_position) / 10.0)
		portal_hint.text = "祭坛 %s  %dm" % [direction_arrow(player.global_position.direction_to(portal_position)),portal_distance]
	else:
		portal_hint.text = ""
	if portal_unlocked and near_portal and Input.is_action_just_pressed("interact"):
		GameState.run_stats = build_run_summary()
		boss_door_entered.emit()

func update_infinite_waves(delta: float) -> void:
	wave_time_left = maxf(0.0,wave_time_left - delta)
	if wave_time_left <= 0.0 and enemies.size() <= WAVE_CLEAR_REMAINDER:
		var available_slots := MAX_ACTIVE_ENEMIES - enemies.size()
		if available_slots >= 4:
			wave += 1
			var spawn_count := mini(available_slots,mini(9 + wave,15))
			spawn_wave(spawn_count,wave - 1,wave_pattern())
			wave_time_left = maxf(8.0,16.0 - wave * 0.35)
			toast.text = "清场完成 · 第 %d 波 %s！新增 %d 只兽人" % [wave,wave_pattern_name(),spawn_count]
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(toast) and toast.text.begins_with("清场完成"):
					toast.text = ""
			)
			if wave % 2 == 0:
				show_upgrade_choice()
	if wave_label:
		var objective := "祭坛已解锁" if portal_unlocked else ("需要冰系控制牌" if wave >= 3 else "清至%d只推进" % WAVE_CLEAR_REMAINDER)
		wave_label.text = "第 %d 波 · %s  ·  剩余 %d  ·  %s" % [wave,wave_pattern_name(),enemies.size(),objective]

func refresh_portal_unlock() -> void:
	if portal_unlocked or wave < 3 or not has_boss_counter_card():
		return
	portal_unlocked = true
	toast.text = "祭坛已解锁！可立即挑战，或继续清场强化卡库"
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(toast) and toast.text.begins_with("祭坛已解锁"):
			toast.text = ""
	)
	queue_redraw()

func has_boss_counter_card() -> bool:
	for card_id in GameState.ammo_library:
		if bool(CombatEngine.card(card_id).get("control",false)):
			return true
	return false

func direction_arrow(direction: Vector2) -> String:
	var sector := int(round(wrapf(direction.angle(),0.0,TAU) / (PI / 4.0))) % 8
	return ["→","↘","↓","↙","←","↖","↑","↗"][sector]

func wave_pattern() -> String:
	match wave % 3:
		0: return "brute"
		1: return "mixed"
		_: return "swarm"

func wave_pattern_name() -> String:
	match wave_pattern():
		"swarm": return "疾袭潮"
		"brute": return "重装潮"
		_: return "混合潮"

func show_upgrade_choice() -> void:
	if "--smoke-test" in OS.get_cmdline_user_args():
		apply_upgrade("staff")
		return
	if is_instance_valid(upgrade_overlay):
		return
	set_upgrade_pause(true)
	upgrade_overlay = ColorRect.new()
	upgrade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_overlay.color = Color(0.02,0.04,0.06,0.88)
	upgrade_overlay.size = Vector2(1280,720)
	hud_layer.add_child(upgrade_overlay)
	var box := VBoxContainer.new()
	box.position = Vector2(330,105)
	box.size = Vector2(620,510)
	box.add_theme_constant_override("separation",14)
	upgrade_overlay.add_child(box)
	var title := Label.new()
	title.text = "清场奖励 · 选择一项战术成长"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",34)
	title.add_theme_color_override("font_color",Color("8defff"))
	PixelStyle.outline(title,5)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "世界已暂停 · 选择一个流派，塑造本局战斗节奏"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size",19)
	subtitle.add_theme_color_override("font_color",Color("d7e8d0"))
	box.add_child(subtitle)
	for option in [
		["staff","近战节奏","冰刃专注","基础伤害保持固定 · 连击窗口 +0.4 秒",Color("70dbea")],
		["arcane","远程施法","奥术回路","元气弹伤害保持固定 · 消耗 -4 · 法力回复 +2/s",Color("a98cff")],
		["vitality","持续作战","猎魔体魄","最大生命 +12 并治疗 · 每次击杀回复 1 生命",Color("78d78a")]
	]:
		var button := Button.new()
		button.text = "【%s】  %s\n%s" % [option[1],option[2],option[3]]
		button.custom_minimum_size = Vector2(600,92)
		button.add_theme_font_size_override("font_size",21)
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		PixelStyle.style_button(button,option[4])
		button.pressed.connect(apply_upgrade.bind(option[0]))
		box.add_child(button)

func apply_upgrade(upgrade_id: String) -> void:
	var chosen_name := ""
	match upgrade_id:
		"staff":
			combo_window_bonus += 0.4
			chosen_name = "冰刃专注"
		"arcane":
			player.spell_cost = maxf(18.0,player.spell_cost - 4.0)
			player.mana_regen += 2.0
			chosen_name = "奥术回路"
		"vitality":
			GameState.player_max_hp += 12
			GameState.player_hp += 12
			kill_heal += 1
			player.hp_changed.emit(GameState.player_hp,GameState.player_max_hp)
			chosen_name = "猎魔体魄"
	upgrade_history.append(chosen_name)
	if is_instance_valid(upgrade_overlay):
		upgrade_overlay.queue_free()
	upgrade_overlay = null
	set_upgrade_pause(false)
	if is_instance_valid(toast):
		toast.text = "获得成长：%s" % chosen_name
		get_tree().create_timer(1.3).timeout.connect(func():
			if is_instance_valid(toast) and toast.text.begins_with("获得成长"):
				toast.text = ""
		)

func set_upgrade_pause(active: bool) -> void:
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_DISABLED if active else Node.PROCESS_MODE_INHERIT
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_DISABLED if active else Node.PROCESS_MODE_INHERIT
	get_tree().paused = active

func on_player_attack(origin: Vector2, direction: Vector2, reach: float) -> void:
	var hit_any := false
	var damage := 10
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		var offset: Vector2 = enemy.global_position - origin
		var distance := offset.length()
		# 宽扇形判定匹配法杖挥动；不再使用横版 sign 判定。
		if distance <= reach and distance > 0.01 and offset.normalized().dot(direction) >= 0.42:
			enemy.take_damage(damage,origin)
			hit_any = true
	if hit_any:
		combo_count += 1
		highest_combo = maxi(highest_combo,combo_count)
		combo_left = 2.2 + combo_window_bonus
		player.confirm_hit()
		if combo_count >= 5:
			trigger_arcane_surge(origin)

func trigger_arcane_surge(origin: Vector2) -> void:
	combo_count = 0
	combo_left = 0.0
	player.restore_mana(20.0)
	for i in range(8):
		var burst := PixelMagicBurst.new()
		burst.global_position = origin + Vector2.from_angle(TAU * i / 8.0) * 18.0 - Vector2(0,12)
		burst.setup(Vector2.from_angle(TAU * i / 8.0))
		add_child(burst)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.global_position.distance_to(origin) <= 175.0:
			enemy.take_damage(8,origin)
	toast.text = "奥术涌动！范围伤害 · 回复 20 法力"
	get_tree().create_timer(1.25).timeout.connect(func():
		if is_instance_valid(toast) and toast.text.begins_with("奥术涌动"):
			toast.text = ""
	)

func on_player_spell(origin: Vector2, direction: Vector2) -> void:
	var orb := ArcaneOrbScript.new()
	orb.global_position = origin + direction * 34.0
	orb.setup(direction,origin,ArcaneOrbScript.DAMAGE)
	orb.enemy_hit.connect(func(_enemy: Node2D,_damage: int,_position: Vector2): player.confirm_hit())
	add_child(orb)

func on_player_weapon_fired(origin: Vector2, direction: Vector2, weapon_id: String) -> void:
	var projectile = PlayerWeaponProjectileScript.new()
	projectile.global_position = origin + direction * 34.0
	var damage := 9 if weapon_id == "bow" else 13
	projectile.setup(direction,weapon_id,damage)
	projectile.enemy_hit.connect(on_weapon_projectile_hit)
	add_child(projectile)

func on_weapon_projectile_hit(primary_enemy: Node2D, _damage: int, world_pos: Vector2, weapon_id: String) -> void:
	player.confirm_hit()
	combo_count += 1
	highest_combo = maxi(highest_combo,combo_count)
	combo_left = 2.2 + combo_window_bonus
	if weapon_id == "arcane_staff":
		for enemy in enemies.duplicate():
			if is_instance_valid(enemy) and enemy != primary_enemy and enemy.global_position.distance_to(world_pos) <= 68.0:
				enemy.take_damage(5,world_pos)
		show_magic_burst(world_pos)
	if combo_count >= 5:
		trigger_arcane_surge(player.global_position)

func show_magic_burst(world_pos: Vector2) -> void:
	for index in range(4):
		var burst := PixelMagicBurst.new()
		burst.global_position = world_pos + Vector2.from_angle(TAU * index / 4.0) * 12.0
		burst.setup(Vector2.from_angle(TAU * index / 4.0))
		add_child(burst)

func on_enemy_ranged_attack(origin: Vector2, direction: Vector2, damage: int) -> void:
	var projectile = EnemyProjectileScript.new()
	projectile.global_position = origin + direction * 28.0
	projectile.setup(direction,damage)
	add_child(projectile)

func on_weapon_changed(_weapon_id: String) -> void:
	update_weapon_hud()
	if is_instance_valid(toast):
		toast.text = "已切换：%s" % player.weapon_name()
		get_tree().create_timer(0.9).timeout.connect(func():
			if is_instance_valid(toast) and toast.text.begins_with("已切换"):
				toast.text = ""
		)

func on_enemy_hit(_enemy: Node2D, amount: int, world_pos: Vector2) -> void:
	play_hit_sound(world_pos)
	show_damage_feedback(world_pos,amount,Color("d6fff0"))

func on_player_damaged(amount: int, world_pos: Vector2) -> void:
	damage_taken += amount
	play_hit_sound(world_pos,true)
	show_damage_feedback(world_pos - Vector2(0,18),amount,Color("ff7168"))
	toast.text = "受到攻击！红圈结束前翻滚可免伤"
	get_tree().create_timer(0.9).timeout.connect(func():
		if is_instance_valid(toast) and toast.text.begins_with("受到攻击"):
			toast.text = ""
	)

func on_enemy_died(enemy: Node2D, rare: bool) -> void:
	enemies.erase(enemy)
	total_kills += 1
	player.restore_mana(8.0)
	if kill_heal > 0:
		player.heal(kill_heal)
	if rare:
		player.heal(4)
	card_drop_attempts += 1
	if RNG.chance(CARD_DROP_CHANCE):
		card_drops += 1
		var card_id := "frost_nova" if rare else "freeze"
		show_card_pickup(enemy.global_position,card_id)
	# 限时武器保持稀有但稳定可见，避免高怪量下连续铺满地面。
	if enemy.role == "ranger" and RNG.chance(0.28):
		spawn_equipment_drop(enemy.global_position,"bow")
	elif enemy.role == "brute" and RNG.chance(0.24):
		spawn_equipment_drop(enemy.global_position,"arcane_staff")
	elif RNG.chance(0.07):
		spawn_equipment_drop(enemy.global_position,"arcane_staff" if RNG.chance(0.55) else "bow")

func spawn_equipment_drop(world_pos: Vector2, weapon_id: String) -> void:
	var drop = EquipmentDropScript.new()
	drop.global_position = world_pos
	drop.setup(weapon_id)
	drop.picked.connect(on_equipment_picked)
	add_child(drop)
	equipment_drops += 1

func on_equipment_picked(weapon_id: String) -> void:
	player.activate_temporary_weapon(weapon_id,10.0)
	var message := "获得限时武器：%s · 持续 10 秒" % player.weapon_name()
	equipment_history.append(message)
	update_weapon_hud()
	toast.text = message
	get_tree().create_timer(1.8).timeout.connect(func():
		if is_instance_valid(toast) and toast.text == message:
			toast.text = ""
	)

func show_damage_feedback(world_pos: Vector2, amount: int, color: Color) -> void:
	var number := Label.new()
	number.z_index = 3000
	number.text = "-%d" % amount
	number.position = world_pos - Vector2(30,65)
	number.size = Vector2(60,36)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size",25)
	number.add_theme_color_override("font_color",color)
	PixelStyle.outline(number,5)
	add_child(number)
	var number_tween := create_tween().set_parallel(true)
	number_tween.tween_property(number,"position",number.position - Vector2(0,38),0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	number_tween.tween_property(number,"modulate:a",0.0,0.5).set_delay(0.16)
	number_tween.chain().tween_callback(number.queue_free)
	for i in range(7):
		var pixel := Polygon2D.new()
		var size := RNG.generator.randi_range(4,7)
		pixel.polygon = PackedVector2Array([Vector2(-size,-size),Vector2(size,-size),Vector2(size,size),Vector2(-size,size)])
		pixel.color = color if i % 2 == 0 else Color.WHITE
		pixel.position = world_pos
		pixel.z_index = 2900
		add_child(pixel)
		var direction := Vector2(RNG.generator.randf_range(-1.0,1.0),RNG.generator.randf_range(-1.0,0.2)).normalized()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(pixel,"position",world_pos + direction * RNG.generator.randf_range(24.0,55.0),0.28)
		tween.tween_property(pixel,"modulate:a",0.0,0.28).set_delay(0.08)
		tween.chain().tween_callback(pixel.queue_free)

func show_card_pickup(world_pos: Vector2, card_id: String) -> void:
	var card := Label.new()
	card.z_index = 3100
	card.text = "❄ %s" % CombatEngine.card_name(card_id)
	card.position = world_pos - Vector2(70,75)
	card.size = Vector2(140,55)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_font_size_override("font_size",18)
	card.add_theme_color_override("font_color",Color("d6fff0"))
	PixelStyle.outline(card,4)
	add_child(card)
	toast.text = "获得卡牌：%s" % CombatEngine.card_name(card_id)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card,"global_position",player.global_position + Vector2(100,-125),0.7).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card,"scale",Vector2(0.5,0.5),0.7)
	tween.chain().tween_callback(func():
		GameState.add_card(card_id)
		card.queue_free()
		get_tree().create_timer(1.2).timeout.connect(func(): toast.text = "")
	)

func update_hp() -> void:
	if hud_hp:
		hud_hp.text = "青袍法师  HP %d/%d" % [GameState.player_hp,GameState.player_max_hp]
	if hp_bar:
		hp_bar.max_value = GameState.player_max_hp
		hp_bar.value = GameState.player_hp

func update_mana(current: float, maximum: float) -> void:
	if hud_mana:
		hud_mana.text = "法力 %d/%d" % [int(current),int(maximum)]
	if mana_bar:
		mana_bar.max_value = maximum
		mana_bar.value = current

func update_card_hud(_card_id: String, _total: int) -> void:
	if not hud_cards:
		return
	var entries := PackedStringArray()
	for card_id in GameState.ammo_library:
		entries.append("%s×%d" % [CombatEngine.card_name(card_id),int(GameState.ammo_library[card_id])])
	if GameState.ammo_library.is_empty():
		hud_cards.text = "卡库：击败兽人获得冰牌"
	else:
		hud_cards.text = "卡库  ❄  %s" % " / ".join(entries)

func update_weapon_hud() -> void:
	if not hud_weapon or not is_instance_valid(player):
		return
	if player.current_weapon == "bow":
		hud_weapon.text = "[3] 疾风弓 · 固定伤害 9 · 剩余 %.1fs\n+射速快 / 不耗法力  − 单体伤害" % player.temporary_weapon_left
	elif player.current_weapon == "arcane_staff":
		hud_weapon.text = "[2] 潮汐法杖 · 固定伤害 13 · 剩余 %.1fs\n+命中溅射 5  − 射速慢、每发耗 5 法力" % player.temporary_weapon_left
	else:
		var reserve := " · %s剩余 %.1fs" % [player.weapon_name_for(player.temporary_weapon_id),player.temporary_weapon_left] if not player.temporary_weapon_id.is_empty() else ""
		hud_weapon.text = "[1] 基础法杖 · 固定伤害 10%s\n+原版扇形挥击  − 必须近身" % reserve

func update_combo_hud() -> void:
	if not combo_label:
		return
	if combo_count <= 0:
		combo_label.text = ""
	else:
		combo_label.text = "奥术连击 %d/5  ·  满层触发涌动" % combo_count

func _draw() -> void:
	# 东北祭坛：使用同一低色阶像素语言制作，不混入旧高清素材。
	draw_circle(portal_position,92,Color(0.16,0.12,0.08,0.72))
	draw_arc(portal_position,78,0,TAU,32,Color("d8b65c") if portal_unlocked else Color("665f52"),8.0)
	draw_arc(portal_position,52,0,TAU,24,Color("72e1ff") if portal_unlocked else Color("536269"),5.0)
	for i in range(8):
		var angle := TAU * i / 8.0
		draw_rect(Rect2(portal_position + Vector2.from_angle(angle) * 78 - Vector2(6,6),Vector2(12,12)),Color("efe08a") if portal_unlocked else Color("77746b"))

func build_run_summary() -> Dictionary:
	return {
		"wave":wave,
		"kills":total_kills,
		"time":elapsed_time,
		"damage_taken":damage_taken,
		"highest_combo":highest_combo,
		"upgrades":upgrade_history.duplicate(),
		"cards":GameState.ammo_library.duplicate(),
		"equipment":equipment_history.duplicate()
	}

func debug_text() -> String:
	return "\n地图 Seed: %d · 河流段: %d · 桥: %d · 纯装饰花草: %d\n波次导演: 第 %d 波 / %s\n怪物: %d/%d · 击杀: %d · 掉卡: %d/%d（40%%）\n武器: %s · 装备掉落: %d\n祭坛: %s · 成长: %s\n峰值连击: %d" % [map_seed,river_segments.size(),bridges.size(),plants.size(),wave,wave_pattern_name(),enemies.size(),MAX_ACTIVE_ENEMIES,total_kills,card_drops,card_drop_attempts,player.weapon_name(),equipment_drops,"已解锁" if portal_unlocked else "封印",str(upgrade_history),highest_combo]

func map_signature() -> String:
	var wall_data := PackedStringArray()
	for wall in walls:
		wall_data.append("%d,%d,%d,%d" % [roundi(wall.position.x),roundi(wall.position.y),roundi(wall.wall_size.x),roundi(wall.wall_size.y)])
	var plant_data := PackedStringArray()
	for plant in plants:
		plant_data.append("%d,%d,%d" % [roundi(plant.position.x),roundi(plant.position.y),plant.plant_variant])
	return "%d|%s|%s|%s" % [map_seed,str(river_points),";".join(wall_data),";".join(plant_data)]
