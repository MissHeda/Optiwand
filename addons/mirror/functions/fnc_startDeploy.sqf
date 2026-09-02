#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Runs the deploy progress bar and opens the feed. Shared by both ways in: the ACE
 * interaction at the door slit and the keybind.
 *
 * Arguments:
 * 0: House <OBJECT>
 * 1: Door selection name <STRING>
 * 2: Middle of the bottom edge of the door, ASL <ARRAY>
 * 3: Horizontal unit vector through the door <ARRAY>
 * 4: Half width of the door <NUMBER>
 * 5: Mode <NUMBER> (default: MODE_DOOR)
 *
 * Return Value:
 * Deploy started <BOOL>
 *
 * Example:
 * [_house, "door_1", _bottomASL, _through, 0.45] call opw_mirror_fnc_startDeploy
 *
 * Public: No
 */

params ["_house", "_door", "_bottomASL", "_through", ["_halfWidth", PANEL_FALLBACK_HALF], ["_mode", MODE_DOOR]];

if (isNull _house || {_bottomASL isEqualTo []} || {_through isEqualTo []}) exitWith {false};

private _args = [_house, _door, _bottomASL, _through, _halfWidth, _mode];
private _time = GVAR(deployTime);

if (_time <= 0) exitWith {
    _args call FUNC(openView);
    true
};

[
    _time,
    _args,
    {(_this select 0) call FUNC(openView)},
    {},
    LLSTRING(Progress_Deploy),
    {[ACE_player] call FUNC(wandReady)},
    ["isNotInside", "isNotSwimming", "isNotSitting"]
] call ACEFUNC(common,progressBar);

true
