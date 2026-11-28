# Справочник публичного API

Файл создаётся автоматически командой `python3 tools/api_report.py` из комментариев и объявлений в `scripts/**/*.gd`. Руками его не правят: смысловые контракты подсистем описаны в `docs/api.md`, границы и точки расширения — в `docs/boundaries.md`. Сборка проверяет актуальность файла через `python3 tools/api_report.py --check`.

Служебные методы и приватные поля (с префиксом `_`) в справочник не попадают.

## Ядро и конфигурация

Каталог `scripts/core/`.

### `scripts/core/game_config.gd`

- Наследует: `Node`
- Назначение: Единый источник параметров баланса. Все вероятности, цены и коэффициенты хранятся в data/balance.json и не дублируются в других скриптах.
- Публичных методов: 1

**Публичные константы**

- `BALANCE_PATH: String = "res://data/balance.json"`

**Публичное состояние**

- `values: Dictionary`

**Методы**

- `func get_section(name: String) -> Dictionary`

## Бой

Каталог `scripts/combat/`.

### `scripts/combat/combat_catalog.gd`

- Наследует: `RefCounted`
- Назначение: Чтение боевых данных из единого файла баланса. Используется и игрой, и точечным тестом, поэтому правила загрузки не дублируются.
- Публичных методов: 7

**Публичные константы**

- `BALANCE_PATH: String = "res://data/balance.json"`

**Методы**

- `static func load_balance() -> Dictionary`
- `static func combat_balance(balance: Dictionary) -> Dictionary`
- `static func hero_data(balance: Dictionary) -> Dictionary`
- `static func skill_map(balance: Dictionary) -> Dictionary`
- `static func campaign_data(balance: Dictionary) -> Dictionary`
- `static func campaign_stages(balance: Dictionary) -> Array`
- `static func enemy_list(balance: Dictionary) -> Array`

### `scripts/combat/combat_formulas.gd`

- Наследует: `RefCounted`
- Назначение: Все формулы боя собраны здесь и читают коэффициенты из единого файла баланса. Дублировать расчёты в других скриптах запрещено.
- Публичных методов: 4

**Публичные константы**

- `DEFAULT_REDUCTION_PER_POINT: float = 0.02`
- `DEFAULT_MAX_REDUCTION: float = 0.6`
- `DEFAULT_CRITICAL_MULTIPLIER: float = 1.5`
- `DEFAULT_MAX_RESISTANCE: float = 0.35`

**Методы**

- `static func defense_reduction(defense: float, balance: Dictionary) -> float`
- `static func calculate_damage( attack: float, target_defense: float, multiplier: float, is_critical: bool, balance: Dictionary, critical_multiplier_override: float = -1.0, target_resistance: float = 0.0, ) -> float`
- `static func roll_critical(crit_chance: float, rng: RandomNumberGenerator) -> bool`
- `static func roll_dodge(dodge_chance: float, rng: RandomNumberGenerator) -> bool`

### `scripts/combat/combat_system.gd`

- Наследует: `RefCounted`
- Назначение: Логика автоматического боя: не зависит от сцен и интерфейса, поэтому проверяется отдельным точечным тестом без запуска всей игры. Новые боевые параметры читаются из hero_data, а помощь питомца — из pet_data.
- Публичных методов: 7

**Сигналы**

- `damage_dealt(target_name: String, amount: float, is_critical: bool)`
- `enemy_defeated(enemy_name: String)`
- `hero_defeated()`
- `skill_used(skill_name: String)`
- `shield_changed(amount: float)`
- `enemy_phase_started(enemy_name: String, phase_name: String, attack_multiplier: float)`
- `pet_attack(pet_name: String, assist_name: String, amount: float)`
- `hero_healed(amount: float)`
- `attack_dodged(target_name: String)`

**Публичное состояние**

- `balance: Dictionary`
- `hero: Variant`
- `enemy: Variant`
- `enemies: Array`
- `skills: Dictionary`
- `rng: RandomNumberGenerator`
- `elapsed: float`
- `hero_interval: float`
- `enemy_interval: float`
- `hero_next_attack: float`
- `enemy_next_attack: float`
- `skill_cooldowns: Dictionary`
- `enemy_index: int`
- `running: bool`
- `boss_phase_count: int`
- `current_boss_phase_active: bool`
- `current_boss_phase_name: String`
- `last_boss_phase_enemy: String`
- `last_boss_phase_name: String`
- `pet_name: String`
- `assist_name: String`
- `pet_attack_ratio: float`
- `pet_interval: float`
- `pet_next_attack: float`
- `pet_attack_count: int`

**Методы**

- `func set_pet_data(pet_data: Dictionary) -> void`
- `func spawn_next_enemy(interval: float = -1.0) -> void`
- `func advance(delta: float) -> void`
- `func perform_attack(attacker, target, multiplier: float, crit_chance_bonus: float = 0.0) -> void`
- `func use_skill(skill_id: String) -> bool`
- `func get_cooldown_remaining(skill_id: String) -> float`
- `func get_state() -> Dictionary`

### `scripts/combat/combatant.gd`

- Наследует: `RefCounted`
- Назначение: Состояние одного участника боя. Формулы урона сюда не входят: они собраны в combat_formulas.gd и не дублируются.
- Публичных методов: 4

**Публичное состояние**

- `display_name: String`
- `max_health: float`
- `health: float`
- `attack: float`
- `base_attack: float`
- `physical_attack: float`
- `magic_attack: float`
- `defense: float`
- `crit_chance: float`
- `critical_multiplier: float`
- `attack_interval_seconds: float`
- `lifesteal: float`
- `dodge: float`
- `resistance: float`
- `health_regen: float`
- `shield: float`
- `alive: bool`
- `is_boss: bool`
- `phase_threshold: float`
- `phase_attack_multiplier: float`
- `phase_name: String`
- `phase_activated: bool`

