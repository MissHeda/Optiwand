# From .blend to a working Optiwand

Guide for `MirrorgunModel.blend` + `Data.rar`, written for someone who already knows
Blender. The German [MODEL-PIPELINE.md](MODEL-PIPELINE.md) covers the same ground as a
click by click walkthrough for someone who does not.

The scaffolding is already in place under `addons/optiwand/` and switched off until the model
files arrive - the mod builds and runs exactly as before until you flip the switch.

The existing wand built on the Spectrum Device is untouched by any of this. If this does not
work out, delete `addons/optiwand/` and nothing is missing.

---

## What is actually in your files

Read out of them, not assumed.

**MirrorgunModel.blend** - Blender 2.91, uncompressed.

| Object | What it is |
| --- | --- |
| `MirrorLP` | the main mesh (low poly) |
| `Screenplane_extra` | the screen surface |
| `Screenplane_old` | older version, gets deleted |
| `Camvert` | helper object |
| `Camera`, `Light` | Blender's own, get deleted |

Materials: `mirrorgun`, `mirrorgun.001`, `mirrorgun.002` and
**`mirrorgun_screen`**. The screen having its own material on its own surface is exactly why
the render target has a chance here - see the last section.

**Data.rar** - four textures and one rvmat:

```
Data/mirrorgun.rvmat
Data/SOF_Mirrorgun_co.png     colour
Data/SOF_Mirrorgun_nohq.png   normals
Data/SOF_Mirrorgun_smdi.png   specular
Data/SOF_Mirrorgun_as.png     ambient shadow
```

**Two things in there are wrong** and have to be fixed:

1. The rvmat points at `\MirrorgunKKC\Data\MirrorgunKKC_nohq.paa` - wrong folder **and** wrong
   filename. The files are called `SOF_Mirrorgun_*`.
2. They are PNGs. Arma only eats PAA.

---

## Step 0: Tools

Neither is installed yet.

1. **Arma 3 Tools** - in Steam under Library > Tools, free. Gives you `ImageToPAA`
   (textures), `Object Builder` (inspecting P3Ds) and `binarize`.
2. **Arma Toolbox for Blender** by Alwarren - exports straight to MLOD P3D, supports 2.9x.
   Install and enable it as a Blender addon.

You do **not** need a P: drive to test. Arma loads MLOD P3Ds directly, just more slowly.
Binarizing only matters for a signed release build.

---

## Step 1: Clean up in Blender

1. Delete `Camera`, `Light` and `Screenplane_old`.
2. Check `Camvert` - if it was only a helper, delete that too.
3. Scale: 1 Blender unit = 1 metre. The wand should end up roughly 0.5-0.8 long. Rescale if
   it is not.
4. **Apply all transforms**: select everything, `Ctrl+A` > *All Transforms*. Unapplied scale
   is the single most common reason a model turns up tiny or enormous in game.
5. Set the origin: the zero point belongs where the hand grips it. Arma hangs the model in
   the hand by that point.

You do **not** need to worry about axes. Arma Toolbox converts Blender's Z-up to Arma's Y-up
on export by itself.

---

## Step 2: The screen selection

The most important step, and the one the render target depends on.

1. Join `Screenplane_extra` into `MirrorLP` (`Ctrl+J`) so one LOD is one object.
2. In edit mode select only the faces of the screen surface.
3. Under *Object Data Properties > Vertex Groups* create a group named exactly **`screen`**
   and hit *Assign*.

Arma Toolbox turns vertex groups into named selections. `screen` is already in both places it
needs to be:

* `addons/optiwand/model.cfg` in `sections[]` - without that entry the selection cannot be
  swapped from config and the render target silently does nothing
* `addons/optiwand/CfgWeapons.hpp` in `hiddenSelections[]`

Also check that the screen surface is **UV mapped 0 to 1**, i.e. it fills the whole texture.
If it sits in some corner of an atlas you get a stretched sliver instead of a picture - that
is precisely what would have killed this on the Spectrum Device.

---

## Step 3: LODs

In Arma Toolbox every Blender object gets an *Arma 3 LOD Properties* panel where you set the
LOD type. A handgun slot weapon needs:

| LOD | Purpose | Required |
| --- | --- | --- |
| **Resolution 0.000** | what you see | yes |
| **Geometry** | collision of the dropped weapon, convex and closed, set the `mass` property | yes |
| **Memory** | points, see below | yes |
| ShadowVolume 0.000 | shadow casting | no, but worth it |
| View Geometry | AI line of sight | no |

