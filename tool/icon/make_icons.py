"""Generates every Duel launcher icon and the Play store art from one drawing.

    python3 tool/icon/make_icons.py        (needs Pillow + numpy)

The mark: a ghost glancing sideways, a tiny spade for the glint in each eye,
drawn the way Darkroom draws its rabbit: white with scanlines, split into
red / green / blue copies like a mis-converged CRT (red and yellow fringe on
the left, cyan and blue on the right), on near-black with a soft light from
the top left.

Writes:
  Android  adaptive icon (background colour, foreground, monochrome for
           Android 13+ themed icons) and the legacy icon.
  iOS      single-size 1024 AppIcon.
  Play     512 icon + 1024x500 feature graphic for the store listing
           (fastlane/metadata/android/en-AU/images).
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SS = 4                                   # supersampling factor
BG = (14, 14, 18)                        # #0E0E12, adaptive background colour
BG_TOP, BG_BOT = (24, 25, 31), (9, 9, 12)
SPLIT = 5                                # RGB offset in design units (192 grid)
SCAN = 0.84                              # scanline brightness on the ghost
GHOST = 1.14                             # the ghost's scale on the full icon


class _Pen:
    """Draws on the 192-unit design grid (the ghost's own scale) into a mask."""

    def __init__(self, S, cx, cy, D, dx=0.0):
        self.u = D / 192 * GHOST
        self.cx, self.cy, self.dx = cx, cy, dx * D / 192
        self.m = Image.new('L', (S, S), 0)
        self.d = ImageDraw.Draw(self.m)

    def P(self, x, y):
        return self.cx + (x - 96) * self.u + self.dx, self.cy + (y - 96 - 4) * self.u

    def ellipse(self, x, y, rx, ry):
        a, b = self.P(x - rx, y - ry), self.P(x + rx, y + ry)
        self.d.ellipse((a[0], a[1], b[0], b[1]), fill=255)

    def rect(self, x0, y0, x1, y1):
        a, b = self.P(x0, y0), self.P(x1, y1)
        self.d.rectangle((a[0], a[1], b[0], b[1]), fill=255)

    def poly(self, pts):
        self.d.polygon([self.P(*p) for p in pts], fill=255)

    def spade(self, cx, cy, r):
        self.ellipse(cx - r * 0.5, cy + r * 0.2, r * 0.55, r * 0.55)
        self.ellipse(cx + r * 0.5, cy + r * 0.2, r * 0.55, r * 0.55)
        self.poly([(cx - r * 1.02, cy + 0.3 * r), (cx + r * 1.02, cy + 0.3 * r), (cx, cy - r)])
        self.poly([(cx, cy + 0.3 * r), (cx - r * 0.35, cy + r * 1.05), (cx + r * 0.35, cy + r * 1.05)])

    def array(self):
        return np.asarray(self.m, dtype=np.float32) / 255


def _mask(S, cx, cy, D, part, dx=0.0):
    """One part of the ghost as a float mask 0..1: 'body', 'eyes' or 'glints'."""
    p = _Pen(S, cx, cy, D, dx)
    if part == 'body':
        p.ellipse(96, 92, 56, 56)                      # head
        p.rect(40, 92, 152, 150)
        for x in (54, 82, 110, 138):                   # the wavy hem
            p.ellipse(x, 150, 14, 16)
    elif part == 'eyes':
        for x in (72, 108):                            # glancing to the left
            p.ellipse(x, 94, 10, 14)
    else:
        for x in (69, 105):                            # a spade for each glint
            p.spade(x, 88, 4.2)
    return p.array()


def _scanlines(S, D):
    period = 4 * D / 192
    rows = (np.arange(S) % period) < period * 0.4
    return np.where(rows, SCAN, 1.0).astype(np.float32)[:, None, None]


def _background(W, H=None):
    H = H or W
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top, bot = np.array(BG_TOP, np.float32), np.array(BG_BOT, np.float32)
    img = np.broadcast_to(top + (bot - top) * t, (H, W, 3)).copy()
    # A soft light from the top left.
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    yy, xx = yy / H, xx / W
    img += (np.clip(1 - np.hypot(xx - 0.2, yy - 0.15) / 0.75, 0, 1) ** 2 * 18)[..., None]
    return img


def mark(S, cx, cy, D, canvas=None):
    """The RGB-split ghost as premultiplied colour (0..255) + alpha (0..1)."""
    shape = canvas or (S, S)
    r, g, b = (_mask(max(shape), cx, cy, D, 'body', d)[: shape[0], : shape[1]] for d in (-SPLIT, 0, SPLIT))
    scan = _scanlines(max(shape), D)[: shape[0]]
    rgb = np.stack([r, g, b], -1) * 255 * scan
    alpha = np.maximum(np.maximum(r, g), b)
    eyes = _mask(max(shape), cx, cy, D, 'eyes')[: shape[0], : shape[1]]
    glints = _mask(max(shape), cx, cy, D, 'glints')[: shape[0], : shape[1]]
    rgb = rgb * (1 - eyes)[..., None]
    rgb = rgb * (1 - glints)[..., None] + (glints * 255)[..., None] * scan
    alpha = np.maximum(alpha * (1 - eyes), glints)
    return rgb, alpha


def _out(px, rgb, alpha=None, size=None):
    if alpha is None:
        img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), 'RGB')
    else:   # un-premultiply for a straight-alpha PNG
        a = np.clip(alpha, 0, 1)
        col = np.where(a[..., None] > 1e-4, rgb / np.maximum(a, 1e-4)[..., None], 0)
        img = Image.fromarray(np.dstack([np.clip(col, 0, 255), a * 255]).astype(np.uint8), 'RGBA')
    return img.resize(size or (px, px), Image.LANCZOS)


