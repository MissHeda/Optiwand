# Optiwand

An under-door inspection camera for Arma 3, in the spirit of the Optiwand from SWAT 4 and
the mirrorgun from Ready or Not.

It is **not** a separate weapon. It is a muzzle attachment for the vanilla Spectrum Device
from the Contact platform, and the picture appears on a 16:9 field monitor over the world. The
device's own housing and screen go out of the aimed view during a peek.

## Requirements

* **CBA_A3**
* **Contact Platform** - free, ships with every Arma 3 install in the `enoch` folder.
  The paid Contact expansion is *not* needed.

ACE3 is optional. It adds the interaction at a door, and the deploy then runs on ACE's progress
bar instead of CBA's. No other mod is required. The muzzle slots and the antennas are vanilla and already
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
| **ACE interaction** at a closed door, with ACE3 loaded | slides the head under the door leaf |
| **Keybind** | unbound by default, set it under Configure Addons |

At a door the picture is there immediately - you are kneeling in a doorway and want to see
what is behind it. Freehand, hold the **left mouse button** until the picture builds up. The
monitor says so while you do: `HOLD LMB TO ACQUIRE`, then a bar, both on its dark screen.

The picture shows on a field monitor, half the screen wide, with its screen in 16:9. It is a picture rendered in Blender (`python tools/render_monitor.py`), not a
stack of UI controls: the camera's picture sits behind it and shows through a hole with some
glass painted over it. The readout and the key legend are on its
screen, as if it were drawing them. Its size and place are `MONITOR_*` in
`addons/mirror/script_component.hpp`.

With *Lock other keys while peeking* on, the default, you stand still while the camera is out,
and the mouse does not turn you: an invisible dialog takes keyboard and mouse from the game
(`fnc_lockDialog`). Turn it off to keep moving. The overlay itself is an `RscTitles` layer, not a dialog - a dialog
would take input focus and pin you in place, and it would hand the mouse cursor back to the
desktop, which on a borderless window with a second monitor let the pointer walk out of the
game entirely.

## Controls

All of these but the right mouse button are CBA keybinds and can be remapped under Configure
Addons > Optiwand. The legend on the monitor follows what you bind them to.

| Key | |
|---|---|
| Arrow keys | swivel the camera head |
| **Ctrl** + Up/Down | extend and retract |
| **Ctrl** + Left/Right | slide sideways (doors only) |
| Page Up / Page Down | zoom |
| N | night vision |
| R | recentre |
| Right mouse button | leave the aimed view, which retracts the camera |

Note that Arma binds the arrow keys to movement by default as a duplicate of WASD. If you
actually walk with the arrow keys, remap one side or the other.

### The keyboard is ours while peeking

Everything except the keys above, voice, radio transmit and Escape is held back while the
camera is out, walking, stance and lean included - the game's own actions and other mods'
keybinds alike. Without that, N switched the player's own goggles (and GGE: NVG Animation
played its gesture over it, which dropped the aimed view and ended the session), and TFAR's
SW stereo keys on Ctrl+Up/Left/Right fired together with extend and slide.

It takes two mechanisms, because returning `true` from a key handler only stops the engine,
never another script. The game side is a KeyDown/KeyUp handler that swallows every key not
bound to one of the pass-through actions. The mod side is CBA: it runs every keybind on a
combo and ORs the results, so for the length of a peek every other mod's handler has its
code swapped for a no-op - press and release both, since TFAR keeps its channel and radio
cycling on the release. CBA's lists themselves are never touched: filtering them was the
first attempt, and CBA never clears a removed handler's parameters, so a handler removed
during a peek came back afterwards. Muting leaves CBA to add, remove and rebind as it always
does, and code only goes back where our no-op is still in place.

Keys are handed back one by one. A key pressed during the peek and still held when it ends
stays locked until it comes up - otherwise its release, armed while muted, would run the
real thing on the way out - but never longer than three seconds, and opening the pause menu
ends the peek and the lock on the spot. *Lock other keys while peeking* under
Optiwand turns all of it off.

## Settings

Under Configure Addons > Optiwand, all in one category.

The mechanics: whether the item must be in hand, whether
freehand peeking is allowed, deploy time, reach, head height, zoom limits and starting
zoom, whether a lack of clearance is reported, and three sliders for the camera offset
(forward, sideways, height).

The offset sliders exist because that value can only be judged in game: the camera must sit
neither inside the device model nor floating beside it, and it must not be looking down its
own shaft. Three axes rather than one, because a single number does not describe the problem.

The picture: whether it has to be acquired by holding the
mouse button, and how long that takes.

## Layout

