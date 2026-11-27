#!/usr/bin/env python3
"""Быстрая проверка репозитория ASHEN WORLD.

Запускается в автоматической сборке (см. .github/workflows/ci.yml) и локально:
    python3 tools/validate_repo.py

Проверяет только то, что можно проверить без движка:
  * целостность спецификации README.md;
  * синтаксис описаний сборок и файлов данных;
  * целостность данных кампании и экипировки;
  * конфликтные маркеры и переводы строк в скриптах GDScript;
  * базовую структуру project.godot, когда он появится.
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
        if int(balance.get("version", 0)) < 4:
            err("data/balance.json: для экипировки ожидается версия баланса не ниже 4")
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
        notes.append(f"Кампания: этапов {len(stages)}, боссовых волн {bosses}")

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
notes.append(f"Скриптов GDScript проверено: {len(gd_paths)}")

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
    notes.append("Пресет Android найден, ключи подписи в репозиторий не попали")
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