**Методы**

- `func receive_damage(amount: float) -> float`
- `func heal(amount: float) -> float`
- `func add_shield(amount: float) -> void`
- `func restore() -> void`

## Кампания и режимы

Каталог `scripts/campaign/`.

### `scripts/campaign/campaign_catalog.gd`

- Наследует: `RefCounted`
- Назначение: Преобразование данных кампании в список противников для одного этапа. Все названия, масштабы и награды берутся из единого файла баланса.
- Публичных методов: 7

**Методы**

- `static func campaign(balance: Dictionary) -> Dictionary`
- `static func stages(balance: Dictionary) -> Array`
- `static func stage_at(balance: Dictionary, index: int) -> Dictionary`
- `static func stage_count(balance: Dictionary) -> int`
- `static func stage_is_boss(stage: Dictionary) -> bool`
- `static func stage_kind(stage: Dictionary) -> String`
- `static func build_enemy_list(stage: Dictionary, balance: Dictionary) -> Array`

### `scripts/campaign/campaign_state.gd`

- Наследует: `RefCounted`
- Назначение: Состояние игрового цикла: этапы, победы, опыт, валюта, экипировка и прогрессия. Шестой этап добавил экспорт и импорт долгосрочного состояния, седьмой — 30 этапов, три режима и миграцию их состояния.
- Публичных методов: 55

**Сигналы**

- `boss_phase_started(enemy_name: String, phase_name: String)`

**Публичные константы**

- `STATUS_BATTLE: int = 0`
- `STATUS_VICTORY: int = 1`
- `STATUS_DEFEAT: int = 2`
- `STATUS_COMPLETE: int = 3`

**Публичное состояние**

- `balance: Dictionary`
- `stages: Array`
- `leveling: Dictionary`
- `economy: Dictionary`
- `campaign: Dictionary`
- `mode_state: Dictionary`
- `active_mode_id: String`
- `equipment: Variant`
- `development: Variant`
- `stage_index: int`
- `level: int`
- `experience: int`
- `gold: int`
- `materials: int`
- `victories: int`
- `defeats: int`
- `highest_stage: int`
- `status: int`
- `system: Variant`
- `last_reward: Dictionary`
- `boss_phase_count: int`
- `current_boss_phase_active: bool`
- `current_boss_phase_name: String`
- `observed_phase_counts: Dictionary`
- `pet_attack_count: int`
- `observed_pet_counts: Dictionary`
- `auto_skill_timer: float`
- `stage_elapsed: float`
- `seed_value: int`

**Методы**

- `func start_stage() -> void`
- `func advance(delta: float) -> void`
- `func use_skill(skill_id: String) -> bool`
- `func get_cooldown_remaining(skill_id: String) -> float`
- `func next_stage() -> bool`
- `func retry_stage() -> bool`
- `func restart_campaign() -> bool`
- `func current_stage() -> Dictionary`
- `func campaign_stage_number() -> int`
- `func stage_number() -> int`
- `func active_index() -> int`
- `func mode_number() -> int`
- `func mode_count() -> int`
- `func mode_id() -> String`
- `func mode_state_view() -> Dictionary`
- `func mode_is_unlocked(mode_id_value: String) -> bool`
- `func dungeon_block_reason(dungeon_id: String) -> String`
- `func mode_status_key() -> String`
- `func mode_status_name(value: int) -> String`
- `func stage_count() -> int`
- `func hero_data() -> Dictionary`
- `func experience_to_next() -> int`
- `func summon_equipment(summon_id: String, count: int = 1) -> Dictionary`
- `func equip_item(item_id: String) -> bool`
- `func auto_equip_items() -> int`
- `func upgrade_item(item_id: String) -> Dictionary`
- `func dismantle_item(item_id: String, force: bool = false) -> Dictionary`
- `func mass_dismantle_items() -> Dictionary`
- `func toggle_item_lock(item_id: String) -> bool`
- `func set_equipment_filters(slot_index: int, rarity_index: int, affix_index: int) -> void`
- `func allocate_attribute(attribute_id: String) -> bool`
- `func upgrade_skill(skill_id: String) -> Dictionary`
- `func toggle_skill_auto(skill_id: String) -> bool`
- `func cycle_skill_variant(skill_id: String) -> String`
- `func upgrade_passive(passive_id: String) -> Dictionary`
- `func select_pet(pet_id: String) -> bool`
- `func upgrade_pet(pet_id: String) -> Dictionary`
- `func get_skill_ids() -> Array`
- `func get_passive_ids() -> Array`
- `func get_pet_ids() -> Array`
- `func get_skill_view(skill_id: String) -> Dictionary`
- `func get_passive_view(passive_id: String) -> Dictionary`
- `func get_pet_view(pet_id: String) -> Dictionary`
- `func get_balance_report() -> Dictionary`
- `func get_auto_battle_report() -> Dictionary`
- `func get_summary() -> Dictionary`
- `static func status_name(value: int) -> String`
- `func export_state() -> Dictionary`
- `func import_state(snapshot: Dictionary) -> void`
- `func select_mode(mode_id_value: String) -> Dictionary`
- `func select_dungeon(dungeon_id: String) -> Dictionary`
- `func repeat_dungeon() -> bool`
- `func restart_mode() -> bool`
- `func grant_experience(amount: int) -> Dictionary`
- `func apply_offline_rewards(report: Dictionary) -> Dictionary`

### `scripts/campaign/mode_catalog.gd`

