extends Node

const CARDS := {
	"freeze": {"name":"冰封", "cost":2, "element":"冰", "type":"秘法", "damage":12, "control":true, "text":"12 冰伤；打断蓄力"},
	"frost_nova": {"name":"寒霜新星", "cost":3, "element":"冰", "type":"秘法", "damage":22, "control":true, "text":"22 冰伤；强力冻结"},
	"bone_spear": {"name":"白骨矛", "cost":1, "element":"物理", "type":"杀伤", "damage":9, "control":false, "text":"造成 9 点伤害"},
	"iron_wall": {"name":"铁壁", "cost":1, "element":"物理", "type":"壁垒", "damage":0, "control":false, "block":10, "text":"获得 10 点护甲"},
	"ignite": {"name":"引燃", "cost":1, "element":"火", "type":"杀伤", "damage":8, "control":false, "text":"造成 8 点火伤"}
}

func card(card_id: String) -> Dictionary:
	return CARDS.get(card_id, {})

func card_name(card_id: String) -> String:
	return str(card(card_id).get("name", card_id))

func resolve_card(card_id: String, previous_element: String) -> Dictionary:
	var data: Dictionary = card(card_id)
	var damage := int(data.get("damage", 0))
	var reaction := ""
	if (previous_element == "火" and data.get("element") == "冰") or (previous_element == "冰" and data.get("element") == "火"):
		damage *= 2
		reaction = "蒸发！伤害 ×2"
	return {"damage":damage, "block":int(data.get("block", 0)), "control":bool(data.get("control", false)), "element":str(data.get("element", "")), "reaction":reaction}
