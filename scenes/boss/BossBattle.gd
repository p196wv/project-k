extends Node2D

signal victory
signal defeat

const PlayerScript = preload("res://entities/player/Player.gd")
const BossScript = preload("res://entities/boss/RealtimeBoss.gd")
const StoneWallScript = preload("res://entities/environment/StoneWall.gd")
const FireballScript = preload("res://entities/effects/BossFireball.gd")
const MeteorScript = preload("res://entities/effects/BossMeteor.gd")
const ArcaneOrbScript = preload("res://entities/effects/ArcaneOrb.gd")
const WeaponProjectileScript = preload("res://entities/effects/PlayerWeaponProjectile.gd")
const PixelMagicBurstScript = preload("res://entities/effects/PixelMagicBurst.gd")
const BossCastAuraScript = preload("res://entities/effects/BossCastAura.gd")
const BossComboSlashScript = preload("res://entities/effects/BossComboSlash.gd")

const ARENA_RECT := Rect2(118,138,1044,484)

var player: CharacterBody2D
var boss: CharacterBody2D
var arena_walls: Array = []
var active_projectiles: Array = []
var active_meteors: Array = []
var hud_hp: ProgressBar
var hud_mana: ProgressBar
var hud_boss: ProgressBar
var hp_label: Label
var mana_label: Label
var boss_label: Label
var intent_label: Label
var weapon_label: Label
var physical_casts := 0
var magic_casts := 0
var meteor_casts := 0
var battle_finished := false
var frost_charges := 0
var hud_layer: CanvasLayer
var phase_overlay: Control
var phase_cards_cast := 0
var pending_phase := 0
var last_phase_card := ""

func _ready() -> void:
	frost_charges = 0
	create_solid_arena()
	create_player()
	create_boss()
	create_hud()
	update_player_hud()
	update_boss_hud(boss.hp,boss.max_hp)
	queue_redraw()

func _exit_tree() -> void:
	get_tree().paused = false

func create_solid_arena() -> void:
	# 可见围墙与碰撞矩形完全一致：竞技场没有薄边、缺口或视觉空气墙。
	add_arena_wall(Vector2(640,117),Vector2(1086,42))
	add_arena_wall(Vector2(640,643),Vector2(1086,42))
	add_arena_wall(Vector2(97,380),Vector2(42,568))
	add_arena_wall(Vector2(1183,380),Vector2(42,568))

func add_arena_wall(position_value: Vector2, size_value: Vector2) -> void:
	var wall = StoneWallScript.new()
	wall.position = position_value
	wall.setup(size_value)
	add_child(wall)
	arena_walls.append(wall)

func create_player() -> void:
	player = PlayerScript.new()
	player.position = Vector2(310,390)
	add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_right = 1280
	player.camera.limit_top = 0
	player.camera.limit_bottom = 720
	player.attacked.connect(on_player_attack)
	player.spell_cast.connect(on_player_spell)
	player.weapon_fired.connect(on_player_weapon_fired)
	player.weapon_changed.connect(func(_weapon_id: String): update_player_hud())
	player.hp_changed.connect(func(_current: int,_maximum: int): update_player_hud())
	player.mana_changed.connect(func(_current: float,_maximum: float): update_player_hud())
	player.damaged.connect(on_player_damaged)
	player.died.connect(on_player_died)

func create_boss() -> void:
	boss = BossScript.new()
	boss.position = Vector2(930,380)
	boss.setup(player)
	add_child(boss)
	boss.hp_changed.connect(update_boss_hud)
	boss.physical_started.connect(on_boss_physical_started)
	boss.magic_cast.connect(on_boss_magic_cast)
	boss.meteor_cast.connect(on_boss_meteor_cast)
	boss.intent_changed.connect(update_intent)
	boss.phase_transition_requested.connect(on_phase_transition_requested)
	boss.defeated.connect(on_boss_defeated)

