#!/usr/bin/env python3
"""Собирает картинку интерфейса из дампа /tmp/hudtool/_hud_probe_state.gd.

Запуск: python3 tools/render_dump.py <dump.json> <width>x<height> <out.png>
"""
import json, os
from PIL import Image, ImageDraw, ImageFont

import sys
S = 2  # supersampling
DUMP = sys.argv[1]
SCREEN = sys.argv[2] if len(sys.argv) > 2 else '720x1280'
OUT = sys.argv[3] if len(sys.argv) > 3 else '/home/user/hud_preview.png'
SW, SH = (int(v) for v in SCREEN.split('x'))
W, H = SW * S, SH * S
d = json.load(open(DUMP))
# Порядок отрисовки как в Godot: сначала меньший z, внутри одного z — порядок дерева.
if d.get("nodes"):
    d["nodes"] = sorted(d["nodes"], key=lambda item: item.get("z_eff", item.get("z_index", 0)) or 0)
TEX = '/tmp/hud_tex'
FONT_B = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT_R = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
img = Image.new('RGBA', (W, H), (8, 6, 16, 255))
draw = ImageDraw.Draw(img)

def c(t):
    if not t: return (255,255,255,255)
    return (int(t[0]*255), int(t[1]*255), int(t[2]*255), int(t[3]*255))

def mul(col, mod):
    a = col[3]*mod[3]
    return (int(col[0]*mod[0]), int(col[1]*mod[1]), int(col[2]*mod[2]), int(a))

def rect(n): 
    x, y, w, h = n['rect']; return [x*S, y*S, (x+w)*S, (y+h)*S]

def font(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT_R, max(6,int(size*S)))

cache = {}
def tex(key):
    if key in cache: return cache[key]
    p = os.path.join(TEX, key + '.png')
    im = Image.open(p).convert('RGBA')
    cache[key] = im
    return im

