extends SceneTree

# Точечная проверка ТОЛЬКО боевой системы второго этапа.
# Запуск: godot --headless --path . --script tests/test_combat.gd
# Полная сборка APK для этой проверки не требуется.

const CombatSystem = preload("res://scripts/combat/combat_system.gd")
const CombatFormulas = preload("res://scripts/combat/combat_formulas.gd")
const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const Combatant = preload("res://scripts/combat/combatant.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка боевой системы второго этапа")
	var data: Dictionary = CombatCatalog.load_balance()
	_check("Файл баланса загружен", not data.is_empty())
	var balance: Dictionary = CombatCatalog.combat_balance(data)
	_check("Настройки боя загружены", not balance.is_empty())
	var all_enemies: Array = CombatCatalog.enemy_list(data)
	_check("Каталог содержит четырнадцать противников", all_enemies.size() == 14)
	var enemies: Array = []
	for entry in all_enemies:
		if entry is Dictionary and str((entry as Dictionary).get("category", "")) == "обычный":
			enemies.append(entry)
		if enemies.size() == 3:
			break
	_check("Обычные противники загружены", enemies.size() == 3)
	var skills: Dictionary = CombatCatalog.skill_map(data)
	_check("Навыки загружены", skills.size() >= 2)

	_test_formulas(balance)
	_test_combatant()
	_test_auto_battle(data, balance, enemies, skills)
	_test_skills(data, balance, skills)
	_test_defeat_and_death(balance, skills)

	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		printerr("  ✗ ", name)


func _test_formulas(balance: Dictionary) -> void:
	var plain: float = CombatFormulas.calculate_damage(10.0, 0.0, 1.0, false, balance)
	_check("Урон без защиты равен атаке", is_equal_approx(plain, 10.0))
	var critical: float = CombatFormulas.calculate_damage(10.0, 0.0, 1.0, true, balance)
	_check("Критический урон учитывает множитель баланса", is_equal_approx(critical, 10.0 * float(balance.get("critical_multiplier", 1.5))))
	var defended: float = CombatFormulas.calculate_damage(10.0, 10.0, 1.0, false, balance)
	var expected: float = 10.0 * (1.0 - 10.0 * float(balance.get("defense_reduction_per_point", 0.02)))
	_check("Защита снижает урон по коэффициенту из данных", is_equal_approx(defended, expected))
	var capped: float = CombatFormulas.defense_reduction(1000.0, balance)
	_check("Снижение урона ограничено пределом", is_equal_approx(capped, float(balance.get("max_defense_reduction", 0.6))))
	var changed: Dictionary = balance.duplicate()
	changed["critical_multiplier"] = 3.0
	_check("Формула читает коэффициент из данных, а не из константы", is_equal_approx(CombatFormulas.calculate_damage(10.0, 0.0, 1.0, true, changed), 30.0))
	var boosted: float = CombatFormulas.calculate_damage(10.0, 0.0, 2.0, false, balance)
	_check("Множитель навыка увеличивает урон", is_equal_approx(boosted, 20.0))
	_check("Нулевая атака не даёт отрицательного урона", is_equal_approx(CombatFormulas.calculate_damage(-5.0, 0.0, 1.0, true, balance), 0.0))


func _test_combatant() -> void:
	var fighter = Combatant.new({"name": "Испытуемый", "max_health": 100.0, "attack": 10.0, "defense": 0.0})
	_check("Здоровье после создания полное", is_equal_approx(fighter.health, 100.0))
	var dealt: float = fighter.receive_damage(30.0)
	_check("Урон уменьшает здоровье", is_equal_approx(dealt, 30.0) and is_equal_approx(fighter.health, 70.0))
	fighter.add_shield(20.0)
	var through: float = fighter.receive_damage(30.0)
	_check("Щит поглощает часть урона", is_equal_approx(through, 10.0) and is_equal_approx(fighter.health, 60.0) and is_equal_approx(fighter.shield, 0.0))
	var last: float = fighter.receive_damage(1000.0)
	_check("Здоровье не уходит ниже нуля", is_equal_approx(last, 60.0) and is_equal_approx(fighter.health, 0.0))
	_check("После смерти участник неживой", not fighter.alive)
	_check("Повторный урон по погибшему не наносится", is_equal_approx(fighter.receive_damage(50.0), 0.0))
	fighter.restore()
	_check("Восстановление возвращает полное здоровье", fighter.alive and is_equal_approx(fighter.health, 100.0))


