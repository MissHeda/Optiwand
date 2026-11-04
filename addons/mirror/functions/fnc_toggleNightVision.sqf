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

// setPiPEffect tints the render target itself, so the picture on the monitor comes through
// green with nothing else to do.
RTT_NAME setPiPEffect [parseNumber GVAR(nightVision)];

// Force the readout to redraw in the same frame
GVAR(readoutState) = [];

true
