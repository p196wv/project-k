extends Node

var seed_value: int = 20260820
var generator := RandomNumberGenerator.new()

func _ready() -> void:
	set_seed(seed_value)

func set_seed(value: int) -> void:
	seed_value = value
	generator.seed = value

func chance(probability: float) -> bool:
	return generator.randf() < probability

func pick(items: Array):
	if items.is_empty():
		return null
	return items[generator.randi_range(0, items.size() - 1)]

func shuffle(items: Array) -> Array:
	var copy := items.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := generator.randi_range(0, i)
		var temp = copy[i]
		copy[i] = copy[j]
		copy[j] = temp
	return copy
