extends Node

const FarmLevelScript = preload("res://scenes/farming/FarmLevel.gd")
const BossBattleScript = preload("res://scenes/boss/BossBattle.gd")

var current_screen: Node
var music_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_input()
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -14.0
	add_child(music_player)
	music_player.finished.connect(func():
		if is_instance_valid(music_player) and music_player.stream:
			music_player.play()
	)
	show_menu()
	if "--smoke-test" in OS.get_cmdline_user_args():
		run_smoke_test.call_deferred()
	elif "--feedback-preview" in OS.get_cmdline_user_args():
		run_feedback_preview.call_deferred()

func run_feedback_preview() -> void:
	start_run()
	await get_tree().process_frame
	var farm = current_screen
	farm.player.position = Vector2(470,520)
	farm.player.invincible_left = 999.0
	for i in range(farm.enemies.size()):
		var enemy = farm.enemies[i]
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		if i == 0:
			enemy.position = Vector2(550,480)
	while is_instance_valid(farm) and is_instance_valid(farm.player):
		var target = farm.enemies[0] if not farm.enemies.is_empty() else null
		farm.player.play_attack_fx()
		if is_instance_valid(target):
			target.hit_flash_left = 0.22
			farm.show_damage_feedback(target.global_position,10,Color("bdf7ff"))
		await get_tree().create_timer(0.62).timeout
		farm.player.hit_flash_left = 0.22
		farm.show_damage_feedback(farm.player.global_position - Vector2(0,24),8,Color("ff6b62"))
		farm.player.shake_camera(5.0)
		await get_tree().create_timer(0.62).timeout

