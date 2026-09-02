#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Pulls the mirror back out: tears down the camera, the monitor and the key handlers.
 * Safe to call at any time, including when nothing is deployed - the dialog's onUnload
 * calls straight back in here, and the active flag is what stops that looping.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call opw_mirror_fnc_closeView
 *
 * Public: No
 */

if (isNil QGVAR(active) || {!GVAR(active)}) exitWith {};

GVAR(active) = false;

// The overlay goes first. It is only a title layer now and traps nobody, but it would be
// the one thing left standing should a later step in here throw - so it goes before
// anything else.
QGVAR(layer) call BIS_fnc_rscLayer cutText ["", "PLAIN", 0];

if (!isNull GVAR(camera)) then {
    GVAR(camera) cameraEffect ["TERMINATE", "BACK", RTT_NAME];
    camDestroy GVAR(camera);
};
GVAR(camera) = objNull;
uiNamespace setVariable [QGVAR(display), displayNull];
uiNamespace setVariable [QGVAR(ctrlReadout), controlNull];
uiNamespace setVariable [QGVAR(ctrlIrTint), controlNull];

if (GVAR(pfhId) >= 0) then {
    [GVAR(pfhId)] call CBA_fnc_removePerFrameHandler;
};
GVAR(pfhId) = -1;

deleteVehicle GVAR(helper);
GVAR(helper) = objNull;

GVAR(axes) = [0, 0, 0, 0, 0];
GVAR(keyAxes) = createHashMap;
GVAR(nightVision) = false;
GVAR(faulted) = false;
GVAR(lastCamPosASL) = [];
GVAR(lastAppliedPos) = [];
GVAR(lastAppliedDir) = [];

GVAR(readoutState) = [];

// The right button may still be down. Latch the aim trigger so it has to be released first.
GVAR(aimLatched) = true;

// Right click brought us in, so right click should hand the operator back a normal stance
// rather than leaving them still shouldered against nothing.
if (cameraView isEqualTo "GUNNER") then {
    ACE_player switchCamera GVAR(viewBefore);
};

[QGVAR(retracted), [ACE_player]] call CBA_fnc_localEvent;
