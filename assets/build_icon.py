#!/usr/bin/env python3
"""Build the multi-resolution Windows ICO from the generated RGBA PNG.

Uses only Python's standard library so the asset can be regenerated without
Pillow or other third-party packages.
"""

from __future__ import annotations

import math
import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parent
SOURCE = ROOT / "FBConsole-app-icon-layered.png"
OUTPUT = ROOT / "FBConsole.ico"
PREVIEW = ROOT / "FBConsole-app-icon-preview.png"
SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)


def read_rgba_png(path: pathlib.Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Input must be a PNG")
    pos, width, height, bit_depth, color_type, interlace = 8, 0, 0, 0, 0, 0
    compressed = bytearray()
    while pos < len(data):
        length = struct.unpack_from(">I", data, pos)[0]
        kind = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break
    if bit_depth != 8 or color_type != 6 or interlace != 0:
        raise ValueError("Expected non-interlaced 8-bit RGBA PNG")

    raw = zlib.decompress(compressed)
    stride = width * 4
    pixels = bytearray(height * stride)
    source_pos = 0
    prior = bytearray(stride)
    for y in range(height):
        filter_type = raw[source_pos]
        source_pos += 1
        row = bytearray(raw[source_pos : source_pos + stride])
        source_pos += stride
        for x in range(stride):
            left = row[x - 4] if x >= 4 else 0
            above = prior[x]
            upper_left = prior[x - 4] if x >= 4 else 0
            if filter_type == 1:
                row[x] = (row[x] + left) & 255
            elif filter_type == 2:
                row[x] = (row[x] + above) & 255
            elif filter_type == 3:
                row[x] = (row[x] + ((left + above) >> 1)) & 255
            elif filter_type == 4:
                p = left + above - upper_left
                pa, pb, pc = abs(p - left), abs(p - above), abs(p - upper_left)
                predictor = left if pa <= pb and pa <= pc else above if pb <= pc else upper_left
                row[x] = (row[x] + predictor) & 255
            elif filter_type != 0:
                raise ValueError(f"Unsupported PNG filter {filter_type}")
        pixels[y * stride : (y + 1) * stride] = row
        prior = row
    return width, height, bytes(pixels)


def resize_rgba(src: bytes, sw: int, sh: int, size: int) -> bytes:
    out = bytearray(size * size * 4)
    for y in range(size):
        fy = (y + 0.5) * sh / size - 0.5
        y0 = max(0, min(sh - 1, math.floor(fy)))
        y1 = min(sh - 1, y0 + 1)
        wy = max(0.0, min(1.0, fy - y0))
        for x in range(size):
            fx = (x + 0.5) * sw / size - 0.5
            x0 = max(0, min(sw - 1, math.floor(fx)))
            x1 = min(sw - 1, x0 + 1)
            wx = max(0.0, min(1.0, fx - x0))
            samples = (
                (y0 * sw + x0, (1 - wx) * (1 - wy)),
                (y0 * sw + x1, wx * (1 - wy)),
                (y1 * sw + x0, (1 - wx) * wy),
                (y1 * sw + x1, wx * wy),
            )
            alpha = sum(src[i * 4 + 3] * weight for i, weight in samples)
            out_i = (y * size + x) * 4
            out[out_i + 3] = round(alpha)
            for channel in range(3):
                premultiplied = sum(
                    src[i * 4 + channel] * src[i * 4 + 3] / 255 * weight
                    for i, weight in samples
                )
                out[out_i + channel] = (
                    round(premultiplied * 255 / alpha) if alpha > 0 else 0
                )
    return bytes(out)


def crop_to_square(src: bytes, width: int, height: int) -> tuple[int, bytes]:
    xs, ys = [], []
    for y in range(height):
        for x in range(width):
            if src[(y * width + x) * 4 + 3] > 8:
                xs.append(x)
                ys.append(y)
    if not xs:
        raise ValueError("The icon image has no visible pixels")
    left, right = min(xs), max(xs) + 1
    top, bottom = min(ys), max(ys) + 1
    crop_width, crop_height = right - left, bottom - top
    side = max(crop_width, crop_height)
    margin = max(2, round(side * 0.015))
    side += margin * 2
    square = bytearray(side * side * 4)
    x_offset = (side - crop_width) // 2
    y_offset = (side - crop_height) // 2
    for y in range(crop_height):
        source_start = ((top + y) * width + left) * 4
        target_start = ((y_offset + y) * side + x_offset) * 4
        square[target_start : target_start + crop_width * 4] = src[
            source_start : source_start + crop_width * 4
        ]
    return side, bytes(square)


def encode_png(size: int, rgba: bytes) -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)

    rows = b"".join(
        b"\0" + rgba[y * size * 4 : (y + 1) * size * 4] for y in range(size)
    )
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    width, height, original = read_rgba_png(SOURCE)
    if width != height:
        raise ValueError("App icon artwork must be square")
    width, rgba = crop_to_square(original, width, height)
    height = width
    PREVIEW.write_bytes(encode_png(512, resize_rgba(rgba, width, width, 512)))
    images = [encode_png(size, resize_rgba(rgba, width, height, size)) for size in SIZES]
    header_size = 6 + 16 * len(images)
    offset = header_size
    directory = bytearray(struct.pack("<HHH", 0, 1, len(images)))
    for size, image in zip(SIZES, images):
        directory.extend(
            struct.pack(
                "<BBBBHHII",
                0 if size == 256 else size,
                0 if size == 256 else size,
                0,
                0,
                1,
                32,
                len(image),
                offset,
            )
        )
        offset += len(image)
    OUTPUT.write_bytes(bytes(directory) + b"".join(images))
    print(f"Wrote {OUTPUT} ({len(images)} sizes, {OUTPUT.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()



