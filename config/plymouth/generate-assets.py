#!/usr/bin/env python3
"""Render the PNG assets for the `obsidian` Plymouth theme.

Everything is authored against a 2160p reference and scaled *down* at runtime by
obsidian.script, because downscaling stays crisp where upscaling goes soft. The one
exception is bloom.png: a wide gaussian has no edges to lose, so it ships small
and is scaled up, which keeps it out of the initramfs at full size.

Run after changing any text or colour, then rebuild the initramfs:

    ./generate-assets.py && sudo plymouth-set-default-theme -R obsidian
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "obsidian")

# Near-black ground with a violet accent; the danger colour is reused for a
# failed passphrase.
BG = (0x0d, 0x11, 0x17)
BG_DARK = (0x01, 0x04, 0x09)
FG = (0xe6, 0xed, 0xf3)
MUTED = (0x62, 0x72, 0xa4)
ACCENT = (0xbd, 0x93, 0xf9)
DANGER = (0xff, 0x6b, 0x7a)
TRACK = (0x22, 0x27, 0x2e)

F = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-{}.ttf"

# Deliberately impersonal: this repository is public, so no username is baked
# into the boot screen. The second half is drawn in the accent colour.
GREETING_LEAD = "Arch "
GREETING_ACCENT = "Linux"
SUBTITLE = "ENTER YOUR LUKS PASSPHRASE"
RETRY = "WRONG PASSPHRASE  ·  TRY AGAIN"

SS = 4  # supersampling factor for the shapes, which have no other antialiasing


def font(weight, size):
    return ImageFont.truetype(F.format(weight), size)


def measure(string, f, track=0):
    d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    if not track:
        box = d.textbbox((0, 0), string, font=f)
        return box[2], box[3]
    w = sum(d.textbbox((0, 0), c, font=f)[2] + track for c in string) - track
    return w, max(d.textbbox((0, 0), c, font=f)[3] for c in string)


def tracked_text(string, f, fill, track, pad=20):
    """Letterspaced text on its own transparent canvas."""
    w, h = measure(string, f, track)
    img = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = pad
    for c in string:
        d.text((x, pad), c, font=f, fill=fill)
        x += d.textbbox((0, 0), c, font=f)[2] + track
    return img


def greeting():
    """Two weights, two colours, one image: the lead light, the second half accented."""
    f_lead, f_name = font("ExtraLight", 184), font("Medium", 184)
    lw, _ = measure(GREETING_LEAD, f_lead)
    nw, _ = measure(GREETING_ACCENT, f_name)
    pad = 40
    img = Image.new("RGBA", (lw + nw + pad * 2, 300), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((pad, pad), GREETING_LEAD, font=f_lead, fill=FG)
    d.text((pad + lw, pad), GREETING_ACCENT, font=f_name, fill=ACCENT)
    return img


def pill(outline):
    """Rounded passphrase field, supersampled so the corners are smooth."""
    w, h, stroke = 920, 136, 4
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        [0, 0, w * SS - 1, h * SS - 1], radius=h * SS // 2,
        fill=BG_DARK + (255,), outline=outline + (255,), width=stroke * SS)
    return img.resize((w, h), Image.LANCZOS)


def dot(color, size=28):
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse([0, 0, size * SS - 1, size * SS - 1], fill=color + (255,))
    return img.resize((size, size), Image.LANCZOS)


def bloom(size=640, peak=34):
    """Deliberately small: obsidian.script scales this up, and a blur has no edges to lose.

    The falloff is computed per pixel rather than drawn as stacked ellipses, which
    banded visibly once scaled to full screen.
    """
    y, x = np.ogrid[:size, :size]
    r = np.hypot(x - (size - 1) / 2, y - (size - 1) / 2) / (size / 2)
    alpha = np.clip(1 - r, 0, 1) ** 2.4 * peak

    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[..., 0], img[..., 1], img[..., 2] = ACCENT
    img[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(img, "RGBA").filter(ImageFilter.GaussianBlur(size / 40))


def rule(color, w=920, h=4):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).rectangle([0, 0, w - 1, h - 1], fill=color + (255,))
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    assets = {
        "greeting": greeting(),
        "subtitle": tracked_text(SUBTITLE, font("Light", 50), MUTED, 10),
        "retry": tracked_text(RETRY, font("Light", 50), DANGER, 10),
        "field": pill(ACCENT),
        "field_error": pill(DANGER),
        "dot": dot(ACCENT),
        "bloom": bloom(),
        "progress_track": rule(TRACK),
        "progress_bar": rule(ACCENT),
    }
    for name, img in assets.items():
        path = os.path.join(OUT, f"{name}.png")
        img.save(path)
        print(f"{name}.png  {img.size[0]}x{img.size[1]}  {os.path.getsize(path)}B")
