#include "script_component.hpp"

ADDON = false;

#include "XEH_PREP.hpp"

#include "initSettings.inc.sqf"

// Runtime state - all client side, all reset by fnc_closeView
GVAR(active)     = false;
GVAR(camera)     = objNull;
GVAR(helper)     = objNull;
GVAR(action)     = [];
GVAR(pfhId)      = -1;
GVAR(scanPfhId)  = -1;
GVAR(axes)       = [0, 0, 0, 0, 0];
GVAR(keyAxes)    = createHashMap;
GVAR(nightVision) = false;
// Whether the head currently has room to work. A state rather than a deploy mode, measured
// every frame in fnc_update - see fnc_setFault.
GVAR(faulted)    = false;
GVAR(stripRect)      = [0, 0, 0, 0];
GVAR(stripRectFault) = [0, 0, 0, 0];
GVAR(hintText)   = "";
GVAR(defaultFov) = FOV_DEFAULT;
GVAR(zoomNear)   = 0.10;
GVAR(zoomFar)    = 0.40;
GVAR(requireClearance) = true;
GVAR(freeExtend) = FREE_EXTEND;
// Set before every deploy. The ACE interaction deploys without the operator aiming, so
// fnc_openView has to raise the device itself - see the note there.
GVAR(viaInteraction) = false;
GVAR(aimLatched) = false;
// Deadline until which fnc_update's aimed-view check is held off, for the interaction path.
GVAR(viewGrace) = 0;

// Which weapons count as a mirror wand. Deliberately a list: device addons register
// themselves, and this addon knows not one weapon class.
if (isNil QGVAR(wandClasses)) then {GVAR(wandClasses) = []};

// Weapon class -> required muzzle attachment, for devices that only count as a wand with
// the right head fitted. The Spectrum Device, for one, stays a plain spectrum analyser
// without a camera. Anything not listed here counts unconditionally, as before.
if (isNil QGVAR(wandMuzzle)) then {GVAR(wandMuzzle) = createHashMap};

GVAR(viewBefore) = "INTERNAL";
GVAR(mode)       = MODE_DOOR;
GVAR(basePitch)  = PITCH_DEFAULT;
// Measured fresh every frame in freehand mode: the look direction that GVAR(pitch) is
// added to as an offset. Unused at a door.
GVAR(freeLookPitch) = 0;
GVAR(freeOffsetForward) = 0.2;
GVAR(freeOffsetRight) = 0;
GVAR(freeOffsetUp) = 0;
GVAR(depthDefault) = DEPTH_DEFAULT;
GVAR(slideLimit) = 0;
GVAR(aimPfhId)   = -1;
GVAR(lastScan)   = [[0, 0, 0], [0, 0, 0]];
GVAR(yawLimit)   = YAW_LIMIT;
GVAR(pitchLimits) = [PITCH_MIN, PITCH_MAX];
GVAR(lastAppliedPos) = [];
GVAR(lastAppliedDir) = [];
GVAR(readoutState) = [];
GVAR(nextDoorCheck) = 0;
GVAR(hudLabels)  = ["AZ", "TILT", "ZOOM"];
GVAR(lastCamPosASL) = [];
GVAR(doorAnimCache) = createHashMap;
GVAR(panelSpanCache) = createHashMap;

// A CONTROL cannot be serialized, so it must not live in missionNamespace
uiNamespace setVariable [QGVAR(display), displayNull];
uiNamespace setVariable [QGVAR(ctrlReadout), controlNull];

ADDON = true;