func _test_auto_battle(data: Dictionary, balance: Dictionary, enemies: Array, skills: Dictionary) -> void:
	var system = CombatSystem.new(CombatCatalog.hero_data(data), enemies, skills, balance, 7)
	var start_health: float = system.enemy.health
	system.advance(1.0)
	_check("Автоатака героя наносит урон", system.enemy != null and system.enemy.health < start_health)
	_check("Автоатака противника уменьшает здоровье героя", system.hero.health < system.hero.max_health)
	var hits: Array = []
	system.damage_dealt.connect(func(_target: String, amount: float, _critical: bool): hits.append(amount))
	for i in range(60):
		system.advance(1.0)
	_check("Бой порождает события урона", hits.size() > 0)
	_check("Здоровье героя не отрицательное", system.hero.health >= 0.0)
	var state: Dictionary = system.get_state()
	_check("Состояние боя содержит здоровье героя", state.has("hero_health"))
	_check("Все противники в итоге повержены", int(state.get("defeated", 0)) >= 3)
	_check("После последнего противника бой остановлен", not system.running)


func _test_skills(data: Dictionary, balance: Dictionary, skills: Dictionary) -> void:
	var mannequin: Array = [{"name": "Тренировочный манекен", "max_health": 100000.0, "attack": 0.0, "defense": 0.0}]
	var system = CombatSystem.new(CombatCatalog.hero_data(data), mannequin, skills, balance, 11)
	var hp_before: float = system.enemy.health
	_check("Навык применяется", system.use_skill("heavy_strike"))
	_check("Навык наносит усиленный урон", hp_before - system.enemy.health > 0.0)
	_check("Повторное применение до отката запрещено", not system.use_skill("heavy_strike"))
	_check("Откат навыка больше нуля", system.get_cooldown_remaining("heavy_strike") > 0.0)
	system.advance(5.0)
	_check("После отката навык снова доступен", system.use_skill("heavy_strike"))
	_check("Неизвестный навык не применяется", not system.use_skill("несуществующий"))
	var guard = CombatSystem.new(CombatCatalog.hero_data(data), mannequin, skills, balance, 13)
	_check("Щитующий навык применяется", guard.use_skill("ash_guard"))
	_check("Щит добавлен", guard.hero.shield > 0.0)
	var shield_before: float = guard.hero.shield
	var health_before: float = guard.hero.health
	guard.hero.receive_damage(5.0)
	_check("Щит принимает урон первым", guard.hero.shield < shield_before and is_equal_approx(guard.hero.health, health_before))


func _test_defeat_and_death(balance: Dictionary, skills: Dictionary) -> void:
	var weak_hero: Dictionary = {"name": "Слабый герой", "max_health": 10.0, "attack": 1.0, "defense": 0.0}
	var strong: Array = [{"name": "Мощный враг", "max_health": 1000.0, "attack": 50.0, "defense": 0.0}]
	var deaths: Array = []
	var system = CombatSystem.new(weak_hero, strong, skills, balance, 3)
	system.hero_defeated.connect(func(): deaths.append(true))
	for i in range(10):
		system.advance(1.0)
	_check("Гибель героя фиксируется один раз", deaths.size() == 1)
	_check("После гибели бой остановлен", not system.running)
	_check("Здоровье погибшего героя равно нулю", is_equal_approx(system.hero.health, 0.0))

	var victories: Array = []
	var fragile: Array = [{"name": "Хрупкий враг", "max_health": 1.0, "attack": 0.0, "defense": 0.0}]
	var wins = CombatSystem.new(
		{"name": "Герой", "max_health": 100.0, "attack": 50.0, "defense": 0.0},
		fragile, skills, balance, 5,
	)
	wins.enemy_defeated.connect(func(name: String): victories.append(name))
	wins.advance(1.0)
	_check("Победа над противником фиксируется", victories.size() == 1)
	_check("После последнего противника бой завершён", not wins.running)
