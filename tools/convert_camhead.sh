#!/usr/bin/env bash
# Gebackene Texturen des Kameraaufsatzes nach PAA wandeln.
#
# Reihenfolge: erst tools/blender_camhead.py in Blender laufen lassen - das legt die PNGs
# unter art/esdcam ab -, danach dieses Skript. Die p3d zeigt bereits auf die PAA-Namen, es
# muss also nichts weiter angepasst werden.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAA="D:/Steam/steamapps/common/Arma 3 Tools/ImageToPAA/ImageToPAA.exe"

if [ ! -f "$PAA" ]; then
    echo "ImageToPAA nicht gefunden: $PAA" >&2
    echo "Pfad oben anpassen, falls die Arma 3 Tools woanders liegen." >&2
    exit 1
fi

for name in co nohq; do
    src="$ROOT/art/esdcam/camhead_$name.png"
    dst="$ROOT/addons/esdcam/data/camhead_$name.paa"
    if [ ! -f "$src" ]; then
        echo "fehlt, uebersprungen: $src"
        continue
    fi
    "$PAA" "$src" "$dst" >/dev/null 2>&1
    printf '%-16s -> %s KB\n' "camhead_$name" "$(( $(stat -c%s "$dst") / 1024 ))"
done
