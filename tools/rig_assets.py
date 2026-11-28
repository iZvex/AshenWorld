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


def arm_mask(image: Image.Image, config: dict) -> np.ndarray:
    """Маска руки с оружием: предплечье и кисть до локтя.

    Рука вырезается из тела отдельным слоем, чтобы в взмахе участвовала не
    только сталь, но и кисть. Клинок остаётся дочерним слоем руки.
    """
    arm = config.get("arm")
    if not isinstance(arm, dict) or not arm.get("points"):
        return np.zeros((image.size[1], image.size[0]), dtype=bool)
    width, height = image.size
    alpha = np.asarray(image).astype(np.float32)[:, :, 3]
    mask = segment_mask(width, height, arm.get("points", []), float(arm.get("radius", 16.0)))
    mask = mask & (alpha > 24)
    gate = arm.get("color_gate")
    if gate:
        # Плащ тёмный и почти без синего: в слой руки идёт сталь и кожа кисти.
        array = np.asarray(image).astype(np.float32)
        value = array[:, :, :3].mean(axis=2)
        mask = mask & (value > float(gate.get("min_value", 42.0)))
    return drop_small(mask, int(config.get("min_component_pixels", 120)))


def fill_arm_hole(rgb: np.ndarray, mask: np.ndarray, solid: np.ndarray) -> np.ndarray:
    """Затягивает место, где была рука: отражение второй половины и рост от краёв.

    Затемнение здесь не нужно: под рукой плащ, а не тень от оружия.
    """
    filled, done = _mirror_fill(rgb, mask, solid)
    rest = mask & solid & (~done)
    if rest.any():
        grown = _spread_fill(filled, mask, solid)
        filled = np.where(rest[:, :, None], grown, filled)
    band = dilate(mask, 1) & solid
    soft = np.asarray(Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8))
                      .filter(ImageFilter.GaussianBlur(1.6))).astype(np.float32)
    seam = band & dilate(mask, 1)
    filled[seam] = (filled[seam] * 0.6 + soft[seam] * 0.4)
    return filled


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


def _mirror_fill(rgb: np.ndarray, mask: np.ndarray,
                 solid: np.ndarray) -> tuple:
    """Заполняет прорезь отражением второй половины фигуры.

    Возвращает картинку и карту уже заполненных пикселей: остальное добирает
    восстановление по краям, чтобы не портить готовую фактуру.
    """
    rgb = rgb.copy()
    height, width = mask.shape
    done = np.zeros_like(mask)
    rows, cols = np.nonzero(mask & solid)
    if rows.size == 0:
        return rgb, done
    for offset in (0, 2, -2, 4, -4, 6, -6, 10, -10):
        mirrored = np.clip(width - 1 - cols + offset, 0, width - 1)
        usable = (solid[rows, mirrored] & (~mask[rows, mirrored])
                  & (~done[rows, cols]))
        if usable.any():
            rgb[rows[usable], cols[usable]] = rgb[rows[usable], mirrored[usable]]
            done[rows[usable], cols[usable]] = True
    return rgb, done


def _spread_fill(rgb: np.ndarray, mask: np.ndarray, solid: np.ndarray) -> np.ndarray:
    """Распространяет цвет тела внутрь прорези от её краёв."""
    rgb = rgb.copy()
    target = mask & solid
    done = np.zeros_like(mask)
    for _step in range(96):
        rest = target & (~done)
        if not rest.any():
            break
        known = (solid & (~target)) | done
        acc = np.zeros_like(rgb)
        cnt = np.zeros(mask.shape, dtype=np.float64)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            shifted_known = np.roll(np.roll(known, dy, axis=0), dx, axis=1)
            shifted_rgb = np.roll(np.roll(rgb, dy, axis=0), dx, axis=1)
            acc += shifted_rgb * shifted_known[:, :, None]
            cnt += shifted_known.astype(np.float64)
        grow = rest & (cnt > 0)
        if not grow.any():
            break
        rgb[grow] = acc[grow] / cnt[grow, None]
        done |= grow
    return rgb


def inpaint_hole(rgb: np.ndarray, mask: np.ndarray, solid: np.ndarray,
                 config: dict) -> np.ndarray:
    """Затягивает прорезь от оружия фактурой самой фигуры.

    Складки ткани идут сверху вниз, поэтому прорезь проще всего продолжить
    сдвинутой копией тела: берём пиксель ниже по вертикали и подставляем его
    в дырку. Остальное (где сдвиг не достаёт) добирает гладкая заливка.
    """
    height, width = mask.shape
    target = mask & solid
    filled = rgb.copy()
    done = np.zeros_like(mask)
    step = int(config.get("shift_pixels", 46))
    for offset in (step, -step, step * 2, -step * 2, int(step * 1.5), -int(step * 1.5)):
        ys = np.clip(np.arange(height) + offset, 0, height - 1)
        candidate = rgb[ys, :]
        usable = target & (~done) & solid[ys, :] & (~mask[ys, :])
        filled[usable] = candidate[usable]
        done |= usable
    rest = target & (~done)
    if rest.any():
        smooth = np.asarray(Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8))
                            .filter(ImageFilter.GaussianBlur(6.0))).astype(np.float32)
        filled[rest] = smooth[rest]
    # Мягкий шов и тень: прорезь читается как затенённое место под оружием.
    layer = Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8))
    soft = np.asarray(layer.filter(ImageFilter.GaussianBlur(2.0))).astype(np.float32)
    band = dilate(mask, 2) & solid
    filled[band] = (filled[band] * 0.45 + soft[band] * 0.55) * 0.86
    return filled


