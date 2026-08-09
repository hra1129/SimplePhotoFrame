#!/usr/bin/env python3
"""Convert SOFTWARE/resource/font.png to SOFTWARE/font.c (RGB565 array)."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def rgb888_to_rgb565(r: int, g: int, b: int) -> int:
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)


def build_font_c(image_path: Path, output_path: Path, symbol: str = "font") -> None:
    img = Image.open(image_path).convert("RGB")
    width, height = img.size

    raw = img.tobytes()
    values: list[int] = []
    for i in range(0, len(raw), 3):
        r = raw[i]
        g = raw[i + 1]
        b = raw[i + 2]
        values.append(rgb888_to_rgb565(r, g, b))

    lines: list[str] = []
    lines.append("// -----------------------------------------------------------------------------")
    lines.append("//\tfont.c")
    lines.append(f"//\tGenerated from {image_path.as_posix()}")
    lines.append(f"//\tBitmap size: {width}x{height} (row-major, RGB565)")
    lines.append("// -----------------------------------------------------------------------------")
    lines.append("")
    lines.append("#include <stdint.h>")
    lines.append("")
    lines.append(f"uint16_t const {symbol}[] = {{")

    per_line = 12
    for i in range(0, len(values), per_line):
        chunk = values[i : i + per_line]
        lines.append("    " + ", ".join(f"0x{v:04X}" for v in chunk) + ",")

    if len(values) > 0:
        lines[-1] = lines[-1][:-1]

    lines.append("};")
    lines.append("")

    output_path.write_text("\n".join(lines), encoding="ascii", newline="\n")


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    default_input = script_dir / "resource" / "font.png"
    default_output = script_dir / "font.c"

    parser = argparse.ArgumentParser(description="Convert font PNG to RGB565 C array.")
    parser.add_argument("--input", type=Path, default=default_input, help="Input PNG path")
    parser.add_argument("--output", type=Path, default=default_output, help="Output C path")
    parser.add_argument("--symbol", default="font", help="C symbol name")
    args = parser.parse_args()

    input_path = args.input.resolve()
    output_path = args.output.resolve()

    if not input_path.exists():
        raise FileNotFoundError(f"Input image not found: {input_path}")

    build_font_c(input_path, output_path, args.symbol)
    print(f"generated: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
