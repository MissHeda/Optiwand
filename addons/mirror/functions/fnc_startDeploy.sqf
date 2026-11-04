#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Runs the deploy progress bar and opens the feed. Shared by every way in that finds a
 * door: aiming, the keybind and, with ACE3 loaded, the interaction at the door slit.
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

// With ACE3 its own bar, so the deploy looks and behaves like every other ACE action and follows
// the player's ACE setting for where the bar sits.
if (isClass (configFile >> "CfgPatches" >> "ace_common")) exitWith {
    [
        _time,
        _args,
        {(_this select 0) call FUNC(openView)},
        {},
        LLSTRING(Progress_Deploy),
        {[CURRENT_UNIT] call FUNC(wandReady)},
        ["isNotInside", "isNotSwimming", "isNotSitting"]
    ] call ACEFUNC(common,progressBar);
    [uiNamespace getVariable ["ace_common_dlgProgress", displayNull]] call FUNC(trackHeldKeys);
    true
};

[
    LLSTRING(Progress_Deploy),
    _time,
    {[CURRENT_UNIT] call FUNC(wandReady)},
    {(_this select 0) call FUNC(openView)},
    {},
    _args
] call CBA_fnc_progressBar;

[uiNamespace getVariable ["cba_ui_BlockInputDisplay", displayNull]] call FUNC(trackHeldKeys);

true