- Наследует: `RefCounted`
- Назначение: Единый каталог трёх режимов седьмого этапа: кампания из 30 этапов, Башня испытаний и Подземелья ресурсов. Все названия, цены входа, награды, масштабы и подписи читаются из раздела modes файла balance.json.
- Публичных методов: 35

**Методы**

- `static func modes_data(balance: Dictionary) -> Dictionary`
- `static func mode_list(balance: Dictionary) -> Array`
- `static func mode_ids(balance: Dictionary) -> Array`
- `static func mode_by_id(balance: Dictionary, mode_id: String) -> Dictionary`
- `static func mode_name(balance: Dictionary, mode_id: String) -> String`
- `static func mode_short(balance: Dictionary, mode_id: String) -> String`
- `static func mode_region(balance: Dictionary, mode_id: String) -> String`
- `static func mode_description(balance: Dictionary, mode_id: String) -> String`
- `static func mode_unlock_stage(balance: Dictionary, mode_id: String) -> int`
- `static func is_mode_unlocked(balance: Dictionary, mode_id: String, highest_stage: int) -> bool`
- `static func mode_unlock_reason(balance: Dictionary, mode_id: String, highest_stage: int) -> String`
- `static func tower_data(balance: Dictionary) -> Dictionary`
- `static func tower_floors(balance: Dictionary) -> Array`
- `static func dungeon_data(balance: Dictionary) -> Dictionary`
- `static func dungeon_runs(balance: Dictionary) -> Array`
- `static func dungeon_ids(balance: Dictionary) -> Array`
- `static func first_dungeon_id(balance: Dictionary) -> String`
- `static func dungeon_by_id(balance: Dictionary, dungeon_id: String) -> Dictionary`
- `static func dungeon_name(balance: Dictionary, dungeon_id: String) -> String`
- `static func dungeon_short(balance: Dictionary, dungeon_id: String) -> String`
- `static func dungeon_unlock_stage(balance: Dictionary, dungeon_id: String) -> int`
- `static func is_dungeon_unlocked(balance: Dictionary, dungeon_id: String, highest_stage: int) -> bool`
- `static func dungeon_entry_cost(balance: Dictionary, dungeon_id: String) -> Dictionary`
- `static func dungeon_block_reason( balance: Dictionary, dungeon_id: String, highest_stage: int, gold: int, materials: int, ) -> String`
- `static func dungeon_reward(balance: Dictionary, dungeon_id: String) -> Dictionary`
- `static func stage_count(balance: Dictionary, mode_id: String) -> int`
- `static func default_state(balance: Dictionary) -> Dictionary`
- `static func first_mode_id(balance: Dictionary) -> String`
- `static func normalize_state(value: Variant, balance: Dictionary, highest_stage: int = 1) -> Dictionary`
- `static func state_from_snapshot(snapshot: Dictionary, balance: Dictionary, highest_stage: int = 1) -> Dictionary`
- `static func stage_at(balance: Dictionary, mode_id: String, index: int, state: Dictionary) -> Dictionary`
- `static func progress_text(balance: Dictionary, mode_id: String, state: Dictionary, current: int, total: int) -> String`
- `static func action_text( balance: Dictionary, mode_id: String, status_key: String, current: int, state: Dictionary, ) -> String`
- `static func status_key(status: int) -> String`
- `static func mode_stats_text(balance: Dictionary, state: Dictionary) -> String`

## Экипировка и призыв

Каталог `scripts/equipment/`.

### `scripts/equipment/equipment_catalog.gd`

- Наследует: `RefCounted`
- Назначение: Чтение данных экипировки из единого файла баланса и общие вычисления силы. Здесь нет состояния игрока: инвентарь и призывы живут в equipment_state.gd.
- Публичных методов: 24

**Методы**

- `static func equipment_data(balance: Dictionary) -> Dictionary`
- `static func slots(balance: Dictionary) -> Array`
- `static func rarities(balance: Dictionary) -> Array`
- `static func affixes(balance: Dictionary) -> Array`
- `static func summons(balance: Dictionary) -> Dictionary`
- `static func upgrade_data(balance: Dictionary) -> Dictionary`
- `static func dismantle_data(balance: Dictionary) -> Dictionary`
- `static func protection_data(balance: Dictionary) -> Dictionary`
- `static func score_weights(balance: Dictionary) -> Dictionary`
- `static func summon_ids(balance: Dictionary) -> Array`
- `static func slot_by_id(balance: Dictionary, slot_id: String) -> Dictionary`
- `static func rarity_by_id(balance: Dictionary, rarity_id: String) -> Dictionary`
- `static func summon_by_id(balance: Dictionary, summon_id: String) -> Dictionary`
- `static func rarity_score(balance: Dictionary, rarity_id: String) -> int`
- `static func rarity_color(balance: Dictionary, rarity_id: String) -> Color`
- `static func rarity_marks(balance: Dictionary, rarity_id: String) -> String`
- `static func slot_id_by_index(balance: Dictionary, index: int) -> String`
- `static func rarity_id_by_index(balance: Dictionary, index: int) -> String`
- `static func stat_key_by_index(balance: Dictionary, index: int) -> String`
- `static func score(balance: Dictionary, stats: Dictionary) -> float`
- `static func stats_text(stats: Dictionary) -> String`
- `static func probability_sum(balance: Dictionary, summon_id: String) -> float`
- `static func probability_text(balance: Dictionary, summon_id: String) -> String`
- `static func summon_info(balance: Dictionary, summon_id: String) -> String`

### `scripts/equipment/equipment_state.gd`

- Наследует: `RefCounted`
- Назначение: Состояние экипировки четвёртого этапа: призывы, редкости, инвентарь, сравнение, надевание, улучшение, блокировка и защита от разбора.
- Публичных методов: 27

**Публичное состояние**

