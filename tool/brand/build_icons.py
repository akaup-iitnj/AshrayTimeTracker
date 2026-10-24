"""
Build every Chronicler icon from one geometry: "Hours to blocks".

An hourglass in the Bold look. Blue sand runs through the neck and lands as
a pile of hour blocks in the category colours: passing time becomes the hours
you log. Colours are the Bold tokens from lib/src/bold.dart.

The mark is drawn in its own space, centred on (0, 0), and placed into each
output with a translate and a scale:

  tool/brand/chronicle-icon.svg            master: the mark on the Bold tile
  tool/brand/chronicle-maskable.svg        full-bleed yellow, safe-zone mark
  assets/brand/chronicle-icon.png          the in-app mark (ChronicleMark)
  web/favicon.png, web/favicon.svg, web/icons/*.png
  android/app/src/main/res/mipmap-*/ic_launcher.png      legacy launcher
  android/app/src/main/res/drawable/ic_launcher_foreground.xml   adaptive
  android/app/src/main/res/drawable/ic_launcher_monochrome.xml   themed icon
  android/app/src/main/res/drawable/ic_notification.xml          status bar
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  android/app/src/main/res/values/ic_launcher_background.xml

PNGs are rendered by headless Chrome, then downsized with Pillow.

Run from the repo root:  python -I tool/brand/build_icons.py
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

YELLOW, INK, PANEL, BLUE = '#FFD84D', '#111111', '#FFFFFF', '#3D5AFE'
SKY, CORAL, PINK = '#7CC4FF', '#FF8A80', '#FF3D7F'

# ---------------------------------------------------------------- the mark
# Mark space: centred on (0, 0); the whole mark spans about ±304 tall and
# ±280 wide, plus its hard shadows.
GLASS = ('M-222,-240 L222,-240 C222,-140 30,-46 30,0 C30,46 222,140 222,240 '
         'L-222,240 C-222,140 -30,46 -30,0 C-30,-46 -222,-140 -222,-240 Z')
SAND = ('M-132,-128 L132,-128 C90,-70 24,-26 0,-18 C-24,-26 -90,-70 -132,-128 Z')
GLASS_STROKE, GLASS_SHADOW = 30, 28
CAPS = [(-280, -304, 560, 56), (-280, 248, 560, 56)]  # x, y, w, h
CAP_RADIUS, CAP_SHADOW = 16, 24
BLOCK, BLOCK_GAP, BLOCK_STROKE, BLOCK_RADIUS = 64, 8, 16, 10
BLOCK_BASE = 240 - 22 - BLOCK
# (column, row, colour): three on the floor of the glass, two on top.
BLOCKS = [(-1, 0, SKY), (0, 0, CORAL), (1, 0, BLUE), (-0.5, 1, PINK), (0.5, 1, SKY)]
# The falling stream, as dashes: (y_top, y_bottom), 16 wide.
STREAM = [(-16, 4), (18, 38), (52, 72)]
STREAM_WIDTH = 16


def f(x):
    return f'{x:.3f}'.rstrip('0').rstrip('.')


def rect_path(x, y, w, h, r=0):
    if not r:
        return f'M{f(x)},{f(y)} h{f(w)} v{f(h)} h{f(-w)} Z'
    return (f'M{f(x + r)},{f(y)} h{f(w - 2 * r)} a{f(r)},{f(r)} 0 0 1 {f(r)},{f(r)} '
            f'v{f(h - 2 * r)} a{f(r)},{f(r)} 0 0 1 {f(-r)},{f(r)} h{f(-(w - 2 * r))} '
            f'a{f(r)},{f(r)} 0 0 1 {f(-r)},{f(-r)} v{f(-(h - 2 * r))} '
            f'a{f(r)},{f(r)} 0 0 1 {f(r)},{f(-r)} Z')


def blocks():
    step = BLOCK + BLOCK_GAP
    for col, row, colour in BLOCKS:
        yield col * step - BLOCK / 2, BLOCK_BASE - row * step, colour


def cap_paths(offset=0):
    return [rect_path(x + offset, y + offset, w, h, CAP_RADIUS) for x, y, w, h in CAPS]


def stream_paths():
    return [rect_path(-STREAM_WIDTH / 2, a, STREAM_WIDTH, b - a) for a, b in STREAM]


# ---------------------------------------------------------------- SVG outputs
def mark_svg():
    """The full-colour mark in mark space."""
    out = [f'<path d="{GLASS}" fill="{INK}" '
           f'transform="translate({GLASS_SHADOW},{GLASS_SHADOW})"/>',
           f'<path d="{GLASS}" fill="{PANEL}" stroke="{INK}" '
           f'stroke-width="{GLASS_STROKE}" stroke-linejoin="round"/>',
           f'<path d="{SAND}" fill="{BLUE}"/>']
    out += [f'<path d="{d}" fill="{BLUE}"/>' for d in stream_paths()]
    for x, y, colour in blocks():
        out.append(f'<path d="{rect_path(x, y, BLOCK, BLOCK, BLOCK_RADIUS)}" '
                   f'fill="{colour}" stroke="{INK}" stroke-width="{BLOCK_STROKE}"/>')
    out += [f'<path d="{d}" fill="{INK}"/>' for d in cap_paths(CAP_SHADOW)]
    out += [f'<path d="{d}" fill="{INK}"/>' for d in cap_paths()]
    return ''.join(out)


def icon_svg():
    """The mark on the Bold tile: yellow, black outline, hard shadow."""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">'
        f'<rect x="128" y="128" width="820" height="820" rx="168" fill="{INK}"/>'
        f'<rect x="72" y="72" width="820" height="820" rx="168" fill="{YELLOW}" '
        f'stroke="{INK}" stroke-width="40"/>'
        f'<g transform="translate(476,476)">{mark_svg()}</g></svg>'
    )


def maskable_svg():
    """Full-bleed yellow; the mark sits inside the 80% safe circle."""
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">'
        f'<rect width="1024" height="1024" fill="{YELLOW}"/>'
        f'<g transform="translate(500,500) scale(0.9)">{mark_svg()}</g></svg>'
    )


# ---------------------------------------------------------------- Android vectors
def vpath(d, fill=None, stroke=None, width=None, indent='        '):
    attrs = [f'android:pathData="{d}"']
    if fill:
        attrs.append(f'android:fillColor="{fill}"')
    if stroke:
        attrs += [f'android:strokeColor="{stroke}"',
                  f'android:strokeWidth="{f(width)}"',
                  'android:strokeLineJoin="round"']
    inner = f'\n{indent}    '.join(attrs)
    return f'{indent}<path\n{indent}    {inner} />\n'


def vector(size_dp, viewport, cx, cy, scale, body):
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Generated by tool/brand/build_icons.py. Do not edit. -->\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        f'    android:width="{size_dp}dp"\n'
        f'    android:height="{size_dp}dp"\n'
        f'    android:viewportWidth="{viewport}"\n'
        f'    android:viewportHeight="{viewport}">\n'
        f'    <group\n'
        f'        android:translateX="{f(cx)}"\n'
        f'        android:translateY="{f(cy)}"\n'
        f'        android:scaleX="{f(scale)}"\n'
        f'        android:scaleY="{f(scale)}">\n'
        f'{body}'
        '    </group>\n'
        '</vector>\n'
    )


def argb(hex_colour):
    return '#FF' + hex_colour.lstrip('#').upper()


def adaptive_foreground():
    """108dp layer; the launcher masks it and supplies the yellow behind.
    The mark's corners (about 413 from centre) stay inside the 33dp circle."""
    shadow =(f'        <group android:translateX="{GLASS_SHADOW}" '
              f'android:translateY="{GLASS_SHADOW}">\n'
              + vpath(GLASS, fill=argb(INK), indent='            ')
              + '        </group>\n')
    body = shadow + vpath(GLASS, fill=argb(PANEL), stroke=argb(INK), width=GLASS_STROKE)
    body += vpath(SAND, fill=argb(BLUE))
    body += ''.join(vpath(d, fill=argb(BLUE)) for d in stream_paths())
    for x, y, colour in blocks():
        body += vpath(rect_path(x, y, BLOCK, BLOCK, BLOCK_RADIUS), fill=argb(colour),
                      stroke=argb(INK), width=BLOCK_STROKE)
    body += ''.join(vpath(d, fill=argb(INK)) for d in cap_paths(CAP_SHADOW))
    body += ''.join(vpath(d, fill=argb(INK)) for d in cap_paths())
    return vector(108, 108, 53, 53, 0.074, body)


