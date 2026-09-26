#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Gives the keyboard back after a peek - see fnc_lockInput.
 *
 * Three steps, because something can still be held when the peek ends:
 *
 *   "peekEnd"  called once as the peek ends. Releases left live because they were armed
 *              before the lock are dropped from the pending list - they were never muted -
 *              and then everything free is handed back as in "drain".
 *   "drain"    hands back every muted handler that has come free: its key is not one pressed
 *              during the peek and still down, and if it is a release, CBA no longer has it
 *              armed. That second test is what lets a muted release run muted on the way out
 *              instead of the real one - and it covers mouse buttons and custom user actions,
 *              which never come through a keyboard KeyUp. Called by the lock's frame handler
 *              and its KeyUp handler, which runs after CBA's. Finishes once nothing is left.
 *   "final"    everything left gets its code back, the display and frame handlers come off.
 *              From "drain" running dry, the drain timeout, or the pause menu.
 *
 * Code only goes back where our no-op is still in place. A handler CBA rebound or
 * re-registered in the meantime has fresh parameters, and those are left alone.
 *
 * Does nothing while a peek is running, so a stale timer cannot unlock the next one.
 * Removing a handler that is currently running is fine - the engine finishes the call it is in.
 *
 * Arguments:
 * 0: Step <STRING> (default: "final")
 *
 * Return Value:
 * None
 *
 * Example:
 * ["final"] call opw_mirror_fnc_releaseInput
 *
 * Public: No
 */

params [["_step", "final", [""]]];

if (GVAR(inputLocked)) exitWith {};

private _fnc_unmute = {
    params ["_namespace", "_id", "_code"];
    private _params = _namespace getVariable _id;
    if (!isNil "_params" && {_params isEqualType []} && {(_params param [2, {}]) isEqualTo GVAR(muteCode)}) then {
        _params set [2, _code];
    };
};

if (_step isEqualTo "peekEnd") then {
    GVAR(mutePending) = [];
    _step = "drain";
};

if (_step isEqualTo "drain") then {
    private _armed = missionNamespace getVariable [CBA_KEY_DOWN_ACTIVE, []];
    private _pressed = GVAR(inputPressed);
    private _still = [];
    {
        _x params ["", "_id", "", "_key", "_isUp"];
        if ((_key in _pressed) || {_isUp && {_id in _armed}}) then {
            _still pushBack _x;
        } else {
            _x call _fnc_unmute;
        };
    } forEach GVAR(muted);
    GVAR(muted) = _still;

    if (_still isEqualTo [] && {_pressed isEqualTo []}) then {_step = "final"};
};

if (_step isNotEqualTo "final") exitWith {};

GVAR(inputDrainGen) = GVAR(inputDrainGen) + 1;
{_x call _fnc_unmute} forEach GVAR(muted);
GVAR(muted) = [];
GVAR(mutePending) = [];

if (GVAR(inputPfh) >= 0) then {
    [GVAR(inputPfh)] call CBA_fnc_removePerFrameHandler;
    GVAR(inputPfh) = -1;
};
if (!isNil QGVAR(inputEhDown)) then {
    ["KeyDown", GVAR(inputEhDown)] call CBA_fnc_removeDisplayHandler;
    GVAR(inputEhDown) = nil;
};
if (!isNil QGVAR(inputEhUp)) then {
    ["KeyUp", GVAR(inputEhUp)] call CBA_fnc_removeDisplayHandler;
    GVAR(inputEhUp) = nil;
};
GVAR(inputSwallowed) = [];
GVAR(inputPressed) = [];
GVAR(inputPreHeld) = [];
