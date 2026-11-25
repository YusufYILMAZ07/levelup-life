#!/usr/bin/env python3
"""CEYYUS marka görsellerini üretir (ikon + açılış ekranı).

Tasarım: koyu erik/indigo zemin üzerinde gül gradyanlı kalp, içinde beyaz
"CY" monogramı ve sağ üstte altın "seviye kıvılcımı". Harici font veya varlık
kullanmaz; tüm şekiller vektörel çizilir (Pillow ≥ 10).

Kullanım:
    python3 tool/generate_ceyyus_icon.py
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create

Çıktılar (assets/icon/):
    ceyyus_icon.png             1024×1024, opak (mağaza / legacy launcher)
    ceyyus_icon_foreground.png  1024×1024, şeffaf (adaptive foreground)
    ceyyus_icon_monochrome.png  1024×1024, şeffaf (adaptive monochrome)
    ceyyus_splash.png           1152×1152, şeffaf (Android 12 / iOS splash)
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "icon")

INK_TOP = (27, 16, 51)  # #1B1033
INK_BOTTOM = (14, 9, 28)  # #0E091C
ROSE_LIGHT = (251, 113, 133)  # #FB7185
ROSE_DARK = (190, 18, 60)  # #BE123C
GOLD_LIGHT = (253, 230, 138)  # #FDE68A
INDIGO = (99, 102, 241)  # #6366F1
WHITE = (255, 255, 255)

SS = 2  # süper örnekleme (anti-aliasing)


def gradient(size: tuple[int, int], top: tuple[int, int, int],
             bottom: tuple[int, int, int]) -> Image.Image:
    """Dikey iki renkli gradyan (üst → alt)."""
    g = Image.linear_gradient("L").resize(size, Image.LANCZOS)
    return Image.composite(Image.new("RGB", size, bottom),
                           Image.new("RGB", size, top), g)


def radial_glow(size: tuple[int, int], center: tuple[float, float],
                radius: float, color: tuple[int, int, int],
                peak: int) -> Image.Image:
    """Yumuşak radyal ışıma katmanı (RGBA)."""
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).ellipse(
        [center[0] - radius, center[1] - radius,
         center[0] + radius, center[1] + radius],
        fill=peak,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(radius * 0.55))
    layer = Image.new("RGBA", size, color + (0,))
    layer.putalpha(mask)
    return layer


def heart_points(cx: float, cy: float, width: float,
                 height: float, steps: int = 720) -> list[tuple[float, float]]:
    """Parametrik kalp eğrisini hedef kutuya oturtur."""
    raw: list[tuple[float, float]] = []
    for i in range(steps):
        t = 2.0 * math.pi * i / steps
        x = 16.0 * math.sin(t) ** 3
        y = (13.0 * math.cos(t) - 5.0 * math.cos(2 * t)
             - 2.0 * math.cos(3 * t) - math.cos(4 * t))
        raw.append((x, y))
    xs = [p[0] for p in raw]
    ys = [p[1] for p in raw]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    sx = width / (max_x - min_x)
    sy = height / (max_y - min_y)
    mid_x = (min_x + max_x) / 2.0
    mid_y = (min_y + max_y) / 2.0
    return [(cx + (x - mid_x) * sx, cy - (y - mid_y) * sy) for x, y in raw]


def star_points(cx: float, cy: float, outer: float, inner: float,
                tips: int = 4) -> list[tuple[float, float]]:
    """Dört uçlu 'seviye kıvılcımı' (yukarı bakan)."""
    pts: list[tuple[float, float]] = []
    for i in range(tips * 2):
        radius = outer if i % 2 == 0 else inner
        angle = -math.pi / 2.0 + math.pi * i / tips
        pts.append((cx + radius * math.cos(angle),
                    cy + radius * math.sin(angle)))
    return pts


def _stroke(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]],
            color: tuple[int, int, int, int], width: int) -> None:
    """Yuvarlak uçlu ve eklemli çizgi."""
    draw.line(pts, fill=color, width=width, joint="curve")
    r = width / 2.0
    for x, y in (pts[0], pts[-1]):
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def draw_monogram(layer: Image.Image, cx: float, cy: float, width: float,
                  height: float, color: tuple[int, int, int, int]) -> None:
    """Kalbin içine 'CY' monogramını çizer (font gerektirmez)."""
    draw = ImageDraw.Draw(layer)
    stroke = max(6, int(round(width * 0.072)))
    cap = height * 0.27
    top = cy - cap * 0.52
    bottom = cy + cap * 0.60

    # C: sağa açık yay (55° → 305°, sol yarım daire üzerinden).
    c_cx = cx - width * 0.135
    c_cy = cy - cap * 0.02
    radius = cap * 0.46
    arc: list[tuple[float, float]] = []
    for i in range(49):
        angle = math.radians(55.0 + 250.0 * i / 48.0)
        arc.append((c_cx + radius * math.cos(angle),
                    c_cy + radius * math.sin(angle)))
    _stroke(draw, arc, color, stroke)

    # Y: iki kol + gövde.
    y_cx = cx + width * 0.145
    arm = cap * 0.44
    joint_y = cy - cap * 0.04
    for start_x in (y_cx - arm * 0.72, y_cx + arm * 0.72):
        _stroke(draw, [(start_x, top), (y_cx, joint_y)], color, stroke)
    _stroke(draw, [(y_cx, joint_y - stroke * 0.15),
                   (y_cx, bottom - cap * 0.06)], color, stroke)


def emblem(size: tuple[int, int], center: tuple[float, float],
           width: float, *, monochrome: bool = False) -> Image.Image:
    """Şeffaf zemin üzerinde kalp + CY + kıvılcım amblemi."""
    w, h = size
    cx, cy = center
    heart_h = width * 0.94
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    points = heart_points(cx, cy, width, heart_h)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)

    if monochrome:
        silhouette = Image.new("RGBA", size, WHITE + (255,))
        silhouette.putalpha(mask)
        canvas.alpha_composite(silhouette)
        spark_c = (cx + width * 0.46, cy - heart_h * 0.40)
        ImageDraw.Draw(canvas).polygon(
            star_points(*spark_c, width * 0.13, width * 0.034),
            fill=WHITE + (255,))
        return canvas

    # Kalp gövdesi: gül gradyanı.
    body = gradient(size, ROSE_LIGHT, ROSE_DARK).convert("RGBA")
    body.putalpha(mask)
    canvas.alpha_composite(body)

    # Üst ışık: hacim hissi (kalp maskesiyle sınırlı).
    highlight = Image.new("RGBA", size, (255, 255, 255, 0))
    ImageDraw.Draw(highlight).ellipse(
        [cx - width * 0.46, cy - heart_h * 0.56,
         cx + width * 0.18, cy - heart_h * 0.02],
        fill=(255, 255, 255, 58))
    highlight = highlight.filter(ImageFilter.GaussianBlur(width * 0.045))
    highlight.putalpha(Image.composite(highlight.getchannel("A"),
                                       Image.new("L", size, 0), mask))
    canvas.alpha_composite(highlight)

    # İnce kenar ışığı.
    rim = Image.new("RGBA", size, (255, 255, 255, 0))
    ImageDraw.Draw(rim).line(points + [points[0]],
                             fill=(255, 228, 230, 90),
                             width=max(2, int(width * 0.010)))
    canvas.alpha_composite(rim)

    draw_monogram(canvas, cx, cy - heart_h * 0.02, width, heart_h,
                  (255, 255, 255, 236))

    # Kıvılcım: yumuşak altın ışıma + keskin yıldız.
    spark_c = (cx + width * 0.46, cy - heart_h * 0.40)
    outer = width * 0.145
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).polygon(
        star_points(*spark_c, outer * 1.35, outer * 0.34),
        fill=GOLD_LIGHT + (150,))
    canvas.alpha_composite(
        glow.filter(ImageFilter.GaussianBlur(width * 0.030)))

    spark = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(spark)
    sd.polygon(star_points(*spark_c, outer, outer * 0.24),
               fill=GOLD_LIGHT + (255,))
    sd.polygon(star_points(*spark_c, outer * 0.62, outer * 0.15),
               fill=(255, 255, 255, 235))
    canvas.alpha_composite(spark)

    # Küçük ikinci kıvılcım (sol üst) kompozisyonu dengeler.
    ImageDraw.Draw(canvas).polygon(
        star_points(cx - width * 0.52, cy - heart_h * 0.46,
                    width * 0.055, width * 0.014),
        fill=GOLD_LIGHT + (210,))
    return canvas


def launcher_icon(px: int) -> Image.Image:
    """Opak, tam kanamalı mağaza ikonu."""
    size = (px * SS, px * SS)
    w, h = size
    base = gradient(size, INK_TOP, INK_BOTTOM).convert("RGBA")
    base.alpha_composite(radial_glow(size, (w * 0.50, h * 0.46), w * 0.44,
                                     (225, 29, 72), 96))
    base.alpha_composite(radial_glow(size, (w * 0.90, h * 0.10), w * 0.38,
                                     INDIGO, 92))
    base.alpha_composite(radial_glow(size, (w * 0.08, h * 0.92), w * 0.30,
                                     (59, 130, 246), 58))
    base.alpha_composite(emblem(size, (w * 0.5, h * 0.48), w * 0.58))
    return base.convert("RGB").resize((px, px), Image.LANCZOS)


def transparent_emblem(px: int, scale: float) -> Image.Image:
    """Şeffaf zemin üzerinde ortalanmış amblem (adaptive / splash)."""
    size = (px * SS, px * SS)
    art = emblem(size, (size[0] / 2.0, size[1] / 2.0), size[0] * scale)
    return art.resize((px, px), Image.LANCZOS)


def monochrome(px: int, scale: float) -> Image.Image:
    """Tema tarafından renklendirilen tek renkli adaptive ikon."""
    size = (px * SS, px * SS)
    art = emblem(size, (size[0] / 2.0, size[1] / 2.0), size[0] * scale,
                 monochrome=True)
    return art.resize((px, px), Image.LANCZOS)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    outputs: dict[str, Image.Image] = {
        "ceyyus_icon.png": launcher_icon(1024),
        "ceyyus_icon_foreground.png": transparent_emblem(1024, 0.52),
        "ceyyus_icon_monochrome.png": monochrome(1024, 0.52),
        # Android 12 splash: ikon 1152'nin ortasındaki 640'lık daireye sığar.
        "ceyyus_splash.png": transparent_emblem(1152, 0.46),
    }
    for name, image in outputs.items():
        path = os.path.join(OUT_DIR, name)
        image.save(path, "PNG", optimize=True)
        print(f"✓ {os.path.relpath(path, ROOT)} · "
              f"{image.width}×{image.height}")


if __name__ == "__main__":
    main()