- `balance: Dictionary`
- `rng: RandomNumberGenerator`
- `seed_value: int`
- `next_item_id: int`
- `inventory: Array`
- `equipped: Dictionary`
- `history: Array`
- `summons_since_guaranteed: Dictionary`
- `total_summons: int`
- `filter_slot_index: int`
- `filter_rarity_index: int`
- `filter_affix_index: int`

**Методы**

- `func reset() -> void`
- `func get_summon_ids() -> Array`
- `func get_summon_cost(summon_id: String, count: int) -> Dictionary`
- `func is_summon_unlocked(summon_id: String, stage_number: int) -> bool`
- `func summon_block_reason(summon_id: String, count: int, stage_number: int, gold: int, materials: int) -> String`
- `func roll_summons(summon_id: String, count: int, stage_number: int) -> Dictionary`
- `func get_item(item_id: String) -> Dictionary`
- `func set_filters(slot_index: int, rarity_index: int, affix_index: int) -> void`
- `func get_filter_values() -> Dictionary`
- `func get_filtered_inventory() -> Array`
- `func equip(item_id: String) -> bool`
- `func auto_equip() -> int`
- `func is_equipped(item_id: String) -> bool`
- `func get_equipped_item(slot_id: String) -> Dictionary`
- `func get_total_bonuses() -> Dictionary`
- `func compare(item_id: String) -> Dictionary`
- `func get_upgrade_cost(item_id: String) -> Dictionary`
- `func upgrade(item_id: String) -> bool`
- `func dismantle_block_reason(item_id: String, force: bool) -> String`
- `func can_dismantle(item_id: String, force: bool = false) -> bool`
- `func dismantle(item_id: String, force: bool = false) -> Dictionary`
- `func mass_dismantle() -> Dictionary`
- `func toggle_lock(item_id: String) -> bool`
- `func export_state() -> Dictionary`
- `func import_state(snapshot: Dictionary) -> void`
- `func get_summary() -> Dictionary`
- `func history_text(limit: int = 3) -> String`

## Прогрессия героя

Каталог `scripts/progression/`.

### `scripts/progression/progression_catalog.gd`

- Наследует: `RefCounted`
- Назначение: Чтение и расчёт прогрессии пятого этапа. Здесь собраны формулы характеристик, уровни навыков, пассивные бонусы, питомцы и оценка баланса. Состояние игрока хранится отдельно в progression_state.gd.
- Публичных методов: 41

**Методы**

- `static func leveling(balance: Dictionary) -> Dictionary`
- `static func combat_settings(balance: Dictionary) -> Dictionary`
- `static func attributes(balance: Dictionary) -> Array`
- `static func attribute_ids(balance: Dictionary) -> Array`
- `static func attribute_by_id(balance: Dictionary, attribute_id: String) -> Dictionary`
- `static func attribute_max_points(balance: Dictionary, attribute_id: String) -> int`
- `static func coefficients(balance: Dictionary) -> Dictionary`
- `static func skills(balance: Dictionary) -> Dictionary`
- `static func skill_ids(balance: Dictionary) -> Array`
- `static func skill_by_id(balance: Dictionary, skill_id: String) -> Dictionary`
- `static func skill_variants(balance: Dictionary) -> Dictionary`
- `static func passives(balance: Dictionary) -> Dictionary`
- `static func passive_ids(balance: Dictionary) -> Array`
- `static func passive_by_id(balance: Dictionary, passive_id: String) -> Dictionary`
- `static func pets(balance: Dictionary) -> Dictionary`
- `static func pet_ids(balance: Dictionary) -> Array`
- `static func pet_by_id(balance: Dictionary, pet_id: String) -> Dictionary`
- `static func balance_settings(balance: Dictionary) -> Dictionary`
- `static func auto_battle_settings(balance: Dictionary) -> Dictionary`
- `static func auto_battle_report(balance: Dictionary, auto_skill_count: int, stage_duration_seconds: float) -> Dictionary`
- `static func stage_power_targets(balance: Dictionary) -> Array`
- `static func power_weights(balance: Dictionary) -> Dictionary`
- `static func effective_points(balance: Dictionary, points: int) -> float`
- `static func empty_bonuses() -> Dictionary`
- `static func merge_bonuses(target: Dictionary, source: Dictionary) -> void`
- `static func attribute_bonuses(balance: Dictionary, allocated: Dictionary) -> Dictionary`
- `static func passive_bonuses(balance: Dictionary, levels: Dictionary) -> Dictionary`
- `static func pet_bonuses(balance: Dictionary, selected_pet_id: String, pet_levels: Dictionary) -> Dictionary`
- `static func total_bonuses(balance: Dictionary, allocated: Dictionary, passive_levels: Dictionary, selected_pet_id: String, pet_levels: Dictionary) -> Dictionary`
- `static func build_hero_data(balance: Dictionary, base_hero: Dictionary, hero_level: int, equipment_bonuses: Dictionary, development_bonuses: Dictionary) -> Dictionary`
- `static func effective_skill_map(balance: Dictionary, hero_level: int, skill_levels: Dictionary, variants: Dictionary, auto_overrides: Dictionary) -> Dictionary`
- `static func skill_upgrade_cost(balance: Dictionary, skill_id: String, current_level: int, hero_level: int) -> Dictionary`
- `static func passive_upgrade_cost(balance: Dictionary, passive_id: String, current_level: int, hero_level: int) -> Dictionary`
- `static func pet_upgrade_cost(balance: Dictionary, pet_id: String, current_level: int, stage_number: int) -> Dictionary`
- `static func pet_combat_data(balance: Dictionary, selected_pet_id: String, pet_levels: Dictionary) -> Dictionary`
- `static func power_score(balance: Dictionary, hero_stats: Dictionary) -> float`
- `static func balance_report(balance: Dictionary, hero_stats: Dictionary, stage_number: int) -> Dictionary`
- `static func attribute_button_text(balance: Dictionary, attribute_id: String, points: int) -> String`
- `static func is_skill_unlocked(balance: Dictionary, skill_id: String, hero_level: int) -> bool`
- `static func is_passive_unlocked(balance: Dictionary, passive_id: String, hero_level: int) -> bool`
- `static func is_pet_unlocked(balance: Dictionary, pet_id: String, stage_number: int) -> bool`

