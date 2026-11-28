# API и контракты подсистем

Документ девятого этапа: фиксирует публичные контракты подсистем ASHEN WORLD, чтобы будущее расширение (в том числе возможный онлайн) встраивалось в готовые швы, а не переписывало игру. Онлайн в текущей версии **не реализована**: сетевых классов, аккаунтов, облачных сохранений, PvP и гильдий нет, разрешение `android.permission.INTERNET` в APK отсутствует.

- Полный список сигнатур всех модулей — в автоматически собранном справочнике [`api_reference.md`](api_reference.md) (`python3 tools/api_report.py`).
- Границы подсистем, направления зависимостей и точки расширения — в [`boundaries.md`](boundaries.md).
- Схема сохранения и миграции — в [`saves.md`](saves.md), правила проекта — в [`rules.md`](rules.md).

## 1. Общие правила

1. **Единственный источник истины** — `scripts/campaign/campaign_state.gd` (`CampaignState`). Он владеет уровнем, опытом, валютой, этапом, режимами, экипировкой (`EquipmentState`) и прогрессией (`ProgressionState`). Интерфейс не хранит игровое состояние: он читает `get_summary()` и вызывает методы.
2. **Каталоги не хранят состояние.** `CombatCatalog`, `CampaignCatalog`, `ModeCatalog`, `EquipmentCatalog`, `ProgressionCatalog`, `SaveCatalog`, `PresentationCatalog` — это `RefCounted` со `static func`, которые только читают `data/balance.json`. Никакого кеша между вызовами, никаких глобальных переменных.
3. **Состояние не знает про интерфейс.** Скрипты `combat/`, `campaign/`, `equipment/`, `progression/`, `save/` не ссылаются на `Control`, сцены, `AshenStyle` и `res://assets`. Обратная связь идёт только через сигналы и возвращаемые словари.
4. **Никаких сетевых вызовов и таймеров реального времени в логике.** Время приходит снаружи: `advance(delta)`, `now_unix` в сохранении, `ProfileManager.set_now()` в тестах.
5. **Детерминизм.** Случайность живёт в `RandomNumberGenerator` с явным `seed`: `CampaignState(balance, seed)` → `CombatSystem(..., seed + active_index() * 118 + active_mode_id.length() * 131)` → `EquipmentState(balance, seed + 777)`. Один и тот же seed и одинаковые вызовы дают одинаковый бой и одинаковый призыв.
6. **Все числа — в `data/balance.json`.** Формулы вызываются через каталоги; в интерфейсе и сцене коэффициентов нет.
7. **Версия сохранения — 8.** Структура профиля и миграции описаны в [`saves.md`](saves.md); добавление поля в сохраняемое состояние — это новая версия и миграция, а не «тихое» расширение.

## 2. Быстрый старт без сцены

```gdscript
var balance: Dictionary = CombatCatalog.load_balance()          # data/balance.json
var campaign = CampaignState.new(balance, 12345)                # этап запускается сам
campaign.advance(0.5)                                           # шаг боя
campaign.use_skill("heavy_strike")                              # ручной навык
var summary: Dictionary = campaign.get_summary()                # всё для интерфейса
var snapshot: Dictionary = campaign.export_state()              # сохраняемое состояние
var report: Dictionary = SaveManager.new(balance, "user://ashenworld_profile.json").save_profile(snapshot)
```

`MainScene` делает то же самое в `setup()`, поэтому точечные проверки работают без запуска игры.

## 3. Баланс

| Модуль | Контракт |
|---|---|
| `scripts/core/game_config.gd` (`GameConfig`, автозагрузка) | `values: Dictionary` — весь `data/balance.json`; `get_section(name) -> Dictionary` возвращает пустой словарь для неизвестного раздела. Ошибка чтения — `push_error` и пустой словарь, без падения. |
| `scripts/combat/combat_catalog.gd` | `load_balance()` — та же загрузка для тестов и сцены; `combat_balance()`, `hero_data()`, `skill_map()`, `campaign_data()`, `campaign_stages()`, `enemy_list()` — срезы баланса. |
| `scripts/campaign/campaign_catalog.gd` | `stages()`, `campaign()`, `build_enemy_list(stage, balance)`, `stage_kind()`, `stage_is_boss()`. |