func run_smoke_test() -> void:
	print("[SMOKE] start")
	start_run()
	await get_tree().process_frame
	assert(GameState.phase == "farm")
	assert(music_player.stream is AudioStreamOggVorbis and music_player.stream.loop)
	assert(current_screen.enemies.size() == 14)
	assert(current_screen.walls.size() >= 8)
	assert(current_screen.plants.size() >= 16)
	assert(current_screen.walls[0].collision_size == current_screen.walls[0].wall_size)
	# 从每堵墙的下方向上跨越整个可见区域，必须被实体碰撞阻挡。
	for test_wall in current_screen.walls:
		var bottom_start: Vector2 = test_wall.global_position + Vector2(0,test_wall.wall_size.y * 0.5 + 42.0)
		var cross_up: Vector2 = Vector2(0,-test_wall.wall_size.y - 84.0)
		assert(current_screen.player.test_move(Transform2D(0.0,bottom_start),cross_up))
	assert(not (current_screen.plants[0] is CollisionObject2D))
	assert(current_screen.is_environment_position_open(current_screen.plants[0].global_position,5.0))
	assert(current_screen.enemies.any(func(enemy): return enemy.role == "ranger"))
	assert(current_screen.river_segments.size() > 8)
	assert(current_screen.bridges.size() == 3)
	var bridge_index: int = current_screen.bridges[0]
	var bridge_midpoint: Vector2 = (current_screen.river_points[bridge_index] + current_screen.river_points[bridge_index + 1]) * 0.5
	assert(not current_screen.debug_has_river_collision_at(bridge_midpoint))
	var blocked_index := 0
	while blocked_index in current_screen.bridges:
		blocked_index += 1
	var blocked_midpoint: Vector2 = (current_screen.river_points[blocked_index] + current_screen.river_points[blocked_index + 1]) * 0.5
	assert(current_screen.debug_has_river_collision_at(blocked_midpoint))
	assert(current_screen.player.body_shape.radius == 11.0)
	assert(current_screen.is_environment_position_open(current_screen.player.global_position,11.0))
	assert(current_screen.is_environment_position_open(current_screen.portal_position,70.0))
	current_screen.set_upgrade_pause(true)
	assert(get_tree().paused)
	assert(current_screen.player.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(current_screen.enemies[0].process_mode == Node.PROCESS_MODE_DISABLED)
	current_screen.set_upgrade_pause(false)
	assert(not get_tree().paused)
	var first_map_signature: String = current_screen.map_signature()
	print("[SMOKE] procedural map, solid walls, flora and hard upgrade pause PASS")
	assert(current_screen.hit_audio_pool.size() == 4)
	var idle_enemy = current_screen.enemies[9]
	var idle_position: Vector2 = idle_enemy.position
	await get_tree().create_timer(0.45).timeout
	assert(not idle_enemy.aggro)
	assert(idle_enemy.position.distance_to(idle_position) > 3.0)
	print("[SMOKE] distant enemy patrols without aggro")
	var patrol_home := Vector2.ZERO
	for test_y in range(240,1201,120):
		for test_x in range(240,2161,120):
			var candidate := Vector2(test_x,test_y)
			if candidate.distance_to(current_screen.player.position) > 600.0 and current_screen.is_environment_position_open(candidate,30.0) and current_screen.is_environment_position_open(candidate + Vector2(120,0),30.0):
				patrol_home = candidate
				break
		if patrol_home != Vector2.ZERO:
			break
	assert(patrol_home != Vector2.ZERO)
	idle_enemy.home_position = patrol_home
	idle_enemy.position = patrol_home + Vector2(120,0)
	idle_enemy.patrol_direction = Vector2.RIGHT
	idle_enemy.patrol_timer = 1.0
	var return_start_x: float = idle_enemy.position.x
	await get_tree().create_timer(0.35).timeout
	assert(idle_enemy.position.x < return_start_x - 5.0)
	assert(idle_enemy.patrol_direction.x < 0.0)
	print("[SMOKE] patrol boundary return stays stable")
	var front_enemy = current_screen.enemies[0]
	var back_enemy = current_screen.enemies[1]
	assert(not current_screen.player.has_weapon("bow"))
	assert(current_screen.player.current_weapon == "basic")
	current_screen.on_equipment_picked("bow")
	assert(current_screen.player.has_weapon("bow"))
	assert(current_screen.player.current_weapon == "bow")
	assert(current_screen.player.temporary_weapon_left > 9.9)
	current_screen.on_equipment_picked("arcane_staff")
	assert(current_screen.player.has_weapon("arcane_staff"))
	assert(current_screen.player.current_weapon == "arcane_staff")
	assert(not current_screen.player.has_weapon("bow"))
	current_screen.on_equipment_picked("bow")
	for test_enemy in current_screen.enemies:
		if test_enemy != front_enemy:
			test_enemy.process_mode = Node.PROCESS_MODE_DISABLED
			test_enemy.position = current_screen.player.position + Vector2(500 + current_screen.enemies.find(test_enemy) * 45,320)
	front_enemy.process_mode = Node.PROCESS_MODE_INHERIT
	front_enemy.stun_left = 1.0
	front_enemy.position = current_screen.player.position + Vector2(135,0)
	var bow_target_hp: int = front_enemy.hp
	current_screen.player.facing = Vector2.RIGHT
	current_screen.player.start_attack()
	await get_tree().create_timer(0.52).timeout
	print("[SMOKE] bow target hp ",bow_target_hp," -> ",front_enemy.hp)
	assert(front_enemy.hp == bow_target_hp - 9)
	current_screen.player.temporary_weapon_left = 0.01
	await get_tree().create_timer(0.08).timeout
	assert(current_screen.player.current_weapon == "basic")
	assert(not current_screen.player.has_weapon("bow"))
	print("[SMOKE] ten-second temporary weapons and bow projectile PASS")
	var hp_before_arrow: int = GameState.player_hp
	current_screen.player.invincible_left = 0.0
	current_screen.on_enemy_ranged_attack(current_screen.player.global_position - Vector2(120,0),Vector2.RIGHT,6)
	await get_tree().create_timer(0.38).timeout
	assert(GameState.player_hp == hp_before_arrow - 6)
	GameState.player_hp = GameState.player_max_hp
	current_screen.player.invincible_left = 0.0
	print("[SMOKE] ranged enemy projectile PASS")
	front_enemy.position = current_screen.player.position + Vector2(60,0)
	back_enemy.position = current_screen.player.position - Vector2(60,0)
	var back_hp: int = back_enemy.hp
	front_enemy.hp = front_enemy.max_hp
	current_screen.combo_count = 0
	current_screen.on_player_attack(current_screen.player.global_position,Vector2.RIGHT,72.0)
	assert(front_enemy.hp == front_enemy.max_hp - 10)
	assert(back_enemy.hp == back_hp)
	print("[SMOKE] directional hit sector PASS")
	current_screen.combo_count = 4
	current_screen.player.mana = 40.0
	front_enemy.hp = front_enemy.max_hp
	back_enemy.position = current_screen.player.position - Vector2(400,0)
	current_screen.on_player_attack(current_screen.player.global_position,Vector2.RIGHT,72.0)
	assert(front_enemy.hp == front_enemy.max_hp - 18)
	assert(current_screen.combo_count == 0)
	assert(current_screen.player.mana == 60.0)
	print("[SMOKE] five-hit arcane surge PASS")
	front_enemy.position = current_screen.player.position + Vector2(500,300)
	back_enemy.position = current_screen.player.position + Vector2(560,300)
	var spell_enemy = current_screen.enemies[2]
	spell_enemy.position = current_screen.player.position + Vector2(130,0)
	spell_enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var spell_hp: int = spell_enemy.hp
	var mana_before: float = current_screen.player.mana
	current_screen.player.facing = Vector2.RIGHT
	current_screen.player.start_spell()
	await get_tree().create_timer(0.55).timeout
	assert(spell_enemy.hp == spell_hp - 18)
	assert(current_screen.player.mana < mana_before - 20.0)
	print("[SMOKE] arcane orb collision PASS")
	current_screen.wave_time_left = 0.0
	current_screen.update_infinite_waves(0.1)
	assert(current_screen.wave == 1)
	print("[SMOKE] wave cannot advance while enemies remain")
	current_screen.wave_time_left = 999.0
	for enemy in current_screen.enemies.duplicate():
		if current_screen.enemies.size() <= current_screen.WAVE_CLEAR_REMAINDER:
			break
		if is_instance_valid(enemy):
			enemy.take_damage(999)
	await get_tree().create_timer(0.9).timeout
	var cleared_wave_count: int = current_screen.enemies.size()
	assert(cleared_wave_count <= current_screen.WAVE_CLEAR_REMAINDER)
	current_screen.wave_time_left = 0.0
	current_screen.update_infinite_waves(0.1)
	assert(current_screen.wave == 2)
	assert(current_screen.enemies.size() > cleared_wave_count)
	await get_tree().process_frame
	assert(current_screen.upgrade_history == ["冰刃专注"])
	assert(current_screen.combo_window_bonus == 0.4)
	print("[SMOKE] wave reinforcement and upgrade choice PASS")
	for enemy in current_screen.enemies.duplicate():
		if current_screen.enemies.size() <= current_screen.WAVE_CLEAR_REMAINDER:
			break
		if is_instance_valid(enemy):
			enemy.take_damage(999)
	await get_tree().create_timer(0.9).timeout
	current_screen.wave_time_left = 0.0
	current_screen.update_infinite_waves(0.1)
	current_screen.refresh_portal_unlock()
	assert(current_screen.wave == 3)
	assert(current_screen.portal_unlocked)
	assert(current_screen.has_boss_counter_card())
	print("[SMOKE] clear-gated third-wave portal objective PASS")
	for enemy in current_screen.enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.take_damage(999)
	await get_tree().create_timer(1.1).timeout
	assert(GameState.ammo_library.size() > 0)
	assert(current_screen.card_drop_attempts == current_screen.total_kills)
	assert(current_screen.card_drops < current_screen.card_drop_attempts)
	var measured_drop_rate: float = float(current_screen.card_drops) / float(current_screen.card_drop_attempts)
	assert(measured_drop_rate >= 0.20 and measured_drop_rate <= 0.60)
	print("[SMOKE] card drop rate target 40%%, measured %.2f PASS" % measured_drop_rate)
	current_screen.player.combo_step = 0
	current_screen.player.start_attack()
	assert(current_screen.player.combo_step == 1)
	current_screen.player.attack_left = 0.0
	current_screen.player.combo_window_left = 0.3
	current_screen.player.start_attack()
	assert(current_screen.player.combo_step == 2)
	current_screen.player.attack_left = 0.0
	current_screen.player.combo_window_left = 0.3
	current_screen.player.start_attack()
	assert(current_screen.player.combo_step == 3)
	print("[SMOKE] player three-hit input chain PASS")
	print("[SMOKE] farm -> cards: ", GameState.ammo_library)
	current_screen.player.activate_temporary_weapon("bow",0.24)
	show_boss()
	await get_tree().process_frame
	assert(GameState.phase == "boss")
	assert(current_screen.ARENA_RECT.size.x < 1100.0)
	assert(current_screen.ARENA_RECT.size.y < 520.0)
	assert(current_screen.arena_walls.size() == 4)
	for arena_wall in current_screen.arena_walls:
		assert(arena_wall.collision_size == arena_wall.wall_size)
	assert(current_screen.player.current_weapon == "bow")
	assert(current_screen.player.has_weapon("bow"))
	assert(not current_screen.player.has_weapon("arcane_staff"))
	await get_tree().create_timer(0.3).timeout
	assert(current_screen.player.current_weapon == "basic")
	assert(not current_screen.player.has_weapon("bow"))
	print("[SMOKE] compact arena, full-solid bounds and cross-scene weapon expiry PASS")
	for _hit in range(4):
		current_screen.boss.take_damage(10,current_screen.player.global_position)
	assert(current_screen.boss_loot_drops == 1)
	assert(current_screen.active_loot.size() == 1)
	GameState.player_hp = GameState.player_max_hp - 20
	current_screen.active_loot[0].on_body_entered(current_screen.player)
	assert(GameState.player_hp == GameState.player_max_hp - 4)
	await get_tree().process_frame
	current_screen.spawn_boss_loot(current_screen.boss.global_position)
	assert(current_screen.boss_loot_drops == 2)
	assert(current_screen.active_loot.size() == 1)
	current_screen.active_loot[0]._on_body_entered(current_screen.player)
	assert(current_screen.player.current_weapon == "bow")
	print("[SMOKE] boss damage loot, healing potion and temporary weapon PASS")
	current_screen.player.position = Vector2(510,390)
	current_screen.boss.position = Vector2(620,390)
	current_screen.player.invincible_left = 0.0
	var hp_before_charge: int = GameState.player_hp
	current_screen.debug_force_physical()
	await get_tree().create_timer(1.05).timeout
	assert(current_screen.physical_casts == 1)
	assert(GameState.player_hp < hp_before_charge)
	print("[SMOKE] telegraphed physical charge damages player PASS")
	current_screen.debug_force_magic()
	assert(current_screen.magic_casts == 1)
	assert(current_screen.active_projectiles.size() >= 5)
	current_screen.debug_force_meteor()
	assert(current_screen.meteor_casts == 1)
	assert(current_screen.active_meteors.size() >= 3)
	print("[SMOKE] animated fireball volley and telegraphed thunder zones PASS")
	var boss_hp_before: int = current_screen.boss.hp
	current_screen.player.position = current_screen.boss.position - Vector2(58,0)
	current_screen.on_player_attack(current_screen.player.global_position,Vector2.RIGHT,72.0)
	assert(current_screen.boss.hp == boss_hp_before - 10)
	var freeze_before: int = int(GameState.ammo_library.get("freeze",0))
	current_screen.boss.hp = floori(float(current_screen.boss.max_hp) * 2.0 / 3.0) + 5
	current_screen.boss.take_damage(10,current_screen.player.global_position)
	assert(get_tree().paused)
	assert(current_screen.pending_phase == 2)
	assert(current_screen.player.process_mode == Node.PROCESS_MODE_DISABLED)
	current_screen.debug_choose_phase_card("freeze")
	assert(not get_tree().paused)
	assert(current_screen.boss.phase_index == 2)
	assert(current_screen.phase_cards_cast == 1)
	assert(int(GameState.ammo_library.get("freeze",0)) == freeze_before - 1)
	print("[SMOKE] phase 1 -> 2 pauses and casts a farm card PASS")
	current_screen.player.invincible_left = 999.0
	var physical_before_phase_two: int = current_screen.physical_casts
	current_screen.debug_force_physical()
	await get_tree().create_timer(1.75).timeout
	assert(current_screen.physical_casts == physical_before_phase_two + 2)
	print("[SMOKE] boss phase-two double combo PASS")
	var nova_before: int = int(GameState.ammo_library.get("frost_nova",0))
	current_screen.boss.hp = floori(float(current_screen.boss.max_hp) / 3.0) + 5
	current_screen.boss.take_damage(10,current_screen.player.global_position)
	assert(get_tree().paused)
	assert(current_screen.pending_phase == 3)
	current_screen.debug_choose_phase_card("frost_nova")
	assert(not get_tree().paused)
	assert(current_screen.boss.phase_index == 3)
	assert(current_screen.phase_cards_cast == 2)
	assert(int(GameState.ammo_library.get("frost_nova",0)) == nova_before - 1)
	print("[SMOKE] phase 2 -> 3 pauses and casts a second card PASS")
	var physical_before_phase_three: int = current_screen.physical_casts
	current_screen.debug_force_physical()
	await get_tree().create_timer(2.25).timeout
	assert(current_screen.physical_casts == physical_before_phase_three + 3)
	print("[SMOKE] boss phase-three triple combo PASS")
	current_screen.boss.hp = 1
	current_screen.player.position = current_screen.boss.position - Vector2(58,0)
	current_screen.on_player_attack(current_screen.player.global_position,Vector2.RIGHT,72.0)
	await get_tree().create_timer(0.9).timeout
	assert(GameState.phase == "victory")
	assert("immortal_bulwark" in SaveManager.legendary_cards)
	var generated_signatures := {first_map_signature:true}
	for test_seed in range(20260821,20260827):
		RNG.set_seed(test_seed)
		GameState.reset_run()
		show_farm()
		await get_tree().process_frame
		var signature: String = current_screen.map_signature()
		assert(not generated_signatures.has(signature))
		generated_signatures[signature] = true
		assert(current_screen.walls.size() >= 8)
		assert(current_screen.bridges.size() == 3)
		assert(current_screen.is_environment_position_open(current_screen.player.global_position,11.0))
		assert(current_screen.is_environment_position_open(current_screen.portal_position,70.0))
	print("[SMOKE] seven seeds generate distinct safe maps")
	print("[SMOKE] PASS: 40% cards -> player combo -> three-phase boss/card transitions -> victory")
	clear_screen()
	music_player.stop()
	music_player.stream = null
	music_player.queue_free()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0)

