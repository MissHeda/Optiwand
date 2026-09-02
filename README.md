# Optiwand

An under-door inspection camera for Arma 3, in the spirit of the Optiwand from SWAT 4 and
the mirrorgun from Ready or Not.

It is **not** a separate weapon. It is a muzzle attachment for the vanilla Spectrum Device
from the Contact platform, and the picture appears on that device's own screen, next to its
compass. The device already brings a screen, a compass and attachment slots - building a
second device next to it would have been redundant.

## Requirements

* **CBA_A3**
* **ACE3**
* **Contact Platform** - free, ships with every Arma 3 install in the `enoch` folder.
  The paid Contact expansion is *not* needed.

No other mod is required. The muzzle slots and the antennas are vanilla and already
`scope = 2`. Mods that extend the Spectrum Device generally read the fitted attachment for
its frequency band; the camera declares none, so they leave it alone.

## How it works

Put **SD Inspection Camera** (`opw_muzzle_camera`) into the muzzle slot of the Spectrum
Device, in place of an antenna. The three vanilla antennas stay available - the item is
added to `compatibleItems`, not swapped in.

There are three ways to deploy it:

| | |
|---|---|
| **Aim** the device (right mouse button) | the natural one, same reflex the vanilla device trains |
| **ACE interaction** at a closed door | slides the head under the door leaf |
| **Keybind** | unbound by default, set it under Configure Addons |

At a door the picture is there immediately - you are kneeling in a doorway and want to see
what is behind it. Freehand, hold the **left mouse button** until the picture builds up.
That drives the device's own transmit bar through `#EM_Transmit` and `#EM_Progress`, so it
is the game's own readout rather than a rebuilt one.

You keep moving the whole time. The overlay is an `RscTitles` layer, not a dialog - a dialog
would take input focus and pin you in place.

## Controls

All of these are CBA keybinds and can be remapped under Configure Addons > Optiwand.

| Key | |
|---|---|
| Arrow keys | swivel the camera head |
| **Ctrl** + Up/Down | extend and retract |
| **Ctrl** + Left/Right | slide sideways (doors only) |
| Page Up / Page Down | zoom |
| N | night vision |
| R | recentre |
| Right mouse button | leave the aimed view, which retracts the camera |

Zoom deliberately avoids the numpad so Arma's own field-of-view zoom stays free - that is
what keeps the small device screen readable.

Note that Arma binds the arrow keys to movement by default as a duplicate of WASD. If you
actually walk with the arrow keys, remap one side or the other.

## Settings

Under Configure Addons, in two groups.

**Optiwand - Mirror** governs the mechanics: whether the item must be in hand, whether
freehand peeking is allowed, deploy time, reach, head height, zoom limits and starting
zoom, whether a lack of clearance refuses the deploy, when the carried monitor appears, and
three sliders for the camera offset (forward, sideways, height).

The offset sliders exist because that value can only be judged in game: the camera must sit
neither inside the device model nor floating beside it. Three axes rather than one, because
a single number does not describe the problem.

**Optiwand - ESD Camera** governs the picture: whether it goes on the device screen or on
the carried monitor, whether it has to be acquired by holding the mouse button, and how long
that takes.

## Layout

```
addons/main      framework, version, macros
addons/mirror    all of the mechanics - deploying, camera, controls, overlay
addons/esdcam    registers the Spectrum Device with the above and puts the
                 picture on its screen
tools/           the Blender pipeline for the model
```

`mirror` knows no weapon class of its own. Devices register themselves in
`opw_mirror_wandClasses`, and if they only count with a particular attachment fitted, in
`opw_mirror_wandMuzzle` as well. That second list is what keeps the Spectrum Device a plain
spectrum analyser when no camera is on it.

## Building

Needs [HEMTT](https://github.com/BrettMayson/HEMTT). Version 1.11.2 is what CI is pinned to.

```bash
hemtt check     # configs and SQF only, no build
hemtt dev       # build for testing, with file patching
hemtt launch    # build and start Arma with the mod loaded
hemtt release   # signed release build
```

Anything specific to your machine - an Arma profile, extra mods - goes on the command line
rather than into `.hemtt/project.toml`, so the checked-in config stays the same for everyone:

```bash
hemtt launch -- -name="Your Profile"
```

Every push and pull request runs `hemtt check` on GitHub. If you update HEMTT locally, bump
`HEMTT_VERSION` in `.github/workflows/check.yml` to match, so CI and your machine keep
agreeing with each other.

## The model

`tools/blender_camhead.py` takes the model from Blender to `camhead.p3d` in one run: it
merges the parts with their modifiers applied, resolves n-gons, orients and scales the
result, bakes the Blender materials into a texture, builds the geometry and memory LODs and
exports.

Orientation is measured, not assumed. The three vanilla antennas of the Spectrum Device all
sit with their origin at the device and extend along **-X**:

| | |
|---|---|
| `muzzle_antenna_01_F` | X -0.392 .. +0.007, 40 cm |
| `muzzle_antenna_02_F` | X -0.410 .. +0.298, 71 cm |
| `muzzle_antenna_03_F` | X -0.557 .. 0.000, 56 cm |

The exact mount point comes from the device's own muzzle proxy, at
(-0.0982, -0.0238, -0.0771) in Blender with no rotation.

Baking is not optional decoration: Arma cannot read Blender node trees. Noise and wave
textures, bump, glass - none of that survives an export. The baked texture is the only way
that look reaches the game. Note that the baked `_co` looks darker than the Blender render,
and should: it holds base colour only, with the metallic sheen coming from the rvmat. Put
the sheen in both and the model turns flat and milky.

After a bake, convert the PNGs with `tools/convert_camhead.sh`.

## Licence

The mod is my own work. It reads vanilla Bohemia configs and references vanilla model paths,
which is ordinary modding practice, and ships no Bohemia assets.
