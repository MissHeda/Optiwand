#!/usr/bin/env bash
# Konvertiert die Quelltexturen aus art\optiwand nach addons\optiwand\data als PAA.
#
# Aufruf aus dem Repo-Wurzelverzeichnis:
#   bash tools/convert_textures.sh
#
# 4096x4096 ist fuer ein 40 cm langes Handgeraet masslos ueberdimensioniert - das sind vier
# Texturen, die im Speicher zusammen ueber 300 MB belegen wuerden. 2048 reicht dafuer
# vollkommen und man sieht keinen Unterschied. Ueber SIZE laesst sich das aendern.

set -euo pipefail

TOOL="/d/Steam/steamapps/common/Arma 3 Tools/ImageToPAA/ImageToPAA.exe"
SRC="art/optiwand"
DST="addons/optiwand/data"
SIZE=2048   # ImageToPAA macht daraus 1024 - fuer ein Handgeraet genau richtig

if [ ! -f "$TOOL" ]; then
    echo "ImageToPAA nicht gefunden unter:"
    echo "  $TOOL"
    echo "Pfad in diesem Skript anpassen."
    exit 1
fi

mkdir -p "$DST"

for stage in co nohq smdi as; do
    in="$SRC/mirrorgun_${stage}.png"
    out="$DST/mirrorgun_${stage}.paa"

    if [ ! -f "$in" ]; then
        echo "FEHLT: $in"
        continue
    fi

    "$TOOL" "-size=$SIZE" "$(cygpath -w "$in")" "$(cygpath -w "$out")" >/dev/null 2>&1 || true

    if [ -f "$out" ]; then
        printf '  %-24s %6d KB\n' "mirrorgun_${stage}.paa" "$(( $(stat -c%s "$out") / 1024 ))"
    else
        echo "  FEHLGESCHLAGEN: mirrorgun_${stage}.paa"
    fi
done

echo
echo "Gegenprobe mit HEMTT:"
for f in "$DST"/mirrorgun_*.paa; do
    printf '  %-24s ' "$(basename "$f")"
    hemtt utils paa inspect "$f" 2>&1 | tr '\n' ' ' | sed 's/  */ /g'
    echo
done
