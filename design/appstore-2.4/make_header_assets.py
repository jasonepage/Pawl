#!/usr/bin/env python3
"""Build Pawl's App Store 2.4 header and search-results artwork."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
KIKI = ROOT / "design/fido-first/unlock-art/locked-v1.png"

GREEN = "#173D0B"
GREEN_DARK = "#0A2107"
GREEN_LIGHT = "#A9DB68"
IVORY = "#FFF4D2"
MUTED = "#C8D6B1"
GOLD = "#F1B632"
FONT_ROUNDED = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
FONT_BODY = "/System/Library/Fonts/Avenir Next.ttc"


def font(path: str, size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size, index=index)


def fit_inside(image: Image.Image, box: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(box, Image.Resampling.LANCZOS)
    return copy


def add_glow(canvas: Image.Image, art: Image.Image, xy: tuple[int, int], radius: int) -> None:
    alpha = art.getchannel("A")
    glow = Image.new("RGBA", art.size, (169, 219, 104, 0))
    glow.putalpha(alpha.filter(ImageFilter.GaussianBlur(radius)))
    canvas.alpha_composite(glow, (xy[0], xy[1] + radius // 3))


def pill(draw: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], text: str) -> None:
    draw.rounded_rectangle(xy, radius=(xy[3] - xy[1]) // 2, fill="#254F13", outline="#497D2D", width=4)
    label_font = font(FONT_BODY, 50, 1)
    draw.text(((xy[0] + xy[2]) // 2, (xy[1] + xy[3]) // 2), text,
              font=label_font, fill=GREEN_LIGHT, anchor="mm")


def header() -> None:
    w, h = 3840, 1646
    canvas = Image.new("RGBA", (w, h), GREEN)
    draw = ImageDraw.Draw(canvas)

    # Quiet depth without weakening thumbnail contrast.
    draw.ellipse((2580, -760, 4300, 980), fill="#204E13")
    draw.ellipse((-950, 1070, 1480, 2640), fill=GREEN_DARK)

    # App Store's iPhone product page center-crops this wide asset. Keep every
    # essential element inside the middle 70%, rather than using the outer edges.
    x = 590
    draw.text((x, 260), "PAWL", font=font(FONT_BODY, 58, 1), fill=GREEN_LIGHT)
    draw.text((x, 420), "Block the app.", font=font(FONT_ROUNDED, 205), fill=IVORY)
    draw.text((x, 650), "Hide the key.", font=font(FONT_ROUNDED, 205), fill=IVORY)
    draw.text((x, 965), "A physical key starts the wait.",
              font=font(FONT_BODY, 60, 1), fill=MUTED)
    draw.text((x, 1045), "Apps relock on their own.",
              font=font(FONT_BODY, 60, 1), fill=MUTED)
    pill(draw, (x, 1180, x + 520, 1298), "15 MIN WAIT")
    pill(draw, (x + 555, 1180, x + 1180, 1298), "AUTO-RELOCK")

    art = fit_inside(Image.open(KIKI).convert("RGBA"), (1260, 900))
    art_xy = (w - art.width - 490, h - art.height - 75)
    add_glow(canvas, art, art_xy, 48)
    canvas.alpha_composite(art, art_xy)

    canvas.convert("RGB").save(OUT / "header-3840x1646.png", quality=95)


def search() -> None:
    w, h = 1920, 1280
    canvas = Image.new("RGBA", (w, h), GREEN)
    draw = ImageDraw.Draw(canvas)

    draw.ellipse((1040, -520, 2180, 620), fill="#204E13")
    draw.ellipse((-500, 870, 980, 1750), fill=GREEN_DARK)

    # Keep all important content inside a generous safe area for search crops.
    art = fit_inside(Image.open(KIKI).convert("RGBA"), (780, 520))
    art_xy = ((w - art.width) // 2, 28)
    add_glow(canvas, art, art_xy, 34)
    canvas.alpha_composite(art, art_xy)

    draw.text((w // 2, 610), "Block the app.", font=font(FONT_ROUNDED, 168), fill=IVORY, anchor="mm")
    draw.text((w // 2, 800), "Hide the key.", font=font(FONT_ROUNDED, 168), fill=IVORY, anchor="mm")
    draw.text((w // 2, 1010), "15 MIN WAIT  •  AUTO-RELOCK", font=font(FONT_BODY, 56, 1),
              fill=GREEN_LIGHT, anchor="mm")
    draw.rounded_rectangle((740, 1100, 1180, 1114), radius=7, fill=GOLD)

    canvas.convert("RGB").save(OUT / "search-1920x1280.png", quality=95)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    header()
    search()