Further resolution LODs with fewer polygons are a nicety, not a requirement.

**Named properties** on every LOD: `autocenter = 0`. Without it Arma recentres the model
itself and it sits crooked in the hand. On the Geometry LOD also set `mass` (in kg, roughly
1-2 for a device like this).

**Memory LOD points** (the names are fixed, Czech, spell them exactly like this):

| Point | Meaning |
| --- | --- |
| `usti hlavne` | front end, axis pointing forward |
| `konec hlavne` | rear end of that same axis |
| `zasleh` | muzzle flash, irrelevant here but has to exist |
| `eye` | camera position when aiming |
| `aimPoint` | aim point when aiming |

`eye` and `aimPoint` matter **more here than usual**: right click to aim is the trigger for
the whole mod. Place them badly and the view jerks as the mirror deploys.

---

## Step 4: Textures

1. Convert the four PNGs to PAA with `ImageToPAA`. If they are 4096x4096, scale them to 2048
   first - plenty for a handheld device and it saves memory.
2. Put the results in `addons/optiwand/data/`.
3. Put `mirrorgun.rvmat` there too, and rewrite **every** texture path inside it:

   ```
   before: \MirrorgunKKC\Data\MirrorgunKKC_nohq.paa
   after:  \z\opw\addons\optiwand\data\mirrorgun_nohq.paa
   ```

   That affects `Stage1` (nohq), `Stage4` (as) and `Stage5` (smdi). `Stage2` and `Stage3` are
   procedural colours and stay as they are.
4. In Blender, point each material's rvmat and texture path at those same paths in the Arma
   Toolbox material panel.
5. Give the screen its **own rvmat**, as unlit or emissive as you can make it. Otherwise
   Arma's lighting darkens the camera picture.

You also need an inventory picture: `data/ui/gear_optiwand_ca.paa`, same ballpark as BI's
own (256x128).

---

## Step 5: Export and switch it on

1. Export to `addons/optiwand/model/mirrorgun.p3d`.
   Different filename? Then change the class in `model.cfg` and `OPTIWAND_MODEL` in
   `script_component.hpp` to match - the CfgModels class name **must** equal the p3d filename
   without its extension.
2. In `addons/optiwand/script_component.hpp`, uncomment:

   ```
   #define MODEL_READY
   ```
3. Build and launch:

   ```
   hemtt launch
   ```
4. **Optiwand** now sits in the arsenal alongside the other one, under handguns.

The rest happens on its own: `addons/optiwand/XEH_preInit.sqf` registers the weapon in
`opw_mirror_wandClasses`, and from there every check in the mod - in hand, aiming, deploying,
interaction - treats it exactly like the ESD based wand. No logic is duplicated.

---

## The screen

This is a **different situation** from the Spectrum Device, and a far more promising one.

On the ESD the screen is a segment display made of some fifty geometry selections that BI
shows and hides through ammo counters. There is simply no surface there to render onto.

Your model has a **real surface with its own material**, and you control the UVs. That puts
the standard route back on the table, the same one vehicle screens in Arma use: declare the
surface as a hidden selection and hand it the render target as its texture. It is already
wired up in `CfgWeapons.hpp`:

```cpp
hiddenSelections[] = {"screen"};
hiddenSelectionsTextures[] = {"#(argb,512,512,1)r2t(opw_mirror_rtt,1)"};
```

`opw_mirror_rtt` is the same render target the mirror camera already draws into. The moment
the mirror is deployed, the picture is sitting there.

**What I cannot promise:** whether Arma treats render targets on **weapon** models the same
way it does on vehicles. For vehicles it is routine; for a weapon held in hand I found no
example anywhere that demonstrably does it. It is possible the weapon render path does not
play along. You will know the first time you hold it.

Two things that are true even if it works:

* While nothing is deployed nobody renders into the target, so the screen shows the last
  frame or black. Screen off, which honestly fits.
* The GUI panel is independent of this. If the screen works you can switch the panel off with
  the CBA option *Show the device housing* and be left with just the device.

If it does not work: drop `hiddenSelections` and `hiddenSelectionsTextures` from
`CfgWeapons.hpp`. Then it is simply a second wand with its own model, and the picture keeps
coming from the panel.
