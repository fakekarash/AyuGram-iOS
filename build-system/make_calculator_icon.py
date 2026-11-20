"""Render the calculator app icon used by the disguise.

Matches the system Calculator icon: a light background, a dark calculator body
with a pale display and a 4x3 key grid whose last column is orange.

The output is a full-bleed 1024x1024 PNG consumed by
Telegram/Telegram-iOS/Telegram.icon/Assets/Calculator.png (Icon Composer masks
the shape itself, so the artwork covers the whole canvas).

Usage:
    python3 build-system/make_calculator_icon.py
"""

import pathlib

from PIL import Image, ImageDraw

SIZE = 1024
BACKGROUND_TOP = (255, 255, 255, 255)
BACKGROUND_BOTTOM = (238, 238, 242, 255)
BODY = (44, 44, 46, 255)
DISPLAY = (209, 209, 214, 255)
KEY = (229, 229, 234, 255)
OPERATOR = (255, 159, 10, 255)

OUTPUT = (
    pathlib.Path(__file__).resolve().parent.parent
    / "Telegram"
    / "Telegram-iOS"
    / "Telegram.icon"
    / "Assets"
    / "Calculator.png"
)


def main() -> int:
    image = Image.new("RGBA", (SIZE, SIZE), BACKGROUND_TOP)
    draw = ImageDraw.Draw(image)

    # Soft vertical gradient so the icon does not look flat beside system icons.
    for y in range(SIZE):
        factor = y / (SIZE - 1)
        color = tuple(
            round(BACKGROUND_TOP[channel] + (BACKGROUND_BOTTOM[channel] - BACKGROUND_TOP[channel]) * factor)
            for channel in range(3)
        )
        draw.line([(0, y), (SIZE, y)], fill=color + (255,))

    # Calculator body.
    body = (252, 178, 772, 846)
    draw.rounded_rectangle(body, radius=118, fill=BODY)

    # Display.
    draw.rounded_rectangle((304, 238, 720, 366), radius=32, fill=DISPLAY)

    # Key grid: three pale columns and one orange column.
    columns = 4
    rows = 3
    key_side = 84
    gap = 28
    grid_width = columns * key_side + (columns - 1) * gap
    start_x = (SIZE - grid_width) // 2
    start_y = 428

    for row in range(rows):
        for column in range(columns):
            x = start_x + column * (key_side + gap)
            y = start_y + row * (key_side + gap)
            color = OPERATOR if column == columns - 1 else KEY
            draw.rounded_rectangle((x, y, x + key_side, y + key_side), radius=24, fill=color)

    image.save(OUTPUT, format="PNG")
    print("wrote", OUTPUT, image.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
