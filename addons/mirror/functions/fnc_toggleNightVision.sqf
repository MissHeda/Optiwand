#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Toggles the camera's image intensifier. The camera has its own, so it makes no
 * difference what the player is wearing on their head.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Handled <BOOL>
 *
 * Example:
 * call opw_mirror_fnc_toggleNightVision
 *
 * Public: No
 */

if (!GVAR(active)) exitWith {false};

GVAR(nightVision) = !GVAR(nightVision);

// Two halves: the effect in the render target, and a wash over the display. The wash is
// what makes the switch unmistakable even where the render effect does little.
RTT_NAME setPiPEffect [parseNumber GVAR(nightVision)];

private _ctrlIrTint = uiNamespace getVariable [QGVAR(ctrlIrTint), controlNull];
if (!isNull _ctrlIrTint) then {
    _ctrlIrTint ctrlShow GVAR(nightVision);
};

// Force the readout to redraw in the same frame
GVAR(readoutState) = [];

true
