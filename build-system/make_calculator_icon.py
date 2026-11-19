"""Render the calculator app icon used by the disguise.

The output is a full-bleed 1024x1024 PNG consumed by
Telegram/Telegram-iOS/Telegram.icon/Assets/Calculator.png (Icon Composer masks
the shape itself, so the artwork covers the whole canvas).

Usage:
    python3 build-system/make_calculator_icon.py
"""

import pathlib

from PIL import Image, ImageDraw

SIZE = 1024
BACKGROUND = (17, 17, 20, 255)
BODY = (216, 216, 220, 255)
DISPLAY = (28, 28, 30, 255)
DISPLAY_TEXT = (120, 200, 120, 255)
KEY = (58, 58, 60, 255)
OPERATOR = (255, 159, 10, 255)

OUTPUT = pathlib.Path(__file__).resolve().parent.parent / "Telegram" / "Telegram-iOS" / "Telegram.icon" / "Assets" / "Calculator.png"


def rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def main() -> int:
    image = Image.new("RGBA", (SIZE, SIZE), BACKGROUND)
    draw = ImageDraw.Draw(image)

    # Device body.
    body = (196, 148, 828, 884)
    rounded_rect(draw, body, 92, BODY)

    # Display.
    rounded_rect(draw, (242, 194, 782, 330), 30, DISPLAY)
    draw.rectangle((560, 236, 748, 262), fill=(232, 232, 234, 255))
    draw.rectangle((620, 278, 748, 296), fill=(120, 120, 124, 255))

    # Keypad: four rows, four columns, the last column is the operator column.
    diameter = 78
    gap = 40
    columns = 4
    rows = 4
    grid_width = columns * diameter + (columns - 1) * gap
    grid_height = rows * diameter + (rows - 1) * gap
    start_x = (SIZE - grid_width) // 2
    start_y = 384 + (432 - grid_height) // 2

    for row in range(rows):
        for column in range(columns):
            center_x = start_x + column * (diameter + gap) + diameter // 2
            center_y = start_y + row * (diameter + gap) + diameter // 2
            color = OPERATOR if column == columns - 1 else KEY
            draw.ellipse(
                (center_x - diameter // 2, center_y - diameter // 2, center_x + diameter // 2, center_y + diameter // 2),
                fill=color,
            )

    image.save(OUTPUT, format="PNG")
    print("wrote", OUTPUT, image.size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
