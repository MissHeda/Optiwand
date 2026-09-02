#!/usr/bin/env bash
# Convert the baked camera attachment textures to PAA.
#
# Order of operations: run tools/blender_camhead.py in Blender first - that writes the PNGs
# to art/esdcam - then this script. The p3d already points at the PAA names, so nothing else
# needs adjusting.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAA="D:/Steam/steamapps/common/Arma 3 Tools/ImageToPAA/ImageToPAA.exe"

if [ ! -f "$PAA" ]; then
    echo "ImageToPAA not found: $PAA" >&2
    echo "Adjust the path above if the Arma 3 Tools live somewhere else." >&2
    exit 1
fi

for name in co nohq; do
    src="$ROOT/art/esdcam/camhead_$name.png"
    dst="$ROOT/addons/esdcam/data/camhead_$name.paa"
    if [ ! -f "$src" ]; then
        echo "missing, skipped: $src"
        continue
    fi
    "$PAA" "$src" "$dst" >/dev/null 2>&1
    printf '%-16s -> %s KB\n' "camhead_$name" "$(( $(stat -c%s "$dst") / 1024 ))"
done
