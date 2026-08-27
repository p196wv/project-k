extends Node

signal card_added(card_id: String, total: int)
signal phase_changed(phase: String)

const START_ENERGY := 3
const DRAW_PER_TURN := 2
const START_HAND := 5
const MAX_HAND := 7

var phase := "menu"
var player_hp := 60
var player_max_hp := 60
var player_armor := 15
var ammo_library: Dictionary = {}
var deck: Array[String] = []
var hand: Array[String] = []
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var energy := START_ENERGY
var legendary_owned: Array[String] = []
var run_stats: Dictionary = {}
var unlocked_weapons := {"basic":true,"arcane_staff":false,"bow":false}
var equipped_weapon := "basic"
var temporary_weapon_id := ""
var weapon_time_left := 0.0

func reset_run() -> void:
	player_max_hp = 60
	player_hp = 60
	player_armor = 15
	ammo_library.clear()
	deck.clear()
	hand.clear()
	draw_pile.clear()
	discard_pile.clear()
	energy = START_ENERGY
	run_stats.clear()
	unlocked_weapons = {"basic":true,"arcane_staff":false,"bow":false}
	equipped_weapon = "basic"
	temporary_weapon_id = ""
	weapon_time_left = 0.0

func set_phase(value: String) -> void:
	phase = value
	phase_changed.emit(value)

func add_card(card_id: String) -> void:
	ammo_library[card_id] = int(ammo_library.get(card_id, 0)) + 1
	card_added.emit(card_id, ammo_library[card_id])

func build_boss_deck() -> void:
	deck.clear()
	for card_id in ammo_library:
		for _i in range(int(ammo_library[card_id])):
			deck.append(card_id)
	# 防止跳关或极端掉落导致无牌可玩，基础牌只用于保证流程闭环。
	deck.append_array(["bone_spear", "iron_wall", "bone_spear", "iron_wall"])
	draw_pile.assign(RNG.shuffle(deck))
	hand.clear()
	discard_pile.clear()
	draw_cards(START_HAND)

func draw_cards(count: int) -> void:
	for _i in range(count):
		if hand.size() >= MAX_HAND:
			return
		if draw_pile.is_empty() and not discard_pile.is_empty():
			draw_pile.assign(RNG.shuffle(discard_pile))
			discard_pile.clear()
		if draw_pile.is_empty():
			return
		hand.append(draw_pile.pop_back())

func discard_card(index: int) -> String:
	if index < 0 or index >= hand.size():
		return ""
	var card_id := hand[index]
	hand.remove_at(index)
	discard_pile.append(card_id)
	return card_id