```
addons/main      framework, version, macros
addons/mirror    all of the mechanics - deploying, camera, controls, overlay
addons/esdcam    registers the Spectrum Device with the above, decides when the
                 picture comes up and hides the device's own screen
include/         CBA and Arma headers the preprocessor needs at build time
tools/           the model pipeline, see "The model" below
art/             model sources - the FBX ships, Bohemia's reference stays on disk
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

The attachment looks like a real endoscope, the mirrorgun of Ready or Not: the Spectrum
Device is the grip and the screen, and on its muzzle sits a thin black cable with the camera
at its end. The build makes it from two sources:

```bash
python tools/build_camhead.py     # art/esdcam/arma3_cam.fbx  ->  addons/esdcam/model/camhead.p3d
python tools/render_icon.py       # the model                 ->  data/ui/*_camhead_*_ca.paa
```

| | |
|---|---|
| connector | the only part kept from the FBX, on Bohemia's atlas where antenna 03 has its own: each face is projected onto the nearest face of `muzzle_antenna_03_F` and takes its UVs. The mod references those files and ships none of them |
| collar, strain relief, cable, camera head | built by `endoscope()` as solids of revolution, in black rubber: the atlas's plain panel with a darker, duller material (`camhead_rubber.rvmat`) |
| coil | spare cable in three loops just in front of the strain relief (`coil_path()`), same rubber |
| coax, plug | antenna 02's on the atlas, from the collar under the device into the lower socket under the display |
| lens | a texture and material of our own (`camhead_lens_co.paa`, `camhead_lens.rvmat`): a coated lens in a ring of LEDs with its reflections painted on, as nothing on the atlas reads as glass |

A cable is never quite straight, so the build gives the stretch in front of the coil a slight
sway from side to side last, in every LOD: `SWAYS` lists a few soft turns that cancel out, and `bent()` turns each cross
section as a whole. The connector stays where it is, and so do the memory points, which keep
the view on the straight axis.

The build also writes LOD 2 and the geometry box with `autocenter = 0`, as Bohemia's antennas
have, and shadows the way antenna 03 has them: the visual LODs carry `lodnoshadow = 1`, and
two shadow volumes (10000 near, 10010 far) plus a shadow buffer LOD (11000) cast the shadow
instead. The volumes are the visible wand cut into thin slabs, each slab replaced by its
convex hull and pulled 0.6 mm in - closed by construction and close to the silhouette, which
the visible mesh itself is not. Coil, coax and plug are closed solids of their own. The build stops if any edge of a volume is not used exactly
twice.

The model ships as MLOD (`addons/esdcam/addon.toml`). Binarize embeds a model's materials
into the ODOL from files it has to read at build time, and without a P drive it cannot read
Bohemia's - the release model would carry an empty material. Arma loads MLOD directly.

`build_camhead.py` needs an MLOD copy of `muzzle_antenna_03_F` in
`art/esdcam/reference/` to project onto, and the Arma 3 Tools for ImageToPAA.
`render_icon.py` needs Blender and the unpacked `weapons_f_enoch` textures (`--bi-data`).
Both are Bohemia's files and stay out of the repo - anything under `addons/` is packed into
the PBO and shipped.

### Which way round the model is

Blender is right handed and Arma is left handed, so the conversion is a mirroring, and a
mirroring gets both the winding and the normals wrong if you are not careful. Get it wrong
and Arma culls the front faces instead of the back ones: the model is there, the texture is
right, and you look straight through it.

The convention was measured off Bohemia's own MLOD samples in `Arma 3 Samples` - the house,
the heli, the car and the boat. Evaluated with the ordinary right handed formulas, all of
them come out **negative** on both of these, and `build_camhead.py` refuses to write a model
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

### The inventory pictures

`render_icon.py` renders both pictures in Blender, on the same textures the game uses. Their
layout is not composed by eye - Arma hangs an attachment's picture over the weapon's, so the
mount has to land where the weapon's muzzle is, and the vanilla antenna pictures agree on
where that is:

| | mount | axis |
|---|---|---|
| `gear_muzzle_antenna_01_ca` | 496.9, 250.0 | 11.4 deg |
| `gear_muzzle_antenna_02_ca` | 502.2, 103.1 | 5.9 deg |
| `gear_muzzle_antenna_03_ca` | 500.0, 228.8 | 9.0 deg |

x = 500 in all three, running away to the left at a shallow angle. The wand's mount goes on
that anchor and its tip in the lower left; the cable leaves the frame on the right, as
antenna 02's does.

The slot overlay is laid out like antenna 02's rather than antenna 03's, because it has to
show the cable loop behind the mount: wand from 6 to 165 px, loop out to about 250. The
overlay is centred on the slot's `iconPosition`, and antennas 01 and 03 put the device's
muzzle at 0.433 of the weapon picture's width with the overlay 0.717 of it wide - so a
mount at 165 of 256 needs an `iconPosition` x of 0.33.

Brightness is anchored through Bohemia's own model: antenna 03 is rendered through the same
setup, and the curve that takes its median to that of `gear_muzzle_antenna_03_ca` is applied
to the wand. So the wand comes out exactly as much lighter than antenna 03 as it is.

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

That scale puts the whole wand at **57.9 cm**, against the antenna's 55.6 cm, and it is
`DEFAULT_LENGTH` in `fbx_to_p3d.py`. `python tools/fbx_to_p3d.py --fit-mount <antenna.p3d>`
re-derives it rather than trusting the constant.

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

There is nothing to bake. Map the faces onto the device's atlas - `build_camhead.py` shows
how, region by region - and anything the atlas has no normal map for gets a material of its
own that is Bohemia's in every other respect, the way the hose does.

## Licence

The mod is my own work. It reads vanilla Bohemia configs and references vanilla model and
texture paths, which is ordinary modding practice, and ships no Bohemia assets.
