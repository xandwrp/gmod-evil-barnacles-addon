import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
INK = (226, 219, 207)
BG_IN = (42, 38, 41)
BG_OUT = (12, 11, 12)
BOX = (118, 116)
TOP = 6

SS = 8
W, H = 170, 170
CX = 85
SACK = [(60, 2), (50, 10), (45, 22), (47, 34), (55, 45), (67, 53), (77, 56), (93, 56), (103, 53), (115, 45), (123, 34), (125, 22), (120, 10), (110, 2)]
RIBS = [(16, 0.78), (30, 0.74), (42, 0.62)]
RIB_WIDTH = 1.1
RIB_SAG = 5
TEETH = [(-10, 54), (-5, 56), (0, 56.5), (5, 56), (10, 54)]
TOOTH = (2.2, 4.5)
STRANDS = [
    [(60, 3), (36, 4), (24, 2), (10, 4), (0, 3)],
    [(36, 4), (30, 9), (31, 15)],
    [(24, 2), (18, 7)],
    [(110, 3), (134, 5), (148, 2), (160, 4), (170, 3)],
    [(134, 5), (139, 11), (137, 17)],
    [(148, 2), (153, 8)],
]
STRAND_R = (1.6, 0.6)
HEAD = (CX, 61, 6)
NECK = [(CX, 64), (CX, 68)]
TORSO = [(CX - 9, 67), (CX + 9, 67), (CX + 8, 84), (CX + 6, 98), (CX - 6, 98), (CX - 8, 84)]
ARMS = [
    [(CX - 9, 68), (CX - 12, 82), (CX - 12, 95), (CX - 11, 101)],
    [(CX + 9, 68), (CX + 12, 82), (CX + 12, 95), (CX + 11, 101)],
]
ARM_R = (3.0, 2.0)
LEGS = [
    [(CX - 3.5, 97), (CX - 4.5, 120), (CX - 4, 142), (CX - 5, 150)],
    [(CX + 3.5, 97), (CX + 4.5, 120), (CX + 4, 142), (CX + 5, 150)],
]
LEG_R = (4.0, 2.6)
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


def width_at(outline, y):
    xs = []
    for (x0, y0), (x1, y1) in zip(outline, outline[1:] + outline[:1]):
        if (y0 - y) * (y1 - y) <= 0 and y0 != y1:
            xs.append(x0 + (x1 - x0) * (y - y0) / (y1 - y0))
    return min(xs), max(xs)


def creature():
    im, draw = layer()
    for strand in STRANDS:
        stroke(draw, spline(strand), *STRAND_R)
    outline = spline(SACK, closed=True)
    draw.polygon([(x * SS, y * SS) for x, y in outline], fill=255)
    for y, k in RIBS:
        left, right = width_at(outline, y)
        half = (right - left) / 2 * k
        rib = [(CX - half + 2 * half * i / 20, y + RIB_SAG * math.sin(math.pi * i / 20)) for i in range(21)]
        stroke(draw, rib, RIB_WIDTH, RIB_WIDTH, 0)
    for x, y in TEETH:
        draw.polygon([((CX + x - TOOTH[0]) * SS, (y - 1) * SS), ((CX + x + TOOTH[0]) * SS, (y - 1) * SS),
                      ((CX + x) * SS, (y + TOOTH[1]) * SS)], fill=255)
    for limb in LEGS:
        stroke(draw, spline(limb), *LEG_R)
    draw.polygon([(x * SS, y * SS) for x, y in spline(TORSO, closed=True)], fill=255)
    for limb in ARMS:
        stroke(draw, spline(limb), *ARM_R)
    stroke(draw, NECK, 3, 3)
    dot(draw, *HEAD)
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
    bg.paste(Image.new("RGB", alpha.size, INK), ((SIZE - alpha.width) // 2, TOP), alpha)
    return bg


if __name__ == "__main__":
    icon = tile(creature().resize((W * 2, H * 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.3)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.save(OUT, optimize=True)
    print("materials/entities/evil_barnacle.png  %dx%d" % icon.size)
    os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
    icon.resize((SIZE * 3, SIZE * 3), Image.LANCZOS).save(PREVIEW)
