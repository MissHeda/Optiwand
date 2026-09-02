#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Statement for the ACE action sitting in the door slit.
 *
 * Arguments:
 * 0: Helper object <OBJECT>
 * 1: Operator <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [_target, _player] call opw_mirror_fnc_deploy
 *
 * Public: No
 */

params ["_target", "_player"];

// Deployed through the ACE menu. Nobody is aiming here, so the eye never gets close enough
// to the small screen on the device - without the monitor there would be nothing to read.
GVAR(viaInteraction) = true;

[
    _target getVariable [QGVAR(house), objNull],
    _target getVariable [QGVAR(door), ""],
    _target getVariable [QGVAR(bottomASL), []],
    _target getVariable [QGVAR(through), []],
    _target getVariable [QGVAR(halfWidth), PANEL_FALLBACK_HALF],
    MODE_DOOR
] call FUNC(startDeploy);