def silhouette(size_dp, viewport, scale, colour):
    """One colour: caps, the glass as an outline, sand and blocks filled."""
    body = vpath(GLASS, stroke=colour, width=GLASS_STROKE * 1.4)
    body += vpath(SAND, fill=colour)
    body += ''.join(vpath(d, fill=colour) for d in stream_paths())
    for x, y, _ in blocks():
        body += vpath(rect_path(x, y, BLOCK, BLOCK, BLOCK_RADIUS), fill=colour)
    body += ''.join(vpath(d, fill=colour) for d in cap_paths())
    return vector(size_dp, viewport, viewport / 2, viewport / 2, scale, body)


# ---------------------------------------------------------------- rendering
def render(svg, size, path):
    """Render an SVG at 1024px with headless Chrome, then downsize."""
    with tempfile.TemporaryDirectory() as tmp:
        page = os.path.join(tmp, 'icon.html')
        shot = os.path.join(tmp, 'shot.png')
        with open(page, 'w', encoding='utf-8') as out:
            out.write('<!doctype html><html><head><style>'
                      'html,body{margin:0;background:transparent}'
                      'svg{display:block}</style></head><body>'
                      f'{svg}</body></html>')
        subprocess.run(
            [CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
             '--force-device-scale-factor=1', '--window-size=1024,1024',
             '--default-background-color=00000000',
             f'--screenshot={shot}', 'file:///' + page.replace('\\', '/')],
            check=True, capture_output=True)
        image = Image.open(shot).convert('RGBA').crop((0, 0, 1024, 1024))
        if size != 1024:
            image = image.resize((size, size), Image.LANCZOS)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        image.save(path, optimize=True)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as out:
        out.write(text)


