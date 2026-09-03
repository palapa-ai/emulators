"""Extract Cupertino icon outlines as Flutter Path code on a 16x16 grid."""
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen

ICONS = {
    "reset": 0xF21C,
    "training": 0xF818,
    "trainingOff": 0xF7DA,
    "fullscreen": 0xF386,
    "fullscreenExit": 0xF37D,
    "check": 0xF3FD,
    "copy": 0xF634,
    "controller": 0xF43A,
    "pause": 0xF478,
    "play": 0xF488,
    "sound": 0xF7EC,
    "muted": 0xF3B9,
    "delete": 0xF4C4,
    "save": 0xF8DD,
    "load": 0xF38A,
}

font = TTFont(sys.argv[1])
cmap = font.getBestCmap()
glyph_set = font.getGlyphSet()
upm = font["head"].unitsPerEm
ascent = font["hhea"].ascent
descent = font["hhea"].descent  # negative

print("// GENERATED from cupertino_icons 1.0.9 (MIT) by tool/extract_glyphs.py")
print("// — outlines only, no font dependency. Do not edit by hand.")
print("part of 'emulator_glyph.dart';")
print()
print("final Map<EmulatorIcon, Path> _cupertinoPaths = {")

for name, code in ICONS.items():
    glyph_name = cmap.get(code)
    if glyph_name is None:
        sys.stderr.write(f"missing: {name} {code:#x}\n")
        continue
    glyph = glyph_set[glyph_name]
    pen = RecordingPen()
    glyph.draw(pen)

    # Bounding box for centering.
    xs, ys = [], []
    for op, pts in pen.value:
        for p in pts:
            if p is not None:
                xs.append(p[0])
                ys.append(p[1])
    if not xs:
        continue
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    scale = 14.0 / max(w, h)
    ox = (16 - w * scale) / 2 - min(xs) * scale
    oy = (16 - h * scale) / 2 + max(ys) * scale  # y flips

    def tx(p):
        return round(p[0] * scale + ox, 2), round(oy - p[1] * scale, 2)

    print(f"  EmulatorIcon.{name}: Path()")
    contour_start = None
    for op, pts in pen.value:
        if op == "moveTo":
            contour_start = pts[0]
            x, y = tx(pts[0])
            print(f"    ..moveTo({x}, {y})")
        elif op == "lineTo":
            x, y = tx(pts[0])
            print(f"    ..lineTo({x}, {y})")
        elif op == "qCurveTo":
            # TrueType strings of quadratics with implied on-curve midpoints.
            # A trailing None closes an all-off-curve contour back at its start.
            points = list(pts)
            last = points[-1] if points[-1] is not None else contour_start
            controls = points[:-1]
            for i, ctrl in enumerate(controls):
                if i < len(controls) - 1:
                    nxt = controls[i + 1]
                    mid = ((ctrl[0] + nxt[0]) / 2, (ctrl[1] + nxt[1]) / 2)
                else:
                    mid = last
                cx, cy = tx(ctrl)
                mx, my = tx(mid)
                print(f"    ..quadraticBezierTo({cx}, {cy}, {mx}, {my})")
            if not controls:
                x, y = tx(last)
                print(f"    ..lineTo({x}, {y})")
        elif op == "curveTo":
            (c1, c2, end) = pts
            ax, ay = tx(c1)
            bx, by = tx(c2)
            ex, ey = tx(end)
            print(f"    ..cubicTo({ax}, {ay}, {bx}, {by}, {ex}, {ey})")
        elif op == "closePath":
            print("    ..close()")
    print("  ,")

print("};")