### `scripts/progression/progression_state.gd`

- Наследует: `RefCounted`
- Назначение: Состояние прогрессии игрока: очки характеристик и навыков, уровни активных и пассивных способностей, варианты развития, автоприменение и питомцы. Валюты живут в CampaignState, поэтому здесь нет копий кошелька.
- Публичных методов: 28

**Публичное состояние**

- `balance: Dictionary`
- `level: int`
- `attribute_points: int`
- `skill_points: int`
- `allocated: Dictionary`
- `skill_levels: Dictionary`
- `skill_variants: Dictionary`
- `skill_auto_use: Dictionary`
- `passive_levels: Dictionary`
- `pet_levels: Dictionary`
- `selected_pet_id: String`

**Методы**

- `func reset() -> void`
- `func set_level(new_level: int, grant_rewards: bool = false) -> void`
- `func grant_level_rewards(levels_gained: int) -> void`
- `func allocate_attribute(attribute_id: String) -> bool`
- `func get_attribute_points(attribute_id: String) -> int`
- `func get_bonuses() -> Dictionary`
- `func get_effective_skill_map() -> Dictionary`
- `func get_auto_skill_ids() -> Array`
- `func get_skill_level(skill_id: String) -> int`
- `func get_skill_variant(skill_id: String) -> String`
- `func is_skill_auto(skill_id: String) -> bool`
- `func get_skill_upgrade_cost(skill_id: String) -> Dictionary`
- `func spend_skill_points(amount: int) -> bool`
- `func increase_skill_level(skill_id: String) -> bool`
- `func toggle_skill_auto(skill_id: String) -> bool`
- `func cycle_skill_variant(skill_id: String) -> String`
- `func get_passive_level(passive_id: String) -> int`
- `func get_passive_upgrade_cost(passive_id: String) -> Dictionary`
- `func increase_passive_level(passive_id: String) -> bool`
- `func is_pet_unlocked(pet_id: String, stage_number: int) -> bool`
- `func select_pet(pet_id: String, stage_number: int) -> bool`
- `func get_pet_level(pet_id: String) -> int`
- `func get_pet_upgrade_cost(pet_id: String, stage_number: int) -> Dictionary`
- `func increase_pet_level(pet_id: String) -> bool`
- `func get_pet_combat_data() -> Dictionary`
- `func export_state() -> Dictionary`
- `func import_state(snapshot: Dictionary) -> void`
- `func get_summary() -> Dictionary`

## Сохранения и профиль

Каталог `scripts/save/`.

### `scripts/save/profile_manager.gd`

- Наследует: `RefCounted`
- Назначение: Связывает локальный профиль с игровым состоянием: загрузка при старте, миграция, офлайн-награды, автосохранение и сохранение при выходе. Формулы и настройки читаются только через save_catalog.gd.
- Публичных методов: 12

**Публичное состояние**

- `balance: Dictionary`
- `manager: Variant`
- `campaign: Variant`
- `now_override: int`
- `format_version: int`
- `autosave_interval: float`
- `autosave_timer: float`
- `profile: Dictionary`
- `startup_status: String`
- `startup_message: String`
- `last_saved_at: int`
- `last_save_result: Dictionary`
- `last_offline_report: Dictionary`
- `startup_log_lines: Array`
- `total_saves: int`

**Методы**

- `func current_now() -> int`
- `func settings() -> Dictionary`
- `func set_setting(key: String, value: Variant) -> void`
- `func set_now(value: int) -> void`
- `func bootstrap(state) -> Dictionary`
- `func collect_offline() -> Dictionary`
- `func save(reason: String) -> Dictionary`
- `func tick(delta: float) -> void`
- `func on_pause() -> Dictionary`
- `func on_resume() -> Dictionary`
- `func hint_text() -> String`
- `func get_report() -> Dictionary`

### `scripts/save/save_catalog.gd`

- Наследует: `RefCounted`
- Назначение: Единые правила шестого–восьмого этапов: настройки локального профиля, лимит AFK, эффективность по последнему достигнутому этапу и формула офлайн-наград. Здесь же находятся подписи для интерфейса, чтобы не дублировать их в main.gd.
- Публичных методов: 25

**Публичные константы**

- `DEFAULT_LIMIT_HOURS: float = 12.0`
- `DEFAULT_TICK_SECONDS: int = 300`
- `DEFAULT_MIN_SECONDS: int = 300`
- `DEFAULT_AFK_EFFICIENCY: float = 0.35`
- `DEFAULT_ACTIVE_EFFICIENCY: float = 1.0`
- `DEFAULT_STAGE_EFFICIENCY: float = 0.1`
- `DEFAULT_MAX_STAGE_MULTIPLIER: float = 1.5`
- `DEFAULT_AUTOSAVE_SECONDS: float = 15.0`
- `DEFAULT_FORMAT_VERSION: int = 8`
- `DEFAULT_MAX_PROFILE_BYTES: int = 1048576`

**Методы**

