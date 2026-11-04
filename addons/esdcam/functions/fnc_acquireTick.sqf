#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Builds the picture up while the left mouse button is held.
 *
 * Arguments:
 * None (called as a frame handler)
 *
 * Return Value:
 * None
 *
 * Example:
 * call opw_esdcam_fnc_acquireTick
 *
 * Public: No
 */

// The mirror component cleans up on retract and sends us its event. Should the handler get
// one more turn anyway - death, mission end - it ends itself here.
if (!EGVAR(mirror,active)) exitWith {
    call FUNC(stopAcquire);
};

if (GVAR(acquired)) exitWith {};

private _delta = diag_deltaTime;
private _step = _delta / (GVAR(acquireTime) max 0.1);

if (GVAR(holding)) then {
    GVAR(acquire) = (GVAR(acquire) + _step) min 1;
} else {
    // Letting go drains faster than holding fills. Otherwise the bar could be walked up by
    // tapping once a second, and holding would be pointless.
    GVAR(acquire) = (GVAR(acquire) - _step * 2) max 0;
};

[true, GVAR(acquire)] call FUNC(showAcquire);

if (GVAR(acquire) >= 1) then {
    GVAR(acquired) = true;
    // Acquiring against a wall is allowed - the bar is the operator transmitting, not the
    // head seeing something. The picture itself waits until there is room; the fault event
    // brings it up the moment there is.
    [false] call FUNC(showAcquire);
    [!EGVAR(mirror,faulted)] call FUNC(showFeed);
};
