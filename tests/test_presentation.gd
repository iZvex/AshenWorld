extends SceneTree

# Точечная проверка восьмого этапа: централизованные параметры полировки,
# процедурный звук, пул эффектов, упрощённый режим, ограничение перерисовки
# интерфейса и офлайн-настройки Android. Полная сборка APK не требуется.
# Запуск: godot --headless --path . --script tests/test_presentation.gd

const CombatCatalog = preload("res://scripts/combat/combat_catalog.gd")
const SaveCatalog = preload("res://scripts/save/save_catalog.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")
const PresentationCatalog = preload("res://scripts/ui/presentation_catalog.gd")
const AshenStyle = preload("res://scripts/ui/ashen_style.gd")
const MainScene = preload("res://scenes/main/main.tscn")

const TEST_PROFILE_PATH: String = "user://test_presentation_profile.json"
const TEST_TIME: int = 1800000000

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("Проверка полировки, звука, эффектов и производительности")
	var data: Dictionary = CombatCatalog.load_balance()
	SaveManager.new(data, TEST_PROFILE_PATH).clear_files()
	_test_balance(data)
	_test_streams(data)
	_test_scene(data)
	SaveManager.new(data, TEST_PROFILE_PATH).clear_files()
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_mute(0, false)
	Engine.max_fps = 60
	print("Итого: %d проверок пройдено, %d провалено" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_balance(data: Dictionary) -> void:
	var section: Dictionary = PresentationCatalog.section(data)
	var interface: Dictionary = PresentationCatalog.interface_config(data)
	var fonts: Dictionary = interface.get("fonts", {}) as Dictionary
	var node_sizes: Dictionary = fonts.get("node_sizes", {}) as Dictionary
	var minimum_sizes: Dictionary = interface.get("minimum_sizes", {}) as Dictionary
	var layout: Dictionary = interface.get("layout", {}) as Dictionary
	var grid_columns: Dictionary = layout.get("grid_columns", {}) as Dictionary
	var navigation: Dictionary = interface.get("navigation", {}) as Dictionary
	var tabs: Dictionary = navigation.get("tabs", {}) as Dictionary
	_check("Читаемые шрифты заданы централизованно", int(fonts.get("default", 0)) >= 20 and node_sizes.size() >= 80)
	var nav_ratios: Dictionary = layout.get("nav_ratios", {}) as Dictionary
	_check("Размеры панелей заданы централизованно", minimum_sizes.size() >= 90 and nav_ratios.size() == 6 and not grid_columns.has("BottomTabs"))
	_check("Шесть разделов нижнего меню заданы в балансе", tabs.size() == 6 and (navigation.get("tab_order", []) as Array).size() == 6)
	_check("Оригинальный фон наброска задан в балансе", str(layout.get("background_texture", "")).ends_with("background_sketch.png"))
	var hud: Dictionary = interface.get("hud", {}) as Dictionary
	var nav_icons: Dictionary = hud.get("nav_icons", {}) as Dictionary
	var stub_icons: Dictionary = hud.get("stub_icons", {}) as Dictionary
	var stub_labels: Dictionary = hud.get("stub_labels", {}) as Dictionary
	var overlay_value: Variant = hud.get("battle_overlay", {})
	var overlay: Dictionary = overlay_value as Dictionary if overlay_value is Dictionary else {}
	var radius_value: Variant = overlay.get("orb_radius", {})
	var radii: Dictionary = radius_value as Dictionary if radius_value is Dictionary else {}
	_check("Конфигурация HUD наброска централизована", nav_icons.size() == 6 and not str(hud.get("nickname", "")).is_empty() and stub_icons.size() >= 8 and stub_labels.size() >= 4 and str(hud.get("stub_text", "")) == "СКОРО")
	_check("Боевой оверлей описан в balance.json", int(radii.get("StrikeButton", 0)) >= 56 and int(radii.get("GuardButton", 0)) >= 44 and int(overlay.get("log_lines", 0)) >= 3)
	var figures_value: Variant = hud.get("enemy_figures", {})
	var figures: Dictionary = figures_value as Dictionary if figures_value is Dictionary else {}
	var by_id_value: Variant = figures.get("by_id", {})
	var by_id: Dictionary = by_id_value as Dictionary if by_id_value is Dictionary else {}
	var pool_value: Variant = figures.get("figures", [])
	var pool: Array = pool_value as Array if pool_value is Array else []
	_check("Фигуры героя и войск заданы централизованно", str(hud.get("hero_figure", "")).contains("hero_battle") and pool.size() >= 3 and by_id.size() >= 10)
	_check("Портрет и силуэты врагов заданы локальными ресурсами", str(hud.get("portrait_texture", "")).ends_with("hero_portrait.png") and str(hud.get("enemy_texture", "")).ends_with("enemy_wraith.svg") and int(hud.get("enemy_cards", 0)) == 5)
	_check("Шкалы здоровья укрупнены централизованно", int((minimum_sizes.get("HeroHealthBar", [0, 0]) as Array)[1]) >= 26 and int((minimum_sizes.get("EnemyHealthBar", [0, 0]) as Array)[1]) >= 26)
	_check("Версия баланса восьмого этапа", int(data.get("version", 0)) == 8)
	_check("Раздел presentation добавлен", not section.is_empty())
	_check("Частота обновления интерфейса ограничена", PresentationCatalog.ui_refresh_seconds(data) <= 0.2)
	var performance: Dictionary = PresentationCatalog.performance_config(data)
	_check("Интервал замера кадров задан в балансе", float(performance.get("sample_seconds", 0.0)) > 0.0)
	_check("Порог низкой частоты кадров задан", float(performance.get("warning_fps", 0.0)) >= 30.0)
	var effects: Dictionary = PresentationCatalog.effect_pool_config(data)
	_check("Пул эффектов ограничен", int(effects.get("capacity", 0)) > 0 and int(effects.get("capacity", 0)) <= 16)
	_check("Длительности анимаций положительны", float(effects.get("label_duration_seconds", 0.0)) > 0.0 and float(effects.get("flash_duration_seconds", 0.0)) > 0.0)
	_check("Размеры подписей заданы централизованно", int(effects.get("label_font_size", 0)) >= 20 and int(effects.get("skill_font_size", 0)) >= 18)
	var particles: Dictionary = PresentationCatalog.particle_config(data)
	_check("Фоновых частиц меньше прежних восемнадцати", int(particles.get("amount", 99)) < 18 and int(particles.get("amount", 0)) > 0)
	_check("Цвет частиц задан в балансе", (particles.get("color", Color.WHITE) as Color).a > 0.0)
	var audio: Dictionary = PresentationCatalog.audio_config(data)
	var sounds: Dictionary = audio.get("sounds", {}) as Dictionary
	_check("Голоса и частота дискретизации заданы", int(audio.get("voice_count", 0)) > 0 and int(audio.get("mix_rate", 0)) >= 8000)
	_check("Все восемь звуковых событий описаны в балансе", sounds.size() == 8)
	for event_id in ["attack", "critical", "skill", "shield", "victory", "defeat", "boss", "click"]:
		var spec: Dictionary = sounds.get(event_id, {}) as Dictionary
		_check("Событие %s имеет параметры" % event_id, not spec.is_empty() and float(spec.get("duration_seconds", 0.0)) > 0.0)
	var defaults: Dictionary = SaveCatalog.default_settings(data)
	_check("Настройка полных эффектов сохранена", bool(defaults.get("effects_enabled", false)))
	var normalized: Dictionary = SaveCatalog.normalize_settings({"effects_enabled": 0, "target_fps": 47}, data)
	_check("Чужие значения эффектов нормализуются", not bool(normalized.get("effects_enabled", true)) and SaveCatalog.fps_options(data).has(int(normalized.get("target_fps", 0))))
	var preset: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	_check("Интернет у APK не запрашивается", "permissions/internet=false" in preset)
	_check("Состояние сети у APK не запрашивается", "permissions/access_network_state=false" in preset)


func _test_streams(data: Dictionary) -> void:
	var audio: Dictionary = PresentationCatalog.audio_config(data)
	var mix_rate: int = int(audio.get("mix_rate", 22050))
	var sounds: Dictionary = audio.get("sounds", {}) as Dictionary
	var streams: Dictionary = {}
	for event_id in sounds.keys():
		var spec: Dictionary = sounds[event_id] as Dictionary
		var stream: AudioStreamWAV = PresentationCatalog.build_stream(spec, mix_rate)
		streams[event_id] = stream
		_check("Звук %s создан в памяти" % str(event_id), stream.data.size() > 0 and stream.mix_rate == mix_rate and stream.format == AudioStreamWAV.FORMAT_16_BITS)
	var attack: AudioStreamWAV = streams["attack"] as AudioStreamWAV
	var victory: AudioStreamWAV = streams["victory"] as AudioStreamWAV
	_check("Короткие звуки различаются по длительности", victory.data.size() > attack.data.size())
	_check("PCM-данные кратны двум байтам", attack.data.size() % 2 == 0)
	_check("Звуки не привязаны к внешним файлам", DirAccess.open("res://assets/audio") == null)


func _test_scene(data: Dictionary) -> void:
	var scene = MainScene.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.setup(data, TEST_PROFILE_PATH, TEST_TIME)
	_check("Сцена полировки создана", scene.audio_player != null and scene.effect_pool != null)
	var interface: Dictionary = PresentationCatalog.interface_config(data)
	var fonts: Dictionary = interface.get("fonts", {}) as Dictionary
	_check("Базовый шрифт применён из баланса", scene.theme.default_font_size == int(fonts.get("default", 0)))
	_check("Нижние вкладки идут одной полосой и остаются крупными", scene.bottom_tabs.get_child_count() == 6 and scene.battle_button.get_theme_font_size("font_size") >= 18)
	_check("Экран боя открыт по умолчанию", scene.active_tab == "battle" and scene.battle_panel.visible and not scene.summon_panel.visible)
	_check("Пул голосов создан один раз", scene.audio_player.voice_count() == 6 and scene.audio_player.stream_count() == 8)
	_check("Пул подписей создан один раз", scene.effect_pool.pool_size() == 8)
	_check("Фоновые частицы настроены из баланса", scene.particles_effect.amount == 12)
	_check("Четыре настройки доступны", not scene.sound_button.disabled and not scene.particles_button.disabled and not scene.fps_button.disabled and not scene.effects_button.disabled)

	var children_before: int = scene.get_child_count()
	for index in range(12):
		scene._spawn_floating_number(str(index), scene.hero_side, AshenStyle.GOLD, 20)
	_check("Пул не создаёт новые узлы на каждый эффект", scene.get_child_count() == children_before)
	_check("Число активных подписей ограничено", scene.effect_pool.active_count() == 8)
	scene.effect_pool._process(1.0)
	_check("Подписи возвращаются в пул", scene.effect_pool.active_count() == 0)
	scene.effect_pool.flash(scene.hero_side, AshenStyle.CRIMSON)
	_check("Подсветка не создаёт отдельный Tween", scene.effect_pool.active_flash_count() == 1 and scene.hero_side.modulate != Color.WHITE)
	scene.effect_pool._process(1.0)
	_check("Подсветка возвращает исходный цвет", scene.effect_pool.active_flash_count() == 0 and scene.hero_side.modulate == Color.WHITE)

	scene._on_sound_pressed()
	_check("Выключатель звука отключил шину и голоса", AudioServer.is_bus_mute(0) and not scene.audio_player.enabled)
	scene._on_sound_pressed()
	_check("Выключатель звука вернул шину и голоса", not AudioServer.is_bus_mute(0) and scene.audio_player.enabled)

	scene._on_effects_pressed()
	_check("Упрощённый режим записан в профиль", not bool(scene.profile_manager.settings().get("effects_enabled", true)))
	_check("Упрощённый режим показан кнопкой", "ПРОСТЫЕ" in scene.effects_button.text)
	_check("Упрощённый режим выключил частицы", not scene.particles_effect.emitting and not scene.particles_effect.visible)
	scene._flash(scene.hero_side, AshenStyle.CRIMSON)
	scene._spawn_floating_number("100", scene.enemy_cards[0], AshenStyle.GOLD)
	_check("Упрощённый режим отключил анимации", scene.effect_pool.active_count() == 0 and scene.effect_pool.active_flash_count() == 0)
	scene._on_effects_pressed()
	_check("Полные эффекты возвращены", bool(scene.profile_manager.settings().get("effects_enabled", false)) and "ПОЛНЫЕ" in scene.effects_button.text and scene.particles_effect.emitting)

	scene.stage_label.text = "МАРКЕР"
	scene._process(0.01)
	_check("Мелкий кадр не перерисовывает весь интерфейс", scene.stage_label.text == "МАРКЕР" and scene.view_refresh_timer > 0.0)
	scene._process(0.1)
	_check("Перерисовка выполняется по интервалу из баланса", "Этап" in scene.stage_label.text and "УДАР" in scene.hint_label.text)
	_check("Технические значения не попадают в боевую подсказку", not ("КАДРЫ" in scene.hint_label.text) and "КАДРЫ" in scene.performance_label.text)
	scene._process(1.0)
	_check("Замер частоты кадров не отрицательный", scene.measured_fps >= 0.0)
	_check("Портретный HUD сохранён при упрощённых эффектах", scene.hero_portrait.texture != null and "ГЕРОЙ" in scene.hero_label.text and not scene.enemy_label.text.is_empty() and scene.nickname_label.text != "")

	root.remove_child(scene)
	scene.free()


func _check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("  ✓ ", name)
	else:
		failed += 1
		printerr("  ✗ ", name)
