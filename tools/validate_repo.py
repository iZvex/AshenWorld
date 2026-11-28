#!/usr/bin/env python3
"""Быстрая проверка репозитория ASHEN WORLD.

Запускается в автоматической сборке (см. .github/workflows/ci.yml) и локально:
    python3 tools/validate_repo.py

Проверяет только то, что можно проверить без движка:
  * целостность спецификации README.md;
  * синтаксис описаний сборок и файлов данных;
  * целостность данных кампании, режимов, экипировки, прогрессии, сохранений, AFK и полировки;
  * конфликтные маркеры и переводы строк в скриптах GDScript;
  * базовую структуру project.godot, когда он появится;
  * границы подсистем из docs/boundaries.md и актуальность docs/api_reference.md.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_SECTIONS = 17

errors: list[str] = []
warnings: list[str] = []
notes: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def files(pattern: str) -> list[Path]:
    return sorted(
        p for p in ROOT.rglob(pattern)
        if ".git" not in p.parts and "build" not in p.parts and ".godot" not in p.parts
    )


# --- 1. Спецификация -------------------------------------------------------
readme = ROOT / "README.md"
if not readme.is_file():
    err("README.md отсутствует")
else:
    text = readme.read_text(encoding="utf-8")
    nums = [int(n) for n in re.findall(r"^## (\d+)\. ", text, flags=re.M)]
    missing = [n for n in range(1, EXPECTED_SECTIONS + 1) if n not in nums]
    if missing:
        err(f"В README.md отсутствуют разделы: {missing}")
    duplicates = sorted({n for n in nums if nums.count(n) > 1})
    if duplicates:
        err(f"Дублируются номера разделов: {duplicates}")
    if "8. **Готово. Полировка" not in text:
        err("README.md: восьмой этап не отмечен готовым")
    if "9. **Готово. Подготовка" not in text:
        err("README.md: девятый этап не отмечен готовым")
    for doc_link in ("docs/api.md", "docs/boundaries.md", "docs/api_reference.md"):
        if doc_link not in text:
            err(f"README.md: нет ссылки на {doc_link}")
    if "Краткое резюме" not in text:
        err("В README.md нет раздела «Краткое резюме»")
    if len(text) < 1000:
        err("README.md подозрительно короткий")
    if "<<<<<<<" in text or ">>>>>>>" in text:
        err("В README.md остались конфликтные маркеры")
    notes.append(f"README.md: {len(text.splitlines())} строк, разделов: {len(set(nums))}")

# --- 2. Описания сборок ----------------------------------------------------
try:
    import yaml
except ImportError:
    warn("PyYAML не установлен — проверка описаний сборок пропущена (в сборке ставится через pip)")
else:
    wf = files("*.yml") + files("*.yaml")
    for path in wf:
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                err(f"{path.relative_to(ROOT)}: корень описания должен быть объектом")
        except Exception as exc:
            err(f"{path.relative_to(ROOT)}: некорректное описание сборки: {exc}")
    notes.append(f"Описаний сборок проверено: {len(wf)}")

# --- 3. Файлы данных -------------------------------------------------------
json_paths = files("*.json")
for path in json_paths:
    try:
        json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        err(f"{path.relative_to(ROOT)}: некорректный файл данных: {exc}")
notes.append(f"Файлов данных проверено: {len(json_paths)}")

# --- 4. Данные кампании ----------------------------------------------------
balance: dict = {}
balance_file = ROOT / "data" / "balance.json"
if balance_file.is_file():
    try:
        balance = json.loads(balance_file.read_text(encoding="utf-8"))
    except Exception as exc:
        balance = {}
        err(f"data/balance.json: некорректные данные кампании: {exc}")
    if isinstance(balance, dict):
        if int(balance.get("version", 0)) != 8:
            err("data/balance.json: для полировки MVP ожидается версия баланса 8")
        if len(balance) != 19:
            err(f"data/balance.json: ожидается 19 разделов, найдено {len(balance)}")
        campaign = balance.get("campaign", {})
        stages = campaign.get("stages", []) if isinstance(campaign, dict) else []
        enemies = balance.get("enemies", {}) if isinstance(balance.get("enemies", {}), dict) else {}
        if not isinstance(stages, list) or len(stages) < 3:
            err("data/balance.json: кампания должна содержать не менее трёх этапов")
            stages = []
        names: set[str] = set()
        bosses = 0
        for number, stage in enumerate(stages, start=1):
            if not isinstance(stage, dict):
                err(f"data/balance.json: этап {number} должен быть объектом")
                continue
            name = str(stage.get("name", ""))
            if not name or name in names:
                err(f"data/balance.json: у этапа {number} отсутствует уникальное название")
            names.add(name)
            waves = stage.get("enemies", [])
            if not isinstance(waves, list) or not waves:
                err(f"data/balance.json: у этапа {number} нет противников")
                waves = []
            for wave in waves:
                if not isinstance(wave, dict):
                    err(f"data/balance.json: у этапа {number} некорректная волна противников")
                    continue
                enemy_id = str(wave.get("id", ""))
                if enemy_id not in enemies:
                    err(f"data/balance.json: этап {number} ссылается на неизвестного противника {enemy_id}")
                if bool(wave.get("boss", False)) or str(stage.get("kind", "")) == "босс":
                    bosses += 1
            reward = stage.get("reward", {})
            if not isinstance(reward, dict) or int(reward.get("experience", 0)) <= 0 or int(reward.get("gold", 0)) <= 0 or int(reward.get("materials", 0)) <= 0:
                err(f"data/balance.json: у этапа {number} нет положительных наград")
        if bosses == 0:
            err("data/balance.json: в кампании должен быть хотя бы один босс")
        if len(stages) != 30:
            err(f"data/balance.json: MVP требует ровно 30 этапов, найдено {len(stages)}")
        if not isinstance(campaign, dict) or str(campaign.get("region", "")) != "Пепельные земли":
            err("data/balance.json: в MVP один регион — Пепельные земли")
        chapters = campaign.get("chapters", []) if isinstance(campaign, dict) else []
        if not isinstance(chapters, list) or len(chapters) != 5:
            err("data/balance.json: 30 этапов должны быть разделены на пять глав")
            chapters = []
        chapter_names = {str(ch.get("name", "")) for ch in chapters if isinstance(ch, dict)}
        for number, stage in enumerate(stages, start=1):
            if not isinstance(stage, dict):
                continue
            if str(stage.get("region", "")) != "Пепельные земли":
                err(f"data/balance.json: этап {number} относится к другому региону")
            if str(stage.get("chapter", "")) not in chapter_names:
                err(f"data/balance.json: у этапа {number} неизвестная глава")
        categories: dict[str, int] = {}
        for enemy in enemies.values():
            if isinstance(enemy, dict):
                category = str(enemy.get("category", ""))
                categories[category] = categories.get(category, 0) + 1
        if categories.get("обычный", 0) != 8 or categories.get("элита", 0) != 3 or categories.get("босс", 0) != 3:
            err("data/balance.json: MVP требует 8 обычных противников, 3 элиты и 3 босса")
        boss_stages = sum(1 for stage in stages if isinstance(stage, dict) and str(stage.get("kind", "")) == "босс")
        elite_stages = sum(1 for stage in stages if isinstance(stage, dict) and str(stage.get("kind", "")) == "элита")
        if boss_stages != 7 or elite_stages != 6:
            err("data/balance.json: ожидается 7 боссовых и 6 элитных этапов кампании")
        previous_rewards = (0, 0, 0)
        for number, stage in enumerate(stages, start=1):
            if not isinstance(stage, dict):
                continue
            reward = stage.get("reward", {})
            if not isinstance(reward, dict):
                continue
            current_rewards = (
                int(reward.get("experience", 0)),
                int(reward.get("gold", 0)),
                int(reward.get("materials", 0)),
            )
            if any(current_rewards[i] < previous_rewards[i] for i in range(3)):
                err(f"data/balance.json: награда этапа {number} меньше предыдущей")
            previous_rewards = current_rewards
        notes.append(f"Кампания: этапов {len(stages)}, глав {len(chapters)}, боссовых этапов {boss_stages}, врагов {len(enemies)}")

# --- 5. Данные экипировки --------------------------------------------------
if isinstance(balance, dict):
    equipment = balance.get("equipment", {})
    if not isinstance(equipment, dict):
        err("data/balance.json: раздел equipment должен быть объектом")
        equipment = {}
    slots = equipment.get("slots", [])
    rarities = equipment.get("rarities", [])
    affixes = equipment.get("affixes", [])
    summons = equipment.get("summons", {})
    if not isinstance(slots, list) or len(slots) != 9:
        err("data/balance.json: экипировка должна содержать ровно девять слотов")
        slots = []
    if not isinstance(rarities, list) or len(rarities) != 6:
        err("data/balance.json: экипировка должна содержать ровно шесть редкостей")
        rarities = []
    if not isinstance(affixes, list) or len(affixes) < 1:
        err("data/balance.json: у предметов должны быть случайные свойства")
        affixes = []
    rarity_ids: set[str] = set()
    for rarity in rarities:
        if not isinstance(rarity, dict):
            err("data/balance.json: редкость должна быть объектом")
            continue
        rarity_id = str(rarity.get("id", ""))
        if not rarity_id or rarity_id in rarity_ids:
            err("data/balance.json: у редкости отсутствует уникальный идентификатор")
        rarity_ids.add(rarity_id)
        if float(rarity.get("multiplier", 0)) <= 0 or int(rarity.get("score", 0)) <= 0:
            err(f"data/balance.json: у редкости {rarity_id} некорректные коэффициенты")
    if not isinstance(summons, dict) or len(summons) < 2:
        err("data/balance.json: должно быть не менее двух категорий призыва")
        summons = {}
    for summon_id, summon in summons.items():
        if not isinstance(summon, dict):
            err(f"data/balance.json: призыв {summon_id} должен быть объектом")
            continue
        chances = summon.get("chances", {})
        if not isinstance(chances, dict):
            err(f"data/balance.json: у призыва {summon_id} некорректные вероятности")
            chances = {}
        chance_sum = sum(float(chances.get(rarity_id, 0)) for rarity_id in rarity_ids)
        if abs(chance_sum - 1.0) > 0.001:
            err(f"data/balance.json: вероятности призыва {summon_id} не дают единицу")
        if int(summon.get("cost_gold", 0)) <= 0 or int(summon.get("pity_threshold", 0)) <= 0:
            err(f"data/balance.json: у призыва {summon_id} некорректная стоимость или гарантия")
        if str(summon.get("guaranteed_rarity", "")) not in rarity_ids:
            err(f"data/balance.json: у призыва {summon_id} неизвестная гарантированная редкость")
    upgrade = equipment.get("upgrade", {})
    if not isinstance(upgrade, dict) or int(upgrade.get("max_level", 0)) <= 0 or float(upgrade.get("stat_growth", 0)) <= 0:
        err("data/balance.json: некорректные параметры улучшения предметов")
    dismantle = equipment.get("dismantle", {})
    if isinstance(dismantle, dict):
        gold_map = dismantle.get("gold", {})
        materials_map = dismantle.get("materials", {})
        if not isinstance(gold_map, dict) or not isinstance(materials_map, dict):
            err("data/balance.json: некорректные награды за разбор")
        else:
            for rarity_id in rarity_ids:
                if rarity_id not in gold_map or rarity_id not in materials_map:
                    err(f"data/balance.json: нет награды за разбор редкости {rarity_id}")
    notes.append(f"Экипировка: слотов {len(slots)}, редкостей {len(rarities)}, призывов {len(summons)}")

# --- 5.1. Данные прогрессии пятого этапа -----------------------------------
progression = balance.get("progression", {})
attributes = balance.get("attributes", [])
coefficients = balance.get("attribute_coefficients", {})
skills = balance.get("skills", {})
variants = balance.get("skill_variants", {})
passives = balance.get("passives", {})
pets = balance.get("pets", {})
balance_settings = balance.get("balance", {})
if not isinstance(progression, dict):
    err("data/balance.json: раздел progression должен быть объектом")
    progression = {}
for key in ("starting_attribute_points", "starting_skill_points", "attribute_points_per_level", "skill_points_per_level", "attribute_soft_cap"):
    if int(progression.get(key, -1)) < 0:
        err(f"data/balance.json: параметр progression.{key} должен быть неотрицательным")
for key in ("skill_upgrade", "passive_upgrade", "pet_upgrade"):
    upgrade = progression.get(key, {})
    if not isinstance(upgrade, dict) or int(upgrade.get("gold_base", 0)) <= 0 or int(upgrade.get("materials_base", 0)) <= 0:
        err(f"data/balance.json: некорректная стоимость улучшения progression.{key}")
if not isinstance(attributes, list) or len(attributes) != 5:
    err("data/balance.json: должно быть ровно пять базовых характеристик")
    attributes = []
attribute_ids: set[str] = set()
for attribute in attributes:
    if not isinstance(attribute, dict):
        err("data/balance.json: характеристика должна быть объектом")
        continue
    attribute_id = str(attribute.get("id", ""))
    if not attribute_id or attribute_id in attribute_ids or not str(attribute.get("name", "")) or not str(attribute.get("short", "")):
        err(f"data/balance.json: у характеристики {attribute_id!r} нет уникального идентификатора или русских подписей")
    attribute_ids.add(attribute_id)
    if int(attribute.get("max_points", 0)) <= 0:
        err(f"data/balance.json: у характеристики {attribute_id} некорректный предел очков")
if not isinstance(coefficients, dict) or not coefficients:
    err("data/balance.json: отсутствуют коэффициенты характеристик")
    coefficients = {}
for key, value in coefficients.items():
    if float(value) <= 0.0:
        err(f"data/balance.json: коэффициент {key} должен быть положительным")
if not isinstance(skills, dict) or len(skills) != 6:
    err("data/balance.json: должно быть ровно шесть активных навыков")
    skills = {}
for skill_id, skill in skills.items():
    if not isinstance(skill, dict) or not str(skill.get("name", "")) or float(skill.get("cooldown_seconds", 0)) <= 0.0 or int(skill.get("max_level", 0)) <= 0 or "auto_use" not in skill:
        err(f"data/balance.json: у навыка {skill_id} некорректные название, откат, предел или авто-режим")
if not isinstance(variants, dict) or len(variants) != 2:
    err("data/balance.json: должно быть ровно два варианта развития навыков")
    variants = {}
for variant_id, variant in variants.items():
    if not isinstance(variant, dict) or float(variant.get("effect_multiplier", 0)) <= 0.0 or float(variant.get("cooldown_multiplier", 0)) <= 0.0:
        err(f"data/balance.json: у варианта {variant_id} некорректные множители")
if not isinstance(passives, dict) or len(passives) != 3:
    err("data/balance.json: должно быть ровно три пассивные способности")
    passives = {}
for passive_id, passive in passives.items():
    bonuses = passive.get("bonuses", {}) if isinstance(passive, dict) else {}
    if not isinstance(passive, dict) or not isinstance(bonuses, dict) or not bonuses or int(passive.get("max_level", 0)) <= 0:
        err(f"data/balance.json: у пассивной способности {passive_id} нет бонусов или предела уровня")
if not isinstance(pets, dict) or len(pets) != 3:
    err("data/balance.json: должно быть ровно три питомца")
    pets = {}
unlock_stages: list[int] = []
for pet_id, pet in pets.items():
    assist = pet.get("assist", {}) if isinstance(pet, dict) else {}
    bonuses = pet.get("base_bonuses", {}) if isinstance(pet, dict) else {}
    unlock_stage = int(pet.get("unlock_stage", 0)) if isinstance(pet, dict) else 0
    unlock_stages.append(unlock_stage)
    if not isinstance(pet, dict) or not isinstance(bonuses, dict) or not bonuses or not isinstance(assist, dict) or float(assist.get("attack_ratio", 0)) <= 0.0 or unlock_stage < 1 or unlock_stage > len(stages):
        err(f"data/balance.json: у питомца {pet_id} нет бонусов, помощи в бою или корректного этапа открытия")
if sorted(unlock_stages) != sorted(set(unlock_stages)):
    err("data/balance.json: этапы открытия питомцев не могут повторяться")
if not isinstance(balance_settings, dict):
    err("data/balance.json: раздел balance должен быть объектом")
    balance_settings = {}
targets = balance_settings.get("stage_power_targets", [])
if not isinstance(targets, list) or len(targets) != len(stages) or any(float(value) <= 0.0 for value in targets):
    err("data/balance.json: для каждого этапа нужна положительная цель силы")
    targets = []
elif targets != sorted(targets):
    err("data/balance.json: цели силы должны не убывать по этапам")
weights = balance_settings.get("power_weights", {})
if not isinstance(weights, dict) or not weights or any(float(value) <= 0.0 for value in weights.values()):
    err("data/balance.json: веса оценки силы должны быть положительными")
if float(balance_settings.get("tolerance", 0)) <= 0.0:
    err("data/balance.json: коридор баланса должен быть положительным")
auto_battle = balance_settings.get("auto_battle", {})
if not isinstance(auto_battle, dict) or not 0.0 < float(auto_battle.get("max_skill_share", 0)) <= 1.0 or float(auto_battle.get("min_stage_duration_seconds", 0)) <= 0.0:
    err("data/balance.json: некорректные ограничения автоматического боя")
notes.append(f"Прогрессия: характеристик {len(attributes)}, навыков {len(skills)}, пассивных способностей {len(passives)}, питомцев {len(pets)}")

# --- 5.2. Сохранения и офлайн-награды шестого этапа -----------------------
afk = balance.get("afk", {})
save = balance.get("save", {})
if not isinstance(afk, dict):
    err("data/balance.json: раздел afk должен быть объектом")
    afk = {}
if not isinstance(save, dict):
    err("data/balance.json: раздел save должен быть объектом")
    save = {}
if float(afk.get("limit_hours", 0)) <= 0.0:
    err("data/balance.json: лимит AFK должен быть положительным")
if int(afk.get("tick_seconds", 0)) <= 0 or int(afk.get("min_seconds", -1)) < 0:
    err("data/balance.json: некорректные интервалы расчёта AFK")
passive_efficiency = float(afk.get("afk_efficiency", 0))
active_efficiency = float(afk.get("active_efficiency", 0))
if not 0.0 < passive_efficiency < active_efficiency <= 1.0:
    err("data/balance.json: активная игра должна быть эффективнее AFK")
if float(afk.get("stage_efficiency_per_stage", -1)) < 0.0 or float(afk.get("max_stage_multiplier", 0)) < 1.0:
    err("data/balance.json: некорректная эффективность по достигнутому этапу")
max_afk_efficiency = passive_efficiency * float(afk.get("max_stage_multiplier", 1.0))
if max_afk_efficiency >= active_efficiency:
    err("data/balance.json: максимальная эффективность AFK должна уступать активной игре")
afk_rewards = afk.get("rewards_per_tick", {})
if not isinstance(afk_rewards, dict) or any(float(value) <= 0.0 for value in afk_rewards.values()):
    err("data/balance.json: награды AFK за интервал должны быть положительными")
if int(save.get("format_version", 0)) != 8:
    err("data/balance.json: после изменения настроек ожидается версия формата сохранения 8")
if float(save.get("autosave_interval_seconds", 0)) <= 0.0:
    err("data/balance.json: интервал автосохранения должен быть положительным")
if int(save.get("max_profile_bytes", 0)) <= 0:
    err("data/balance.json: предел размера профиля должен быть положительным")
profile_path = str(save.get("profile_path", ""))
if not profile_path.startswith("user://") or not profile_path.endswith(".json"):
    err("data/balance.json: профиль должен храниться в локальном user:// JSON-файле")
if not str(save.get("temp_suffix", "")) or not str(save.get("backup_suffix", "")) or str(save.get("temp_suffix", "")) == str(save.get("backup_suffix", "")):
    err("data/balance.json: у временного файла и резервной копии должны быть разные суффиксы")
player_settings = save.get("default_settings", {})
if (
    not isinstance(player_settings, dict)
    or "sound_enabled" not in player_settings
    or "particles_enabled" not in player_settings
    or "effects_enabled" not in player_settings
    or int(player_settings.get("target_fps", 0)) <= 0
):
    err("data/balance.json: некорректные сохраняемые настройки игрока")
fps_options = save.get("fps_options", [])
if not isinstance(fps_options, list) or not fps_options or any(int(value) <= 0 for value in fps_options):
    err("data/balance.json: варианты частоты кадров должны быть положительными")
elif isinstance(player_settings, dict) and int(player_settings.get("target_fps", 0)) not in [int(value) for value in fps_options]:
    err("data/balance.json: частота кадров по умолчанию должна входить в список вариантов")
for rel in [
    "scripts/save/save_catalog.gd",
    "scripts/save/save_manager.gd",
    "scripts/save/profile_manager.gd",
    "tests/test_saves.gd",
    "docs/saves.md",
]:
    if not (ROOT / rel).is_file():
        err(f"Шестой этап: отсутствует {rel}")
main_src = (ROOT / "scripts/main/main.gd").read_text(encoding="utf-8") if (ROOT / "scripts/main/main.gd").is_file() else ""
for token in ["profile_manager.bootstrap", "NOTIFICATION_APPLICATION_PAUSED", "NOTIFICATION_EXIT_TREE", "_apply_settings", "_save("]:
    if token not in main_src:
        err(f"scripts/main/main.gd: отсутствует подключение сохранений ({token})")
scene_src = (ROOT / "scenes/main/main.tscn").read_text(encoding="utf-8") if (ROOT / "scenes/main/main.tscn").is_file() else ""
for token in ["SettingsRow", "SoundButton", "ParticlesButton", "FpsButton"]:
    if token not in scene_src:
        err(f"scenes/main/main.tscn: отсутствует рабочая настройка {token}")
if "сохранение появится позже" in scene_src or "сохранение появится позже" in main_src:
    err("Шестой этап: в интерфейсе осталась устаревшая подсказка о сохранении")
notes.append(
    f"Сохранение: версия {int(save.get('format_version', 0))}, "
    f"AFK {float(afk.get('limit_hours', 0)):g} ч, автосохранение "
    f"{float(save.get('autosave_interval_seconds', 0)):g} с"
)

# --- 5.3. Контент и режимы седьмого этапа ----------------------------------
modes = balance.get("modes", {})
if not isinstance(modes, dict):
    err("data/balance.json: раздел modes должен быть объектом")
    modes = {}
mode_list = modes.get("list", [])
if not isinstance(mode_list, list) or len(mode_list) != 3:
    err("data/balance.json: MVP требует ровно три игровых режима")
    mode_list = []
mode_ids = [str(mode.get("id", "")) for mode in mode_list if isinstance(mode, dict)]
if mode_ids != ["campaign", "tower", "dungeon"]:
    err("data/balance.json: ожидаются режимы campaign, tower и dungeon")
mode_unlocks = {
    str(mode.get("id", "")): int(mode.get("unlock_stage", 0))
    for mode in mode_list if isinstance(mode, dict)
}
if mode_unlocks.get("campaign", 0) != 1 or mode_unlocks.get("tower", 0) != 5 or mode_unlocks.get("dungeon", 0) != 8:
    err("data/balance.json: режимы должны открываться на этапах 1, 5 и 8")
for mode in mode_list:
    if not isinstance(mode, dict):
        continue
    mode_id = str(mode.get("id", ""))
    for key in ("name", "short", "region", "description", "progress_label", "action_next", "action_restart"):
        if not str(mode.get(key, "")):
            err(f"data/balance.json: у режима {mode_id} нет подписи {key}")
if not str(modes.get("defeat_action", "")):
    err("data/balance.json: у режимов нет подписи действия после поражения")

tower = modes.get("tower", {})
if not isinstance(tower, dict):
    err("data/balance.json: раздел modes.tower должен быть объектом")
    tower = {}
tower_floors = tower.get("floors", [])
if not isinstance(tower_floors, list) or len(tower_floors) != 30:
    err("data/balance.json: Башня испытаний должна содержать 30 ярусов")
    tower_floors = []
tower_names: set[str] = set()
for number, floor in enumerate(tower_floors, start=1):
    if not isinstance(floor, dict):
        err(f"data/balance.json: ярус {number} должен быть объектом")
        continue
    floor_name = str(floor.get("name", ""))
    if not floor_name or floor_name in tower_names:
        err(f"data/balance.json: у яруса {number} отсутствует уникальное название")
    tower_names.add(floor_name)
    waves = floor.get("enemies", [])
    if not isinstance(waves, list) or not waves:
        err(f"data/balance.json: у яруса {number} нет противников")
        waves = []
    for wave in waves:
        if not isinstance(wave, dict) or str(wave.get("id", "")) not in enemies:
            err(f"data/balance.json: ярус {number} ссылается на неизвестного противника")
    reward = floor.get("reward", {})
    if not isinstance(reward, dict) or any(int(reward.get(key, 0)) <= 0 for key in ("experience", "gold", "materials")):
        err(f"data/balance.json: у яруса {number} нет положительных наград")
    if number % 5 == 0 and str(floor.get("kind", "")) != "босс":
        err(f"data/balance.json: ярус {number} должен завершаться боссом")

dungeon = modes.get("dungeon", {})
if not isinstance(dungeon, dict):
    err("data/balance.json: раздел modes.dungeon должен быть объектом")
    dungeon = {}
dungeon_runs = dungeon.get("runs", [])
if not isinstance(dungeon_runs, list) or len(dungeon_runs) != 3:
    err("data/balance.json: должно быть ровно три подземелья ресурсов")
    dungeon_runs = []
run_ids: set[str] = set()
unlock_stages = []
for run in dungeon_runs:
    if not isinstance(run, dict):
        err("data/balance.json: подземелье должно быть объектом")
        continue
    run_id = str(run.get("id", ""))
    if not run_id or run_id in run_ids:
        err("data/balance.json: у подземелья отсутствует уникальный идентификатор")
    run_ids.add(run_id)
    unlock_stages.append(int(run.get("unlock_stage", 0)))
    cost = run.get("entry_cost", {})
    reward = run.get("reward", {})
    if not isinstance(cost, dict) or int(cost.get("gold", -1)) < 0 or int(cost.get("materials", -1)) < 0:
        err(f"data/balance.json: у подземелья {run_id} некорректная цена входа")
    if not isinstance(reward, dict) or any(int(reward.get(key, 0)) <= 0 for key in ("experience", "gold", "materials")):
        err(f"data/balance.json: у подземелья {run_id} нет положительных наград")
    waves = run.get("enemies", [])
    if not isinstance(waves, list) or not waves:
        err(f"data/balance.json: у подземелья {run_id} нет противников")
        waves = []
    for wave in waves:
        if not isinstance(wave, dict) or str(wave.get("id", "")) not in enemies:
            err(f"data/balance.json: подземелье {run_id} ссылается на неизвестного противника")
if sorted(unlock_stages) != [8, 12, 18] or len(set(unlock_stages)) != 3:
    err("data/balance.json: подземелья должны открываться на этапах 8, 12 и 18")

stage_files = [
    "scripts/campaign/mode_catalog.gd",
    "tests/test_modes.gd",
    "docs/campaign.md",
    "docs/saves.md",
]
for rel in stage_files:
    if not (ROOT / rel).is_file():
        err(f"Седьмой этап: отсутствует {rel}")
main_src = (ROOT / "scripts/main/main.gd").read_text(encoding="utf-8") if (ROOT / "scripts/main/main.gd").is_file() else ""
for token in ["ModeCatalog", "_on_tab_pressed", "_refresh_mode_ui", "_on_dungeon_button_pressed", "вход в подземелье"]:
    if token not in main_src:
        err(f"scripts/main/main.gd: отсутствует подключение режимов ({token})")
scene_src = (ROOT / "scenes/main/main.tscn").read_text(encoding="utf-8") if (ROOT / "scenes/main/main.tscn").is_file() else ""
for token in ["ModeButton", "ModePanel", "CampaignModeButton", "TowerModeButton", "DungeonModeButton", "GoldDungeonButton", "MaterialsDungeonButton", "ExperienceDungeonButton"]:
    if token not in scene_src:
        err(f"scenes/main/main.tscn: отсутствует рабочая кнопка/панель режима {token}")
save_src = (ROOT / "scripts/save/save_manager.gd").read_text(encoding="utf-8")
for token in ["ModeCatalog.state_from_snapshot", 'result["modes"]']:
    if token not in save_src:
        err(f"scripts/save/save_manager.gd: отсутствует миграция режимов ({token})")
campaign_src = (ROOT / "scripts/campaign/campaign_state.gd").read_text(encoding="utf-8")
for token in ["ModeCatalog.stage_at", "ModeCatalog.state_from_snapshot", "select_mode", "select_dungeon"]:
    if token not in campaign_src:
        err(f"scripts/campaign/campaign_state.gd: отсутствует поддержка режимов ({token})")
ci_src = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8") if (ROOT / ".github/workflows/ci.yml").is_file() else ""
if "tests/test_modes.gd" not in ci_src:
    err(".github/workflows/ci.yml: отсутствует точечная проверка режимов")
if "tests/test_input.gd" not in ci_src:
    err("автоматическая сборка не запускает tests/test_input.gd")
if "tests/test_presentation.gd" not in ci_src:
    err(".github/workflows/ci.yml: отсутствует точечная проверка полировки")
notes.append(f"Режимы: {len(mode_list)}, ярусов {len(tower_floors)}, подземелий {len(dungeon_runs)}")

# --- 5.4. Полировка восьмого этапа -----------------------------------------
presentation = balance.get("presentation", {})
if not isinstance(presentation, dict):
    err("data/balance.json: раздел presentation должен быть объектом")
    presentation = {}
ui_refresh = float(presentation.get("ui_refresh_seconds", 0))
if not 0.0 < ui_refresh <= 0.2:
    err("data/balance.json: интервал обновления интерфейса должен быть не более 0.2 с")
performance_sample = float(presentation.get("performance_sample_seconds", 0))
if not 0.0 < performance_sample <= 10.0:
    err("data/balance.json: некорректный интервал замера частоты кадров")
effect_pool = presentation.get("effect_pool", {})
if not isinstance(effect_pool, dict):
    err("data/balance.json: effect_pool должен быть объектом")
    effect_pool = {}
pool_capacity = int(effect_pool.get("capacity", 0))
if not 1 <= pool_capacity <= 16:
    err("data/balance.json: пул эффектов должен содержать от 1 до 16 подписей")
for key in ("label_duration_seconds", "label_rise_pixels", "label_font_size", "skill_font_size", "flash_duration_seconds"):
    if float(effect_pool.get(key, 0)) <= 0:
        err(f"data/balance.json: параметр эффекта {key} должен быть положительным")
ambient = presentation.get("ambient_particles", {})
if not isinstance(ambient, dict) or not 1 <= int(ambient.get("amount", 0)) < 18:
    err("data/balance.json: количество фоновых частиц должно быть уменьшено")
audio = presentation.get("audio", {})
if not isinstance(audio, dict):
    err("data/balance.json: раздел audio должен быть объектом")
    audio = {}
if not 8000 <= int(audio.get("mix_rate_hz", 0)) <= 48000 or not 1 <= int(audio.get("voice_count", 0)) <= 16:
    err("data/balance.json: некорректные параметры пула локальных звуков")
sound_specs = audio.get("sounds", {})
required_sounds = {"attack", "critical", "skill", "shield", "victory", "defeat", "boss", "click"}
if not isinstance(sound_specs, dict) or set(sound_specs) != required_sounds:
    err("data/balance.json: должны быть описаны все восемь звуковых событий")
else:
    for event_id, spec in sound_specs.items():
        if not isinstance(spec, dict) or any(float(spec.get(key, 0)) <= 0 for key in ("frequency_hz", "end_frequency_hz", "duration_seconds", "amplitude", "fade_seconds")):
            err(f"data/balance.json: некорректные параметры звука {event_id}")
stage8_files = [
    "scripts/ui/presentation_catalog.gd",
    "scripts/ui/ashen_audio.gd",
    "scripts/ui/effect_pool.gd",
    "tests/test_presentation.gd",
    "tests/test_input.gd",
    "docs/android.md",
]
for rel in stage8_files:
    if not (ROOT / rel).is_file():
        err(f"Восьмой этап: отсутствует {rel}")
for token in ["PresentationCatalog", "AshenAudio", "EffectPool", "_on_effects_pressed", "_configure_particles", "view_refresh_seconds", "audio_player.play"]:
    if token not in main_src:
        err(f"scripts/main/main.gd: отсутствует подключение полировки ({token})")
for token in ["EffectsButton", "amount = 12"]:
    if token not in scene_src:
        err(f"scenes/main/main.tscn: отсутствует настройка полировки {token}")
catalog_src = (ROOT / "scripts/save/save_catalog.gd").read_text(encoding="utf-8")
for token in ["DEFAULT_FORMAT_VERSION: int = 8", '"effects_enabled"']:
    if token not in catalog_src:
        err(f"scripts/save/save_catalog.gd: отсутствует настройка восьмого этапа ({token})")
android_doc = (ROOT / "docs/android.md").read_text(encoding="utf-8") if (ROOT / "docs/android.md").is_file() else ""
for token in ["реальном Android-устройстве", "авиарежиме", "30 FPS", "упрощён"]:
    if token not in android_doc:
        err(f"docs/android.md: отсутствует пункт проверки ({token})")
external_audio = files("*.wav") + files("*.ogg") + files("*.mp3")
if external_audio:
    err("Восьмой этап: звуки должны создаваться в памяти, внешние аудиофайлы не нужны")
if "Проверка офлайн-пакета и параметров полировки" not in ci_src:
    err(".github/workflows/ci.yml: отсутствует проверка офлайн-пакета восьмого этапа")
notes.append(
    f"Полировка: интерфейс {ui_refresh:g} с, пул {pool_capacity}, "
    f"звуков {len(sound_specs) if isinstance(sound_specs, dict) else 0}, "
    f"частиц {int(ambient.get('amount', 0)) if isinstance(ambient, dict) else 0}"
)

# --- 5.5. HUD по наброску, нижнее меню и читаемые шрифты -------------------
interface = presentation.get("interface", {})
if not isinstance(interface, dict):
    err("data/balance.json: presentation.interface должен быть объектом")
    interface = {}
fonts = interface.get("fonts", {})
if not isinstance(fonts, dict):
    err("data/balance.json: presentation.interface.fonts должен быть объектом")
    fonts = {}
node_sizes = fonts.get("node_sizes", {})
if not isinstance(node_sizes, dict) or len(node_sizes) < 80:
    err("data/balance.json: должны быть описаны размеры шрифтов всех рабочих узлов")
    node_sizes = {}
if int(fonts.get("default", 0)) < 20:
    err("data/balance.json: базовый шрифт интерфейса должен быть не меньше 20")
if any(int(value) < 18 for value in node_sizes.values()):
    err("data/balance.json: рабочие подписи интерфейса должны быть не меньше 18")
if int(effect_pool.get("spark_capacity", 0)) < 16:
    err("data/balance.json: пул искр попаданий должен вмещать не меньше 16 частиц")
if int(effect_pool.get("slash_capacity", 0)) < 2:
    err("data/balance.json: следов оружия должно быть не меньше двух")
if float(effect_pool.get("spark_life_seconds", 0)) <= 0.0 or float(effect_pool.get("slash_life_seconds", 0)) <= 0.0:
    err("data/balance.json: эффекты попаданий должны иметь конечное время жизни")
death_tint = effect_pool.get("death_tint_rgba", [])
if not isinstance(death_tint, list) or len(death_tint) < 4 or float(death_tint[3]) >= 1.0:
    err("data/balance.json: поверженный враг должен уходить в приглушённый силуэт")
hit_flash = effect_pool.get("hit_flash_rgba", [])
if not isinstance(hit_flash, list) or len(hit_flash) < 4:
    err("data/balance.json: у попадания должен быть цвет вспышки")
if float(effect_pool.get("death_fade_seconds", 0)) <= 0.0:
    err("data/balance.json: затухание поверженного врага должно занимать время")
if int(effect_pool.get("skill_font_size", 0)) < 18:
    err("data/balance.json: всплывающие названия навыков должны быть не меньше 18")
minimum_sizes = interface.get("minimum_sizes", {})
if not isinstance(minimum_sizes, dict) or len(minimum_sizes) < 90:
    err("data/balance.json: размеры панелей и кнопок должны быть централизованы")
    minimum_sizes = {}
for slot_name, expected in (("SkillSlot3", [52, 52]), ("SkillSlot4", [52, 52]), ("AutoButton", [160, 44])):
    value = minimum_sizes.get(slot_name, []) if isinstance(minimum_sizes, dict) else []
    if not isinstance(value, list) or len(value) < 2 or [int(value[0]), int(value[1])] != expected:
        err(f"data/balance.json: {slot_name} должен быть {expected[0]}x{expected[1]}")
overlay_config = (interface.get("hud", {}) or {}).get("battle_overlay", {})
if not isinstance(overlay_config, dict):
    err("data/balance.json: battle_overlay должен описывать кнопки навыков")
    overlay_config = {}
skill_icons = overlay_config.get("icons", {})
if not isinstance(skill_icons, dict) or not str(skill_icons.get("StrikeButton", "")).endswith("crossed_swords_icon.png") or not str(skill_icons.get("GuardButton", "")).endswith("shield_icon.png"):
    err("data/balance.json: у кнопок удара и щита должны быть локальные иконки")
cooldown_ring = overlay_config.get("cooldown_ring", {})
if not isinstance(cooldown_ring, dict) or float(cooldown_ring.get("thickness", 0)) < 4:
    err("data/balance.json: кольцо перезарядки должно иметь заметную толщину")
if float(overlay_config.get("auto_delay_seconds", 0)) < 0.5:
    err("data/balance.json: автобой должен ждать перед продолжением пути")
if int(overlay_config.get("slots", 0)) < 2 or str(overlay_config.get("slot_tooltip", "")) != "СКОРО":
    err("data/balance.json: слоты будущих навыков должны быть подписаны СКОРО")
for name_index in range(1, 6):
    value = minimum_sizes.get(f"EnemyNameLabel{name_index}", []) if isinstance(minimum_sizes, dict) else []
    if not isinstance(value, list) or len(value) < 2 or int(value[1]) < 40:
        err(f"data/balance.json: EnemyNameLabel{name_index} должен вмещать две строки имени врага")
for bar_name, min_height, min_width in (("HeroHealthBar", 26, 0), ("EnemyMiniBar1", 10, 124)):
    value = minimum_sizes.get(bar_name, []) if isinstance(minimum_sizes, dict) else []
    if not isinstance(value, list) or len(value) < 2 or int(value[1]) < min_height or int(value[0]) < min_width:
        err(f"data/balance.json: {bar_name} должен быть шкалой над фигурой (не ниже {min_height} пикселей)")
spacing = interface.get("spacing", {})
if not isinstance(spacing, dict) or len(spacing) < 30:
    err("data/balance.json: отступы интерфейса должны быть централизованы")
    spacing = {}
margin_spec = spacing.get("Margin", {}) if isinstance(spacing, dict) else {}
if not isinstance(margin_spec, dict) or int(margin_spec.get("margin_left", 0)) < 8 or int(margin_spec.get("margin_bottom", 0)) < 8:
    err("data/balance.json: у экрана разделов должны оставаться отступы от краёв")
layout = interface.get("layout", {})
if not isinstance(layout, dict):
    err("data/balance.json: presentation.interface.layout должен быть объектом")
    layout = {}
grid_columns = layout.get("grid_columns", {})
nav_ratios = layout.get("nav_ratios", {})
if not isinstance(nav_ratios, dict) or len(nav_ratios) != 6 or any(float(value) <= 0.0 for value in nav_ratios.values()):
    err("data/balance.json: пропорции кнопок нижней навигации должны быть описаны для шести разделов")
if not isinstance(grid_columns, dict) or int(grid_columns.get("ArenaEnemies", 0)) != 3 or "BottomTabs" in grid_columns:
    err("data/balance.json: арена остаётся сеткой на три колонки, а навигация идёт одной полосой")
navigation = interface.get("navigation", {})
if not isinstance(navigation, dict):
    err("data/balance.json: presentation.interface.navigation должен быть объектом")
    navigation = {}
tab_order = navigation.get("tab_order", [])
tabs = navigation.get("tabs", {})
expected_tabs = {"battle", "inventory", "summon", "progression", "mode", "settings"}
if not isinstance(tab_order, list) or len(tab_order) != 6 or set(tab_order) != expected_tabs:
    err("data/balance.json: нижнее меню должно содержать шесть рабочих разделов")
if not isinstance(tabs, dict) or set(tabs) != expected_tabs:
    err("data/balance.json: разделы нижнего меню должны быть описаны полностью")
else:
    for tab_id, spec in tabs.items():
        if not isinstance(spec, dict) or any(key not in spec for key in ("button", "panel", "label", "section_title", "panel_title_node")):
            err(f"data/balance.json: неполное описание раздела {tab_id}")

hud = interface.get("hud", {})
if not isinstance(hud, dict):
    err("data/balance.json: presentation.interface.hud должен быть объектом")
    hud = {}
expected_background = "res://assets/ui/background_sketch.png"
if str(layout.get("background_texture", "")) != expected_background:
    err("data/balance.json: новый оригинальный фон должен быть задан через presentation.interface")
for rel, label in [
    ("assets/ui/background_sketch.png", "игрового фона"),
    ("assets/ui/hero_portrait.png", "портрета героя"),
]:
    if not (ROOT / rel).is_file() or not (ROOT / (rel + ".import")).is_file():
        err(f"Ассеты {label} и их файлы импорта должны присутствовать в репозитории")
nav_icons = hud.get("nav_icons", {})
nav_buttons = {"battle": "BattleButton", "inventory": "EquipmentButton", "summon": "SummonButton",
               "progression": "ProgressionButton", "mode": "ModeButton", "settings": "SettingsButton"}
if not isinstance(nav_icons, dict) or set(nav_icons) != expected_tabs:
    err("data/balance.json: нижняя навигация должна содержать иконки шести реальных разделов")
else:
    for tab_id, spec in nav_icons.items():
        if not isinstance(spec, dict) or any(key not in spec for key in ("button", "icon", "label")):
            err(f"data/balance.json: неполное описание иконки раздела {tab_id}")
            continue
        if str(spec["button"]) != nav_buttons[tab_id]:
            err(f"data/balance.json: иконка раздела {tab_id} должна стоять на кнопке {nav_buttons[tab_id]}")
        icon_rel = str(spec["icon"]).removeprefix("res://")
        if not (ROOT / icon_rel).is_file() or not (ROOT / (icon_rel + ".import")).is_file():
            err(f"Иконка раздела {tab_id} и её файл импорта отсутствуют")
if not str(hud.get("nickname", "")).strip():
    err("data/balance.json: в карточке профиля должен быть задан никнейм")
stub_icons = hud.get("stub_icons", {})
if not isinstance(stub_icons, dict) or len(stub_icons) < 8:
    err("data/balance.json: должны быть описаны локальные иконки некликабельных заглушек")
else:
    for node_name, icon_path in stub_icons.items():
        icon_rel = str(icon_path).removeprefix("res://")
        if not str(icon_path).startswith("res://assets/ui/icons/"):
            err(f"data/balance.json: иконка {node_name} должна быть локальным ресурсом")
        elif not (ROOT / icon_rel).is_file() or not (ROOT / (icon_rel + ".import")).is_file():
            err(f"Иконка заглушки {node_name} и её файл импорта отсутствуют")
hero_figure = str(hud.get("hero_figure", ""))
if not hero_figure.endswith("hero_battle.png"):
    err("data/balance.json: фигура героя на поле боя не задана")
figures = hud.get("enemy_figures", {})
if not isinstance(figures, dict) or len(figures.get("by_id", {})) < 10 or len(figures.get("figures", [])) < 3:
    err("data/balance.json: фигуры войск противника заданы не полностью")
for figure_path in list(figures.get("figures", [])) + [hero_figure]:
    rel = str(figure_path).replace("res://", "")
    if not (ROOT / rel).is_file():
        err(f"нет файла фигуры боя: {rel}")
stub_labels = hud.get("stub_labels", {})
if not isinstance(stub_labels, dict) or len(stub_labels) < 4 or any("СКОРО" not in str(text) for text in stub_labels.values()):
    err("data/balance.json: все нереализованные элементы должны быть помечены СКОРО")
if str(hud.get("stub_text", "")) != "СКОРО":
    err("data/balance.json: общая подпись заглушек должна быть СКОРО")
if str(hud.get("portrait_texture", "")) != "res://assets/ui/hero_portrait.png":
    err("data/balance.json: портрет героя должен быть локальным оригинальным ассетом")
if str(hud.get("enemy_texture", "")) != "res://assets/ui/icons/enemy_wraith.svg" or int(hud.get("enemy_cards", 0)) != 5:
    err("data/balance.json: силуэты врагов арены должны быть описаны централизованно")

for token in ["background_sketch.png", "hero_portrait.png", "ArenaHero", "ProfilePanel", "NicknameLabel", "RatingValueLabel", "HeroVitals", "HeroPortrait", "HeroHealthBar", "EnemyMiniBar1", "EnemyNameLabel1", "FutureRail", "ArenaEnemies", "BottomBar", "BottomTabs", "SummonPanel", "SettingsPanel", "SectionTitle", "BattleOverlay", "LogCard", "StrikeButton", "GuardButton", "StrikeCooldown", "GuardCooldown", "StrikeCooldownLabel", "GuardCooldownLabel", "SkillSlot3", "SkillSlot4", "AutoButton"]:
    if token not in scene_src:
        err(f"scenes/main/main.tscn: отсутствует узел или ресурс игрового HUD ({token})")
for forbidden in ["MiniMap", "Minimap", "Joystick", "VirtualJoystick", "MapFrame"]:
    if re.search(r'\[node name="[^"]*' + forbidden, scene_src, flags=re.I):
        err(f"scenes/main/main.tscn: мини-карта или джойстик не должны присутствовать ({forbidden})")

def scene_section(start_marker: str, end_marker: str) -> str:
    first = scene_src.find(start_marker)
    second = scene_src.find(end_marker, first + 1) if first >= 0 else -1
    return scene_src[first:second] if first >= 0 and second > first else ""

for start_marker, end_marker, label in [
    ('[node name="QuestStub"', '[node name="FutureRail"', "задания"),
    ('[node name="FutureRail"', '[node name="StubStrip"', "будущих разделов"),
    ('[node name="StubStrip"', '[node name="BattleOverlay"', "декоративных заглушек"),
    ('[node name="ArenaEnemies"', '[node name="ProfilePanel"', "арены"),
    ('[node name="HeroVitals"', '[node name="CurrencyBar"', "шкал над фигурой героя"),
]:
    section = scene_section(start_marker, end_marker)
    if not section or 'type="Button"' in section or 'type="TextureButton"' in section:
        err(f"scenes/main/main.tscn: секция {label} должна быть некликабельным декором без кнопок")
animations_config = interface.get("animations", {})
if not isinstance(animations_config, dict) or len(animations_config) < 6:
    err("data/balance.json: плавные анимации интерфейса должны быть описаны в presentation.interface.animations")
else:
    for anim_key, anim_max in (("section_fade_seconds", 0.45), ("nav_glow_seconds", 0.45), ("pop_scale_seconds", 0.45), ("press_seconds", 0.4)):
        value = float(animations_config.get(anim_key, 0.0))
        if value <= 0.0 or value > anim_max:
            err(f"data/balance.json: {anim_key} должен быть коротким и заметным")
main_src = (ROOT / "scripts/main/main.gd").read_text(encoding="utf-8")
for token in ("_animate_control", "_tick_ui_animations", '"glow"', '"pop"'):
    if token not in main_src:
        err(f"scripts/main/main.gd: плавные анимации интерфейса должны использовать {token}")
style_src = (ROOT / "scripts/ui/ashen_style.gd").read_text(encoding="utf-8")
for palette_name, palette_hex in (("BACKGROUND", "#100D16"), ("PANEL", "#211724"), ("GOLD", "#C58B43"),
                                  ("CRIMSON", "#8C263A"), ("RUNE", "#7545B8"), ("PARCHMENT", "#B8A7A0")):
    if f'const {palette_name}: Color = Color("{palette_hex}")' not in style_src:
        err(f"scripts/ui/ashen_style.gd: палитра брифа требует {palette_name} = {palette_hex}")
if "nav_button_style(active: bool, pressed: bool = false)" not in style_src or "shadow_size" not in style_src:
    err("scripts/ui/ashen_style.gd: активная вкладка навигации должна получать золотое свечение")
if "nav_disabled_style" not in style_src:
    err("scripts/ui/ashen_style.gd: у недоступного раздела должен быть отдельный стиль")
bottom_bar_size = minimum_sizes.get("BottomBar", []) if isinstance(minimum_sizes, dict) else []
bottom_tabs_size = minimum_sizes.get("BottomTabs", []) if isinstance(minimum_sizes, dict) else []
if not isinstance(bottom_bar_size, list) or len(bottom_bar_size) < 2 or int(bottom_bar_size[1]) > 132 or int(bottom_bar_size[1]) < 118:
    err("data/balance.json: панель навигации должна быть ниже прежней, но не тесной")
if not isinstance(bottom_tabs_size, list) or len(bottom_tabs_size) < 2 or int(bottom_tabs_size[1]) < 108:
    err("data/balance.json: кнопки навигации должны оставаться удобными для нажатия")
nav_start = scene_src.find('[node name="BottomBar"')
nav_section = scene_src[nav_start:] if nav_start >= 0 else ""
if nav_section.count('name="NavLabel"') != 6 or nav_section.count('name="NavIcon"') != 6:
    err("scenes/main/main.tscn: каждая кнопка нижней навигации должна иметь иконку и подпись")
if "QuickRail" in scene_src:
    err("scenes/main/main.tscn: боковая колонка иконок заменена нижней навигацией")
if scene_src.count("СКОРО") < 4:
    err("scenes/main/main.tscn: нереализованные элементы должны быть явно помечены СКОРО")
for token in ["PresentationCatalog.interface_config", "AshenStyle.build_theme(interface_config)", "_apply_interface_config", "_apply_hud_config", "_apply_nav_icons", "_refresh_arena_vitals", "_refresh_arena_enemies", "_rating_value", "_on_tab_pressed", "_select_tab"]:
    if token not in main_src:
        err(f"scripts/main/main.gd: отсутствует подключение игрового HUD ({token})")
presentation_catalog = (ROOT / "scripts/ui/presentation_catalog.gd").read_text(encoding="utf-8") if (ROOT / "scripts/ui/presentation_catalog.gd").is_file() else ""
if "static func interface_config" not in presentation_catalog or '"hud": _dict(data, "hud")' not in presentation_catalog:
    err("scripts/ui/presentation_catalog.gd: отсутствует чтение параметров интерфейса или HUD")
ui_doc = (ROOT / "docs/ui.md").read_text(encoding="utf-8") if (ROOT / "docs/ui.md").is_file() else ""
for token in ["нижнее меню", "presentation.interface", "портрет", "навигаци", "рейтинг", "СКОРО", "мини-карт", "джойстик", "оверле", "БОЙ", "ИНВЕНТАРЬ", "ПРИЗЫВ", "НАСТРОЙКИ"]:
    if token not in ui_doc:
        err(f"docs/ui.md: отсутствует описание игрового интерфейса ({token})")
ui_tests = (ROOT / "tests/test_ui.gd").read_text(encoding="utf-8") if (ROOT / "tests/test_ui.gd").is_file() else ""
for token in ["_test_bottom_navigation", "_test_sketch_hud", "Мини-карта и джойстик отсутствуют"]:
    if token not in ui_tests:
        err(f"tests/test_ui.gd: отсутствует сценарий игрового HUD ({token})")
if 'presentation["interface"]' not in ci_src:
    err(".github/workflows/ci.yml: отсутствует проверка параметров presentation.interface в APK")
notes.append(
    f"Интерфейс: разделов {len(tabs) if isinstance(tabs, dict) else 0}, "
    f"иконок навигации {len(nav_icons) if isinstance(nav_icons, dict) else 0}, "
    f"шрифт {int(fonts.get('default', 0))}, кнопок навигации {len(nav_ratios) if isinstance(nav_ratios, dict) else 0}"
)

# --- 6. Скрипты GDScript ---------------------------------------------------
gd_paths = files("*.gd")
for path in gd_paths:
    src = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)
    if "<<<<<<<" in src or ">>>>>>>" in src:
        err(f"{rel}: конфликтные маркеры")
    if "\r\n" in src:
        warn(f"{rel}: переводы строк CRLF (Godot ожидает LF)")
    if src.strip() and not src.endswith("\n"):
        warn(f"{rel}: нет перевода строки в конце файла")
    for token in ["HTTPRequest.new", "WebSocket", "ENetMultiplayerPeer", "WebRTCMultiplayerPeer", "MultiplayerAPI",
                  "HTTPClient", "StreamPeerTCP", "PacketPeer", "NetworkedMultiplayer"]:
        if token in src:
            err(f"{rel}: базовый игровой процесс должен оставаться офлайн ({token})")
notes.append(f"Скриптов GDScript проверено: {len(gd_paths)}")

# --- 6.5. Границы подсистем и документация API (этап 9) --------------------
# Правила из docs/boundaries.md должны выполняться в коде, а не только на бумаге.
def strip_comments(source: str) -> str:
    return "\n".join(line for line in source.splitlines() if not line.strip().startswith("#"))


state_dirs = ("scripts/combat", "scripts/campaign", "scripts/equipment", "scripts/progression", "scripts/save")
allowed_disk = {"scripts/save/save_manager.gd", "scripts/combat/combat_catalog.gd", "scripts/core/game_config.gd"}
logic_tokens = ("Control", "Node2D", "AshenStyle", "main.gd", "res://assets")
for path in gd_paths:
    rel_text = str(path.relative_to(ROOT)).replace("\\", "/")
    code = strip_comments(path.read_text(encoding="utf-8"))
    if rel_text.startswith("scripts/") and ("FileAccess" in code or "DirAccess" in code) and rel_text not in allowed_disk:
        err(f"{rel_text}: запись и чтение файлов разрешены только в слое сохранений и загрузке баланса")
    if any(rel_text.startswith(prefix) for prefix in state_dirs):
        for token in logic_tokens:
            if token in code:
                err(f"{rel_text}: логика не должна зависеть от интерфейса ({token})")
    if rel_text.endswith("catalog.gd") and re.search(r"(?m)^var\s+[a-zA-Z_]", code):
        err(f"{rel_text}: каталоги не хранят состояние, только константы и static func")
main_rel = "scripts/main/main.gd"
if (ROOT / main_rel).is_file() and "FileAccess" in strip_comments((ROOT / main_rel).read_text(encoding="utf-8")):
    err(f"{main_rel}: экран не пишет файлы напрямую, только через SaveManager/ProfileManager")
api_doc = (ROOT / "docs/api.md").read_text(encoding="utf-8") if (ROOT / "docs/api.md").is_file() else ""
boundaries_doc = (ROOT / "docs/boundaries.md").read_text(encoding="utf-8") if (ROOT / "docs/boundaries.md").is_file() else ""
if not api_doc:
    err("docs/api.md: контракты подсистем не описаны")
if not boundaries_doc:
    err("docs/boundaries.md: границы подсистем не описаны")
for token in ["get_summary", "export_state", "import_state", "advance", "STATUS_BATTLE", "format_version", "api_reference.md", "boundaries.md"]:
    if token not in api_doc:
        err(f"docs/api.md: отсутствует описание контракта ({token})")
for subsystem in ["game_config.gd", "combat_system.gd", "campaign_state.gd", "mode_catalog.gd", "equipment_state.gd",
                  "progression_state.gd", "save_manager.gd", "profile_manager.gd", "presentation_catalog.gd", "main.gd"]:
    if subsystem not in api_doc:
        err(f"docs/api.md: подсистема {subsystem} не описана")
for token in ["CatalogSource", "BattleAuthority", "SaveBackend", "PresenceSource", "авиарежим", "офлайн", "миграц"]:
    if token not in boundaries_doc:
        err(f"docs/boundaries.md: не описан обязательный пункт ({token})")
report_check = subprocess.run(
    [sys.executable, str(ROOT / "tools/api_report.py"), "--check"],
    cwd=ROOT, capture_output=True, text=True,
)
if report_check.returncode != 0:
    err(f"docs/api_reference.md: справочник API не собран заново ({report_check.stdout.strip()})")
else:
    notes.append("Справочник API актуален, границы подсистем проверены")

# --- 7. Настройки проекта и требования портретного Android -----------------
project = ROOT / "project.godot"
if project.is_file():
    cfg = project.read_text(encoding="utf-8")
    if "[application]" not in cfg:
        err("project.godot: нет раздела [application]")
    if "config/name" not in cfg:
        warn("project.godot: не задано config/name")
    if "run/main_scene" not in cfg:
        err("project.godot: не задана главная сцена")
    icon_match = re.search(r'^config/icon="([^"]+)"', cfg, flags=re.M)
    if not icon_match:
        warn("project.godot: не задана иконка проекта")
    elif not (ROOT / icon_match.group(1).removeprefix("res://")).is_file():
        err(f"project.godot: файл иконки не найден: {icon_match.group(1)}")
    else:
        notes.append(f"Иконка проекта: {icon_match.group(1)}")
    if "window/handheld/orientation=1" not in cfg:
        err("project.godot: ожидается портретная ориентация (window/handheld/orientation=1)")
    if "import_etc2_astc=true" not in cfg:
        err("project.godot: для экспорта на Android нужно сжатие текстур ETC2/ASTC")
    notes.append("project.godot найден, настройки портретного Android проверены")
else:
    notes.append("project.godot ещё нет — проверки движка пропущены (ожидаемо на этапе 0)")

# --- 8. Язык сообщений коммитов --------------------------------------------
# По правилам проекта все коммиты, комментарии и документация пишутся
# только на русском языке. Технические идентификаторы остаются в исходном виде.
result = subprocess.run(
    ["git", "log", "-1", "--pretty=%s"],
    cwd=ROOT, capture_output=True, text=True,
)
message = result.stdout.strip()
if result.returncode == 0 and message:
    if not re.search(r"[А-Яа-яЁё]", message):
        err("Сообщение последнего коммита должно быть на русском языке")
    notes.append(f"Сообщение коммита: {message}")

# --- 9. Пресет экспорта Android --------------------------------------------
preset = ROOT / "export_presets.cfg"
if preset.is_file():
    cfg_text = preset.read_text(encoding="utf-8")
    if 'platform="Android"' not in cfg_text:
        err('export_presets.cfg: нет пресета с platform="Android"')
    if "gradle_build/use_gradle_build=true" in cfg_text:
        warn("export_presets.cfg: включена сборка Gradle, для неё нужна отдельная настройка сборки")
    for line in cfg_text.splitlines():
        if line.startswith("keystore/") and '=""' not in line:
            err(f"export_presets.cfg: указан ключ подписи ({line.split('=')[0]}), секреты коммитить нельзя")
    if "permissions/internet=false" not in cfg_text or "permissions/access_network_state=false" not in cfg_text:
        err("export_presets.cfg: APK не должен запрашивать доступ к сети или её состоянию")
    notes.append("Пресет Android найден, офлайн-разрешения и ключи подписи проверены")
else:
    notes.append("Пресет Android ещё не создан")

# --- Итог ------------------------------------------------------------------
for line in notes:
    print(f"  • {line}")
for line in warnings:
    print(f"  ! ПРЕДУПРЕЖДЕНИЕ: {line}")
for line in errors:
    print(f"  ✗ ОШИБКА: {line}")

if errors:
    print(f"\nПроверка не пройдена: {len(errors)} ошибок, {len(warnings)} предупреждений.")
    sys.exit(1)
print(f"\nПроверка завершена успешно: 0 ошибок, {len(warnings)} предупреждений.")