def main():
    if not os.path.exists(CHROME):
        sys.exit(f'Chrome not found at {CHROME}')
    brand = os.path.join(ROOT, 'tool', 'brand')
    icon, maskable = icon_svg(), maskable_svg()
    write(os.path.join(brand, 'chronicle-icon.svg'), icon + '\n')
    write(os.path.join(brand, 'chronicle-maskable.svg'), maskable + '\n')

    render(icon, 256, os.path.join(ROOT, 'assets', 'brand', 'chronicle-icon.png'))

    web = os.path.join(ROOT, 'web')
    write(os.path.join(web, 'favicon.svg'), icon + '\n')
    render(icon, 32, os.path.join(web, 'favicon.png'))
    render(icon, 192, os.path.join(web, 'icons', 'Icon-192.png'))
    render(icon, 512, os.path.join(web, 'icons', 'Icon-512.png'))
    render(maskable, 192, os.path.join(web, 'icons', 'Icon-maskable-192.png'))
    render(maskable, 512, os.path.join(web, 'icons', 'Icon-maskable-512.png'))

    for folder, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                         ('xxhdpi', 144), ('xxxhdpi', 192)]:
        render(icon, size, os.path.join(RES, f'mipmap-{folder}', 'ic_launcher.png'))

    drawable = os.path.join(RES, 'drawable')
    write(os.path.join(drawable, 'ic_launcher_foreground.xml'), adaptive_foreground())
    write(os.path.join(drawable, 'ic_launcher_monochrome.xml'),
          silhouette(108, 108, 0.074, '#FF000000'))
    write(os.path.join(drawable, 'ic_notification.xml'),
          silhouette(24, 24, 0.035, '#FFFFFFFF'))
    write(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'),
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<!-- Generated by tool/brand/build_icons.py. Do not edit. -->\n'
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <background android:drawable="@color/ic_launcher_background" />\n'
          '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
          '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
          '</adaptive-icon>\n')
    write(os.path.join(RES, 'values', 'ic_launcher_background.xml'),
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<!-- Generated by tool/brand/build_icons.py. Do not edit. -->\n'
          '<resources>\n'
          f'    <color name="ic_launcher_background">{YELLOW}</color>\n'
          '</resources>\n')
    print('Chronicler icons written.')


if __name__ == '__main__':
    main()
