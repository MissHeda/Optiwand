# Optiwand - instructions for Claude

Arma 3 mod by Miss Heda (Mia): an inspection camera ("SD Inspection Camera") as a muzzle
attachment for the vanilla Spectrum Device. Work happens on branch `camera-model`
(ahead of `main`, version 1.0.0, the first release, not out yet). Read `README.md` first - "The
model" section explains the whole model pipeline.

## Rules

- Chat with Mia in German. Everything in the repo is English: code, comments, commit
  messages, README, stringtables (`<English>` only, no other languages).
- Bump PATCH in `addons/main/script_version.hpp` with every round of bug fixes, unasked,
  unless it was already bumped since the last release. Nothing is released yet, and 1.0.0 is the first release (Mia, 2026-11-04), so it stays 1.0.0 until that is out.
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
  without ImageToPAA it keeps the committed `camhead_lens_co.paa`.
- `tools/render_icon.py` (inventory pictures) cannot run in the cloud. After any visual
  change, tell Mia to run `python tools/render_icon.py` locally.

## Waiting for Mia's in-game test (2026-11-01)

The look was reworked on 2026-11-02, nothing of it seen in game yet. Mia did not like the
thick hose with its flange, however it was bent: she wants it to look like a real endoscope
or the mirrorgun in Ready or Not, still as an attachment. Now only the connector comes from
the FBX; `endoscope()` builds collar, strain relief, thin cable and slim camera head, in
`camhead_rubber.rvmat`. On top of that she asked for a coil of cable in front of the attachment, so it looks as if it
could be paid out further (`coil_path()`), and a cable back into the device (`COAX_ROUTE`).
She also asked for a monitor of her own, a real looking 16:9 picture rather than one built
from Arma UI elements, which reverses the old "no second screen" decision, and the device's
own monitor is to go, keeping only the attachment (`fnc_hideDevice`, not yet seen in game; the
esdcam `gui.hpp` is gone). gui.hpp holds Screen, Feed, Monitor and the build-up, `tools/render_monitor.py` renders `addons/mirror/data/monitor_ca.paa`.
The freehand camera now sits on the wand's real end: the right hand plus `TIP_REACH` along
the weapon direction (`fnc_wandBase`), fine offset in the `tipOffset*` settings. Not yet seen
in game. The monitor sits almost on the bottom edge of the screen (`MONITOR_BOTTOM`), readout and legend
on its screen, keys labelled with what they do in game, no reflection on the glass: she took
that for a see-through screen.
The keyboard lock holds back walking, stance and lean too (2026-11-03): a log of her test showed
the lock active with only WASD/QE pressed, which it let through by design, and she counted that
as not working. Returning true held back WASD but not Q/E or the mouse, so she asked for a layer:
`fnc_lockDialog` opens an invisible dialog and hands keys to CBA's dispatch. Not yet seen in game.
The mod no longer needs ACE (2026-11-04). `fnc_startDeploy` uses ACE's bar with ACE loaded and CBA's
bar, unmoved, without it. The ACE branch is not yet seen in game.
Things she already decided:

1. **Shape of the cable.** Rejected: a downward curve, and sharp kinks. Wanted: essentially
   straight, minimally swaying left and right now and then. `bent()` applies `SWAYS` in every
   LOD; the memory points stay on the straight axis on purpose.
2. **Shadow.** `lodnoshadow = 1` on LODs 1 and 2 (as Bohemia's `muzzle_antenna_03_F`), shadow
   volumes 10000 and 10010 and a shadow buffer LOD 11000, built by `shadow_mesh()`: the
   visible wand cut into ~1 mm slabs, each replaced by its convex hull (`convex_hull()`, own
   quickhull - no scipy) and pulled 0.6 mm in radially. Each piece has points of its own. The
   build fails if an edge is not used exactly twice. If the shadow is missing entirely, the
   engine is not using 11000 - first suspect `lodnoshadow`.
3. **Lens.** Its own material and painted texture with LEDs (`lens_colour()`,
   `camhead_lens.rvmat`). If it looks flat or too bright in game, the rvmat's `forcedDiffuse`
   is the first knob.

After any visual change Mia's machine re-renders the inventory icons
(`python tools/render_icon.py`).

Still waiting for Mia's in-game feedback (do not reopen unless she reports a problem):
mouse escaping a borderless window while aiming (fixed in b773f9d by removing the map
control), and the keyboard lock while peeking (`fnc_lockInput`, `fnc_releaseInput`).