def inside_body(solid: np.ndarray, cut: np.ndarray, config: dict) -> np.ndarray:
    """Какие пиксели прорези лежат внутри фигуры, а какие торчали в воздух.

    Считаем расстояние до ближайшего пикселя тела: узкая полоса под оружием
    всегда рядом с тканью, а клинок, уходящий за силуэт, оказывается далеко.
    """
    from scipy.ndimage import distance_transform_edt

    body = solid & (~cut)
    if not body.any():
        return np.zeros_like(cut)
    distance = distance_transform_edt(~body)
    radius = float((config.get("segments") or [{}])[0].get("radius", 12))
    limit = float(config.get("inside_pixels", round(radius) + 10))
    return cut & (distance <= limit)


def clean_base(image: Image.Image, config: dict, weapon: np.ndarray) -> np.ndarray:
    """Готовая фигура без оружия, выровненная по исходной картинке.

    Художник рисует фигуру с оружием, поэтому прорезь нечем заполнить. Для
    таких персонажей рядом лежит чистая основа (``clean_body``): та же фигура
    без оружия. Здесь она матируется, масштабируется под исходник и
    подставляется только в полосу оружия — вся остальная графика остаётся
    исходной.
    """
    from scipy import ndimage

    path = ROOT / str(config.get("clean_body", "")).replace("res://", "")
    original = np.asarray(image).astype(np.float32)
    if not path.is_file():
        return original
    clean = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
    alpha = clean[:, :, 3]
    if alpha.min() > 250:
        # Шахматный фон мог быть запечён в картинку: убираем светлые поля,
        # связанные с краем кадра.
        light = (clean[:, :, :3].min(axis=2) > 195) & (
            clean[:, :, :3].max(axis=2) - clean[:, :, :3].min(axis=2) < 24)
        labels, count = ndimage.label(light)
        border = set(labels[0, :]) | set(labels[-1, :]) | set(labels[:, 0]) | set(labels[:, -1])
        border.discard(0)
        background = np.isin(labels, list(border)) if border else np.zeros_like(light)
        alpha = np.where(background, 0.0, 255.0)
    solid = alpha > 40
    solid = ndimage.binary_fill_holes(solid)
    labels, count = ndimage.label(solid)
    if count:
        sizes = ndimage.sum(solid, labels, range(1, count + 1))
        keep = np.isin(labels, [index + 1 for index, size in enumerate(sizes) if size > 400])
        solid = solid & keep
    clean[:, :, 3] = np.where(solid, 255.0, 0.0)
    # Светлые точки от шахматного фона внутри фигуры.
    for _step in range(4):
        light = solid & (clean[:, :, :3].min(axis=2) > 195) & (
            clean[:, :, :3].max(axis=2) - clean[:, :, :3].min(axis=2) < 24)
        if not light.any():
            break
        median = np.stack([ndimage.median_filter(clean[:, :, index], size=5) for index in range(3)], axis=2)
        clean[:, :, :3] = np.where(light[:, :, None], median, clean[:, :, :3])
    ready = Image.fromarray(np.clip(clean, 0, 255).astype(np.uint8), "RGBA")
    return align_to_original(ready, image)


def align_to_original(clean: Image.Image, original: Image.Image) -> np.ndarray:
    """Подгоняет чистую фигуру под исходник: высота, ступни, центр корпуса."""
    base = np.asarray(original).astype(np.float32)
    cleaned = np.asarray(clean).astype(np.float32)
    base_solid = base[:, :, 3] > 40
    clean_solid = cleaned[:, :, 3] > 40
    if not clean_solid.any():
        return base
    base_rows, base_cols = np.nonzero(base_solid)
    clean_rows, clean_cols = np.nonzero(clean_solid)
    base_height = base_rows.max() - base_rows.min() + 1
    clean_height = clean_rows.max() - clean_rows.min() + 1
    scale = base_height / max(1, clean_height)
    size = (max(1, int(round(clean.width * scale))), max(1, int(round(clean.height * scale))))
    resized = np.asarray(clean.resize(size, Image.LANCZOS)).astype(np.float32)
    rows, cols = np.nonzero(resized[:, :, 3] > 40)
    if rows.size == 0:
        return base
    torso = rows < rows.mean()
    dx = int(round(base_cols[base_rows < base_rows.mean()].mean() - cols[torso].mean()))
    dy = int(round(base_rows.max() - rows.max()))
    canvas = np.zeros_like(base)
    height, width = base.shape[:2]
    ys = np.arange(resized.shape[0]) + dy
    xs = np.arange(resized.shape[1]) + dx
    valid_y = (ys >= 0) & (ys < height)
    valid_x = (xs >= 0) & (xs < width)
    canvas[np.ix_(ys[valid_y], xs[valid_x])] = resized[np.ix_(np.nonzero(valid_y)[0], np.nonzero(valid_x)[0])]
    return canvas