func create_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 20
	add_child(hud_layer)
	var header := ColorRect.new()
	header.color = Color(0.035,0.045,0.05,0.94)
	header.position = Vector2(0,0)
	header.size = Vector2(1280,92)
	hud_layer.add_child(header)
	hud_hp = make_bar(Vector2(24,17),Vector2(260,22),Color("58d978"))
	hud_mana = make_bar(Vector2(24,52),Vector2(260,17),Color("59cfff"))
	hud_boss = make_bar(Vector2(775,24),Vector2(470,26),Color("ef5a4e"))
	hud_layer.add_child(hud_hp)
	hud_layer.add_child(hud_mana)
	hud_layer.add_child(hud_boss)
	hp_label = make_label(Vector2(32,15),18,Color.WHITE)
	mana_label = make_label(Vector2(32,48),16,Color("d5f7ff"))
	boss_label = make_label(Vector2(790,24),19,Color.WHITE)
	weapon_label = make_label(Vector2(312,16),18,Color("ffe08a"))
	intent_label = make_label(Vector2(312,51),17,Color("d9e6cf"))
	intent_label.size = Vector2(450,28)
	for label in [hp_label,mana_label,boss_label,weapon_label,intent_label]:
		hud_layer.add_child(label)
	var help := make_label(Vector2(235,674),17,Color("dce8d1"))
	help.text = "J 攻击 · Q 元气弹 · K/Shift 翻滚 · 1/2/3 切换已拾取武器"
	help.size = Vector2(810,28)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(help)

