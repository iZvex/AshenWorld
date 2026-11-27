extends RefCounted

# Чтение боевых данных из единого файла баланса. Используется и игрой,
# и точечным тестом, поэтому правила загрузки не дублируются.

const BALANCE_PATH: String = "res://data/balance.json"


static func load_balance() -> Dictionary:
	var file: FileAccess = FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть файл баланса: %s" % BALANCE_PATH)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Некорректный файл баланса: %s" % BALANCE_PATH)
		return {}
	return parsed as Dictionary


static func combat_balance(balance: Dictionary) -> Dictionary:
	return balance.get("combat", {}) as Dictionary


static func hero_data(balance: Dictionary) -> Dictionary:
	return balance.get("hero", {}) as Dictionary


static func skill_map(balance: Dictionary) -> Dictionary:
	return balance.get("skills", {}) as Dictionary


static func campaign_data(balance: Dictionary) -> Dictionary:
	return balance.get("campaign", {}) as Dictionary


static func campaign_stages(balance: Dictionary) -> Array:
	return campaign_data(balance).get("stages", []) as Array


static func enemy_list(balance: Dictionary) -> Array:
	var enemies: Dictionary = balance.get("enemies", {}) as Dictionary
	var keys: Array = enemies.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		var entry: Variant = enemies[key]
		if entry is Dictionary:
			var copy: Dictionary = (entry as Dictionary).duplicate()
			copy["id"] = str(key)
			result.append(copy)
	return result