def build(image: Image.Image, config: dict) -> tuple:
    """Возвращает тело, слой оружия и маску оружия."""
    from scipy import ndimage

    core = dilate(weapon_mask(image, config), int(config.get("grow_pixels", 3)))
    # Оружие: мягкая кромка, чтобы поворот не давал рваных краёв.
    soft = Image.fromarray((core * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    source = np.asarray(image).astype(np.float32)
    blade = source.copy()
    blade[:, :, 3] = blade[:, :, 3] * (np.asarray(soft).astype(np.float32) / 255.0)
    blade_image = Image.fromarray(np.clip(blade, 0, 255).astype(np.uint8))

    body = source.copy()
    if config.get("clean_body"):
        # Полоса оружия берётся из заранее нарисованной чистой фигуры.
        clean = clean_base(image, config, core)
        band = ndimage.binary_dilation(core, iterations=int(config.get("patch_pixels", 9)))
        # В полосе оружия берём чистую основу целиком, включая прозрачность:
        # иначе остаются красная нить свечения и чёрные пятна.
        body[:, :, 3] = np.where(band, clean[:, :, 3], source[:, :, 3])
        substituted = band[:, :, None] & (clean[:, :, 3:] > 0)
        body[:, :, :3] = np.where(substituted, clean[:, :, :3], source[:, :, :3])
        body[:, :, 3] = ndimage.gaussian_filter(body[:, :, 3], 0.9)
    else:
        # Запасной путь: затягиваем прорезь соседними пикселями.
        solid = source[:, :, 3] > 24
        body[:, :, :3] = inpaint_hole(body[:, :, :3], core, solid, config)
    body[:, :, :3] = _fix_alpha_border(body[:, :, :3], body[:, :, 3])
    arm_image = Image.new("RGBA", image.size, (0, 0, 0, 0))
    arm_cut = arm_mask(image, config)
    if arm_cut.any():
        # Рука берётся из тела: клинка в ней уже нет, только кисть и предплечье.
        arm_pixels = body.copy()
        arm_pixels[:, :, 3] = np.where(arm_cut, body[:, :, 3], 0.0)
        soft = Image.fromarray((arm_cut * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
        arm_pixels[:, :, 3] = arm_pixels[:, :, 3] * (np.asarray(soft).astype(np.float32) / 255.0)
        arm_image = Image.fromarray(np.clip(arm_pixels, 0, 255).astype(np.uint8))
        solid = body[:, :, 3] > 24
        body[:, :, :3] = fill_arm_hole(body[:, :, :3], arm_cut, solid)
        body[:, :, :3] = _fix_alpha_border(body[:, :, :3], body[:, :, 3])
    body_image = Image.fromarray(np.clip(body, 0, 255).astype(np.uint8))
    return body_image, blade_image, core, arm_image


def _fix_alpha_border(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Красит прозрачные пиксели цветом фигуры, как импорт Godot.

    Иначе при масштабировании прозрачные пиксели с чужим цветом дают кайму.
    """
    rgb = rgb.copy()
    known = alpha > 24
    for _step in range(12):
        if known.all():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros(alpha.shape, dtype=np.float64)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted_known = np.roll(np.roll(known, dy, axis=0), dx, axis=1)
            shifted_rgb = np.roll(np.roll(rgb, dy, axis=0), dx, axis=1)
            acc += shifted_rgb * shifted_known[:, :, None]
            cnt += shifted_known.astype(np.float64)
        grow = (~known) & (cnt > 0)
        if not grow.any():
            break
        rgb[grow] = acc[grow] / cnt[grow, None]
        known |= grow
    return rgb


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
        body, blade, mask, arm = build(image, config)
        body_path = ROOT / str(config["body"]).replace("res://", "")
        blade_path = ROOT / str(config["blade"]).replace("res://", "")
        body_path.parent.mkdir(parents=True, exist_ok=True)
        body.save(body_path, optimize=True)
        blade.save(blade_path, optimize=True)
        extra = ""
        arm_path_value = str(config.get("arm_file", "")).replace("res://", "")
        if arm_path_value:
            arm_path = ROOT / arm_path_value
            arm_path.parent.mkdir(parents=True, exist_ok=True)
            arm.save(arm_path, optimize=True)
            extra = f", {arm_path.name} {arm_path.stat().st_size // 1024} КБ"
        print(f"  {name}: {body_path.name} {body_path.stat().st_size // 1024} КБ, "
              f"{blade_path.name} {blade_path.stat().st_size // 1024} КБ{extra}")
        if show_preview:
            preview(name, image, body, blade, mask, config)
    return 0


if __name__ == "__main__":
    sys.exit(main())
