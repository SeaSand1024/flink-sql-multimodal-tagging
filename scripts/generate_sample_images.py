#!/usr/bin/env python3
"""generate_sample_images.py — paint 3 simple PNGs (one per event) and print
their Base64 data URLs. Use the printed URLs to replace PLACEHOLDER_Ex tokens
in data/events.json when you want distinct, reproducible local image fixtures.

Usage:  python3 scripts/generate_sample_images.py [out_dir]
"""
import base64
import io
import os
import sys
import struct
import zlib

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "data", "images")


def _png(width: int, height: int, pixel_rows: "list[bytes]") -> bytes:
    """Minimal PNG encoder (RGBA)."""
    def chunk(tag: bytes, data: bytes) -> bytes:
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    raw = b"".join(b"\x00" + row for row in pixel_rows)
    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def _solid(rgba: "tuple[int,int,int,int]", w: int = 64, h: int = 64) -> bytes:
    row = bytes(rgba) * w
    return _png(w, h, [row] * h)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    fixtures = {
        "e1": (40, 120, 90, 255),   # green-ish -> outdoor
        "e2": (60, 60, 200, 255),   # blue-ish  -> tech
        "e3": (230, 180, 200, 255), # pink-ish  -> skincare
    }
    for name, rgba in fixtures.items():
        data = _solid(rgba)
        path = os.path.join(OUT, f"{name}.png")
        with open(path, "wb") as f:
            f.write(data)
        b64 = base64.b64encode(data).decode("ascii")
        print(f"[*] wrote {path} ({len(data)} bytes)")
        print(f"[*] {name} data-url:\n  data:image/png;base64,{b64}")


if __name__ == "__main__":
    main()