**Контракт `balance`:** 19 разделов, `version` = версия баланса, `save.format_version = 8`. Разделы читаются только через каталоги; прямой доступ `GameConfig.values["..."]` в логике не используется.

## 4. Бой

`CombatSystem` (`scripts/combat/combat_system.gd`) — независимый от сцены бой одного этапа.

```gdscript
CombatSystem.new(hero_data: Dictionary, enemy_list: Array, skill_map: Dictionary,
                 combat_balance: Dictionary, seed_value: int = 12345, pet_data: Dictionary = {})
```

| Метод | Контракт |
|---|---|
| `advance(delta: float) -> void` | Шаг боя. Работает только при `running` и `delta > 0`. Самодостаточен: если враг погиб вне `perform_attack`, метод сам отправляет `enemy_defeated` и вызывает `spawn_next_enemy()` — бой не зависает. |
| `perform_attack(attacker, target, multiplier, crit_chance_bonus = 0.0) -> void` | Один удар по правилам `CombatFormulas`; поднимает `damage_dealt`, при смерти — `enemy_defeated`/`hero_defeated`. |
| `use_skill(skill_id: String) -> bool` | `false`, если навыка нет, он на откате или бой не идёт. Успех поднимает `skill_used`. |
| `get_cooldown_remaining(skill_id) -> float` | Секунды до готовности, `0.0` — навык доступен. |
| `spawn_next_enemy(interval = -1.0) -> void` | Берёт следующего врага из `enemies`; когда список кончился — `enemy = null`, `running = false`. |
| `set_pet_data(pet_data) -> void` | Обновляет питомца без перезапуска боя. |
| `get_state() -> Dictionary` | Снимок для отладки и тестов: индексы, интервалы, откаты, флаги босс-фазы. |

**Сигналы:** `damage_dealt(target_name, amount, is_critical)`, `enemy_defeated(enemy_name)`, `hero_defeated()`, `skill_used(skill_name)`, `shield_changed(amount)`, `enemy_phase_started(enemy_name, phase_name, attack_multiplier)`, `pet_attack(pet_name, assist_name, amount)`, `hero_healed(amount)`, `attack_dodged(target_name)`.

**Инварианты:** `enemy_index` — индекс текущего врага в `enemies` (`-1` до первого спавна); `running = true` означает, что в списке ещё есть противники; `enemies[i]` — **словари** (не `Combatant`), живой боец — только `enemy`.

`Combatant` (`scripts/combat/combatant.gd`) — `RefCounted` с полями `display_name`, `max_health`, `health`, `attack`, `defense`, `crit_chance`, `dodge`, `shield`, `alive`, `is_boss`, `phase_*`; методы `receive_damage(amount) -> float` (возвращает принятый урон), `heal()`, `add_shield()`, `restore()`.

## 5. Кампания

`CampaignState` (`scripts/campaign/campaign_state.gd`), `RefCounted`.

```gdscript
CampaignState.new(balance: Dictionary, initial_seed: int = 12345)
```

Статусы: `STATUS_BATTLE = 0`, `STATUS_VICTORY = 1`, `STATUS_DEFEAT = 2`, `STATUS_COMPLETE = 3` (кампания пройдена).

