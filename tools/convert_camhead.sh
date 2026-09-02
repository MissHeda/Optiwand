#!/usr/bin/env bash
# Convert the baked camera attachment textures to PAA.
#
# Order of operations: run tools/blender_camhead.py in Blender first - that writes the PNGs
# to art/esdcam - then this script. The p3d already points at the PAA names, so nothing else
# needs adjusting.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# ImageToPAA ships with the Arma 3 Tools. Set IMAGETOPAA if yours lives somewhere the
# search below does not cover.
PAA="${IMAGETOPAA:-}"
if [ -z "$PAA" ]; then
    for drive in C D E F; do
        for lib in "Steam" "SteamLibrary" "Program Files (x86)/Steam"; do
            cand="$drive:/$lib/steamapps/common/Arma 3 Tools/ImageToPAA/ImageToPAA.exe"
            [ -f "$cand" ] && PAA="$cand" && break 2
        done
    done
fi

if [ ! -f "$PAA" ]; then
    echo "ImageToPAA not found." >&2
    echo 'Set IMAGETOPAA to its full path, e.g.' >&2
    echo '  IMAGETOPAA="C:/SteamLibrary/steamapps/common/Arma 3 Tools/ImageToPAA/ImageToPAA.exe"' >&2
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
