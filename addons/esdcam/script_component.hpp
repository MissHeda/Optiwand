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
// The picture is on the mirror component's field monitor, and only the attachment is left of
// the device: its own housing and screen stay out of the aimed view, see fnc_hideDevice. No
// config of the device's display is changed, so with an antenna fitted it stays exactly what it
// is in vanilla.
// ---------------------------------------------------------------------------------------

// Controls on the mirror component's overlay. Must match addons\mirror\script_component.hpp.
#define IDC_MONITOR_SCREEN 9140100
#define IDC_MONITOR_FEED 9140102
#define IDC_MONITOR_ACQ_LABEL 9140112
#define IDC_MONITOR_ACQ_TRACK 9140114
#define IDC_MONITOR_ACQ_FILL 9140116

// The device's 3D housing and screen, on its display. Read out of ui_f_enoch.
#define IDC_DEVICE_SCREEN 10
#define IDC_DEVICE_MODEL 11
#define DEVICE_HIDDEN_SCALE 0.0001

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

// Our own model: an endoscope - connector, strain relief, a coil of thin cable and a slim
// camera head with a ring of LEDs. Mount at the origin, head towards -X, the same placement as
// the three vanilla antennas, measured from their p3d.
//
// 57.9 cm long, and that number is not free either: the connector was modelled off
// muzzle_antenna_03_F, and this is the length at which it comes out the same size as the
// vanilla one, to within a tenth of a percent.
//
// A cable like antenna 02's runs into the socket under the display. Built by
// tools/build_camhead.py; see "The model" in the README.
#define CAM_MODEL QPATHTOF(model\camhead.p3d)

// Inventory picture, rendered from our own model by tools/render_icon.py on the device's
// own textures. 512x512 with alpha, mount at x = 500 and the wand running away to the
// lower left, as on Bohemia's gear_muzzle_antenna_01_ca to _03_ca, so it sits in the
// arsenal list looking like it belongs between them rather than next to them.
#define CAM_PICTURE QPATHTOF(data\ui\gear_camhead_ca.paa)

// The second picture, and it is a different job: this is the overlay Arma draws onto the
// weapon's own inventory picture to show the camera fitted. 256x128, flat side on, laid out
// like hgun_esd_01_antenna_02_F_ca: the wand left of the mount, the cable loop right of it.
// It hangs on the slot, not on the item, so it lives in MuzzleSlot4 in CfgWeapons.hpp,
// whose iconPosition goes with this layout.
#define CAM_SLOT_PICTURE QPATHTOF(data\ui\hgun_esd_01_camhead_F_ca.paa)

