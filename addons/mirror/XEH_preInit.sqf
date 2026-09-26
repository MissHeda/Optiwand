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

// Keyboard lock while peeking - see fnc_lockInput.
GVAR(lockInput) = true;
GVAR(inputLocked) = false;
GVAR(inputAllowedKeys) = [];
GVAR(inputSwallowed) = [];
GVAR(inputPreHeld) = [];
GVAR(inputDrainGen) = 0;
// The lock's frame handler, running while locked and while draining - see fnc_lockInput.
GVAR(inputPfh) = -1;
// Keys pressed during the current peek and still down.
GVAR(inputPressed) = [];
// What a muted CBA handler runs instead of its own code. Distinctive on purpose: code is
// compared by its text, and fnc_releaseInput only restores where this exact no-op still sits.
GVAR(muteCode) = {"opw_mirror_lockInput"; nil};
// [namespace, id, original code, key, is release] for every handler muted, and
// [namespace, id, key, true] for releases armed before the lock, muted once CBA disarms them.
GVAR(muted) = [];
GVAR(mutePending) = [];
// Every key currently down, kept by two small handlers in XEH_postInit. The lock needs it to
// leave alone whatever was already held when it started.
GVAR(heldKeys) = [];
// CBA keybinds that stay live while locked, as prefixes of CBA's handler ids, which it builds
// as "addon$action_down_N", lower case. Ours, and every radio's transmit key - peeking under a
// door is exactly when someone needs to call out what is behind it. Another mod that needs a
// key through appends its own prefix here.
GVAR(inputPassCba) = [
    "opw$",
    "tfar$swtransmit", "tfar$lrtransmit", "tfar$ddtransmit",
    "acre2$defaultpttkey", "acre2$altpttkey"
];
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
