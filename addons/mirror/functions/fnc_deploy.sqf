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

// Ueber das ACE-Menue ausgebracht. Hier zielt niemand, also kommt das Auge nicht nah
// genug an den kleinen Bildschirm am Geraet - ohne Monitor waere nichts zu erkennen.
GVAR(viaInteraction) = true;

[
    _target getVariable [QGVAR(house), objNull],
    _target getVariable [QGVAR(door), ""],
    _target getVariable [QGVAR(bottomASL), []],
    _target getVariable [QGVAR(through), []],
    _target getVariable [QGVAR(halfWidth), PANEL_FALLBACK_HALF],
    MODE_DOOR
] call FUNC(startDeploy);