func make_bar(position_value: Vector2, size_value: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = position_value
	bar.size = size_value
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("15201b")
	background.border_color = Color("91a078")
	background.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.border_color = fill_color.lightened(0.2)
	fill.set_border_width_all(2)
	bar.add_theme_stylebox_override("background",background)
	bar.add_theme_stylebox_override("fill",fill)
	return bar

func make_label(position_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = position_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color("101611"))
	label.add_theme_constant_override("outline_size",4)
	return label

func on_player_attack(origin: Vector2, direction: Vector2, reach: float) -> void:
	if battle_finished or not is_instance_valid(boss) or boss.dead:
		return
	var offset: Vector2 = boss.global_position - origin
	if offset.length() <= reach + 34.0 and direction.normalized().dot(offset.normalized()) >= 0.38:
		boss.take_damage(10,origin)
		player.confirm_hit()
		show_damage(boss.global_position - Vector2(0,54),10,Color("fff0a0"))

func on_player_spell(origin: Vector2, direction: Vector2) -> void:
	var orb = ArcaneOrbScript.new()
	orb.global_position = origin + direction.normalized() * 26.0
	orb.setup(direction,origin)
	add_child(orb)
	orb.enemy_hit.connect(func(_enemy: Node2D,damage: int,position_value: Vector2):
		player.confirm_hit()
		show_damage(position_value - Vector2(0,54),damage,Color("a7efff"))
		if frost_charges > 0 and is_instance_valid(boss) and not boss.dead:
			frost_charges -= 1
			boss.apply_frost_stagger()
			update_player_hud()
	)

func on_player_weapon_fired(origin: Vector2, direction: Vector2, weapon_id: String) -> void:
	var damage := 9 if weapon_id == "bow" else 13
	var projectile = WeaponProjectileScript.new()
	projectile.global_position = origin + direction.normalized() * 28.0
	projectile.setup(direction,weapon_id,damage)
	add_child(projectile)
	projectile.enemy_hit.connect(func(_enemy: Node2D,hit_damage: int,position_value: Vector2,_weapon: String):
		player.confirm_hit()
		show_damage(position_value - Vector2(0,54),hit_damage,Color("8feeff" if weapon_id == "arcane_staff" else "ffe08a"))
	)

func on_boss_physical_started(position_value: Vector2, direction: Vector2, combo_step: int) -> void:
	physical_casts += 1
	var slash = BossComboSlashScript.new()
	slash.global_position = position_value + direction * 34.0 - Vector2(0,16)
	slash.setup(direction,combo_step)
	add_child(slash)
	var accent = PixelMagicBurstScript.new()
	accent.global_position = position_value + direction * 34.0 - Vector2(0,16)
	accent.setup(direction,[Color("ffbd75"),Color("ff865e"),Color("ff5548")][clampi(combo_step - 1,0,2)])
	add_child(accent)

func on_boss_magic_cast(position_value: Vector2, direction: Vector2, phase_two: bool) -> void:
	magic_casts += 1
	spawn_cast_aura(position_value,Color("ff9b48"))
	var count: int = [5,6,8][boss.phase_index - 1]
	var spread: float = [0.52,0.62,0.76][boss.phase_index - 1]
	for index in range(count):
		var ratio := float(index) / float(count - 1) - 0.5
		var fireball = FireballScript.new()
		fireball.global_position = position_value + direction.rotated(ratio * spread) * 42.0
		fireball.setup(direction.rotated(ratio * spread),player,phase_two)
		add_child(fireball)
		active_projectiles.append(fireball)
		fireball.tree_exited.connect(func(): active_projectiles.erase(fireball))

func on_boss_meteor_cast(target_position: Vector2, phase_two: bool) -> void:
	meteor_casts += 1
	spawn_cast_aura(boss.global_position - Vector2(0,18),Color("dc77ff"))
	var count := 5 if boss.phase_index >= 3 else 3
	for index in range(count):
		var offset := Vector2.ZERO if index == 0 else Vector2.from_angle(index * 2.2 + meteor_casts) * (72.0 + index * 18.0)
		var point := target_position + offset
		point.x = clampf(point.x,ARENA_RECT.position.x + 70.0,ARENA_RECT.end.x - 70.0)
		point.y = clampf(point.y,ARENA_RECT.position.y + 70.0,ARENA_RECT.end.y - 70.0)
		var meteor = MeteorScript.new()
		meteor.global_position = point
		meteor.setup(player,0.78 + index * 0.08,phase_two)
		add_child(meteor)
		active_meteors.append(meteor)
		meteor.tree_exited.connect(func(): active_meteors.erase(meteor))

func spawn_cast_aura(position_value: Vector2, color: Color) -> void:
	var aura = BossCastAuraScript.new()
	aura.global_position = position_value
	aura.setup(color)
	add_child(aura)

func on_phase_transition_requested(next_phase: int) -> void:
	pending_phase = next_phase
	clear_boss_hazards()
	player.velocity = Vector2.ZERO
	player.process_mode = Node.PROCESS_MODE_DISABLED
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	show_phase_card_overlay(next_phase)

func clear_boss_hazards() -> void:
	for projectile in active_projectiles.duplicate():
		if is_instance_valid(projectile):
			projectile.queue_free()
	for meteor in active_meteors.duplicate():
		if is_instance_valid(meteor):
			meteor.queue_free()
	active_projectiles.clear()
	active_meteors.clear()

func show_phase_card_overlay(next_phase: int) -> void:
	get_tree().paused = true
	phase_overlay = ColorRect.new()
	phase_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	phase_overlay.color = Color(0.025,0.04,0.07,0.94)
	phase_overlay.position = Vector2.ZERO
	phase_overlay.size = Vector2(1280,720)
	hud_layer.add_child(phase_overlay)
	var title := make_label(Vector2(260,92),38,Color("a9e9ff"))
	title.text = "阶段转换  %d → %d" % [next_phase - 1,next_phase]
	title.size = Vector2(760,60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_overlay.add_child(title)
	var prompt := make_label(Vector2(260,154),21,Color.WHITE)
	prompt.text = "战斗已暂停：从 Farm 获得的卡牌中施放一张，削弱下一阶段"
	prompt.size = Vector2(760,42)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_overlay.add_child(prompt)
	var box := VBoxContainer.new()
	box.position = Vector2(365,225)
	box.size = Vector2(550,330)
	box.add_theme_constant_override("separation",18)
	phase_overlay.add_child(box)
	var has_card := false
	for card_id in ["freeze","frost_nova"]:
		var count := int(GameState.ammo_library.get(card_id,0))
		if count <= 0:
			continue
		has_card = true
		var description := "造成 10 伤害 · 增加 1 次寒霜打断" if card_id == "freeze" else "造成 18 伤害 · 回复 30 法力"
		var button := Button.new()
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.text = "%s ×%d\n%s" % [CombatEngine.card_name(card_id),count,description]
		button.custom_minimum_size = Vector2(550,92)
		button.add_theme_font_size_override("font_size",19)
		PixelStyle.style_button(button,Color("4e8fa9") if card_id == "freeze" else Color("7658b5"))
		button.pressed.connect(cast_phase_card.bind(card_id))
		box.add_child(button)
	if not has_card:
		var fallback := Button.new()
		fallback.process_mode = Node.PROCESS_MODE_ALWAYS
		fallback.text = "奥术整备\n没有卡牌：回复 20 法力后进入下一阶段"
		fallback.custom_minimum_size = Vector2(550,92)
		fallback.add_theme_font_size_override("font_size",19)
		PixelStyle.style_button(fallback,Color("596779"))
		fallback.pressed.connect(cast_phase_card.bind("fallback"))
		box.add_child(fallback)

func cast_phase_card(card_id: String) -> void:
	if pending_phase <= 0 or not is_instance_valid(boss):
		return
	get_tree().paused = false
	last_phase_card = card_id
	phase_cards_cast += 1
	var card_damage := 0
	if card_id == "freeze":
		consume_card(card_id)
		card_damage = 10
		frost_charges = mini(3,frost_charges + 1)
	elif card_id == "frost_nova":
		consume_card(card_id)
		card_damage = 18
		player.restore_mana(30.0)
	else:
		player.restore_mana(20.0)
	spawn_cast_aura(boss.global_position - Vector2(0,18),Color("9eeeff"))
	boss.complete_phase_transition(card_damage)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	pending_phase = 0
	if is_instance_valid(phase_overlay):
		phase_overlay.queue_free()
	phase_overlay = null
	update_player_hud()
	update_boss_hud(boss.hp,boss.max_hp)

func consume_card(card_id: String) -> void:
	var left := maxi(0,int(GameState.ammo_library.get(card_id,0)) - 1)
	if left <= 0:
		GameState.ammo_library.erase(card_id)
	else:
		GameState.ammo_library[card_id] = left

func on_player_damaged(amount: int, position_value: Vector2) -> void:
	show_damage(position_value - Vector2(0,52),amount,Color("ff746a"))
	update_player_hud()

func on_player_died() -> void:
	if battle_finished:
		return
	battle_finished = true
	defeat.emit()

func on_boss_defeated() -> void:
	if battle_finished:
		return
	battle_finished = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	clear_boss_hazards()
	await get_tree().create_timer(0.65).timeout
	victory.emit()

func update_player_hud() -> void:
	if not is_instance_valid(hud_hp) or not is_instance_valid(player):
		return
	hud_hp.max_value = GameState.player_max_hp
	hud_hp.value = GameState.player_hp
	hud_mana.max_value = player.MAX_MANA
	hud_mana.value = player.mana
	hp_label.text = "生命 %d / %d" % [GameState.player_hp,GameState.player_max_hp]
	mana_label.text = "法力 %d / %d" % [roundi(player.mana),roundi(player.MAX_MANA)]
	weapon_label.text = "当前：%s · 寒霜打断 %d" % [player.weapon_name(),frost_charges]

func update_boss_hud(current: int, maximum: int) -> void:
	if not is_instance_valid(hud_boss):
		return
	hud_boss.max_value = maximum
	hud_boss.value = current
	boss_label.text = "炎魔领主 %d / %d · 阶段 %d/3" % [current,maximum,boss.phase_index if is_instance_valid(boss) else 1]

func update_intent(text: String, color: Color) -> void:
	if is_instance_valid(intent_label):
		intent_label.text = text
		intent_label.add_theme_color_override("font_color",color)

func show_damage(position_value: Vector2, amount: int, color: Color) -> void:
	var label := make_label(position_value,22,color)
	label.text = "-%d" % amount
	label.z_index = 4000
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label,"position:y",position_value.y - 32.0,0.42)
	tween.tween_property(label,"modulate:a",0.0,0.42)
	tween.chain().tween_callback(label.queue_free)

func debug_force_physical() -> void:
	if is_instance_valid(boss):
		boss.start_physical()

func debug_force_magic() -> void:
	if is_instance_valid(boss):
		on_boss_magic_cast(boss.global_position,boss.global_position.direction_to(player.global_position),boss.phase_two)

func debug_force_meteor() -> void:
	if is_instance_valid(boss):
		on_boss_meteor_cast(player.global_position,boss.phase_two)

func debug_choose_phase_card(card_id := "freeze") -> void:
	if pending_phase > 0:
		cast_phase_card(card_id if int(GameState.ammo_library.get(card_id,0)) > 0 else "fallback")

func debug_set_boss_low() -> void:
	if is_instance_valid(boss):
		boss.phase_index = 3
		boss.phase_two = true
		boss.transitioning = false
		boss.hp = 1
		update_boss_hud(boss.hp,boss.max_hp)

func debug_text() -> String:
	return "\nBOSS: %d/%d · 阶段 %d/3 · 状态: %s\n物理/火球/雷暴: %d/%d/%d · 转阶段卡: %d" % [boss.hp,boss.max_hp,boss.phase_index,boss.state,physical_casts,magic_casts,meteor_casts,phase_cards_cast]

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("11151a"))
	draw_rect(Rect2(72,92,1136,576),Color("20231d"))
	# 三层石框与碰撞边界完全重合，场地边缘更容易在战斗中辨认。
	draw_rect(ARENA_RECT.grow(18),Color("171b18"))
	draw_rect(ARENA_RECT.grow(10),Color("72553b"))
	draw_rect(ARENA_RECT.grow(4),Color("2b332b"))
	draw_rect(ARENA_RECT,Color("3d4938"))
	# 低对比错缝地砖只做视觉分区，不带体积。
	for y in range(int(ARENA_RECT.position.y),int(ARENA_RECT.end.y),32):
		for x in range(int(ARENA_RECT.position.x),int(ARENA_RECT.end.x),32):
			var row_index := floori(float(y - ARENA_RECT.position.y) / 32.0)
			var brick_x := x + (16 if row_index % 2 == 1 else 0)
			var alternate := (floori(float(brick_x) / 32.0) + row_index) % 3 == 0
			draw_rect(Rect2(brick_x,y,30,30),Color("465441") if alternate else Color("414d3c"))
			draw_line(Vector2(brick_x,y + 1),Vector2(brick_x + 29,y + 1),Color(0.50,0.59,0.43,0.18),1)
	# 中央封印和四角火印强化 BOSS 房的主题，不参与碰撞。
	var center := ARENA_RECT.get_center()
	for radius in [116.0,88.0,52.0]:
		draw_arc(center,radius,0,TAU,48,Color(0.78,0.38,0.18,0.24),4.0)
	for index in range(8):
		var direction := Vector2.from_angle(index * TAU / 8.0)
		draw_line(center + direction * 56.0,center + direction * 108.0,Color(0.82,0.43,0.20,0.20),5.0)
	for corner in [Vector2(142,176),Vector2(1138,176),Vector2(142,624),Vector2(1138,624)]:
		draw_rect(Rect2(corner - Vector2(12,12),Vector2(24,24)),Color("2a1a16"))
		draw_rect(Rect2(corner - Vector2(6,8),Vector2(12,16)),Color("d26a32"))
		draw_rect(Rect2(corner - Vector2(2,4),Vector2(4,8)),Color("ffd36b"))
	draw_string(ThemeDB.fallback_font,Vector2(508,128),"炎魔封印场",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("eacb83"))
