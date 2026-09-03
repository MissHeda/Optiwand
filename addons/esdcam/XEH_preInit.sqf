#include "script_component.hpp"

ADDON = false;

#include "XEH_PREP.hpp"
#include "initSettings.inc.sqf"

// Runtime state of the picture build-up
GVAR(pfh) = -1;
GVAR(acquire) = 0;
GVAR(acquired) = false;
GVAR(holding) = false;
// How many segments of the acquisition readout are lit. -1 means the readout is not on
// screen at all, which is a different state from zero lit segments.
GVAR(acqLit) = -1;

uiNamespace setVariable [QGVAR(hidden), []];   // [control, original fade]

// Register the Spectrum Device with the mirror component - but only with a camera head on.
//
// The wandMuzzle entry is the decisive one: without it, aiming the device would bring our
// view up even with an antenna fitted. This way the device without a camera stays exactly
// what it is in vanilla.
//
// The isNil guards cover the case where this addon runs before the mirror component -
// its preInit creates the same containers.
if (isNil QEGVAR(mirror,wandClasses)) then {EGVAR(mirror,wandClasses) = []};
if (isNil QEGVAR(mirror,wandMuzzle)) then {EGVAR(mirror,wandMuzzle) = createHashMap};

{
    EGVAR(mirror,wandClasses) pushBackUnique _x;
    EGVAR(mirror,wandMuzzle) set [_x, CAM_ITEM];
} forEach [
    "hgun_esd_01_F",
    "hgun_esd_01_antenna_01_F",
    "hgun_esd_01_antenna_02_F",
    "hgun_esd_01_antenna_03_F"
];

ADDON = true;