| Метод | Контракт |
|---|---|
| `start_stage() -> void` | Пересобирает бой текущего этапа. Если этапов больше нет — `STATUS_COMPLETE`, `system = null`. Если у этапа нет врагов — `push_error`, `STATUS_DEFEAT`. |
| `advance(delta) -> void` | Шаг боя и автонавыков; меняет статус на победу/поражение ровно один раз и заполняет `last_reward`. |
| `use_skill(skill_id) -> bool`, `get_cooldown_remaining(skill_id) -> float` | Проброс в `system` с учётом статуса. |
| `next_stage() -> bool` | Переход после победы; `last_reward` уже начислен. |
| `retry_stage() -> bool` | Повтор после поражения, герой восстанавливается. |
| `restart_campaign() -> bool` | Сброс кампании после `STATUS_COMPLETE`. |
| `get_summary() -> Dictionary` | Полный снимок для интерфейса (см. таблицу ниже). Только чтение. |
| `export_state() -> Dictionary` / `import_state(snapshot)` | Сохраняемое состояние; `import_state` мягко нормализует значения через `clampi`/`maxi`. |
| `grant_experience(amount)`, `apply_offline_rewards(report)` | Начисление опыта и офлайн-наград; вызываются только слоем экрана. |
| `select_mode(mode_id)`, `select_dungeon(dungeon_id)`, `repeat_dungeon()`, `restart_mode()` | Переключение режимов; неизвестный идентификатор игнорируется. |
| `mode_state_view()`, `mode_status_key()`, `dungeon_block_reason(id)`, `mode_is_unlocked(id)` | Состояние режимов для интерфейса. |
| Экипировка/прогрессия | `summon_equipment()`, `equip_item()`, `auto_equip_items()`, `upgrade_item()`, `dismantle_item()`, `mass_dismantle_items()`, `toggle_item_lock()`, `set_equipment_filters()`, `allocate_attribute()`, `upgrade_skill()`, `toggle_skill_auto()`, `cycle_skill_variant()`, `upgrade_passive()`, `select_pet()`, `upgrade_pet()` — тонкие обёртки над `EquipmentState`/`ProgressionState`, возвращают те же словари. |

**Ключи `get_summary()` (для интерфейса):** `stage`, `stages`, `stage_name`, `region`, `chapter`, `kind`, `boss`, `status`, `status_name`, `level`, `experience`, `experience_to_next`, `gold`, `materials`, `victories`, `defeats`, `highest_stage`, `balance_version`, `last_reward`, `boss_phase_count`, `boss_phase_active`, `boss_phase_name`, `equipment_power`, `inventory_count`, `equipped_count`, `total_summons`, `class_name`, `attribute_points`, `skill_points`, `development_bonus_score`, `selected_pet_name`, `pet_attack_count`, `balance_ratio`, `balance_status`, `auto_skill_count`, `total_skill_count`, `auto_skill_share`, `auto_battle_status`, `stage_duration`, `min_stage_duration`, `mode_id`, `mode_name`, `mode_short`, `mode_region`, `mode_description`, `mode_stage`, `mode_count`, `mode_status_key`, `mode_progress`, `mode_stats`, `mode_state`, `dungeon_id`, `dungeon_name`.

Удаление ключа — ломающее изменение для интерфейса и тестов; новые ключи добавлять можно.

## 6. Режимы

`ModeCatalog` (`scripts/campaign/mode_catalog.gd`) — только `static func`, три режима (`campaign`, `tower`, `dungeon`) и три подземелья.

| Метод | Контракт |
|---|---|
| `default_state(balance)`, `normalize_state(value, balance, highest_stage)`, `state_from_snapshot(snapshot, balance, highest_stage)` | Каноническое состояние режимов; `state_from_snapshot` терпит старые сохранения и мусор. |
| `mode_ids(balance)`, `mode_by_id()`, `mode_name()`, `mode_short()`, `mode_region()`, `mode_description()`, `mode_unlock_stage()`, `is_mode_unlocked()`, `mode_unlock_reason()` | Описание и доступность режимов. |
| `dungeon_ids()`, `dungeon_by_id()`, `dungeon_name()`, `dungeon_short()`, `dungeon_unlock_stage()`, `is_dungeon_unlocked()`, `dungeon_entry_cost()`, `dungeon_block_reason()`, `dungeon_reward()` | Подземелья: вход, цена, награда, причина блокировки (пустая строка — можно входить). |
| `stage_at(balance, mode_id, index, state)` | Этап режима; для башни подставляет ярус, для подземелья — сложность. |
| `progress_text()`, `mode_stats_text()`, `action_text()`, `status_key()`, `stage_count()` | Готовые тексты и статусы для интерфейса (правило: интерфейс не собирает игровые подписи сам). |

## 7. Экипировка и призыв

`EquipmentState` (`scripts/equipment/equipment_state.gd`), `RefCounted`, `EquipmentState.new(balance, seed_value = 12345)`.

