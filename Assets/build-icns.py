#!/usr/bin/env python3
"""Build AppIcon.icns from the source artwork Assets/Bezel.png.

Pipeline: resize the source into every iconset size (LANCZOS), encode each
PNG losslessly with zlib level 9 + adaptive filtering (pixel data verified
against the freshly resized original), then pack AppIcon.icns directly from
those PNGs using standard modern type codes — avoiding iconutil's lossy
JPEG2000 encoding for large sizes.

Usage: python3 Assets/build-icns.py   (after replacing Assets/Bezel.png)
"""
import io
import os
import struct

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ICONSET = os.path.join(HERE, "AppIcon.iconset")
ICNS = os.path.join(HERE, "AppIcon.icns")
SRC = os.path.join(HERE, "Bezel.png")

# (iconset PNG, icns chunk type, edge length in px)
ENTRIES = [
    ("icon_16x16.png", "icp4", 16),
    ("icon_16x16@2x.png", "ic11", 32),
    ("icon_32x32.png", "icp5", 32),
    ("icon_32x32@2x.png", "ic12", 64),
    ("icon_128x128.png", "ic07", 128),
    ("icon_128x128@2x.png", "ic13", 256),
    ("icon_256x256.png", "ic08", 256),
    ("icon_256x256@2x.png", "ic14", 512),
    ("icon_512x512.png", "ic09", 512),
    ("icon_512x512@2x.png", "ic10", 1024),
]


def encode_lossless(img: Image.Image, icc: bytes | None) -> bytes:
    """Re-encode losslessly (zlib 9 + adaptive filter), pixel-verified."""
    expected = img.tobytes()
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True, icc_profile=icc)
    check = Image.open(io.BytesIO(buf.getvalue()))
    assert check.size == img.size and check.mode == img.mode
    assert check.tobytes() == expected, "PNG encoding was not lossless!"
    return buf.getvalue()


def render_iconset() -> None:
    src = Image.open(SRC)
    icc = src.info.get("icc_profile")
    for fname, _code, px in ENTRIES:
        resized = src.resize((px, px), Image.LANCZOS)
        data = encode_lossless(resized, icc)
        with open(os.path.join(ICONSET, fname), "wb") as f:
            f.write(data)
        print(f"  {fname}: {px}px, {len(data)} bytes")


def pack_icns() -> None:
    chunks = b""
    for fname, code, _px in ENTRIES:
        with open(os.path.join(ICONSET, fname), "rb") as f:
            data = f.read()
        chunks += code.encode("ascii") + struct.pack(">I", len(data) + 8) + data
    icns = b"icns" + struct.pack(">I", len(chunks) + 8) + chunks
    with open(ICNS, "wb") as f:
        f.write(icns)
    print(f"  AppIcon.icns: {len(icns)} bytes (all PNG entries, lossless)")


if __name__ == "__main__":
    render_iconset()
    pack_icns()
