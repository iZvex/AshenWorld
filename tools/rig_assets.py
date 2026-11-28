#!/usr/bin/env python3
"""Нарезка готовых фигур на тело и оружие для анимации взмахов.

Из одной картинки персонажа получаются два слоя одинакового размера:
  *_body.png  — фигура без оружия, прорезь залита соседними пикселями;
  *_blade.png — только оружие на прозрачном фоне, в исходных координатах.

Слои совпадают пиксель в пиксель, поэтому в игре достаточно повернуть
слой оружия вокруг точки хвата — и получится настоящий взмах мечом,
топором или косой из уже нарисованной графики.

Настройки (капсулы вдоль оружия и точка хвата) лежат в
data/balance.json → presentation.interface.rig.characters.

Запуск:
  python3 tools/rig_assets.py            # записать слои
  python3 tools/rig_assets.py --preview  # плюс лист предпросмотра в /tmp
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
BALANCE = ROOT / "data" / "balance.json"
HAND_FILL_RADIUS = 3.0


def load_rig() -> dict:
    data = json.loads(BALANCE.read_text(encoding="utf-8"))
    return data["presentation"]["interface"]["rig"]


def segment_mask(width: int, height: int, points: list, radius: float) -> np.ndarray:
    yy, xx = np.mgrid[0:height, 0:width]
    mask = np.zeros((height, width), dtype=bool)
    for start, end in zip(points[:-1], points[1:]):
        px, py = xx - start[0], yy - start[1]
        dx, dy = end[0] - start[0], end[1] - start[1]
        length = max(1e-6, dx * dx + dy * dy)
        t = np.clip((px * dx + py * dy) / length, 0.0, 1.0)
        ddx, ddy = px - t * dx, py - t * dy
        mask |= (ddx * ddx + ddy * ddy) <= radius * radius
    return mask


def drop_small(mask: np.ndarray, minimum: int) -> np.ndarray:
    """Убирает искры и обрывки фона, случайно попавшие в капсулу."""
    height, width = mask.shape
    seen = np.zeros_like(mask)
    keep = np.zeros_like(mask)
    for start_y in range(height):
        for start_x in range(width):
            if not mask[start_y, start_x] or seen[start_y, start_x]:
                continue
            stack = [(start_y, start_x)]
            seen[start_y, start_x] = True
            cells = []
            while stack:
                y, x = stack.pop()
                cells.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(cells) >= minimum:
                for y, x in cells:
                    keep[y, x] = True
    return keep


def weapon_mask(image: Image.Image, config: dict) -> np.ndarray:
    width, height = image.size
    alpha = np.asarray(image).astype(np.float32)[:, :, 3]
    mask = np.zeros((height, width), dtype=bool)
    for segment in config.get("segments", []):
        mask |= segment_mask(width, height, segment.get("points", []), float(segment.get("radius", 10.0)))
    mask = mask & (alpha > 24)
    gate = config.get("color_gate")
    if gate:
        # Отсекаем тёмную ткань плаща: в слой оружия идёт только его цвет
        # (клинок ярко-красный), иначе при повороте с плаща уезжает кусок.
        array = np.asarray(image).astype(np.float32)
        red, green, blue = array[:, :, 0], array[:, :, 1], array[:, :, 2]
        colour = (red > float(gate.get("min_value", 90.0))) & \
                 (red > green + float(gate.get("min_delta", 22.0))) & \
                 (red > blue + float(gate.get("min_delta", 22.0)) * 0.5)
        grow = int(gate.get("grow_pixels", 2))
        if grow > 0:
            grown = colour.copy()
            for _step in range(grow):
                shifted = grown.copy()
                shifted[1:, :] |= grown[:-1, :]
                shifted[:-1, :] |= grown[1:, :]
                shifted[:, 1:] |= grown[:, :-1]
                shifted[:, :-1] |= grown[:, 1:]
                grown = shifted
            colour = grown
        mask = mask & colour
    return drop_small(mask, int(config.get("min_component_pixels", 120)))


def dilate(mask: np.ndarray, steps: int) -> np.ndarray:
    grown = mask.copy()
    for _step in range(steps):
        shifted = grown.copy()
        shifted[1:, :] |= grown[:-1, :]
        shifted[:-1, :] |= grown[1:, :]
        shifted[:, 1:] |= grown[:, :-1]
        shifted[:, :-1] |= grown[:, 1:]
        shifted[1:, 1:] |= grown[:-1, :-1]
        shifted[:-1, :-1] |= grown[1:, 1:]
        grown = shifted
    return grown


def build(image: Image.Image, config: dict) -> tuple:
    # Захватываем и свечение вокруг клинка: иначе оно остаётся на теле
    # и заливка прорези подкрашивает её в красный.
    mask = dilate(weapon_mask(image, config), int(config.get("grow_pixels", 3)))
    # Оружие: мягкая кромка, чтобы поворот не давал рваных краёв.
    soft = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    blade = np.asarray(image).astype(np.float32)
    blade[:, :, 3] = blade[:, :, 3] * (np.asarray(soft).astype(np.float32) / 255.0)
    blade_image = Image.fromarray(np.clip(blade, 0, 255).astype(np.uint8))

    # Тело: вырезаем оружие и заливаем прорезь цветом самой фигуры.
    body = np.asarray(image).astype(np.float32)
    body[mask, 3] = 0.0
    # Сначала затягиваем цвета фигуры в прозрачные пиксели, иначе размытие
    # подмешивает белый фон PNG и прорезь светится светлой полосой.
    for _step in range(14):
        known = body[:, :, 3] > 24
        total = np.zeros_like(body[:, :, :3])
        weight = np.zeros_like(body[:, :, :1])
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            shifted_known = np.roll(np.roll(known, dy, axis=0), dx, axis=1)
            shifted_rgb = np.roll(np.roll(body[:, :, :3], dy, axis=0), dx, axis=1)
            total += shifted_rgb * shifted_known[:, :, None]
            weight += shifted_known[:, :, None]
        fillable = (~known) & (weight[:, :, 0] > 0)
        body[:, :, :3] = np.where(fillable[:, :, None], total / np.maximum(weight, 1.0), body[:, :, :3])
        body[:, :, 3] = np.where(fillable, 255.0, body[:, :, 3])
    body_image = Image.fromarray(np.clip(body, 0, 255).astype(np.uint8))
    for _step in range(8):
        blurred = np.asarray(body_image.filter(ImageFilter.GaussianBlur(2.0))).astype(np.float32)
        current = np.asarray(body_image).astype(np.float32)
        hole = mask & (current[:, :, 3] < 40)
        current[hole] = blurred[hole]
        body_image = Image.fromarray(np.clip(current, 0, 255).astype(np.uint8))
    # Возвращаем прозрачность за пределами фигуры: заливка не должна рисовать фон.
    restored = np.asarray(body_image).astype(np.float32)
    outside = np.asarray(image).astype(np.float32)[:, :, 3] <= 24
    restored[outside, 3] = 0.0
    body_image = Image.fromarray(np.clip(restored, 0, 255).astype(np.uint8))
    # Прорезь должна читаться как тень от оружия: гасим цвет до серого и темним,
    # иначе на теле остаётся «призрак» клинка.
    filled = np.asarray(body_image).astype(np.float32)
    luminance = (filled[mask, 0] * 0.3 + filled[mask, 1] * 0.59 + filled[mask, 2] * 0.11) * 0.72
    filled[mask, 0] = luminance
    filled[mask, 1] = luminance * 0.94
    filled[mask, 2] = luminance * 1.02
    body_image = Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8))
    return body_image, blade_image, mask


def preview(name: str, image: Image.Image, body: Image.Image, blade: Image.Image,
            mask: np.ndarray, config: dict) -> None:
    grip = config["grip"]
    angles = [float(config.get("windup_degrees", -55.0)), 0.0, float(config.get("strike_degrees", 30.0))]
    width, height = image.size
    sheet = Image.new("RGBA", (width * 2 * (len(angles) + 1), height * 2 + 30), (24, 20, 32, 255))
    draw = ImageDraw.Draw(sheet)
    marked = image.copy()
    overlay = np.asarray(marked).astype(np.float32)
    overlay[mask, 0] = np.minimum(255.0, overlay[mask, 0] * 0.45 + 150)
    overlay[mask, 1] *= 0.35
    overlay[mask, 2] *= 0.35
    marked = Image.fromarray(np.clip(overlay, 0, 255).astype(np.uint8)).resize((width * 2, height * 2), Image.LANCZOS)
    ImageDraw.Draw(marked).ellipse([grip[0] * 2 - 8, grip[1] * 2 - 8, grip[0] * 2 + 8, grip[1] * 2 + 8],
                                   outline=(0, 255, 120, 255), width=3)
    sheet.alpha_composite(marked, (0, 30))
    draw.text((8, 8), f"{name}: маска", fill=(197, 139, 67, 255))
    for index, angle in enumerate(angles):
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        canvas.alpha_composite(body)
        rotated = blade.rotate(angle, resample=Image.BICUBIC, center=(grip[0], grip[1]))
        canvas.alpha_composite(rotated)
        sheet.alpha_composite(canvas.resize((width * 2, height * 2), Image.LANCZOS), ((index + 1) * width * 2, 30))
        draw.text(((index + 1) * width * 2 + 8, 8), f"{angle:+.0f}°", fill=(184, 167, 160, 255))
    sheet.convert("RGB").save(f"/tmp/rig_{name}.png")
    print(f"  предпросмотр: /tmp/rig_{name}.png")


def main() -> int:
    show_preview = "--preview" in sys.argv
    rig = load_rig()
    characters = rig.get("characters", {})
    if not characters:
        print("в balance.json нет presentation.interface.rig.characters")
        return 1
    for name, config in characters.items():
        source = ROOT / str(config["figure"]).replace("res://", "")
        if not source.exists():
            print(f"  {name}: нет файла {source}")
            continue
        image = Image.open(source).convert("RGBA")
        body, blade, mask = build(image, config)
        body_path = ROOT / str(config["body"]).replace("res://", "")
        blade_path = ROOT / str(config["blade"]).replace("res://", "")
        body_path.parent.mkdir(parents=True, exist_ok=True)
        body.save(body_path, optimize=True)
        blade.save(blade_path, optimize=True)
        print(f"  {name}: {body_path.name} {body_path.stat().st_size // 1024} КБ, "
              f"{blade_path.name} {blade_path.stat().st_size // 1024} КБ")
        if show_preview:
            preview(name, image, body, blade, mask, config)
    return 0


if __name__ == "__main__":
    sys.exit(main())
