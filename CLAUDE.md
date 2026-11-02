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

- `tools/build_camhead.py` runs here: without the antenna 03 reference it reuses the
  mount head UVs stored in the committed `camhead.p3d` (byte-identical output), and
  without ImageToPAA it keeps the committed `camhead_hose_nohq.paa`.
- `tools/render_icon.py` (inventory pictures) cannot run in the cloud. After any visual
  change, tell Mia to run `python tools/render_icon.py` locally.

## Waiting for Mia's in-game test (2026-11-01)

Her verdict after the last round: "Ist sehr gut geworden", with two complaints, both now
changed blind - do not touch them again unless she reports back:

1. **The shadow looked weird.** The old shadow volume was a crude 8-sided lathe. Now:
   `lodnoshadow = 1` on LODs 1 and 2 (as Bohemia's `muzzle_antenna_03_F`), shadow volumes
   10000 and 10010 and a shadow buffer LOD 11000, built by `shadow_mesh()`: the visible wand
   cut into ~1 mm slabs, each replaced by its convex hull (`convex_hull()`, own quickhull -
   no scipy) and pulled 0.6 mm in radially; cable, plug and boot as closed tubes/lathes,
   clips as hulls. Each piece has points of its own (no shared edges between pieces). The
   build fails if an edge is not used exactly twice. The visible mesh could not be used
   directly: it is open at the hose/flange and head/mount joints and has T-junctions at
   the badge. If the shadow is now missing entirely, the engine is not using 11000 - first
   suspect `lodnoshadow`.
2. **The hose was too light, and still silver when only darkened (2026-11-02).** It now sits
   on `PLAIN_RECT`, the dark plastic of the camera body, with `esd_01.rvmat`'s own values.
   Only the rib normal map differs.

Mia has to re-render the inventory icons locally (`python tools/render_icon.py`).

Still waiting for Mia's in-game feedback (do not reopen unless she reports a problem):
mouse escaping a borderless window while aiming (fixed in b773f9d by removing the map
control), and the keyboard lock while peeking (`fnc_lockInput`, `fnc_releaseInput`).