| Метод | Контракт |
|---|---|
| `roll_summons(summon_id, count, stage_number) -> Dictionary` | `{"success": bool, "reason": String, "items": Array, "guaranteed_count": int}`. Ничего не начисляет: предметы добавляет вызывающий (`CampaignState.summon_equipment`), чтобы цена и награда жили в одном месте. |
| `get_summon_cost(summon_id, count)`, `is_summon_unlocked()`, `summon_block_reason()` | Цена и причины отказа. |
| `equip(item_id) -> bool`, `auto_equip() -> int`, `is_equipped()`, `get_equipped_item(slot_id)`, `get_total_bonuses()`, `compare(item_id)` | Надевание и сравнение; `get_total_bonuses()` — единственный источник бонусов для боя. |
| `upgrade(item_id) -> Dictionary`, `get_upgrade_cost(item_id)` | Улучшение и его цена. |
| `dismantle(item_id, force = false) -> Dictionary`, `mass_dismantle() -> Dictionary`, `dismantle_block_reason()`, `can_dismantle()` | Разбор с защитой надетых и запертых предметов. |
| `toggle_lock(item_id) -> bool` | Замок предмета. |
| `set_filters(slot, rarity, affix)`, `get_filter_values()`, `get_filtered_inventory()` | Фильтры списка; `-1` — «все». |
| `export_state() -> Dictionary` / `import_state(snapshot)` | Сохраняемое состояние инвентаря. |
| `get_summary() -> Dictionary`, `history_text(limit = 3)` | Сводка и история призывов для панели. |

**Предмет (словарь):** `id`, `name`, `slot`, `slot_name`, `rarity`, плюс характеристики и список аффиксов `{"stat", "name", "value"}`. Ключ `id` уникален внутри профиля (`item-N`).

## 8. Прогрессия

`ProgressionState` (`scripts/progression/progression_state.gd`) — `RefCounted`, `ProgressionState.new(balance, level = 1)`.

- `set_level(level, grant_rewards = false)`, `grant_level_rewards(levels_gained)`, `allocate_attribute(attribute_id)`, `get_attribute_points()`, `get_bonuses()`.
- `get_effective_skill_map()` — карта навыков с учётом уровней и вариантов; **бою передаётся только она**.
- `get_auto_skill_ids()`, `get_skill_level()`, `get_skill_variant()`, `is_skill_auto()`, `get_skill_upgrade_cost()`, `spend_skill_points()`, `increase_skill_level()`, `toggle_skill_auto()`, `cycle_skill_variant()`.
- `get_passive_level()`, `get_passive_upgrade_cost()`, `increase_passive_level()`.
- `is_pet_unlocked(pet_id, stage_number)`, `select_pet()`, `get_pet_level()`, `get_pet_upgrade_cost()`, `increase_pet_level()`, `get_pet_combat_data()` — данные питомца для `CombatSystem`.
- `export_state()` / `import_state(snapshot)` — ключи: `level`, `attribute_points`, `skill_points`, `allocated`, `skill_levels`, `skill_variants`, `skill_auto_use`, `passive_levels`, `pet_levels`, `selected_pet_id`.
- `get_summary()` — сводка для панели прогрессии.

## 9. Сохраняемое состояние и профиль

`SaveManager` (`scripts/save/save_manager.gd`) — единственная точка записи на диск.

| Метод | Контракт |
|---|---|
| `SaveManager.new(balance, profile_path = "")` | Путь профиля задаётся снаружи (в игре `user://ashenworld_profile.json`, в тестах — свой файл). Ограничение размера `max_bytes` берётся из баланса (`SaveCatalog.max_profile_bytes`), а не из аргумента. |
| `load_profile() -> Dictionary` | `{"valid": bool, "status": "new"|"loaded"|"migrated"|"recovered"|"corrupted"|"future", "payload": Dictionary, "version": int, "saved_at": int, "reason": String}`. Аварийный файл `.tmp` подхватывается как `recovered`, повреждённый JSON не роняет игру. |
| `save_profile(payload, now_unix = -1) -> Dictionary` | Пишет конверт с контрольной суммой FNV-1a, возвращает статус записи. |
| `file_paths()`, `clear_files()` | Пути основного и временного файла; удаление профиля для тестов. |
| `normalize_payload(payload, source_version, saved_at)` | Приводит старое сохранение к версии 8: `settings` переезжает в `profile.settings`, `active_mode`/`mode_index` — в `modes`. |
| Статические: `build_envelope()`, `canonical_envelope()`, `canonical_text()`, `checksum_for()`, `store_envelope()`, `status_text()` | Формат конверта и контрольная сумма. Меняются только вместе с версией формата. |

