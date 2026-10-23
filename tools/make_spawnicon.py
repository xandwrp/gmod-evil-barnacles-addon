import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
INK = (226, 219, 207)
BG_IN = (42, 38, 41)
BG_OUT = (12, 11, 12)
BOX = (112, 84)
CEILING = 24

SS = 8
W, H = 170, 120
CX = 85
SACK = [
    (66, 0), (104, 0), (111, 4), (117, 10), (122, 17), (124, 26), (120, 34), (114, 40), (106, 45), (98, 48), (92, 49),
    (89, 52), (85, 54), (81, 52), (78, 49), (72, 48), (64, 45), (56, 40), (50, 33), (47, 25), (49, 16), (54, 9), (59, 4),
]
FOLDS = [[(49, 27), (55, 28), (60, 27)], [(123, 24), (117, 26), (112, 25)], [(70, 45), (73, 41)], [(101, 44), (98, 40)]]
FOLD_R = 1.0
LUMPS = [(52, 12, 4), (47, 22, 3.5), (52, 36, 4.5), (62, 44, 3.5), (76, 49, 3), (117, 12, 4.5), (123, 23, 3), (118, 37, 4), (107, 45, 4), (95, 49, 3)]
TONGUE = [(85, 52), (86.5, 64), (84, 78), (86.5, 92), (85, 106)]
TONGUE_R = (2.6, 1.5)
TIP = (85, 107, 3.0)
FEELERS = [
    [(80, 50), (76, 59), (77.5, 68)],
    [(90, 50), (95, 57), (93.5, 64)],
]
FEELER_R = (1.6, 0.6)
ROOTS = [
    [(64, 1), (55, 3.5), (47, 1.5), (38, 4.5), (30, 2), (22, 5)],
    [(55, 3.5), (52, 9), (54, 14)],
    [(47, 1.5), (42, 6), (36, 8)],
    [(38, 4.5), (35, 11)],
    [(30, 2), (24, 0.5)],
    [(106, 1), (115, 4), (123, 2), (132, 5.5), (141, 3), (149, 6)],
    [(115, 4), (118, 10), (116, 15)],
    [(123, 2), (129, 7), (135, 9)],
    [(132, 5.5), (134, 12)],
    [(141, 3), (147, 0.5)],
]
ROOT_R = (2.0, 0.6)
OUT = os.path.join(os.path.dirname(__file__), "..", "materials", "entities", "evil_barnacle.png")
PREVIEW = os.path.join(os.path.dirname(__file__), "..", "renders", "spawnicon_preview.png")


def layer():
    im = Image.new("L", (W * SS, H * SS), 0)
    return im, ImageDraw.Draw(im)


def dot(draw, x, y, r, fill=255):
    draw.ellipse(((x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS), fill=fill)


def stroke(draw, points, r0, r1, fill=255):
    total = sum(math.dist(a, b) for a, b in zip(points, points[1:])) or 1
    run = 0
    for a, b in zip(points, points[1:]):
        seg = math.dist(a, b)
        n = max(1, int(seg * 4))
        for i in range(n + 1):
            f = (run + seg * i / n) / total
            dot(draw, a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n, r0 + (r1 - r0) * f, fill)
        run += seg


def spline(points, closed=False, n=8):
    pts = points[-1:] + points + points[:2] if closed else points[:1] + points + points[-1:]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1:i + 3]
        for s in range(n):
            t = s / n
            out.append(tuple(0.5 * (2 * p1[k] + (p2[k] - p0[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t * t
                                    + (3 * p1[k] - p0[k] - 3 * p2[k] + p3[k]) * t ** 3) for k in (0, 1)))
    return out if closed else out + [points[-1]]


def creature():
    im, draw = layer()
    for root in ROOTS:
        stroke(draw, spline(root), *ROOT_R)
    stroke(draw, spline(TONGUE), *TONGUE_R)
    dot(draw, *TIP)
    for feeler in FEELERS:
        stroke(draw, spline(feeler), *FEELER_R)
    draw.polygon([(x * SS, y * SS) for x, y in spline(SACK, closed=True)], fill=255)
    for lump in LUMPS:
        dot(draw, *lump)
    for fold in FOLDS:
        stroke(draw, spline(fold), FOLD_R, FOLD_R * 0.5, 0)
    return im


def tile(alpha):
    alpha = alpha.crop(alpha.getbbox())
    k = min(BOX[0] / alpha.width, BOX[1] / alpha.height)
    alpha = alpha.resize((max(1, round(alpha.width * k)), max(1, round(alpha.height * k))), Image.LANCZOS)
    bg = Image.new("RGB", (SIZE, SIZE))
    px = bg.load()
    for j in range(SIZE):
        for i in range(SIZE):
            t = min(1, math.hypot(i - SIZE / 2, j - SIZE / 2) / (SIZE * 0.72)) ** 2
            px[i, j] = tuple(round(a + (b - a) * t) for a, b in zip(BG_IN, BG_OUT))
    bg.paste(Image.new("RGB", alpha.size, INK), ((SIZE - alpha.width) // 2, CEILING), alpha)
    return bg


if __name__ == "__main__":
    icon = tile(creature().resize((W * 2, H * 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.3)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.save(OUT, optimize=True)
    print("materials/entities/evil_barnacle.png  %dx%d" % icon.size)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    icon.resize((SIZE * 3, SIZE * 3), Image.LANCZOS).save(PREVIEW)