func setup_input() -> void:
	add_key_action("move_left", [KEY_A, KEY_LEFT])
	add_key_action("move_right", [KEY_D, KEY_RIGHT])
	add_key_action("move_up", [KEY_W, KEY_UP])
	add_key_action("move_down", [KEY_S, KEY_DOWN])
	add_key_action("jump", [KEY_SPACE])
	add_key_action("attack", [KEY_J])
	var mouse_attack := InputEventMouseButton.new()
	mouse_attack.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse_attack)
	add_key_action("spell", [KEY_Q])
	var mouse_spell := InputEventMouseButton.new()
	mouse_spell.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("spell",mouse_spell)
	add_key_action("roll", [KEY_K, KEY_SHIFT])
	add_key_action("interact", [KEY_E, KEY_ENTER])
	add_key_action("weapon_basic", [KEY_1])
	add_key_action("weapon_staff", [KEY_2])
	add_key_action("weapon_bow", [KEY_3])

func add_key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)

func play_music(path: String) -> void:
	if ResourceLoader.exists(path):
		var stream = load(path)
		# 导入设置之外再显式开启循环，并以 finished 信号作为兜底。
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if music_player.stream != stream:
			music_player.stream = stream
			music_player.play()

func clear_screen() -> void:
	if is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = null

func show_menu() -> void:
	clear_screen()
	GameState.set_phase("menu")
	play_music("res://xDeviruchi - 16 bit Fantasy & Adventure (2025)/Loopable + one shots/ogg/02 - Title Theme.ogg")
	var ui := make_full_panel(Color("101522"))
	current_screen = ui
	add_child(ui)
	add_menu_pixel_art(ui)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.position = Vector2(-260, -190)
	box.size = Vector2(520, 380)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.add_child(box)
	box.add_child(make_label("PROJECT K", 58, Color("72e1ff"), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label("PIXEL ACTION ROGUELITE", 20, Color("c8b47a"), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label("第一章 · 翡翠林地", 18, Color("9ee879"), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_spacer(20))
	box.add_child(make_button("开始游戏", show_class_select))
	box.add_child(make_button("操作说明", show_controls))
	box.add_child(make_button("退出", get_tree().quit))

func show_class_select() -> void:
	clear_screen()
	GameState.set_phase("class_select")
	var ui := make_full_panel(Color("101522"))
	current_screen = ui
	add_child(ui)
	add_menu_pixel_art(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(340, 120)
	box.size = Vector2(600, 500)
	ui.add_child(box)
	box.add_child(make_label("选择职业", 40, Color("72e1ff"), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_label("青袍法师 · HP 60 · 法力 100 · 法杖与元气弹", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(make_button("选择青袍法师并进入林地", start_run))
	for name in ["剑士", "狂战士", "游侠"]:
		var locked := Button.new()
		locked.text = "%s（尚未解锁）" % name
		locked.disabled = true
		locked.custom_minimum_size.y = 52
		PixelStyle.style_button(locked, Color("526a78"))
		box.add_child(locked)
	box.add_child(make_button("返回", show_menu))

func show_controls() -> void:
	clear_screen()
	var ui := make_full_panel(Color("101522"))
	current_screen = ui
	add_child(ui)
	var text := "操作说明\n\nWASD / 方向键：八方向移动\n连续 J / 鼠标左键：基础法杖三段连招\nQ / 鼠标右键：元气弹（消耗法力）\nK / Shift：翻滚（短暂无敌）\n1 / 2 / 3：基础法杖 / 远程法杖 / 弓\n掉落武器拾取后持续 10 秒\n\n怪物约 40% 概率掉落卡牌\n清理至 2 只残敌后推进兽潮\n成长选择与 BOSS 转阶段期间战斗暂停\n\n炎魔共有三个阶段\n观察冲锋、火球与雷暴预警，使用卡牌削弱下一阶段"
	var label := make_label(text, 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	label.position = Vector2(260, 90)
	label.size = Vector2(760, 470)
	ui.add_child(label)
	var back := make_button("返回", show_menu)
	back.position = Vector2(490, 590)
	back.size = Vector2(300, 54)
	ui.add_child(back)

func start_run() -> void:
	if "--smoke-test" in OS.get_cmdline_user_args():
		RNG.set_seed(20260820)
	else:
		RNG.set_seed(hash("%s-%s" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]))
	GameState.reset_run()
	show_farm()

func show_farm() -> void:
	clear_screen()
	GameState.set_phase("farm")
	play_music("res://xDeviruchi - 16 bit Fantasy & Adventure (2025)/Loopable + one shots/ogg/04 - Silent Forest.ogg")
	var farm = FarmLevelScript.new()
	current_screen = farm
	add_child(farm)
	farm.boss_door_entered.connect(show_boss)
	farm.player_defeated.connect(show_defeat)

func show_boss() -> void:
	clear_screen()
	GameState.set_phase("boss")
	play_music("res://xDeviruchi - 16 bit Fantasy & Adventure (2025)/Loopable + one shots/ogg/17 - Decisive Battle 2 - The Calamity.ogg")
	var battle = BossBattleScript.new()
	current_screen = battle
	add_child(battle)
	battle.victory.connect(show_victory)
	battle.defeat.connect(show_defeat)

func show_victory() -> void:
	clear_screen()
	GameState.set_phase("victory")
	play_music("res://xDeviruchi - 16 bit Fantasy & Adventure (2025)/Loopable + one shots/ogg/06 - Victory!.ogg")
	SaveManager.unlock_legendary("immortal_bulwark")
	var ui := make_full_panel(Color("151120"))
	current_screen = ui
	add_child(ui)
	var text := make_label("炎魔已被击败\n\n获得传说卡「不灭壁垒」\n你在缩圈竞技场中突破了冲锋、火球与雷暴组合。\n\n%s" % format_run_stats(), 30, Color("ffd54f"), HORIZONTAL_ALIGNMENT_CENTER)
	text.position = Vector2(260, 100)
	text.size = Vector2(760, 380)
	ui.add_child(text)
	var again := make_button("重新开始", start_run)
	again.position = Vector2(490, 530)
	again.size = Vector2(300, 60)
	ui.add_child(again)

func show_defeat() -> void:
	clear_screen()
	GameState.set_phase("defeat")
	var ui := make_full_panel(Color("190e15"))
	current_screen = ui
	add_child(ui)
	var label := make_label("挑战失败\n\n%s\n\n观察攻击预警，用翻滚穿过火球缝隙后再试。" % format_run_stats(), 32, Color("ff8178"), HORIZONTAL_ALIGNMENT_CENTER)
	label.position = Vector2(240, 170)
	label.size = Vector2(800, 180)
	ui.add_child(label)
	var retry := make_button("重试本章", start_run)
	retry.position = Vector2(490, 430)
	retry.size = Vector2(300, 60)
	ui.add_child(retry)

func format_run_stats() -> String:
	if GameState.run_stats.is_empty():
		return "本次为快速挑战"
	var stats := GameState.run_stats
	var total_seconds := int(float(stats.get("time",0.0)))
	var minutes := floori(total_seconds / 60.0)
	var seconds := total_seconds % 60
	var upgrades: Array = stats.get("upgrades",[])
	return "Farm 结算：第 %d 波 · 击杀 %d · %02d:%02d\n峰值连击 %d · 承伤 %d · 成长 %s" % [int(stats.get("wave",1)),int(stats.get("kills",0)),minutes,seconds,int(stats.get("highest_combo",0)),int(stats.get("damage_taken",0))," / ".join(upgrades) if not upgrades.is_empty() else "无"]

func restart_stage() -> void:
	if GameState.phase == "boss":
		show_boss()
	elif GameState.phase == "farm":
		start_run()
	else:
		show_menu()

func show_toast(message: String) -> void:
	var toast := Label.new()
	toast.z_index = 1200
	toast.text = message
	toast.position = Vector2(470, 70)
	toast.add_theme_font_size_override("font_size", 22)
	toast.add_theme_color_override("font_color", Color("72e1ff"))
	add_child(toast)
	get_tree().create_timer(1.5).timeout.connect(toast.queue_free)

func make_full_panel(color: Color) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = color
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return panel

func add_menu_pixel_art(panel: Control) -> void:
	var root := "res://assets/puny_characters/Puny-Characters/"
	var grass: Texture2D = load(root + "Environment/Grass2.png")
	var dirt: Texture2D = load(root + "Environment/Dirt.png")
	for y in range(12):
		for x in range(20):
			var tile := Sprite2D.new()
			tile.texture = dirt if absf(y - 6) < 1 and x > 2 and x < 18 else grass
			tile.position = Vector2(x * 64 + 32,y * 64 + 32)
			tile.scale = Vector2(4,4)
			tile.modulate = Color("64774f")
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			panel.add_child(tile)
	# 中央暗幕压低背景噪点，让标题和按钮保持清楚，同时保留两侧林地轮廓。
	var center_shade := ColorRect.new()
	center_shade.position = Vector2(300,0)
	center_shade.size = Vector2(680,720)
	center_shade.color = Color(0.025,0.055,0.045,0.58)
	center_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center_shade)
	var top_fade := ColorRect.new()
	top_fade.position = Vector2(0,0)
	top_fade.size = Vector2(1280,92)
	top_fade.color = Color(0.02,0.04,0.035,0.42)
	top_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_fade)
	var tree_texture: Texture2D = load(root + "Environment/Tree.png")
	for position in [Vector2(55,70),Vector2(120,90),Vector2(1190,80),Vector2(1250,110),Vector2(75,640),Vector2(1195,645)]:
		var tree := Sprite2D.new()
		tree.texture = tree_texture
		tree.position = position
		tree.scale = Vector2(5,5)
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.add_child(tree)
	var hero := Sprite2D.new()
	hero.texture = load(root + "Mage-Cyan.png")
	hero.region_enabled = true
	hero.region_rect = Rect2(0,0,32,32)
	hero.position = Vector2(210,430)
	hero.scale = Vector2(5,5)
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(hero)
	var orc := Sprite2D.new()
	orc.texture = load(root + "Orc-Grunt.png")
	orc.region_enabled = true
	orc.region_rect = Rect2(0,0,32,32)
	orc.position = Vector2(1080,430)
	orc.scale = Vector2(5,5)
	orc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(orc)

func make_label(text_value: String, size_value: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelStyle.outline(label, 4)
	return label

func make_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(360, 56)
	button.add_theme_font_size_override("font_size", 22)
	PixelStyle.style_button(button)
	button.pressed.connect(callback)
	return button

func make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer
