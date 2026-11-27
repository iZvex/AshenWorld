extends SceneTree

# Точечная проверка восьмого этапа: формула AFK, безопасная запись,
# резервная копия, миграции v6/v7→v8, режимы и восстановление после перезапуска.
# Запуск: godot --headless --path . --script tests/test_saves.gd

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")
const ModeCatalog = preload("res://scripts/campaign/mode_catalog.gd")
const SaveCatalog = preload("res://scripts/save/save_catalog.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")
const MainScene = preload("res://scenes/main/main.tscn")

const PROFILE_PATH: String = "user://test_saves_profile.json"
const ALT_PATH: String = "user://test_saves_alt.json"
const MIGRATION_PATH: String = "user://test_saves_migration.json"
const RESTART_PATH: String = "user://test_saves_restart.json"
const SETTINGS_PATH: String = "user://test_saves_settings.json"
const TEST_TIME: int = 1800000000

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка сохранений, миграции и офлайн-наград восьмого этапа")
	var data: Dictionary = CombatCatalog.load_balance()
	_cleanup_all(data)
	_test_config(data)
	_test_offline_formula(data)
	_test_safe_files(data)
	_test_migration(data)
	_test_v6_to_v8_migration(data)
	_test_v7_to_v8_migration(data)
	_test_campaign_snapshot(data)
	_test_restart_with_offline(data)
	_test_settings_controls(data)
	_cleanup_all(data)
	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		printerr("  ✗ ", name)


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


static func _array(value: Variant) -> Array:
	return value as Array if value is Array else []


func _cleanup_all(data: Dictionary) -> void:
	for path in [PROFILE_PATH, ALT_PATH, MIGRATION_PATH, RESTART_PATH, SETTINGS_PATH]:
		SaveManager.new(data, path).clear_files()


