#!/usr/bin/env python3
"""CEYYUS web / iOS PWA ikonlarını tek kaynaktan üretir.

Kaynak: assets/icon/ceyyus_icon.png (1024×1024, opak)
Çıktılar (web/):
    icons/apple-touch-icon.png   180×180  (iOS Ana Ekrana Ekle)
    icons/Icon-192.png           192×192  (manifest "any")
    icons/Icon-512.png           512×512  (manifest "any")
    icons/Icon-maskable-192.png  192×192  (manifest "maskable")
    icons/Icon-maskable-512.png  512×512  (manifest "maskable")
    favicon.png                   64×64   (tarayıcı sekmesi)

Maskable ikonlar, Android/iOS maskeleme güvenli alanı için %8 iç boşlukla
gece mavisi (#0B1124) zemin üzerine yeniden yerleştirilir. Diğer ikonlar
tam kanamalı kaynaktan LANCZOS ile küçültülür (keskin, opak).

Kullanım:
    python3 tools/generate_web_icons.py
"""

from __future__ import annotations

import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "icon", "ceyyus_icon.png")
WEB_DIR = os.path.join(ROOT, "web")
ICON_DIR = os.path.join(WEB_DIR, "icons")

BACKGROUND = (11, 17, 36)  # #0B1124 gece mavisi
MASKABLE_INSET = 0.08  # her kenarda %8 güvenli alan


def load_source() -> Image.Image:
    if not os.path.exists(SOURCE):
        raise SystemExit(
            f"Kaynak ikon bulunamadı: {SOURCE}\n"
            "Önce `python3 tool/generate_ceyyus_icon.py` çalıştırın."
        )
    image = Image.open(SOURCE).convert("RGB")
    if image.width != image.height:
        raise SystemExit("Kaynak ikon kare olmalı (1024×1024).")
    return image


def resized(source: Image.Image, size: int) -> Image.Image:
    return source.resize((size, size), Image.LANCZOS)


def maskable(source: Image.Image, size: int) -> Image.Image:
    """Tam kanamalı arka plan + ortada güvenli alana sığan amblem."""
    canvas = Image.new("RGB", (size, size), BACKGROUND)
    inner_size = max(1, int(round(size * (1.0 - 2.0 * MASKABLE_INSET))))
    inset = (size - inner_size) // 2
    canvas.paste(resized(source, inner_size), (inset, inset))
    return canvas


def main() -> None:
    os.makedirs(ICON_DIR, exist_ok=True)
    source = load_source()

    outputs: dict[str, Image.Image] = {
        os.path.join(ICON_DIR, "apple-touch-icon.png"): resized(source, 180),
        os.path.join(ICON_DIR, "Icon-192.png"): resized(source, 192),
        os.path.join(ICON_DIR, "Icon-512.png"): resized(source, 512),
        os.path.join(ICON_DIR, "Icon-maskable-192.png"): maskable(source, 192),
        os.path.join(ICON_DIR, "Icon-maskable-512.png"): maskable(source, 512),
        os.path.join(WEB_DIR, "favicon.png"): resized(source, 64),
    }

    for path, image in outputs.items():
        image.save(path, "PNG", optimize=True)
        print(
            f"✓ {os.path.relpath(path, ROOT)} · "
            f"{image.width}×{image.height}"
        )


if __name__ == "__main__":
    main()
