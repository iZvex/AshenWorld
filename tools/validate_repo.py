#!/usr/bin/env python3
"""Быстрая проверка репозитория ASHEN WORLD.

Запускается в автоматической сборке (см. .github/workflows/ci.yml) и локально:
    python3 tools/validate_repo.py

Проверяет только то, что можно проверить без движка:
  * целостность спецификации README.md;
  * синтаксис описаний сборок и файлов данных;
  * конфликтные маркеры и переводы строк в скриптах GDScript;
  * базовую структуру project.godot, когда он появится.
"""
from __future__ import annotations

import json
import re
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

# --- 4. Скрипты GDScript ---------------------------------------------------
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

# --- 5. project.godot (проверки появятся вместе с проектом) ---------------
project = ROOT / "project.godot"
if project.is_file():
    cfg = project.read_text(encoding="utf-8")
    if "[application]" not in cfg:
        err("project.godot: нет раздела [application]")
    if "config/name" not in cfg:
        warn("project.godot: не задано config/name")
    notes.append("project.godot найден")
else:
    notes.append("project.godot ещё нет — проверки движка пропущены (ожидаемо на этапе 0)")

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
