#!/usr/bin/env python3
"""Pack PNG icon sizes into the standard macOS icns container."""

from pathlib import Path
from struct import pack
import sys

iconset = Path(sys.argv[1])
destination = Path(sys.argv[2])
entries = [
    (b"icp4", "icon_16x16.png"),
    (b"icp5", "icon_32x32.png"),
    (b"icp6", "icon_32x32@2x.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
]
chunks = []
for kind, filename in entries:
    image = (iconset / filename).read_bytes()
    if not image.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Invalid PNG: {filename}")
    chunks.append(kind + pack(">I", len(image) + 8) + image)
payload = b"".join(chunks)
destination.write_bytes(b"icns" + pack(">I", len(payload) + 8) + payload)
