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
GVAR(defaultFov) = FOV_DEFAULT;
GVAR(zoomNear)   = 0.10;
GVAR(zoomFar)    = 0.40;
GVAR(requireClearance) = true;
GVAR(guiMode)    = 0;
GVAR(freeExtend) = FREE_EXTEND;
// Wird vor jedem Ausbringen gesetzt: ueber die ACE-Interaktion kommt der Monitor immer
// mit, ueber Zielen oder Taste richtet er sich nach der Einstellung.
GVAR(viaInteraction) = false;
GVAR(aimLatched) = false;

// Welche Waffen als Spiegelstab zaehlen. Bewusst eine Liste: die Waffen-Addons tragen
// sich selbst ein, dieses Addon kennt keine einzige Waffenklasse.
if (isNil QGVAR(wandClasses)) then {GVAR(wandClasses) = []};

// Waffenklasse -> benoetigter Muendungsaufsatz, fuer Geraete, die nur mit dem passenden
// Kopf als Stab zaehlen. Das Spectrum Device etwa bleibt ohne Kamera ein Spektrumanalysator.
// Wer hier nichts eintraegt, zaehlt wie bisher immer.
if (isNil QGVAR(wandMuzzle)) then {GVAR(wandMuzzle) = createHashMap};

// Wands whose own model carries the render target on a screen surface. For those the
// monitor panel stays hidden - the picture is on the device, putting a second copy of it
// in front of the player's face would be absurd. The dialog itself still opens, because it
// is what captures the keys.
if (isNil QGVAR(screenWands)) then {GVAR(screenWands) = []};
GVAR(viewBefore) = "INTERNAL";
GVAR(mode)       = MODE_DOOR;
GVAR(basePitch)  = PITCH_DEFAULT;
// Freihand jeden Frame neu gemessen: die Blickrichtung, auf die GVAR(pitch) als
// Ablage aufaddiert wird. An der Tuer unbenutzt.
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
uiNamespace setVariable [QGVAR(ctrlIrTint), controlNull];

ADDON = true;