`ProfileManager` (`scripts/save/profile_manager.gd`) — офлайн-время, настройки, автосохранение 15 с: `bootstrap(state)`, `collect_offline()`, `save(reason)`, `tick(delta)`, `on_pause()`, `on_resume()`, `settings()`, `set_setting(key, value)`, `hint_text()`, `get_report()`, `set_now(value)`.

Настройки профиля: `sound_enabled`, `particles_enabled`, `effects_enabled`, `target_fps` — значения по умолчанию приходят из `balance.save.default_settings`.

## 10. Представление

- `PresentationCatalog` (`scripts/ui/presentation_catalog.gd`) — только чтение: `interface_config()`, `performance_config()`, `effect_pool_config()`, `particle_config()`, `audio_config()`, `sound_spec()`, `build_stream()`, `ui_refresh_seconds()`, `section()`. Ничего не кеширует и не хранит состояние.
- `AshenStyle` (`scripts/ui/ashen_style.gd`) — статические конструкторы `StyleBoxFlat` и `Theme`: `build_theme(interface_config)`, `nav_button_style(active)`, `orb_style(active, radius)`, `bar_fill(color)` и другие. Палитра — константы модуля.
- `AshenAudio` (`scripts/ui/ashen_audio.gd`, `Node`) — `configure(balance, sound_on)`, `set_enabled(value)`, `play(event_id)`, `stream_count()`, `voice_count()`. События: `attack`, `critical`, `skill`, `shield`, `victory`, `defeat`, `boss`, `click`. Пул из 6 голосов, процедурный PCM, внешних файлов нет.
- `EffectPool` (`scripts/ui/effect_pool.gd`, `Node`) — `configure(target, data)`, `spawn_text(text, near, color, font_size)`, `flash()`, `pulse()`, `reset()`, `active_count()`, `active_flash_count()`, `pool_size()`. Пул фиксированного размера (8), лишние эффекты отбрасываются.

## 11. Слой экрана

`scripts/main/main.gd` (`Control`) — единственная точка склейки логики и интерфейса. Публично используются `setup(data, profile_path = "", now_unix = -1)` (повторный вызов игнорируется), поля `campaign`, `profile_manager`, `audio_player`, `effect_pool`, кнопки и подписи для тестов. Вся остальная логика — приватные методы `_update_view()`, `_select_tab()`, `_refresh_arena_vitals()`.

Правила слоя: не писать файлы самостоятельно (только через `ProfileManager`/`SaveManager`), не считать формулы (только через каталоги), не хранить игровое состояние.

## 12. Ошибки и статусы

- Методы, которые могут отказать по правилам игры, возвращают `Dictionary` с `success`/`reason` (`roll_summons`, `upgrade_item`, `dismantle_item`) или `bool`.
- `reason` — короткая русская фраза для интерфейса; пустая строка означает успех.
- `push_error` используется только для нарушений контракта (нет файла баланса, нет врагов на этапе), то есть для ситуаций, которые в релизе невозможны.
- Ни один публичный метод не бросает исключений и не вызывает `assert` в релизной сборке.

## 13. Версионирование

1. Публичный метод или ключ `get_summary()` **не удаляется и не переименовывается** без обновления интерфейса и тестов в том же коммите.
2. Структура сохранения меняется только с ростом `save.format_version` и миграцией в `SaveManager.normalize_payload()`; старые файлы обязаны загружаться (`migrated`).
3. Справочник `docs/api_reference.md` пересобирается командой `python3 tools/api_report.py`; сборка падает, если он устарел, поэтому любое изменение публичного API сразу видно в диффе.
