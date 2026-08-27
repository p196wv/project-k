extends Node

const SAVE_PATH := "user://monster_deck_save.json"
var legendary_cards: Array[String] = []

func _ready() -> void:
	load_save()

func unlock_legendary(card_id: String) -> void:
	if card_id not in legendary_cards:
		legendary_cards.append(card_id)
	save()

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"legendary_cards":legendary_cards}))

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		legendary_cards.assign(data.get("legendary_cards", []))