- `static func save_settings(balance: Dictionary) -> Dictionary`
- `static func afk_settings(balance: Dictionary) -> Dictionary`
- `static func format_version(balance: Dictionary) -> int`
- `static func profile_path(balance: Dictionary) -> String`
- `static func temp_suffix(balance: Dictionary) -> String`
- `static func backup_suffix(balance: Dictionary) -> String`
- `static func max_profile_bytes(balance: Dictionary) -> int`
- `static func autosave_interval_seconds(balance: Dictionary) -> float`
- `static func default_settings(balance: Dictionary) -> Dictionary`
- `static func fps_options(balance: Dictionary) -> Array`
- `static func normalize_settings(value: Variant, balance: Dictionary) -> Dictionary`
- `static func next_target_fps(balance: Dictionary, current_fps: int) -> int`
- `static func default_profile(created_at: int, balance: Dictionary) -> Dictionary`
- `static func normalize_profile(value: Variant, fallback_time: int, balance: Dictionary) -> Dictionary`
- `static func limit_hours(balance: Dictionary) -> int`
- `static func limit_seconds(balance: Dictionary) -> int`
- `static func tick_seconds(balance: Dictionary) -> int`
- `static func min_seconds(balance: Dictionary) -> int`
- `static func active_efficiency(balance: Dictionary) -> float`
- `static func stage_multiplier(balance: Dictionary, highest_stage: int) -> float`
- `static func afk_efficiency(balance: Dictionary) -> float`
- `static func efficiency(balance: Dictionary, highest_stage: int) -> float`
- `static func offline_rewards(balance: Dictionary, last_saved_at: int, now_unix: int, highest_stage: int) -> Dictionary`
- `static func format_duration(seconds: int) -> String`
- `static func reward_text(report: Dictionary) -> String`

### `scripts/save/save_manager.gd`

- Наследует: `RefCounted`
- Назначение: Локальный профиль ASHEN WORLD: JSON в user://, контрольная сумма, версия формата, миграция v6/v7→v8, состояние режимов, резервная копия и атомарная замена основного файла. Никаких сетевых зависимостей и секретов: профиль целиком офлайн.
- Публичных методов: 11

**Публичные константы**

- `FORMAT_LABEL: String = "ashenworld-profile"`
- `FNV_OFFSET: int = 2166136261`
- `FNV_PRIME: int = 16777619`

**Публичное состояние**

- `balance: Dictionary`
- `format_version: int`
- `profile_path: String`
- `temp_path: String`
- `backup_path: String`
- `max_bytes: int`

**Методы**

- `static func canonical_envelope(envelope: Dictionary) -> Dictionary`
- `static func canonical_text(envelope: Dictionary) -> String`
- `static func checksum_for(envelope: Dictionary) -> String`
- `static func build_envelope(payload: Dictionary, saved_at: int, version: int) -> Dictionary`
- `static func store_envelope(envelope: Dictionary, path: String) -> bool`
- `static func status_text(status: String) -> String`
- `func file_paths() -> Dictionary`
- `func clear_files() -> void`
- `func normalize_payload(payload: Dictionary, source_version: int, saved_at: int) -> Dictionary`
- `func load_profile() -> Dictionary`
- `func save_profile(payload: Dictionary, now_unix: int = -1) -> Dictionary`

## Представление

Каталог `scripts/ui/`.

### `scripts/ui/ashen_audio.gd`

- Наследует: `Node`
- Назначение: Небольшой пул голосов для коротких процедурных звуков боя и интерфейса. Все PCM-сигналы строятся один раз из data/balance.json, поэтому APK не содержит внешних аудиофайлов и не запрашивает доступ к сети.
- Публичных методов: 5

**Публичное состояние**

- `players: Array`
- `clips: Dictionary`
- `enabled: bool`
- `next_voice: int`

**Методы**

- `func configure(balance: Dictionary, sound_on: bool) -> void`
- `func set_enabled(value: bool) -> void`
- `func play(event_id: String) -> void`
- `func stream_count() -> int`
- `func voice_count() -> int`

### `scripts/ui/ashen_style.gd`

- Наследует: `RefCounted`
- Назначение: Единая палитра и игровые стили тёмного фэнтези. Крупные карточки и высокие полосы заменены одной строкой здоровья; нижняя навигация, рамки и активные вкладки выделены так, чтобы структура экрана читалась с первого взгляда.
- Публичных методов: 32

**Публичные константы**

- `BACKGROUND: Color = Color("#0B0910")`
- `PANEL: Color = Color("#17121F")`
- `PANEL_BORDER: Color = Color("#4A3A58")`
- `EMBER: Color = Color("#E08A3C")`
- `GOLD: Color = Color("#F4C98A")`
- `RUNE: Color = Color("#B49AC6")`
- `PARCHMENT: Color = Color("#E6DCCB")`
- `MUTED: Color = Color("#9A8CA3")`
- `CRIMSON: Color = Color("#A63D40")`
- `STEEL: Color = Color("#6E8CA8")`
- `SHIELD_COLOR: Color = Color("#B49AC6")`
- `HERO_COLOR: Color = Color("#6E8CA8")`
- `ENEMY_COLOR: Color = Color("#A63D40")`

**Методы**

