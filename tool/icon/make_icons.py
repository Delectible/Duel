"""Generates every Duel launcher icon and the Play store art from one drawing.

    python3 tool/icon/make_icons.py        (needs Pillow)

The mark: two playing cards fanned against each other, a spade and a heart,
on dark card-table green. A placeholder until the app has real art.

Writes:
  Android  adaptive icon (background colour, foreground, monochrome for
           Android 13+ themed icons) and the legacy icon.
  iOS      single-size 1024 AppIcon.
  Play     512 icon + 1024x500 feature graphic for the store listing
           (fastlane/metadata/android/en-AU/images).
"""
import json
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SS = 4                                   # supersampling factor
BG = (11, 46, 35)                        # #0B2E23, adaptive background colour
BG_TOP, BG_BOT = (18, 66, 50), (6, 30, 23)
CARD, EDGE = (246, 242, 232), (200, 192, 176)
RED, INK = (200, 36, 44), (22, 22, 26)


def _gradient(w, h, top, bot):
    g = Image.new('RGB', (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bot)))
    return g.resize((w, h))


def _heart(d, cx, cy, r, fill):
    d.ellipse((cx - 2 * r, cy - r * 1.6, cx, cy + r * 0.4), fill=fill)
    d.ellipse((cx, cy - r * 1.6, cx + 2 * r, cy + r * 0.4), fill=fill)
    d.polygon([(cx - 1.93 * r, cy - 0.2 * r), (cx, cy - 0.9 * r), (cx + 1.93 * r, cy - 0.2 * r), (cx, cy + 2.1 * r)], fill=fill)


def _spade(d, cx, cy, r, fill):
    d.ellipse((cx - 2 * r, cy - r * 0.4, cx, cy + r * 1.6), fill=fill)
    d.ellipse((cx, cy - r * 0.4, cx + 2 * r, cy + r * 1.6), fill=fill)
    d.polygon([(cx - 1.93 * r, cy + 0.2 * r), (cx, cy + 0.9 * r), (cx + 1.93 * r, cy + 0.2 * r), (cx, cy - 2.1 * r)], fill=fill)
    d.polygon([(cx, cy + 0.6 * r), (cx - 0.9 * r, cy + 2.4 * r), (cx + 0.9 * r, cy + 2.4 * r)], fill=fill)


def _card(size, suit, mono=None):
    """One upright card, size = card height in px (2.5:3.5), as RGBA."""
    h = size
    w = round(h * 5 / 7)
    pad = round(h * 0.04)
    im = Image.new('RGBA', (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rad = round(h * 0.08)
    face = mono or CARD
    if mono is None:
        d.rounded_rectangle((pad, pad, pad + w, pad + h), rad, fill=EDGE)
        inset = max(1, round(h * 0.012))
        d.rounded_rectangle((pad + inset, pad + inset, pad + w - inset, pad + h - inset), rad - inset, fill=face)
    else:
        d.rounded_rectangle((pad, pad, pad + w, pad + h), rad, fill=face)
    ink = (0, 0, 0, 0) if mono else (RED if suit == 'heart' else INK)
    draw = _heart if suit == 'heart' else _spade
    draw(d, pad + w / 2, pad + h / 2, h * 0.11, ink)
    # Corner pips.
    draw(d, pad + w * 0.2, pad + h * 0.13, h * 0.035, ink)
    draw(d, pad + w * 0.8, pad + h * 0.87, h * 0.035, ink)
    return im


def mark(size, mono=None):
    """The two fanned cards centred on a transparent size x size canvas."""
    S = size * SS
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ch = round(S * 0.58)
    for suit, angle, dx in (('spade', 16, -0.16), ('heart', -16, 0.16)):
        c = _card(ch, suit, mono).rotate(angle, resample=Image.BICUBIC, expand=True)
        x = round(S / 2 + dx * S - c.width / 2)
        y = round(S / 2 - c.height / 2 + S * 0.02)
        if mono is None:
            shadow = Image.new('RGBA', c.size, (0, 0, 0, 0))
            shadow.putalpha(c.getchannel('A').point(lambda a: a * 0.35))
            out.alpha_composite(shadow, (x + round(S * 0.012), y + round(S * 0.018)))
        else:
            # Single-colour: cut a gap round the front card so the two read apart.
            gap = Image.new('L', out.size, 0)
            gap.paste(c.getchannel('A'), (x, y))
            gap = gap.filter(ImageFilter.MaxFilter(2 * round(S * 0.012) + 1))
            out.putalpha(ImageChops.subtract(out.getchannel('A'), gap))
        out.alpha_composite(c, (x, y))
    return out.resize((size, size), Image.LANCZOS)


def full_icon(size):
    """Opaque square icon: table green + the mark."""
    im = _gradient(size, size, BG_TOP, BG_BOT).convert('RGBA')
    im.alpha_composite(mark(round(size * 0.92)), (round(size * 0.04), round(size * 0.04)))
    return im.convert('RGB')


def _save(im, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p, optimize=True)


def _font(px):
    for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf', 'DejaVuSerif-Bold.ttf'):
        try:
            return ImageFont.truetype(f, px)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    res = ('android', 'app', 'src', 'main', 'res')
    for dpi, scale in (('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)):
        _save(full_icon(round(48 * scale)), *res, f'mipmap-{dpi}', 'ic_launcher.png')
        # Adaptive layers are 108 dp; the mark fits the 66 dp safe circle.
        fg = round(108 * scale)
        inner = round(72 * scale)
        for name, mono in (('ic_launcher_foreground', None), ('ic_launcher_monochrome', (255, 255, 255))):
            layer = Image.new('RGBA', (fg, fg), (0, 0, 0, 0))
            layer.alpha_composite(mark(inner, mono), ((fg - inner) // 2, (fg - inner) // 2))
            _save(layer, *res, f'mipmap-{dpi}', f'{name}.png')
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
    fg = _gradient(1024, 500, BG_TOP, BG_BOT).convert('RGBA')
    fg.alpha_composite(mark(460), (90, 20))
    d = ImageDraw.Draw(fg)
    d.text((600, 250), 'Duel', font=_font(150), fill=CARD, anchor='lm')
    _save(fg.convert('RGB'), *play, 'featureGraphic.png')


def _save_text(text, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(text + '\n')


if __name__ == '__main__':
    main()
