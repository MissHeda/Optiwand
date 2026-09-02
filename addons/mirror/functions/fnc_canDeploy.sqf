#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Condition for the mirror action on a door helper.
 *
 * Arguments:
 * 0: Helper object <OBJECT>
 * 1: Operator <OBJECT>
 *
 * Return Value:
 * Can deploy <BOOL>
 *
 * Example:
 * [_target, _player] call opw_mirror_fnc_canDeploy
 *
 * Public: No
 */

params ["_target", "_player"];

if (GVAR(active)) exitWith {false};
if (!isNull objectParent _player) exitWith {false};
if (!([_player] call FUNC(wandReady))) exitWith {false};

private _house = _target getVariable [QGVAR(house), objNull];
if (isNull _house) exitWith {false};
if ((_target getVariable [QGVAR(bottomASL), []]) isEqualTo []) exitWith {false};

// An open door has no slit to work, so there is nothing to offer
private _animations = ([_house, _target getVariable [QGVAR(door), ""]] call FUNC(getDoorAnimations)) select 0;

_animations isEqualTo [] || {(_house animationPhase (_animations select 0)) <= DOOR_OPEN_PHASE}