def contain_fit(im, box_w, box_h):
    iw, ih = im.size
    sc = min(box_w/iw, box_h/ih)
    nw, nh = max(1,int(iw*sc)), max(1,int(ih*sc))
    piece = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new('RGBA', (box_w, box_h), (0,0,0,0))
    canvas.alpha_composite(piece, ((box_w-nw)//2, (box_h-nh)//2))
    return canvas

def crop_fit(im, box_w, box_h):
    iw, ih = im.size
    sc = max(box_w/iw, box_h/ih)
    nw, nh = max(1,int(iw*sc)), max(1,int(ih*sc))
    im2 = im.resize((nw, nh), Image.LANCZOS)
    l = (nw - box_w)//2; t = (nh - box_h)//2
    return im2.crop((l, t, l+box_w, t+box_h))

def wrap(text, fnt, maxw):
    lines=[]
    for para in text.split('\n'):
        words = para.split(' ')
        cur=''
        for w_ in words:
            t = (cur+' '+w_).strip()
            if draw.textlength(t, font=fnt) <= maxw or not cur:
                cur = t
            else:
                lines.append(cur); cur = w_
        lines.append(cur)
    return lines

for n in d['nodes']:
    t = n['type']
    b = rect(n)
    mod = n.get('modulate', [1,1,1,1])
    if t == 'TextureRect' and n.get('tex_key'):
        im = tex(n['tex_key'])
        bw, bh = int(b[2]-b[0]), int(b[3]-b[1])
        if bw <= 0 or bh <= 0: continue
        mode = n.get('stretch', 6)
        piece = contain_fit(im, bw, bh) if mode in (4, 5) else crop_fit(im, bw, bh)
        if mod[3] < 1 or mod[0] < 1:
            a = piece.split()[3].point(lambda v: int(v*mod[3]))
            piece.putalpha(a)
        img.alpha_composite(piece, (int(b[0]), int(b[1])))
    elif t == 'ColorRect' and 'color' in n:
        col = mul(c(n['color']), mod)
        layer = Image.new('RGBA', img.size, (0,0,0,0))
        ImageDraw.Draw(layer).rectangle(b, fill=col)
        img.alpha_composite(layer)
    elif t in ('Panel','PanelContainer','Button'):
        st = n.get('style')
        if st:
            bg = mul(c(st['bg']), mod); bd = mul(c(st['border']), mod)
            r = max(0, int(st['radius']*S)); bw = max(0, int(st['bw']*S))
            layer = Image.new('RGBA', img.size, (0,0,0,0))
            lay = ImageDraw.Draw(layer)
            if bg[3] > 0:
                lay.rounded_rectangle(b, radius=r, fill=bg)
            if bd[3] > 0 and bw > 0:
                lay.rounded_rectangle(b, radius=r, outline=bd, width=bw)
            img.alpha_composite(layer)
    if t == 'ProgressBar' and 'bar' in n:
        mn, mx, val = n['bar']
        frac = 0.0 if mx <= mn else max(0.0, min(1.0, (val-mn)/(mx-mn)))
        rad = max(0, int(n.get('bar_radius', 4)*S))
        layer = Image.new('RGBA', img.size, (0,0,0,0)); lay = ImageDraw.Draw(layer)
        if 'bar_bg' in n:
            lay.rounded_rectangle(b, radius=rad, fill=mul(c(n['bar_bg']), mod))
        fw = (b[2]-b[0])*frac
        if fw > 0 and 'fill' in n:
            lay.rounded_rectangle([b[0], b[1], b[0]+fw, b[3]], radius=rad, fill=mul(c(n['fill']), mod))
        img.alpha_composite(layer)
    if n.get('text'):
        txt = n['text']
        if not txt.strip(): continue
        fs = n.get('font_size', 20)
        bold = t == 'Button' or txt.isupper()
        fnt = font(fs, bold)
        col = mul(c(n.get('font_color')), mod)
        bw, bh = b[2]-b[0], b[3]-b[1]
        if bw <= 2 or bh <= 2: continue
        if int(n.get('autowrap', 1)) == 0:
            lines = txt.split('\n')
        else:
            lines = wrap(txt, fnt, bw)
        layer = Image.new('RGBA', img.size, (0,0,0,0))
        halo = 2*S  # тёмный ореол из темы (shadow_outline_size)
        SQ = 0.9  # шрифт Godot уже DejaVu примерно на 10%
        lh = fnt.size*1.22*len(lines)
        y = b[1] + max(0, (bh-lh)/2)
        for line in lines:
            asc, desc = fnt.getmetrics()
            tw = draw.textlength(line, font=fnt)
            tmp_w = max(1, int(tw)+4+2*halo)
            tmp_h = int(asc+desc)+4+2*halo
            tmp = Image.new('RGBA', (tmp_w, tmp_h), (0,0,0,0))
            lum = 0.2126*col[0] + 0.7152*col[1] + 0.0722*col[2]
            halo_col = (10, 8, 15, 218) if lum > 0.3 else (250, 238, 214, 190)
            ImageDraw.Draw(tmp).text((2+halo, 1+halo), line, font=fnt, fill=col,
                                     stroke_width=halo, stroke_fill=halo_col)
            bbox = tmp.getbbox()
            if bbox:
                tmp = tmp.crop(bbox)
            cw, ch = max(1, int(tmp.size[0]*SQ)), tmp.size[1]
            piece = tmp.resize((cw, ch), Image.LANCZOS)
            al = n.get('align', 0)
            if al == 1: x = b[0] + (bw-cw)/2
            elif al == 2: x = b[2] - cw
            else: x = b[0]
            layer.alpha_composite(piece, (int(x), int(y)))
            y += fnt.size*1.22
        mask = Image.new('L', img.size, 0)
        ImageDraw.Draw(mask).rectangle(b, fill=255)
        layer.putalpha(Image.composite(layer.split()[3], Image.new('L', img.size, 0), mask))
        img.alpha_composite(layer)
    if n.get('icon_key'):
        im = tex(n['icon_key'])
        side = int(min(b[2]-b[0], b[3]-b[1]) * 0.68)
        piece = crop_fit(im, side, side)
        cx = int(b[0] + (b[2]-b[0]-side)/2)
        cy = int(b[1] + (b[3]-b[1]-side)/2)
        img.alpha_composite(piece, (cx, cy))

img.convert('RGB').resize((SW, SH), Image.LANCZOS).save(OUT, optimize=True)
print('saved', OUT, os.path.getsize(OUT))