def full_icon(px):
    """Opaque square icon (iOS, Play, legacy Android): the ghost on the dark background."""
    S = px * SS
    rgb, a = mark(S, S / 2, S / 2, S)
    return _out(px, _background(S) * (1 - a[..., None]) + rgb)


def foreground(px):
    """Adaptive icon foreground (108 dp): the ghost inside the 66 dp safe zone."""
    S = px * SS
    rgb, a = mark(S, S / 2, S / 2, S * 0.74)
    return _out(px, rgb, a)


def monochrome(px):
    """Android 13+ themed icon: one colour, eyes cut out (the system tints it)."""
    S = px * SS
    D = S * 0.74
    body = _mask(S, S / 2, S / 2, D, 'body')
    eyes = _mask(S, S / 2, S / 2, D, 'eyes')
    a = body * (1 - eyes)
    return _out(px, np.full((S, S, 3), 255, np.float32) * a[..., None], a)


def _save(im, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p, optimize=True)


def _font(px):
    for f in (os.path.join(ROOT, 'assets', 'fonts', 'Fredoka-Bold.ttf'),
              '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        try:
            return ImageFont.truetype(f, px)
        except OSError:
            pass
    return ImageFont.load_default()


def feature_graphic():
    """1024 x 500 for the store listing: the ghost, then "Duel" split the same way."""
    W, H = 1024 * SS, 500 * SS
    img = _background(W, H)
    D = H * 1.02
    rgb, a = mark(W, W * 0.27, H * 0.5, D, canvas=(H, W))
    img = img * (1 - a[..., None]) + rgb
    # The name, in three offset copies that add up to white.
    font = _font(190 * SS)
    planes = []
    for d in (-SPLIT, 0, SPLIT):
        m = Image.new('L', (W, H), 0)
        ImageDraw.Draw(m).text((W * 0.52 + d * SS * 1.6, H * 0.5), 'Duel', font=font, fill=255, anchor='lm')
        planes.append(np.asarray(m, np.float32) / 255)
    text = np.stack(planes, -1) * 255
    ta = np.max(np.stack(planes, -1), -1)
    img = img * (1 - ta[..., None]) + text
    return _out(0, img, size=(1024, 500))


def main():
    res = ('android', 'app', 'src', 'main', 'res')
    for dpi, scale in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
        _save(full_icon(round(48 * scale)), *res, f'mipmap-{dpi}', 'ic_launcher.png')
        layer = round(108 * scale)
        _save(foreground(layer), *res, f'mipmap-{dpi}', 'ic_launcher_foreground.png')
        _save(monochrome(layer), *res, f'mipmap-{dpi}', 'ic_launcher_monochrome.png')
    _save_text('\n'.join([
        '<?xml version="1.0" encoding="utf-8"?>',
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">',
        '    <background android:drawable="@color/ic_launcher_background" />',
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />',
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />',
        '</adaptive-icon>',
    ]), *res, 'mipmap-anydpi-v26', 'ic_launcher.xml')
    _save_text('\n'.join([
        '<?xml version="1.0" encoding="utf-8"?>',
        '<resources>',
        '    <color name="ic_launcher_background">#%02X%02X%02X</color>' % BG,
        '</resources>',
    ]), *res, 'values', 'ic_launcher_background.xml')

    icons = ('ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    _save(full_icon(1024), *icons, 'AppIcon-1024.png')
    _save_text(json.dumps({
        'images': [{'filename': 'AppIcon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
        'info': {'version': 1, 'author': 'xcode'},
    }, indent=2), *icons, 'Contents.json')

    play = ('fastlane', 'metadata', 'android', 'en-AU', 'images')
    _save(full_icon(512), *play, 'icon.png')
    _save(feature_graphic(), *play, 'featureGraphic.png')


def _save_text(text, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(text + '\n')


if __name__ == '__main__':
    main()