func _corrupt(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _test_config(data: Dictionary) -> void:
	_check("Версия баланса восьмого этапа", int(data.get("version", 0)) == 8)
	_check("Лимит AFK равен двенадцати часам", SaveCatalog.limit_hours(data) == 12 and SaveCatalog.limit_seconds(data) == 43200)
	_check("Версия формата сохранения восьмая", SaveCatalog.format_version(data) == 8)
	_check("Интервал автосохранения положителен", SaveCatalog.autosave_interval_seconds(data) > 0.0)
	_check("Предел размера профиля положителен", SaveCatalog.max_profile_bytes(data) > 0)
	_check("Путь профиля локальный", SaveCatalog.profile_path(data).begins_with("user://"))
	_check("Суффиксы временного файла и копии различны", SaveCatalog.temp_suffix(data) != SaveCatalog.backup_suffix(data))
	var settings: Dictionary = SaveCatalog.default_settings(data)
	_check("Настройки игрока подготовлены", settings.has("sound_enabled") and settings.has("particles_enabled") and settings.has("effects_enabled") and int(settings.get("target_fps", 0)) > 0)
	_check("Полные эффекты включены по умолчанию", bool(settings.get("effects_enabled", false)))
	var fps_options: Array = SaveCatalog.fps_options(data)
	_check("Варианты частоты кадров заданы в балансе", fps_options.size() >= 2 and fps_options.has(int(settings.get("target_fps", 60))))
	_check("Целевая частота кадров переключается по балансу", SaveCatalog.next_target_fps(data, int(settings.get("target_fps", 60))) != int(settings.get("target_fps", 60)))
	var normalized: Dictionary = SaveCatalog.normalize_settings({"target_fps": 47, "sound_enabled": 0, "effects_enabled": 0}, data)
	_check("Некорректные настройки приведены к доступным значениям", fps_options.has(int(normalized.get("target_fps", 0))) and not bool(normalized.get("sound_enabled", true)) and not bool(normalized.get("effects_enabled", true)))
	_check("Активная игра эффективнее AFK", SaveCatalog.active_efficiency(data) > SaveCatalog.efficiency(data, 5))
	_check("Пятый этап эффективнее первого", SaveCatalog.stage_multiplier(data, 5) > SaveCatalog.stage_multiplier(data, 1))
	var rewards: Dictionary = _dict(_dict(data.get("afk", {})).get("rewards_per_tick", {}))
	_check("Награды за интервал заданы", int(rewards.get("experience", 0)) > 0 and int(rewards.get("gold", 0)) > 0 and int(rewards.get("materials", 0)) > 0)


func _test_offline_formula(data: Dictionary) -> void:
	var now: int = TEST_TIME
	var six_hours: Dictionary = SaveCatalog.offline_rewards(data, now - 6 * 3600, now, 1)
	_check("Шесть часов отсутствия дают награду", bool(six_hours.get("eligible", false)))
	_check("Учтено фактическое время", int(six_hours.get("credited_seconds", 0)) == 21600 and not bool(six_hours.get("capped", true)))
	_check("Награды AFK положительные", int(six_hours.get("experience", 0)) > 0 and int(six_hours.get("gold", 0)) > 0 and int(six_hours.get("materials", 0)) > 0)
	_check("Активный режим эффективнее пассивного", bool(six_hours.get("active_is_better", false)))
	var twenty_hours: Dictionary = SaveCatalog.offline_rewards(data, now - 20 * 3600, now, 1)
	_check("Двадцать часов ограничены двенадцатью", int(twenty_hours.get("credited_seconds", 0)) == 43200 and bool(twenty_hours.get("capped", false)))
	_check("Лимит отмечен в отчёте", str(twenty_hours.get("status", "")) == "учтён лимит")
	_check("Ограниченная награда больше шести часов", int(twenty_hours.get("gold", 0)) > int(six_hours.get("gold", 0)))
	var short_absence: Dictionary = SaveCatalog.offline_rewards(data, now - 120, now, 1)
	_check("Короткое отсутствие не даёт награду", not bool(short_absence.get("eligible", true)) and int(short_absence.get("gold", 0)) == 0)
	var time_travel: Dictionary = SaveCatalog.offline_rewards(data, now + 1000, now, 1)
	_check("Перевод часов назад не создаёт награду", int(time_travel.get("elapsed_seconds", -1)) == 0 and not bool(time_travel.get("eligible", true)))
	var fifth_stage: Dictionary = SaveCatalog.offline_rewards(data, now - 6 * 3600, now, 5)
	_check("Достигнутый пятый этап увеличивает награду", int(fifth_stage.get("gold", 0)) > int(six_hours.get("gold", 0)))
	_check("Множитель этапа попал в отчёт", float(fifth_stage.get("stage_multiplier", 0.0)) > float(six_hours.get("stage_multiplier", 0.0)))
	_check("Текст награды понятен игроку", "Офлайн" in SaveCatalog.reward_text(six_hours) and "опыта" in SaveCatalog.reward_text(six_hours))
	_check("Длительность двенадцати часов форматирована", SaveCatalog.format_duration(43200) == "12 ч 0 мин")


func _test_safe_files(data: Dictionary) -> void:
	var manager = SaveManager.new(data, PROFILE_PATH)
	manager.clear_files()
	var first: Dictionary = manager.save_profile({"marker": "первый", "number": 7}, TEST_TIME)
	_check("Первое сохранение успешно", bool(first.get("success", false)) and str(first.get("checksum", "")) != "")
	var paths: Dictionary = manager.file_paths()
	_check("Основной файл создан", FileAccess.file_exists(str(paths.get("main", ""))))
	_check("Временный файл удалён после записи", not FileAccess.file_exists(str(paths.get("temp", ""))))
	_check("Резервной копии ещё нет", not FileAccess.file_exists(str(paths.get("backup", ""))))
	var loaded: Dictionary = manager.load_profile()
	var loaded_payload: Dictionary = _dict(loaded.get("payload", {}))
	_check("Профиль загружен", str(loaded.get("status", "")) == "loaded" and str(loaded_payload.get("marker", "")) == "первый")
	_check("Метка времени сохранена", int(loaded.get("saved_at", 0)) == TEST_TIME)
	_check("Версия формата добавлена при загрузке", int(loaded_payload.get("profile_version", 0)) == 8)
	_check("Настройки профиля добавлены", _dict(_dict(loaded_payload.get("profile", {})).get("settings", {})).has("sound_enabled"))

	var second: Dictionary = manager.save_profile({"marker": "второй", "number": 8}, TEST_TIME + 60)
	_check("Второе сохранение обновило копию", bool(second.get("success", false)) and bool(second.get("backup_updated", false)))
	_check("Резервная копия создана", FileAccess.file_exists(str(paths.get("backup", ""))))
	var loaded_second: Dictionary = manager.load_profile()
	_check("Профиль содержит вторые данные", str(_dict(loaded_second.get("payload", {})).get("marker", "")) == "второй")

	_corrupt(PROFILE_PATH, "{")
	var recovered: Dictionary = manager.load_profile()
	_check("Повреждение основного файла обнаружено", str(recovered.get("status", "")) == "recovered")
	_check("Предыдущее состояние восстановлено из копии", str(_dict(recovered.get("payload", {})).get("marker", "")) == "первый")
	_check("Резервная копия возвращена в основной файл", bool(recovered.get("restored", false)))
	_check("Повторная загрузка чистая", str(manager.load_profile().get("status", "")) == "loaded")

	_corrupt(PROFILE_PATH, "повреждено")
	_corrupt(str(paths.get("backup", "")), "тоже повреждено")
	var corrupted: Dictionary = manager.load_profile()
	_check("Повреждение обоих файлов обработано", str(corrupted.get("status", "")) == "corrupted" and not bool(corrupted.get("success", true)))
	var fresh: Dictionary = manager.save_profile({"marker": "третий"}, TEST_TIME + 120)
	_check("После повреждения можно сохранить новый профиль", bool(fresh.get("success", false)))
	_check("Новый профиль загружается", str(_dict(manager.load_profile().get("payload", {})).get("marker", "")) == "третий")

	var future_manager = SaveManager.new(data, ALT_PATH)
	future_manager.clear_files()
	var future_envelope: Dictionary = SaveManager.build_envelope({"marker": "будущее"}, TEST_TIME, 99)
	_check("Файл будущей версии записан для проверки", SaveManager.store_envelope(future_envelope, ALT_PATH))
	var future_loaded: Dictionary = future_manager.load_profile()
	_check("Файл будущей версии не принят", str(future_loaded.get("status", "")) == "future")
	var future_save: Dictionary = future_manager.save_profile({"marker": "перезапись"}, TEST_TIME + 1)
	_check("Файл будущей версии не перезаписывается", not bool(future_save.get("success", true)))
	future_manager.clear_files()
	manager.clear_files()


func _test_migration(data: Dictionary) -> void:
	var manager = SaveManager.new(data, MIGRATION_PATH)
	manager.clear_files()
	var old_payload: Dictionary = {
		"marker": "старый",
		"highest_stage": 3,
		"settings": {"sound_enabled": false},
	}
	var envelope: Dictionary = SaveManager.build_envelope(old_payload, TEST_TIME - 1000, 5)
	_check("Старый формат записан для проверки", SaveManager.store_envelope(envelope, MIGRATION_PATH))
	var loaded: Dictionary = manager.load_profile()
	var payload: Dictionary = _dict(loaded.get("payload", {}))
	var profile: Dictionary = _dict(payload.get("profile", {}))
	_check("Старый профиль обновлён", str(loaded.get("status", "")) == "migrated" and int(payload.get("migrated_from", 0)) == 5)
	_check("Данные старого профиля сохранены", str(payload.get("marker", "")) == "старый" and int(payload.get("highest_stage", 0)) == 3)
	_check("Версия формата повышена", int(payload.get("profile_version", 0)) == 8)
	_check("Состояние AFK создано при миграции", int(profile.get("last_offline_claim_at", 0)) == TEST_TIME - 1000)
	_check("Настройки перенесены", not bool(_dict(profile.get("settings", {})).get("sound_enabled", true)))
	_check("Недостающие настройки дополнены", int(_dict(profile.get("settings", {})).get("target_fps", 0)) == 60)
	manager.clear_files()


func _test_v6_to_v8_migration(data: Dictionary) -> void:
	var manager = SaveManager.new(data, MIGRATION_PATH)
	manager.clear_files()
	var old_payload: Dictionary = {
		"balance_version": 6,
		"stage_index": 4,
		"status": CampaignState.STATUS_COMPLETE,
		"highest_stage": 5,
		"level": 4,
		"experience": 33,
		"gold": 321,
		"materials": 44,
		"victories": 5,
		"profile": {"settings": {"sound_enabled": false}},
		"profile_version": 6,
	}
	var envelope: Dictionary = SaveManager.build_envelope(old_payload, TEST_TIME - 1000, 6)
	_check("Профиль шестого этапа записан для миграции", SaveManager.store_envelope(envelope, MIGRATION_PATH))
	var loaded: Dictionary = manager.load_profile()
	var payload: Dictionary = _dict(loaded.get("payload", {}))
	var modes: Dictionary = _dict(payload.get("modes", {}))
	_check("Профиль v6 обновлён до v8", str(loaded.get("status", "")) == "migrated" and int(payload.get("migrated_from", 0)) == 6)
	_check("Версия профиля и баланса повышена", int(payload.get("profile_version", 0)) == 8 and int(payload.get("balance_version", 0)) == 8)
	_check("Прогресс кампании сохранён при миграции", int(payload.get("stage_index", -1)) == 4 and int(payload.get("highest_stage", 0)) == 5 and int(payload.get("gold", 0)) == 321)
	_check("Состояние трёх режимов создано", modes.size() >= 6 and str(modes.get("active_mode", "")) == "campaign")
	_check("Победы режимов обнулены", _dict(modes.get("mode_victories", {})).size() == 3)
	_check("Настройки перенесены", not bool(_dict(_dict(payload.get("profile", {})).get("settings", {})).get("sound_enabled", true)))
	var state = CampaignState.new(data)
	state.import_state(payload)
	_check("Старое завершение не обрывает кампанию из 30 этапов", state.status == CampaignState.STATUS_BATTLE and state.stage_number() == 5)
	_check("Активный режим после миграции — кампания", state.mode_id() == "campaign")
	manager.clear_files()


func _test_v7_to_v8_migration(data: Dictionary) -> void:
	var manager = SaveManager.new(data, MIGRATION_PATH)
	manager.clear_files()
	var old_payload: Dictionary = {
		"balance_version": 7,
		"stage_index": 4,
		"highest_stage": 5,
		"profile": {"settings": {"sound_enabled": false, "particles_enabled": true, "target_fps": 30}},
		"profile_version": 7,
		"modes": {"active_mode": "campaign", "tower_floor": 3},
	}
	var envelope: Dictionary = SaveManager.build_envelope(old_payload, TEST_TIME - 1000, 7)
	_check("Профиль седьмого этапа записан для миграции", SaveManager.store_envelope(envelope, MIGRATION_PATH))
	var loaded: Dictionary = manager.load_profile()
	var payload: Dictionary = _dict(loaded.get("payload", {}))
	var settings: Dictionary = _dict(_dict(payload.get("profile", {})).get("settings", {}))
	_check("Профиль v7 обновлён до v8", str(loaded.get("status", "")) == "migrated" and int(payload.get("migrated_from", 0)) == 7)
	_check("Версии профиля и баланса обновлены", int(payload.get("profile_version", 0)) == 8 and int(payload.get("balance_version", 0)) == 8)
	_check("Настройки v7 сохранены", not bool(settings.get("sound_enabled", true)) and bool(settings.get("particles_enabled", false)) and int(settings.get("target_fps", 0)) == 30)
	_check("Настройка полных эффектов добавлена миграцией", bool(settings.get("effects_enabled", false)))
	_check("Прогресс кампании не потерян", int(payload.get("stage_index", -1)) == 4 and int(payload.get("highest_stage", 0)) == 5)
	manager.clear_files()


func _test_campaign_snapshot(data: Dictionary) -> void:
	var state = CampaignState.new(data, 321)
	state.stage_index = 2
	state.status = CampaignState.STATUS_VICTORY
	state.level = 3
	state.experience = 42
	state.gold = 250
	state.materials = 80
	state.victories = 2
	state.defeats = 1
	state.highest_stage = 4
	state.seed_value = 321
	state.last_reward = {"experience": 45, "gold": 12, "materials": 5}
	state.boss_phase_count = 2
	state.development.set_level(3, false)
	state.development.allocate_attribute("strength")
	state.development.increase_skill_level("heavy_strike")
	state.development.cycle_skill_variant("heavy_strike")
	state.development.toggle_skill_auto("heavy_strike")
	state.development.increase_passive_level("ashen_endurance")
	state.development.select_pet("ash_fox", 3)
	state.development.increase_pet_level("ash_fox")
	var summon: Dictionary = state.equipment.roll_summons("ash", 2, 3)
	var items: Array = _array(summon.get("items", []))
	if items.size() > 0 and items[0] is Dictionary:
		var first_id: String = str((items[0] as Dictionary).get("id", ""))
		state.equipment.equip(first_id)
		state.equipment.upgrade(first_id)
	var snapshot: Dictionary = state.export_state()
	_check("Снимок содержит версию баланса", int(snapshot.get("balance_version", 0)) == 8)
	_check("Снимок содержит экипировку и развитие", _dict(snapshot.get("equipment", {})).size() > 0 and _dict(snapshot.get("development", {})).size() > 0)
	_check("Состояние генератора предметов сохранено", str(_dict(snapshot.get("equipment", {})).get("rng_state", "")) != "")

	var restored = CampaignState.new(data, 999)
	restored.import_state(snapshot)
	_check("Этап восстановлен", restored.stage_index == 2 and restored.stage_number() == 3)
	_check("Результат этапа восстановлен", restored.status == CampaignState.STATUS_VICTORY)
	_check("Уровень и опыт восстановлены", restored.level == 3 and restored.experience == 42)
	_check("Валюта восстановлена", restored.gold == 250 and restored.materials == 80)
	_check("Счётчики побед и поражений восстановлены", restored.victories == 2 and restored.defeats == 1)
	_check("Последний достигнутый этап восстановлен", restored.highest_stage == 4)
	_check("Зерно и награда восстановлены", restored.seed_value == 321 and int(_dict(restored.last_reward).get("gold", 0)) == 12)
	_check("Фазы босса восстановлены", restored.boss_phase_count == 2)
	_check("Бой создан на сохранённом этапе", restored.system != null)
	_check("Инвентарь восстановлен", restored.equipment.inventory.size() == 2 and restored.equipment.total_summons == 2)
	_check("Надетый предмет восстановлен", int(restored.equipment.get_summary().get("equipped_count", 0)) > 0)
	_check("Генератор предметов восстановлен", restored.equipment.rng.state == state.equipment.rng.state)
	_check("Очко характеристики восстановлено", restored.development.get_attribute_points("strength") == 1)
	_check("Уровень навыка восстановлен", restored.development.get_skill_level("heavy_strike") == 2)
	_check("Вариант навыка восстановлен", restored.development.get_skill_variant("heavy_strike") == "haste")
	_check("Авто-режим навыка восстановлен", not restored.development.is_skill_auto("heavy_strike"))
	_check("Пассивная способность восстановлена", restored.development.get_passive_level("ashen_endurance") == 1)
	_check("Питомец восстановлен", restored.development.selected_pet_id == "ash_fox" and restored.development.get_pet_level("ash_fox") == 2)

	var offline: Dictionary = SaveCatalog.offline_rewards(data, TEST_TIME - 3600, TEST_TIME, 4)
	var gold_before: int = restored.gold
	var materials_before: int = restored.materials
	var applied: Dictionary = restored.apply_offline_rewards(offline)
	_check("Офлайн-награда применилась", bool(applied.get("success", false)))
	_check("Офлайн-золото начислено", restored.gold == gold_before + int(offline.get("gold", 0)))
	_check("Офлайн-пепел начислен", restored.materials == materials_before + int(offline.get("materials", 0)))
	_check("Офлайн-опыт учтён", int(applied.get("experience", 0)) == int(offline.get("experience", 0)) and restored.level >= 3)

	var mode_state = CampaignState.new(data, 777)
	mode_state.highest_stage = 20
	mode_state.gold = 500
	mode_state.materials = 500
	_check("Башня открыта на двадцатом этапе", bool(mode_state.select_mode("tower").get("success", false)))
	mode_state.mode_state["tower_floor"] = 9
	mode_state.mode_state["highest_tower_floor"] = 10
	mode_state.mode_state["dungeon_id"] = "experience"
	mode_state.mode_state["dungeon_runs"] = 3
	var wins: Dictionary = mode_state.mode_state.get("mode_victories", {}) as Dictionary
	wins["tower"] = 7
	var mode_snapshot: Dictionary = mode_state.export_state()
	var mode_restored = CampaignState.new(data, 999)
	mode_restored.import_state(mode_snapshot)
	_check("Активный режим восстановлен", mode_restored.mode_id() == "tower")
	_check("Ярус башни восстановлен", int(mode_restored.mode_state.get("tower_floor", -1)) == 9 and mode_restored.mode_number() == 10)
	_check("Выбранное подземелье восстановлено", str(mode_restored.mode_state.get("dungeon_id", "")) == "experience")
	_check("Счётчики режимов восстановлены", int(mode_restored.mode_state.get("dungeon_runs", 0)) == 3 and int(_dict(mode_restored.mode_state.get("mode_victories", {})).get("tower", 0)) == 7)

	var restart_state = CampaignState.new(data, 123)
	restart_state.stage_index = 4
	restart_state.highest_stage = 5
	restart_state.status = CampaignState.STATUS_COMPLETE
	_check("Новый поход запускается", restart_state.restart_campaign())
	_check("Новый поход сохраняет достигнутый этап", restart_state.highest_stage == 5 and restart_state.stage_index == 0)


func _test_restart_with_offline(data: Dictionary) -> void:
	SaveManager.new(data, RESTART_PATH).clear_files()
	var now0: int = TEST_TIME
	var now1: int = TEST_TIME + 3 * 3600
	var now2: int = now1 + 60

	var first_scene = MainScene.instantiate()
	root.add_child(first_scene)
	first_scene.set_process(false)
	first_scene.setup(data, RESTART_PATH, now0)
	_check("Первый запуск создал профиль", str(first_scene.profile_manager.get_report().get("status", "")) == "new")
	var first_state = first_scene.campaign
	first_state.stage_index = 2
	first_state.status = CampaignState.STATUS_VICTORY
	first_state.level = 3
	first_state.experience = 42
	first_state.gold = 250
	first_state.materials = 80
	first_state.victories = 2
	first_state.highest_stage = 4
	first_state.development.set_level(3, false)
	first_state.development.allocate_attribute("strength")
	first_state.development.increase_skill_level("heavy_strike")
	first_state.development.select_pet("ash_fox", 3)
	var summon: Dictionary = first_state.equipment.roll_summons("ash", 2, 3)
	var items: Array = _array(summon.get("items", []))
	if items.size() > 0 and items[0] is Dictionary:
		first_state.equipment.equip(str((items[0] as Dictionary).get("id", "")))
	var saved: Dictionary = first_scene.profile_manager.save("перед перезапуском")
	_check("Состояние перед перезапуском сохранено", bool(saved.get("success", false)))
	root.remove_child(first_scene)
	first_scene.free()

	var second_scene = MainScene.instantiate()
	root.add_child(second_scene)
	second_scene.set_process(false)
	second_scene.setup(data, RESTART_PATH, now1)
	var report2: Dictionary = second_scene.profile_manager.get_report()
	var offline2: Dictionary = _dict(report2.get("offline", {}))
	var second_state = second_scene.campaign
	_check("Профиль загружен после перезапуска", str(report2.get("status", "")) == "loaded")
	_check("Три часа отсутствия дали офлайн-награду", bool(offline2.get("eligible", false)) and int(offline2.get("credited_seconds", 0)) == 10800)
	_check("Офлайн-награда больше нуля", int(offline2.get("gold", 0)) > 0 and int(offline2.get("experience", 0)) > 0)
	_check("Кампания продолжилась с третьего этапа", second_state.stage_index == 2 and second_state.status == CampaignState.STATUS_VICTORY)
	_check("Уровень и валюта сохранены", second_state.level >= 3 and second_state.gold == 250 + int(offline2.get("gold", 0)))
	_check("Пепел с офлайн-наградой сохранён", second_state.materials == 80 + int(offline2.get("materials", 0)))
	_check("Достигнутый этап сохранён", second_state.highest_stage == 4)
	_check("Экипировка после перезапуска на месте", second_state.equipment.total_summons == 2 and int(second_state.equipment.get_summary().get("equipped_count", 0)) > 0)
	_check("Прогрессия после перезапуска на месте", second_state.development.get_attribute_points("strength") == 1 and second_state.development.get_skill_level("heavy_strike") == 2)
	_check("Питомец после перезапуска на месте", second_state.development.selected_pet_id == "ash_fox")
	_check("Журнал сообщает об офлайн-награде", "Офлайн" in second_scene.battle_log.text)
	_check("Журнал сообщает о профиле", "Профиль" in second_scene.battle_log.text)
	_check("Подсказка сообщает о локальном сохранении", "локальное сохранение" in second_scene.hint_label.text and "12 ч" in second_scene.hint_label.text)
	var profile2: Dictionary = _dict(report2.get("profile", {}))
	_check("Получение офлайн-награды учтено один раз", int(profile2.get("total_offline_claims", 0)) == 1)
	_check("Время отсутствия учтено в профиле", int(profile2.get("total_offline_seconds", 0)) >= 10800)
	_check("После загрузки профиль пересохранён", bool(_dict(report2.get("save", {})).get("success", false)))
	var gold_after_offline: int = second_state.gold
	root.remove_child(second_scene)
	second_scene.free()

	var third_scene = MainScene.instantiate()
	root.add_child(third_scene)
	third_scene.set_process(false)
	third_scene.setup(data, RESTART_PATH, now2)
	var report3: Dictionary = third_scene.profile_manager.get_report()
	var offline3: Dictionary = _dict(report3.get("offline", {}))
	_check("Короткое повторное отсутствие не даёт награду", not bool(offline3.get("eligible", true)))
	_check("Награда не выдана повторно", third_scene.campaign.gold == gold_after_offline)
	_check("Счётчик получений не удвоился", int(_dict(report3.get("profile", {})).get("total_offline_claims", 0)) == 1)
	root.remove_child(third_scene)
	third_scene.free()
	SaveManager.new(data, RESTART_PATH).clear_files()

func _test_settings_controls(data: Dictionary) -> void:
	SaveManager.new(data, SETTINGS_PATH).clear_files()
	var scene = MainScene.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.setup(data, SETTINGS_PATH, TEST_TIME)
	var defaults: Dictionary = scene.profile_manager.settings()
	_check("Звук по умолчанию включён", bool(defaults.get("sound_enabled", false)) and not AudioServer.is_bus_mute(0))
	_check("Частицы по умолчанию включены", bool(defaults.get("particles_enabled", false)) and scene.particles_effect.emitting and scene.particles_effect.visible)
	_check("Частота кадров применена к движку", Engine.max_fps == int(defaults.get("target_fps", 0)))
	_check("Кнопки настроек доступны", not scene.sound_button.disabled and not scene.particles_button.disabled and not scene.fps_button.disabled and not scene.effects_button.disabled)
	_check("Текст частоты кадров соответствует настройке", str(int(defaults.get("target_fps", 0))) in scene.fps_button.text)

	scene._on_sound_pressed()
	_check("Выключатель звука отключил шину", AudioServer.is_bus_mute(0) and "ВЫКЛ" in scene.sound_button.text)
	scene._on_particles_pressed()
	_check("Выключатель частиц остановил эффект", not scene.particles_effect.emitting and not scene.particles_effect.visible and "ВЫКЛ" in scene.particles_button.text)
	scene._on_effects_pressed()
	_check("Упрощённый режим отключил визуальные эффекты", not bool(scene.profile_manager.settings().get("effects_enabled", true)) and "ПРОСТЫЕ" in scene.effects_button.text and scene.effect_pool.pool_size() == 8)
	var previous_fps: int = Engine.max_fps
	scene._on_fps_pressed()
	_check("Кнопка частоты кадров изменила предел", Engine.max_fps != previous_fps and str(Engine.max_fps) in scene.fps_button.text)
	var changed: Dictionary = scene.profile_manager.settings()
	_check("Изменения записаны в профиль", not bool(changed.get("sound_enabled", true)) and not bool(changed.get("particles_enabled", true)) and not bool(changed.get("effects_enabled", true)))

	var saves_before: int = int(scene.profile_manager.get_report().get("total_saves", 0))
	scene.profile_manager.tick(float(SaveCatalog.autosave_interval_seconds(data)))
	_check("Автосохранение сработало по интервалу", int(scene.profile_manager.get_report().get("total_saves", 0)) > saves_before)
	scene._notification(NOTIFICATION_APPLICATION_PAUSED)
	_check("Пауза приложения сохранила профиль", int(scene.profile_manager.get_report().get("total_saves", 0)) > saves_before + 1)

	var gold_before: int = scene.campaign.gold
	scene.profile_manager.set_now(TEST_TIME + 3600)
	scene._notification(NOTIFICATION_APPLICATION_RESUMED)
	var resume_report: Dictionary = scene.profile_manager.get_report()
	var resume_offline: Dictionary = _dict(resume_report.get("offline", {}))
	_check("Возвращение после часа выдало офлайн-награду", bool(resume_offline.get("eligible", false)))
	_check("Офлайн-золото начислено при возвращении", scene.campaign.gold > gold_before)
	_check("Время последнего получения обновлено", int(_dict(resume_report.get("profile", {})).get("last_offline_claim_at", 0)) == TEST_TIME + 3600)
	root.remove_child(scene)
	scene.free()

	var reload_scene = MainScene.instantiate()
	root.add_child(reload_scene)
	reload_scene.set_process(false)
	reload_scene.setup(data, SETTINGS_PATH, TEST_TIME + 3660)
	var restored: Dictionary = reload_scene.profile_manager.settings()
	_check("Настройки восстановлены после перезапуска", not bool(restored.get("sound_enabled", true)) and not bool(restored.get("particles_enabled", true)) and not bool(restored.get("effects_enabled", true)) and restored.get("target_fps", 0) == changed.get("target_fps", 0))
	_check("Звук остался выключенным", AudioServer.is_bus_mute(0))
	_check("Частицы остались выключенными", not reload_scene.particles_effect.emitting)
	_check("Частота кадров восстановлена", Engine.max_fps == int(restored.get("target_fps", 0)))
	root.remove_child(reload_scene)
	reload_scene.free()
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_mute(0, false)
	Engine.max_fps = 0
	SaveManager.new(data, SETTINGS_PATH).clear_files()
