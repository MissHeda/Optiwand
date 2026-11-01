# Optiwand - instructions for Claude

Arma 3 mod by Miss Heda (Mia): an inspection camera ("SD Inspection Camera") as a muzzle
attachment for the vanilla Spectrum Device. Work happens on branch `camera-model`
(13+ commits ahead of `main`, version 1.0.1, unreleased). Read `README.md` first - "The
model" section explains the whole model pipeline.

## Rules

- Chat with Mia in German. Everything in the repo is English: code, comments, commit
  messages, README, stringtables (`<English>` only, no other languages).
- Bump PATCH in `addons/main/script_version.hpp` with every round of bug fixes, unasked,
  unless it was already bumped since the last release (last release 1.0.0, now 1.0.1).
- Every answer that changed the mod ends with this block, which Mia clicks to test on her
  Windows machine (PowerShell: `;`, never `&&`):

  ```bash
  cd "C:\Users\Heda\GitHub Repos\Optiwand"; hemtt launch
  ```

- Mia tests in game herself. Never claim something works in game.
- CBA setting descriptions: literal `\n` every ~40 characters, paragraphs, no "Server
  setting" line. Order settings by topic, then numbers > switches > lists > text boxes.
- Never commit Bohemia files. `art/esdcam/reference/` (an MLOD of antenna 03) is
  gitignored and local only; the mod only references `\a3\...` paths.
- Match the code style around you: comment density, naming, docstrings that say why.

## Cloud sessions

No Arma, no Arma 3 Tools (ImageToPAA, binarize), no Blender, no Bohemia files. Install
`pip install numpy pillow` and HEMTT's Linux binary (see `.github/workflows/check.yml`,
version 1.22.0) to run `hemtt check` / `hemtt build`.

- `tools/build_camhead.py` projects the mount head onto antenna 03's UVs and needs the
  local reference. A fallback that reuses the UVs stored in the committed `camhead.p3d`
  when the reference is missing is being worked on locally and may not be pushed yet - if
  `python tools/build_camhead.py` fails for lack of the reference, implement it: match
  each FBX face to its stored face in LOD 1 of `addons/esdcam/model/camhead.p3d` by corner
  positions (float32) and reuse those UVs; the output must stay byte-identical.
- `tools/render_icon.py` (inventory pictures) cannot run in the cloud. After any visual
  change, tell Mia to run `python tools/render_icon.py` locally.

## Open tasks (Mia, 2026-11-01, after testing in game)

Her verdict: "Ist sehr gut geworden". Two things left:

1. **The shadow looks weird.** Not yet diagnosed. Most likely cause: the shadow volume
   (`shadow_lod()` in `build_camhead.py`, resolution 10000) is a crude 8-sided lathe,
   0.6 mm inside the visual surface, plus a 4-sided cable tube. The visual hose has 32
   sides, so self-shadowing on the model is faceted and the cast shadow does not match the
   silhouette (the flange octagon is also rotated 22.5 deg against the real one). Bohemia's
   antennas do it differently - measured from their MLODs:
   - `muzzle_antenna_03_F`: LOD 1 and 1100 carry `#Property# lodnoshadow = 1`; shadow
     volume 10000 = 1170 points / 1560 faces (follows the visual closely), 10010 = 72/96,
     plus 11000 = 771/390 and 11010 = 52/24.
   - `muzzle_antenna_02_F`: 10000 = 3480/4640, 10010 = 72/96, 11000 = 2594/1160,
     11010 = 62/24; no `lodnoshadow`.
   Plan: build the shadow volume from the visual geometry itself (closed, triangulated,
   all edges in `#SharpEdges#`, same winding convention as the visual LODs) instead of the
   coarse lathe, add a low-detail 10010, and set `lodnoshadow = 1` on LODs 1 and 2 as
   antenna 03 does. Check the shadow LOD is a closed 2-manifold with consistent winding
   before committing (each edge used exactly twice, opposite directions).
2. **The hose is too light** (renders almost white-blue). It sits on antenna 02's
   galvanised rods (`HOSE_RECT` in `build_camhead.py`) with `camhead_hose.rvmat`.
   Cheapest blind fix: scale `diffuse[]` and `ambient[]` in `write_hose_material()` (now
   1.1 and 1), e.g. 0.45 for gunmetal, 0.3 for dark steel - this needs no new UVs and no
   new PAA. Regenerate the rvmat with the build (or edit both the script and the generated
   file identically). Then Mia re-renders the icons locally.

Still waiting for Mia's in-game feedback (do not reopen unless she reports a problem):
mouse escaping a borderless window while aiming (fixed in b773f9d by removing the map
control), and the keyboard lock while peeking (`fnc_lockInput`, `fnc_releaseInput`).
