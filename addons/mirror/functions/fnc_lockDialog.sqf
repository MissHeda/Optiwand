#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Opens or closes the invisible dialog that holds the player still during a locked peek.
 *
 * Swallowing keys on the mission display stops most of what the engine does with them, but not
 * all of it: Q and E still leaned, and the mouse went on turning the player. A dialog takes both
 * away from the game. It also takes the keys from CBA, which listens on the mission display, so
 * everything is handed to CBA's own dispatch from here: the keybinds fnc_lockInput left live run
 * as usual, the muted ones run their no-op. The mouse buttons stand in for the two things that
 * would otherwise be lost with them: right click ends the peek, and the left button is passed on
 * for the picture build-up. Escape ends the peek as well, rather than opening the pause menu.
 *
 * Both end it on the release, not the press. The dialog closes with the peek, and the release of
 * a press the game never saw would land on the mission display, which is the same mismatch
 * fnc_lockInput waits out before opening this: the view freezes until the button is clicked again.
 *
 * A dialog also frees the mouse pointer, which on a borderless window could walk out of the
 * game. fnc_update brings it back well before it reaches the edge of the screen, and the disabled map
 * control is there because a map is the only way Arma offers to swap the cursor for a blank one.
 *
 * Arguments:
 * 0: Open <BOOL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [true] call opw_mirror_fnc_lockDialog
 *
 * Public: No
 */

#include "\a3\ui_f\hpp\defineDIKCodes.inc"

params [["_open", false, [false]]];

if (!_open) exitWith {
    GVAR(lockDialogOpen) = false;
    private _dialog = findDisplay IDD_LOCK;
    if (!isNull _dialog) then {_dialog closeDisplay 2};
};

if (GVAR(lockDialogOpen)) exitWith {};

if (!createDialog QGVAR(lockDialog)) exitWith {
    WARNING("lock dialog failed to open - the mouse and some keys stay live while peeking");
};

GVAR(lockDialogOpen) = true;

private _dialog = findDisplay IDD_LOCK;

private _cursor = _dialog displayCtrl IDC_LOCK_CURSOR;
_cursor ctrlMapCursor ["", QGVAR(blank)];
_cursor ctrlEnable false;

// First, because the handlers below can end the peek and close this dialog. A key still held when
// the wait for it timed out comes up here.
[_dialog] call FUNC(trackHeldKeys);

_dialog displayAddEventHandler ["KeyDown", {
    if ((_this select 1) isEqualTo DIK_ESCAPE) exitWith {true};
    _this call cba_events_fnc_keyHandlerDown;
    true
}];

_dialog displayAddEventHandler ["KeyUp", {
    if ((_this select 1) isEqualTo DIK_ESCAPE) exitWith {
        call FUNC(closeView);
        true
    };
    // A key pressed before this dialog opened and let go here. The mission display's KeyUp will
    // not see it, and it would stay held back after the peek until it was pressed once more.
    private _key = _this select 1;
    GVAR(inputPressed) = GVAR(inputPressed) - [_key];
    GVAR(inputSwallowed) = GVAR(inputSwallowed) - [_key];
    _this call cba_events_fnc_keyHandlerUp;
    true
}];

_dialog displayAddEventHandler ["MouseButtonDown", {
    params ["", "_button"];
    if (_button isEqualTo 1) exitWith {true};
    [QGVAR(lockedMouse), [_button, true]] call CBA_fnc_localEvent;
    _this call cba_events_fnc_mouseHandlerDown;
    true
}];

_dialog displayAddEventHandler ["MouseButtonUp", {
    params ["", "_button"];
    if (_button isEqualTo 1) exitWith {
        call FUNC(closeView);
        true
    };
    [QGVAR(lockedMouse), [_button, false]] call CBA_fnc_localEvent;
    _this call cba_events_fnc_mouseHandlerUp;
    true
}];
