extends Control

# Стартовая сцена проекта. Показывает реальное состояние загрузки данных:
# сколько разделов баланса прочитано и какой интервал атаки задан.
# Неработающих кнопок и заглушек интерфейса здесь нет.

@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	var sections: int = GameConfig.values.size()
	var combat: Dictionary = GameConfig.get_section("combat")
	var interval: float = float(combat.get("attack_interval_seconds", 0.0))
	status_label.text = "ASHEN WORLD\nРазделов баланса: %d\nИнтервал атаки: %.1f с" % [sections, interval]
	print("Главная сцена готова, разделов баланса: %d" % sections)
