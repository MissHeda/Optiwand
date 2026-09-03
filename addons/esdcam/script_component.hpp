#define COMPONENT esdcam
#define COMPONENT_BEAUTIFIED ESD Camera
#include "\z\opw\addons\main\script_mod.hpp"
#include "\z\opw\addons\main\script_macros.hpp"

// ---------------------------------------------------------------------------------------
// Camera attachment for the Spectrum Device from the Contact platform.
//
// Read out of its own config (a3\Weapons_F_Enoch\Pistols\ESD_01\config.bin):
//
//   hgun_esd_01_base_F   weaponInfoType = "RscWeaponSpectrumAnalyzerGeneric"
//                        WeaponSlotsInfo > MuzzleSlot / MuzzleSlot2 / MuzzleSlot3
//   muzzle_antenna_0*_f  class EM { antenna = ... }, base muzzle_antenna_base_01_F
//
// We hang in MuzzleSlot - the same place the directional antenna normally occupies. That
// makes the camera a real alternative to an antenna rather than a second weapon.
//
// ---------------------------------------------------------------------------------------
// The picture sits on the device's own screen
//
// The device display draws its controls onto a real 3D model (analyzer_screen.p3d) through
// "class Areas > Usertexture". That is where the camera picture goes - between Bohemia's
// compass and its signal readout, which is exactly where it belongs.
//
// Locked controls do not stand in the way of this. The overlay from fnc_openView captures
// keyboard and mouse, but it does NOT throw the player out of the aimed view - the device
// stays in hand and its display stays open. In game the device remains visible along the
// bottom edge of the screen.
//
// No camera of our own is needed: the mirror component already runs one and renders to
// opw_mirror_rtt. We only show that same target in a second place.
// ---------------------------------------------------------------------------------------

// Must match RTT_NAME and RTT_SIZE in addons\mirror\script_component.hpp.
#define FEED_TEXTURE "#(argb,2048,2048,1)r2t(opw_mirror_rtt,1)"

// Our own controls. High enough not to collide with any vanilla assignment: taken there are
// 10/11, 999, 1994-1999, 3000-3xxx, 4000-4005, 5500-5802 and 6700-6714.
#define IDC_FEED 71010
#define IDC_FEED_GRAIN 71012

// Vanilla controls that have to go while the camera runs. Read out of ui_f_enoch: the
// picture covers the plot area, but the labels sit beside it - LabelsV to its left,
// LabelsH and the selected-signal text below. Left alone they would keep showing dBm and
// MHz next to a camera image.
#define IDC_LINES 1999
#define IDC_LABELS_V 5550
#define IDC_LABELS_H 5650
#define IDC_SIGNAL_TEXT 5802
#define IDC_NO_ANTENNA 1998
#define IDC_SELECTED 4000
#define IDC_FOCUS 4002
#define IDC_PROGRESS 4005
#define IDC_SELECTED_TEXT 4001

// The compass deliberately stays on. It sits above the plot area, and it is the reason the
// whole thing reads as factory equipment rather than as an add-on.
#define IDC_COMPASS 5700

#define SPECTRUM_DISPLAY "RscWeaponSpectrumAnalyzerGeneric"

// Catches every variant of the device: hgun_esd_01_F itself and the three that ship with an
// antenna already fitted.
#define ESD_WEAPON_PREFIX "hgun_esd_"

// Must match MODE_DOOR in addons\mirror\script_component.hpp. The mirror component passes
// the mode along in its deployed event.
#define MODE_DOOR 0

#define FADE_SHOW 0
#define FADE_HIDE 1

// Two spellings of the same name: the class is declared unquoted, while everywhere else -
// weapons[], compatibleItems[], comparisons in script - the string is what is wanted.
#define CAM_ITEM_CLASS opw_muzzle_camera
#define CAM_ITEM QUOTE(CAM_ITEM_CLASS)

// Our own model: the inspection wand - flanged base, thin shaft, camera head with a ring
// of LEDs. Mount at the origin, head towards -X, the same placement as the three vanilla
// antennas, measured from their p3d.
//
// 57.9 cm long, and that number is not free either: the mount head was modelled off
// muzzle_antenna_03_F, and this is the length at which it comes out the same size as the
// vanilla one, to within a tenth of a percent across collar, shoulder and flange. Built
// from art/esdcam/arma3_cam.fbx by tools/fbx_to_p3d.py; see "The model" in the README.
#define CAM_MODEL QPATHTOF(model\camhead.p3d)

// Inventory picture, rendered from our own model by tools/render_icon.py. 512x512 with
// alpha, the object across the diagonal, lit from the upper left - all measured off
// Bohemia's gear_muzzle_antenna_01_ca and _03_ca, so it sits in the arsenal list looking
// like it belongs between them rather than next to them.
#define CAM_PICTURE QPATHTOF(data\ui\gear_camhead_ca.paa)

// The second picture, and it is a different job: this is the overlay Arma draws onto the
// weapon's own inventory picture to show the camera fitted. 256x128, flat side on, mount to
// the right - measured off hgun_esd_01_antenna_03_F_ca, which lands its mount at 247.0/63.7
// where ours lands at 247/64. It hangs on the slot, not on the item, so it lives in
// MuzzleSlot4 in CfgWeapons.hpp.
#define CAM_SLOT_PICTURE QPATHTOF(data\ui\hgun_esd_01_camhead_F_ca.paa)

