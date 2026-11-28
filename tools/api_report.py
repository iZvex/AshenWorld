#!/usr/bin/env python3
"""Справочник публичного API подсистем ASHEN WORLD.

Скрипт читает GDScript-файлы из `scripts/` и собирает `docs/api_reference.md`:
для каждого модуля печатаются наследование, назначение, сигналы, публичные
константы, состояние и методы с сигнатурами.

Запуск:
    python3 tools/api_report.py           # перезаписать docs/api_reference.md
    python3 tools/api_report.py --check   # проверить, что файл актуален (для CI)
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = ROOT / "scripts"
TARGET = ROOT / "docs" / "api_reference.md"

MODULE_TITLES = {
    "scripts/core": "Ядро и конфигурация",
    "scripts/combat": "Бой",
    "scripts/campaign": "Кампания и режимы",
    "scripts/equipment": "Экипировка и призыв",
    "scripts/progression": "Прогрессия героя",
    "scripts/save": "Сохранения и профиль",
    "scripts/ui": "Представление",
    "scripts/main": "Слой экрана",
}
MODULE_ORDER = list(MODULE_TITLES)

FUNC_RE = re.compile(r"^(static\s+)?func\s+(?P<name>[A-Za-z_][A-Za-z_0-9]*)")
SIGNAL_RE = re.compile(r"^signal\s+(?P<rest>.+)$")
CONST_RE = re.compile(r"^const\s+(?P<name>[A-Za-z_][A-Za-z_0-9]*)\s*:\s*(?P<type>[A-Za-z_0-9\[\]]+)\s*=\s*(?P<value>.+)$")
VAR_RE = re.compile(r"^var\s+(?P<name>[A-Za-z_][A-Za-z_0-9]*)\s*(?::\s*(?P<type>[A-Za-z_0-9\[\]]+))?")


def module_key(path: Path) -> str:
    return str(path.parent.relative_to(ROOT)).replace("\\", "/")


def module_rank(path: Path) -> tuple[int, str]:
    key = module_key(path)
    index = MODULE_ORDER.index(key) if key in MODULE_ORDER else len(MODULE_ORDER)
    return (index, path.name)


def read_purpose(lines: list[str]) -> str:
    purpose: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("#"):
            text = stripped.lstrip("#").strip()
            if text:
                purpose.append(text)
            continue
        if stripped == "" and purpose:
            break
        if stripped == "":
            continue
        break
    return " ".join(purpose)


def collect_functions(lines: list[str]) -> list[tuple[str, str]]:
    """Возвращает список (имя, сигнатура) для всех функций модуля."""
    functions: list[tuple[str, str]] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        match = FUNC_RE.match(line)
        if not match:
            index += 1
            continue
        signature = line.rstrip()
        step = 1
        while not signature.endswith(":") and index + step < len(lines):
            signature += " " + lines[index + step].strip()
            step += 1
        if signature.endswith(":"):
            signature = signature[:-1]
        signature = re.sub(r"\s+", " ", signature)
        functions.append((match.group("name"), signature))
        index += step
    return functions


def render_module(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    rel = str(path.relative_to(ROOT)).replace("\\", "/")
    extends = "RefCounted"
    for line in lines:
        if line.startswith("extends "):
            extends = line.split("extends ", 1)[1].strip()
            break
    body_start = 0
    for position, line in enumerate(lines):
        if line.startswith("extends "):
            body_start = position + 1
            break
    purpose = read_purpose(lines[body_start:])

    signals: list[str] = []
    constants: list[tuple[str, str, str]] = []
    variables: list[tuple[str, str]] = []
    for line in lines:
        signal_match = SIGNAL_RE.match(line)
        if signal_match:
            signals.append(signal_match.group("rest").strip())
            continue
        const_match = CONST_RE.match(line)
        if const_match:
            constants.append((const_match.group("name"), const_match.group("type"), const_match.group("value").strip()))
            continue
        var_match = VAR_RE.match(line)
        if var_match:
            variables.append((var_match.group("name"), var_match.group("type") or "Variant"))

    functions = collect_functions(lines)
    public_functions = [(name, signature) for name, signature in functions if not name.startswith("_")]

    out: list[str] = []
    out.append(f"### `{rel}`")
    out.append("")
    out.append(f"- Наследует: `{extends}`")
    if purpose:
        out.append(f"- Назначение: {purpose}")
    out.append(f"- Публичных методов: {len(public_functions)}")
    out.append("")
    if signals:
        out.append("**Сигналы**")
        out.append("")
        for signal_text in signals:
            out.append(f"- `{signal_text}`")
        out.append("")
    if constants:
        out.append("**Публичные константы**")
        out.append("")
        for name, type_name, value in constants:
            out.append(f"- `{name}: {type_name} = {value}`")
        out.append("")
    if variables:
        out.append("**Публичное состояние**")
        out.append("")
        for name, type_name in variables:
            out.append(f"- `{name}: {type_name}`")
        out.append("")
    if public_functions:
        out.append("**Методы**")
        out.append("")
        for _name, signature in public_functions:
            out.append(f"- `{signature}`")
        out.append("")
    return out


def build() -> str:
    files = sorted(SCRIPTS.rglob("*.gd"), key=module_rank)
    out: list[str] = []
    out.append("# Справочник публичного API")
    out.append("")
    out.append(
        "Файл создаётся автоматически командой `python3 tools/api_report.py` из комментариев и объявлений "
        "в `scripts/**/*.gd`. Руками его не правят: смысловые контракты подсистем описаны в "
        "`docs/api.md`, границы и точки расширения — в `docs/boundaries.md`. "
        "Сборка проверяет актуальность файла через `python3 tools/api_report.py --check`."
    )
    out.append("")
    out.append("Служебные методы и приватные поля (с префиксом `_`) в справочник не попадают.")
    out.append("")
    current_module = ""
    for path in files:
        key = module_key(path)
        if key != current_module:
            title = MODULE_TITLES.get(key, key)
            out.append(f"## {title}")
            out.append("")
            out.append(f"Каталог `{key}/`.")
            out.append("")
            current_module = key
        out.extend(render_module(path))
    text = "\n".join(out).rstrip("\n") + "\n"
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description="Справочник API подсистем ASHEN WORLD")
    parser.add_argument("--check", action="store_true", help="только проверить актуальность файла")
    parser.add_argument("--stdout", action="store_true", help="напечатать справочник вместо записи")
    args = parser.parse_args()

    text = build()
    if args.stdout:
        sys.stdout.write(text)
        return 0
    if args.check:
        if not TARGET.is_file():
            print(f"Нет файла справочника: {TARGET.relative_to(ROOT)}")
            return 1
        current = TARGET.read_text(encoding="utf-8")
        if current != text:
            print("Справочник API устарел: выполните python3 tools/api_report.py")
            return 1
        print("Справочник API актуален")
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(text, encoding="utf-8")
    print(f"Справочник API записан: {TARGET.relative_to(ROOT)} ({len(text.splitlines())} строк)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
