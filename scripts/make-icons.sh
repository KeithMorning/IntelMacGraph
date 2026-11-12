#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
iconset="$(pwd)/build/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" Resources/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
# Package the PNG representations directly; iconutil's encoder is unavailable
# in some sandboxed build sessions. ICNS stores each representation as a chunk.
python3 scripts/pack-icons.py "$iconset" build/AppIcon.icns