- `static func panel_style(background: Color = PANEL, border: Color = PANEL_BORDER) -> StyleBoxFlat`
- `static func compact_panel_style() -> StyleBoxFlat`
- `static func ornate_panel_style(background: Color = Color("#17121F"), border: Color = GOLD) -> StyleBoxFlat`
- `static func header_style() -> StyleBoxFlat`
- `static func bottom_bar_style() -> StyleBoxFlat`
- `static func content_panel_style() -> StyleBoxFlat`
- `static func hud_panel_style() -> StyleBoxFlat`
- `static func muted_panel_style() -> StyleBoxFlat`
- `static func circle_button_style(background: Color = Color("#1B1020"), border: Color = GOLD) -> StyleBoxFlat`
- `static func portrait_frame_style() -> StyleBoxFlat`
- `static func ring_texture(diameter: int, thickness: float, color: Color) -> ImageTexture`
- `static func slot_placeholder_style() -> StyleBoxFlat`
- `static func auto_button_style(active: bool) -> StyleBoxFlat`
- `static func ground_shadow_style() -> StyleBoxFlat`
- `static func battlefield_card_style() -> StyleBoxFlat`
- `static func enemy_bar_background() -> StyleBoxFlat`
- `static func enemy_bar_fill() -> StyleBoxFlat`
- `static func level_badge_style() -> StyleBoxFlat`
- `static func currency_pill_style() -> StyleBoxFlat`
- `static func vitals_plate_style() -> StyleBoxFlat`
- `static func nav_button_style(active: bool) -> StyleBoxFlat`
- `static func quick_icon_style(active: bool) -> StyleBoxFlat`
- `static func enemy_card_style(active: bool = false) -> StyleBoxFlat`
- `static func orb_style(active: bool = false, radius: int = 62) -> StyleBoxFlat`
- `static func log_strip_style() -> StyleBoxFlat`
- `static func active_tab_style() -> StyleBoxFlat`
- `static func inactive_tab_style() -> StyleBoxFlat`
- `static func button_style(background: Color, border: Color) -> StyleBoxFlat`
- `static func action_button_style() -> StyleBoxFlat`
- `static func bar_background() -> StyleBoxFlat`
- `static func bar_fill(color: Color) -> StyleBoxFlat`
- `static func build_theme(config: Dictionary = {}) -> Theme`

### `scripts/ui/effect_pool.gd`

- Наследует: `Node`
- Назначение: Переиспользуемые всплывающие подписи и короткие подсветки интерфейса. Вместо отдельного Label и Tween на каждый удар используется пул фиксированного размера; _process() активен только во время анимации и не нагружает простой кадр.
- Публичных методов: 9

**Публичное состояние**

- `canvas: Control`
- `config: Dictionary`
- `labels: Array`
- `slots: Array`
- `flashes: Dictionary`
- `full_effects: bool`

**Методы**

- `func configure(target: Control, data: Dictionary) -> void`
- `func set_full_effects(value: bool) -> void`
- `func spawn_text(text: String, near: Control, color: Color, font_size: int) -> void`
- `func flash(control: Control, color: Color) -> void`
- `func pulse(control: Control, color: Color) -> void`
- `func reset() -> void`
- `func active_count() -> int`
- `func active_flash_count() -> int`
- `func pool_size() -> int`

### `scripts/ui/presentation_catalog.gd`

- Наследует: `RefCounted`
- Назначение: Единый каталог полировки восьмого этапа: все длительности эффектов, размеры пула, параметры фоновых частиц и локальных звуков берутся из раздела presentation файла data/balance.json. Внешние аудиофайлы, сеть и онлайн-сервисы не используются: короткие сигналы создаются в памяти.
- Публичных методов: 11

**Публичные константы**

- `DEFAULT_UI_REFRESH_SECONDS: float = 0.1`
- `DEFAULT_SAMPLE_SECONDS: float = 1.0`
- `DEFAULT_MIX_RATE: int = 22050`
- `DEFAULT_POOL_CAPACITY: int = 8`
- `WAV_SIGNED_LIMIT: int = 32767`

**Методы**

- `static func section(balance: Dictionary) -> Dictionary`
- `static func ui_refresh_seconds(balance: Dictionary) -> float`
- `static func interface_config(balance: Dictionary) -> Dictionary`
- `static func performance_config(balance: Dictionary) -> Dictionary`
- `static func away_config(balance: Dictionary) -> Dictionary`
- `static func notice_config(balance: Dictionary) -> Dictionary`
- `static func effect_pool_config(balance: Dictionary) -> Dictionary`
- `static func particle_config(balance: Dictionary) -> Dictionary`
- `static func audio_config(balance: Dictionary) -> Dictionary`
- `static func sound_spec(source: Dictionary) -> Dictionary`
- `static func build_stream(spec: Dictionary, mix_rate: int) -> AudioStreamWAV`

## Слой экрана

Каталог `scripts/main/`.

### `scripts/main/main.gd`

- Наследует: `Control`
- Назначение: Портретный HUD в духе наброска: оригинальный фон, портрет героя, крупные шкалы, правая быстрая навигация и некликабельные заглушки будущих разделов. Реальная логика кампании, экипировки, прогрессии, сохранений, режимов, звука и эффектов сохранена.
- Публичных методов: 2

**Публичные константы**

- `FORCE_DISMANTLE_WINDOW_MS: int = 5000`

**Публичное состояние**

