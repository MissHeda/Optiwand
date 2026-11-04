#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Keeps GVAR(heldKeys) right while another display has the input.
 *
 * That list is filled from the mission display, which never sees a release that lands on a dialog.
 * The entry then stayed behind until the same key was pressed again. For a mouse button, every peek
 * until then sat out the whole of LOCK_DIALOG_WAIT before fnc_lockInput opened its dialog, with the
 * mouse live. A progress bar is the likely place: the right click that raised the device goes up
 * during the bar.
 *
 * Arguments:
 * 0: Display <DISPLAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [_display] call opw_mirror_fnc_trackHeldKeys
 *
 * Public: No
 */

params [["_display", displayNull, [displayNull]]];

if (isNull _display) exitWith {};

_display displayAddEventHandler ["KeyUp", {
    private _index = GVAR(heldKeys) find (_this select 1);
    if (_index > -1) then {GVAR(heldKeys) deleteAt _index};
    false
}];

_display displayAddEventHandler ["MouseButtonUp", {
    private _index = GVAR(heldKeys) find (CBA_MOUSE_OFFSET + (_this select 1));
    if (_index > -1) then {GVAR(heldKeys) deleteAt _index};
    false
}];
