#!/usr/bin/env python3
"""Прогон интерфейса ASHEN WORLD по критериям §11 брифа.

Читает дамп узлов из /tmp/hudtool/_hud_probe_state.gd и проверяет:
  * всё ли влезает в портретный экран заданного размера;
  * не перекрываются ли ключевые блоки (навигация, навыки, кнопка этапа, шкалы);
  * достаточно ли велики области нажатия;
  * не обрезаны ли подписи и не мельче ли шрифт 18.

Запуск: python3 tools/ui_audit.py <dump.json> <width>x<height>
"""
import json
import sys

# Блоки, которые обязаны целиком помещаться на экране.
MUST_FIT = [
    "ProfilePanel", "GoldPill", "AshPill", "QuestStub", "StubStrip", "LogCard",
    "HintLabel", "HeroVitals", "ArenaHero", "ArenaEnemies", "StrikeButton",
    "GuardButton", "AutoButton", "SkillSlot3", "SkillSlot4", "SkillsSoonLabel",
    "BottomBar", "NoticeFeed",
]

# Пары, которые не должны пересекаться.
NO_OVERLAP = [
    ("AutoButton", "BottomBar"), ("SkillsSoonLabel", "BottomBar"),
    ("StrikeButton", "BottomBar"), ("GuardButton", "BottomBar"),
    ("StrikeButton", "HeroVitals"), ("GuardButton", "HeroVitals"),
    ("AutoButton", "ActionButton"), ("ActionButton", "BottomBar"),
    ("HeroVitals", "ProfilePanel"), ("LogCard", "ArenaEnemies"),
    ("NoticeFeed", "BottomBar"), ("StrikeButton", "AutoButton"),
]

# Кликабельные элементы: минимальная сторона 44 пикселя.
TAP_TARGETS = ["StrikeButton", "GuardButton", "AutoButton", "ActionButton",
               "BattleButton", "EquipmentButton", "SummonButton",
               "ProgressionButton", "ModeButton", "SettingsButton"]


def main():
    if len(sys.argv) < 3:
        print("использование: ui_audit.py <dump.json> <width>x<height>")
        return 2
    dump_path, size = sys.argv[1], sys.argv[2]
    width, height = (int(value) for value in size.split("x"))
    data = json.load(open(dump_path, encoding="utf-8"))
    nodes = {node["name"]: node for node in data["nodes"]}
    problems = []
    notes = []

    def rect(name):
        node = nodes.get(name)
        if node is None:
            return None
        x, y, w, h = node["rect"]
        return (x, y, w, h)

    def inside(box):
        x, y, w, h = box
        return x >= -0.5 and y >= -0.5 and x + w <= width + 0.5 and y + h <= height + 0.5

    def intersect(a, b):
        ax, ay, aw, ah = a
        bx, by, bw, bh = b
        dx = min(ax + aw, bx + bw) - max(ax, bx)
        dy = min(ay + ah, by + bh) - max(ay, by)
        return dx > 1.0 and dy > 1.0

    # 1. Всё ли помещается
    for name in MUST_FIT:
        box = rect(name)
        if box is None:
            continue
        if not inside(box):
            problems.append(f"{name} выходит за экран: {box}")

    # 2. Перекрытия
    for first, second in NO_OVERLAP:
        a, b = rect(first), rect(second)
        if a is None or b is None:
            continue
        if intersect(a, b):
            problems.append(f"{first} перекрывает {second}")

    # 3. Области нажатия
    for name in TAP_TARGETS:
        box = rect(name)
        if box is None:
            continue
        if min(box[2], box[3]) < 44.0:
            problems.append(f"{name} меньше 44 пикселей: {box[2]:.0f}×{box[3]:.0f}")

    # 4. Подписи: размер шрифта и нехватка места (мерки Godot, need_w/need_h)
    for node in data["nodes"]:
        text = str(node.get("text") or "").strip()
        if not text or node["type"] not in ("Label", "Button"):
            continue
        size_px = int(node.get("font_size") or 0)
        if size_px and size_px < 18:
            problems.append(f"{node['name']}: шрифт {size_px} меньше 18")
        box = node["rect"]
        need_w = float(node.get("need_w") or 0.0)
        need_h = float(node.get("need_h") or 0.0)
        if node.get("autowrap") in (0, None) and need_w > box[2] + 2.0:
            problems.append(
                f"{node['name']}: подпись «{text}» шире блока ({need_w:.0f} > {box[2]:.0f})"
            )
        if need_h > box[3] + 3.0:
            problems.append(
                f"{node['name']}: подпись «{text}» выше блока ({need_h:.0f} > {box[3]:.0f})"
            )

    # 5. Кластеры целиком на экране
    cluster = [rect(name) for name in ("StrikeButton", "GuardButton", "SkillSlot3", "AutoButton")]
    cluster = [box for box in cluster if box is not None]
    if cluster:
        left = min(box[0] for box in cluster)
        bottom = max(box[1] + box[3] for box in cluster)
        notes.append(f"кластер навыков: x от {left:.0f}, низ {bottom:.0f}")
        nav = rect("BottomBar")
        if nav is not None and bottom > nav[1] - 4.0:
            problems.append("кластер навыков заходит на панель навигации")
    arena = rect("ArenaEnemies")
    if arena is not None:
        notes.append(f"арена: {arena[2]:.0f}×{arena[3]:.0f} при экране {width}×{height}")

    print(f"=== {size} ===")
    for note in notes:
        print(f"  · {note}")
    if problems:
        for problem in problems:
            print(f"  ✗ {problem}")
    else:
        print("  ✓ замечаний нет")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