- `title_label: Label`
- `stage_label: Label`
- `sigil: TextureRect`
- `divider: TextureRect`
- `level_label: Label`
- `experience_bar: ProgressBar`
- `gold_label: Label`
- `materials_label: Label`
- `hero_side: VBoxContainer`
- `hero_label: Label`
- `enemy_label: Label`
- `hero_health_bar: ProgressBar`
- `enemy_health_bar: ProgressBar`
- `shield_bar: ProgressBar`
- `enemy_hint_label: Label`
- `stage_notice: Label`
- `battle_overlay: Control`
- `arena_hero: TextureRect`
- `hero_ground: Panel`
- `enemy_ground: Panel`
- `equipment_button: Button`
- `equipment_power_label: Label`
- `equipment_panel: PanelContainer`
- `wallet_label: Label`
- `item_power_label: Label`
- `summon_type_button: Button`
- `summon_one_button: Button`
- `summon_ten_button: Button`
- `summon_info_label: Label`
- `summon_status_label: Label`
- `history_label: Label`
- `slot_filter: OptionButton`
- `rarity_filter: OptionButton`
- `affix_filter: OptionButton`
- `item_list: ItemList`
- `item_details: Label`
- `equip_button: Button`
- `upgrade_button: Button`
- `lock_button: Button`
- `dismantle_button: Button`
- `auto_equip_button: Button`
- `mass_dismantle_button: Button`
- `equipment_hint_label: Label`
- `progression_button: Button`
- `progression_panel: PanelContainer`
- `progression_wallet_label: Label`
- `progression_power_label: Label`
- `attribute_buttons: Dictionary`
- `attribute_hint_label: Label`
- `progression_skill_list: ItemList`
- `progression_skill_details: Label`
- `skill_upgrade_button: Button`
- `skill_auto_button: Button`
- `skill_variant_button: Button`
- `passive_buttons: Dictionary`
- `pet_buttons: Dictionary`
- `progression_pet_details: Label`
- `pet_upgrade_button: Button`
- `progression_hint_label: Label`
- `strike_button: Button`
- `guard_button: Button`
- `action_button: Button`
- `log_card: Panel`
- `battle_log: Label`
- `hint_label: Label`
- `mode_button: Button`
- `mode_panel: PanelContainer`
- `mode_status_label: Label`
- `mode_stats_label: Label`
- `mode_hint_label: Label`
- `mode_buttons: Dictionary`
- `dungeon_buttons: Dictionary`
- `particles_effect: CPUParticles2D`
- `sound_button: Button`
- `particles_button: Button`
- `fps_button: Button`
- `effects_button: Button`
- `battle_button: Button`
- `summon_button: Button`
- `settings_button: Button`
- `header_frame: PanelContainer`
- `bottom_bar: PanelContainer`
- `section_title: Label`
- `content_area: VBoxContainer`
- `battle_panel: PanelContainer`
- `inventory_panel: PanelContainer`
- `summon_panel: PanelContainer`
- `settings_panel: PanelContainer`
- `summon_wallet_label: Label`
- `battle_title: Label`
- `battle_hint_label: Label`
- `inventory_title: Label`
- `summon_title: Label`
- `summon_hint_label: Label`
- `progression_title: Label`
- `mode_title: Label`
- `settings_title: Label`
- `settings_info_label: Label`
- `performance_label: Label`
- `away_window: Control`
- `away_card: PanelContainer`
- `away_title_label: Label`
- `away_time_label: Label`
- `away_rewards_label: Label`
- `away_hint_label: Label`
- `away_claim_button: Button`
- `notice_feed: VBoxContainer`
- `notice_labels: Array`
- `notice_times: Array`
- `notice_colors: Array`
- `save_indicator: TextureRect`
- `strike_icon: TextureRect`
- `guard_icon: TextureRect`
- `strike_cooldown_ring: TextureProgressBar`
- `guard_cooldown_ring: TextureProgressBar`
- `strike_cooldown_label: Label`
- `guard_cooldown_label: Label`
- `skill_slot3: PanelContainer`
- `skill_slot4: PanelContainer`
- `skills_soon_label: Label`
- `auto_button: Button`
- `auto_advance: bool`
- `auto_advance_timer: float`
- `save_flash: float`
- `away_config: Dictionary`
- `notice_config: Dictionary`
- `settings_hint_label: Label`
- `bottom_tabs: BoxContainer`
- `background: TextureRect`
- `dim_overlay: ColorRect`
- `hero_portrait: TextureRect`
- `portrait_frame: PanelContainer`
- `portrait_holder: Control`
- `level_badge: PanelContainer`
- `power_icon: TextureRect`
- `gold_pill: PanelContainer`
- `ash_pill: PanelContainer`
- `profile_panel: PanelContainer`
- `profile_lines: VBoxContainer`
- `stats_row: HBoxContainer`
- `nickname_label: Label`
- `rating_label: Label`
- `hero_vitals: PanelContainer`
- `battle_power_label: Label`
- `currency_bar: PanelContainer`
- `currency_row: HBoxContainer`
- `quest_stub: PanelContainer`
- `future_rail: VBoxContainer`
- `arena_enemies: GridContainer`
- `stub_strip: HBoxContainer`
- `enemy_cards: Array`
- `enemy_figure_by_id: Dictionary`
- `enemy_figure_default: String`
- `enemy_figure_pool: Array`
- `nav_icons: Dictionary`
- `nav_icons_nodes: Dictionary`
- `nav_labels: Dictionary`
- `enemy_name_labels: Array`
- `enemy_mini_bars: Array`
- `hud_config: Dictionary`
- `interface_config: Dictionary`
- `navigation_config: Dictionary`
- `tab_info: Dictionary`
- `tab_order: Array`
- `default_tab: String`
- `hide_label: String`
- `tabs: Dictionary`
- `content_panels: Dictionary`
- `active_tab: String`
- `audio_player: Variant`
- `effect_pool: Variant`
- `effect_config: Dictionary`
- `view_refresh_seconds: float`
- `view_refresh_timer: float`
- `fps_sample_seconds: float`
- `fps_sample_timer: float`
- `measured_fps: float`
- `campaign: Variant`
- `profile_manager: Variant`
- `balance: Dictionary`
- `log_lines: PackedStringArray`
- `initialized: bool`
- `equipment_visible: bool`
- `progression_visible: bool`
- `mode_visible: bool`
- `selected_summon_id: String`
- `selected_item_id: String`
- `selected_skill_id: String`
- `selected_pet_id: String`
- `force_dismantle_item_id: String`
- `force_dismantle_deadline_ms: int`

**Методы**

- `func setup(data: Dictionary, profile_path: String = "", now_unix: int = -1) -> void`
- `func auto_label() -> String`
