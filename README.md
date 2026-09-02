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
include/         CBA and Arma headers the preprocessor needs at build time
tools/           the model pipeline, see "The model" below
art/             model sources - the FBX ships, the 4096 bakes stay on disk
```

`include/` is not part of the mod. It is there so the build can resolve `\x\cba\...` and
`\a3\...` includes without a P-drive, which is what lets CI build on a machine with no Arma
installed. Removing it breaks the build immediately.

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

The wand is modelled outside this repo and arrives as an FBX plus baked textures. Turning
that into `camhead.p3d` and its PAAs is done by the scripts in `tools/`, so the shipped
assets can be rebuilt from the sources at any time:

```bash
python tools/fbx_to_p3d.py        # art/esdcam/arma3_cam.fbx  ->  addons/esdcam/model/camhead.p3d
python tools/bake_textures.py     # art/esdcam/bake/*.png     ->  addons/esdcam/data/camhead_*.paa
python tools/render_icon.py       # the model                 ->  data/ui/gear_camhead_ca.paa
python tools/preview_p3d.py       # renders the result, to check it before starting Arma
```

They need only `numpy` and `pillow`. Neither Blender nor the Arma 3 Tools have to be
installed: `tools/fbx.py`, `tools/p3d.py` and `tools/paa.py` read binary FBX and read and
write MLOD P3D and PAA on their own. Where ImageToPAA *is* found it is used for the
textures anyway, because it LZO-compresses the mipmaps and the built-in encoder does not -
same pictures, about a fifth of the bytes. `IMAGETOPAA` overrides the search,
`--encoder builtin` skips it.

### Which way round the model is

Blender is right handed and Arma is left handed, so the conversion is a mirroring, and a
mirroring gets both the winding and the normals wrong if you are not careful. Get it wrong
and Arma culls the front faces instead of the back ones: the model is there, the texture is
right, and you look straight through it.

The convention was measured off Bohemia's own MLOD samples in `Arma 3 Samples` - the house,
the heli, the car and the boat. Evaluated with the ordinary right handed formulas, all of
them come out **negative** on both of these, and `fbx_to_p3d.py` refuses to write a model
that does not:

| | |
|---|---|
| signed volume of the mesh | which way the faces are wound |
| divergence flux of the stored normals | which way the normals point |

Both, separately. The tempting test - does `cross(v1-v0, v2-v0)` agree with the stored
normal - proves nothing on its own: flip the winding *and* the normals and the model is
still perfectly consistent with itself while being inside out. That is exactly the mistake
these two numbers exist to catch, and it is not one you can see in a preview render either,
since a rasteriser without backface culling draws both cases identically.

The model came with four materials over one shared UV layout, one 4096 bake each.
`bake_textures.py` folds them into a single set by rasterising each material's UV islands,
and fills everything outside them by growing the island content outwards - without that,
mipmapping pulls the bake background into the silhouette.

Ownership comes before that growing, and the order matters. Grow first and a material's
margin writes over the next one's real surface: `blitz` is eight tiny scattered islands over
a brown LED bake, and it put 209 brown texels into the middle of the grey body that way -
visible in game as a scatter of small brown dots.

`--tint R,G,B` sets what the housing should look like. The wand's own bake sits at 19/19/19,
which reads almost black next to the device; the default target is 35/36/38, the median of
Bohemia's own `esd_01_co.paa`, so the attachment matches the thing it is bolted to. It is a
per channel gain rather than an offset, so the bake's own contrast survives, and it only
touches `Plastik` and `Schlauch` - the lens and the LEDs are signal colours. `--tint none`
leaves the bake alone.

### The inventory picture

`render_icon.py` writes `data/ui/gear_camhead_ca.paa`. Its layout is not composed by eye -
Arma hangs an attachment's picture over the weapon's, so the mount has to land where the
weapon's muzzle is, and all three vanilla antenna pictures agree on where that is:

| | mount | axis |
|---|---|---|
| `gear_muzzle_antenna_01_ca` | 496.9, 250.0 | 11.4 deg |
| `gear_muzzle_antenna_02_ca` | 502.2, 103.1 | 5.9 deg |
| `gear_muzzle_antenna_03_ca` | 500.0, 228.8 | 9.0 deg |

x = 500 in all three, running away to the left at a shallow angle and filling the frame -
they are not on the diagonal. The renderer places two model points on two frame points
rather than centring, so the wand's mount lands on that anchor and its tip in the lower
left; the result comes out at 501.8, 237.1 against antenna 3's 500.0, 228.8.

### Where the size comes from

The FBX carries no real world scale - 13.2 units, which taken literally would be a 13 metre
wand - so the length had to come from somewhere else. It comes from the model itself: the
mount head was built off `muzzle_antenna_03_F`, the SD Jammer Antenna, and there is exactly
one scale at which every feature of it lands on the vanilla one.

| distance from the device | antenna 03 | this model |
|---|---|---|
| 1 mm | 42.6 mm | 42.5 mm | 
| 30 mm | 42.6 mm | 42.5 mm |
| 41 mm | 81.0 mm | 81.0 mm |
| 60 mm | 123.3 mm | 123.3 mm |
| 75 mm | 66.2 mm | 66.2 mm |

That scale puts the whole wand at **57.9 cm**, against the antenna's 55.6 cm, and it is the
default in `fbx_to_p3d.py`. `--fit-mount <antenna.p3d>` re-derives it rather than trusting
the constant; feed it an MLOD copy of a vanilla antenna. Such a copy is a Bohemia asset, so
it belongs under `art/esdcam/reference/` and never inside `addons/` - anything under there
is packed into the PBO and shipped.

### Making another one

Orientation is measured, not assumed. The three vanilla antennas of the Spectrum Device all
sit with their origin at the device and extend along **-X**:

| | |
|---|---|
| `muzzle_antenna_01_F` | X -0.392 .. +0.007, 40 cm |
| `muzzle_antenna_02_F` | X -0.410 .. +0.298, 71 cm |
| `muzzle_antenna_03_F` | X -0.557 .. 0.000, 56 cm |

So: mount at the origin, camera head towards -X, around 40 to 55 cm long. The exact mount
point is the device's own muzzle proxy, at (-0.0982, -0.0238, -0.0771) in Blender with no
rotation. Note that `muzzle_antenna_02_F` reaches back to +0.298, so a connector may wrap
back over the front of the device.

Three LODs are needed: a resolution LOD, a convex geometry LOD carrying the mass, and a
memory LOD with `usti hlavne` and `konec hlavne` - the vector between those two is the
direction the head looks.

Materials have to be baked. Arma cannot read Blender node trees, so noise and wave textures,
bump and glass do not survive an export; a baked texture is the only way that look reaches
the game. Bake base colour rather than the lit image - the metallic sheen belongs in the
rvmat, and putting it in both leaves the model flat and milky.

Bohemia's channel conventions for the other maps, which the bake has to follow because
nothing downstream corrects them: `_smdi` keeps the specular level and power in green and
blue, `_as` is read from green alone.

## Licence

The mod is my own work. It reads vanilla Bohemia configs and references vanilla model paths,
which is ordinary modding practice, and ships no Bohemia assets.
