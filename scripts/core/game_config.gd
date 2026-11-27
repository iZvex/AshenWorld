extends Node

# Единый источник параметров баланса. Все вероятности, цены и коэффициенты
# хранятся в data/balance.json и не дублируются в других скриптах.

const BALANCE_PATH: String = "res://data/balance.json"

var values: Dictionary = {}


func _ready() -> void:
	values = _load_balance()


func _load_balance() -> Dictionary:
	var file: FileAccess = FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть файл баланса: %s" % BALANCE_PATH)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Файл баланса содержит некорректные данные: %s" % BALANCE_PATH)
		return {}
	return parsed as Dictionary


func get_section(name: String) -> Dictionary:
	if not values.has(name):
		return {}
	var section: Variant = values[name]
	if section is Dictionary:
		return section as Dictionary
	return {}
