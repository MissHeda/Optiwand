#include "..\script_component.hpp"
#include "\a3\ui_f\hpp\defineDIKCodes.inc"
/*
 * Author: Miss Heda
 * Takes the keyboard for the length of a peek. Giving it back is fnc_releaseInput.
 *
 * Other mods' keys kept firing underneath the camera, on two separate paths, and each needs
 * its own answer.
 *
 * The engine. The overlay is a title layer and takes no input focus, so Arma goes on acting on
 * every key. N switched the player's own night vision - which GGE: NVG Animation watches for
 * through currentVisionMode, so it played its goggles-down gesture, the gesture took the
 * player out of the aimed view and the session closed. A KeyDown/KeyUp handler on the mission
 * display that returns true stops the engine acting on a key, so every key that is not bound
 * to one of PASS_ACTIONS is swallowed, on both edges.
 *
 * CBA. Returning true does nothing to other scripted handlers. CBA's dispatcher runs every
 * keybind on a combo and ORs the results - there is no early exit in
 * cba_events_fnc_keyHandlerDown - so TFAR's SW stereo keys on Ctrl+Up/Left/Right ran
 * alongside our extend and slide whatever we returned. So every other mod's handler is
 * muted: its code is swapped for a no-op (fnc_muteKeybind), on the press and on the release
 * side both - TFAR puts its channel and radio cycling on the release.
 *
 * Muting the code rather than filtering CBA's lists is deliberate, and the lists were tried
 * first. CBA never clears a handler's parameters when it removes one, so after the peek there
 * is no telling a handler we filtered out from one CBA removed meanwhile, and the removed one
 * came back. A muted handler stays in CBA's lists, CBA adds, removes and rebinds as it always
 * does, and CBA's own "already fired" bookkeeping keeps running - so a key held on the way out
 * of the peek does not fire again on its auto repeat. Restoring only where the code is still
 * our no-op leaves anything CBA has replaced alone.
 *
 * The edges, each of which went wrong once:
 *
 *   A release armed before the lock started - ACE's interaction menu held open as the peek
 *   begins - still has to run, or that menu never closes. Those are left live
 *   (GVAR(mutePending)) until CBA disarms them, which is when the press that armed them is
 *   over, and muted then. A fresh press of the same key during the peek mutes them at once:
 *   a release that went to another display, like the pause menu, leaves CBA holding one armed
 *   for good, and it must not run live on every press after that.
 *
 *   A key already down when the lock starts (GVAR(inputPreHeld)) had its press reach the
 *   engine before we were here, so its release must reach it too or it sticks. That is all it
 *   earns - its repeats are still swallowed. The list comes from GVAR(heldKeys), which is not
 *   exact: a release that lands on another display, like the inventory the key itself opened,
 *   never reaches it, and a stale entry must not let a key through.
 *
 *   The lock hands back what is free and holds back the rest. When the peek ends, a handler
 *   stays muted while its key was pressed during the peek and is still down, or - for a
 *   release - while CBA still has it armed: that release was armed muted, and restoring first
 *   would let the real one run on the way out. The armed test is what covers mouse buttons
 *   and custom user actions, which never come through a keyboard KeyUp. A frame handler hands
 *   back the rest as it comes free, and ends the lock when nothing is left. Presses lost to
 *   another display cannot hold that open forever: it ends DRAIN_TIMEOUT seconds after the
 *   peek at the latest, and the pause menu ends it at once (XEH_postInit).
 *
 * Should CBA ever rename these variables, the CBA half is skipped and logged - peeking still
 * works, only other mods' keybinds go on firing.
 *
 * Arguments:
 * 0: Lock <BOOL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [true] call opw_mirror_fnc_lockInput
 *
 * Public: No
 */

params [["_lock", false, [false]]];

if (!_lock) exitWith {
    if (!GVAR(inputLocked)) exitWith {};
    GVAR(inputLocked) = false;

    ["peekEnd"] call FUNC(releaseInput);
    if (GVAR(inputPfh) < 0) exitWith {};

    // Something is still held. The frame handler hands it back as it comes free; this is the
    // backstop for a release that never arrives. The generation stamp keeps an old timer from
    // cutting a later drain short.
    GVAR(inputDrainGen) = GVAR(inputDrainGen) + 1;
    [{
        params ["_generation"];
        if (_generation isEqualTo GVAR(inputDrainGen)) then {["final"] call FUNC(releaseInput)};
    }, [GVAR(inputDrainGen)], DRAIN_TIMEOUT] call CBA_fnc_waitAndExecute;
};

if (GVAR(inputLocked) || {!GVAR(lockInput)}) exitWith {};
GVAR(inputLocked) = true;
// A new peek inside a drain carries on with it: cancel the drain's timer, keep what it holds.
GVAR(inputDrainGen) = GVAR(inputDrainGen) + 1;

////////////////////////////////////////////////////////////////////////////////
// Engine
////////////////////////////////////////////////////////////////////////////////

// Resolved from the player's own bindings at every lock, so a rebound W still walks.
// actionKeys packs modifier combos into numbers a float cannot hold exactly, so only the plain
// keys below 65536 are read - mouse and joystick live above that and never come through
// KeyDown anyway. A combo like Ctrl+W still passes, because W itself does.
private _allowed = [
    DIK_ESCAPE,
    DIK_LSHIFT, DIK_RSHIFT, DIK_LCONTROL, DIK_RCONTROL, DIK_LMENU, DIK_RMENU
];
{
    {
        if (_x < 65536) then {_allowed pushBackUnique (_x % 256)};
    } forEach (actionKeys _x);
} forEach PASS_ACTIONS;
GVAR(inputAllowedKeys) = _allowed;
GVAR(inputPreHeld) = GVAR(heldKeys) - GVAR(inputPressed);

if (isNil QGVAR(inputEhDown)) then {
    GVAR(inputEhDown) = ["KeyDown", {
        params ["", "_key"];
        // Repeats of a key swallowed during the peek, and after it until it comes up
        if (_key in GVAR(inputSwallowed)) exitWith {true};
        // Draining: new presses belong to the player again
        if (!GVAR(inputLocked)) exitWith {false};
        // Held into the lock: allowed keys pass, the rest have their repeats swallowed, and
        // neither is claimed - its release goes where its press went
        if (_key in GVAR(inputPreHeld)) exitWith {!(_key in GVAR(inputAllowedKeys))};
        // A fresh press. Any release still pending on this key belongs to a press that is not
        // coming up here any more, so mute it before this press's release can reach it. CBA's
        // KeyDown ran first and only arms releases, it never runs one.
        if (GVAR(mutePending) isNotEqualTo []) then {
            private _still = [];
            {
                if ((_x select 2) isEqualTo _key) then {_x call FUNC(muteKeybind)} else {_still pushBack _x};
            } forEach GVAR(mutePending);
            GVAR(mutePending) = _still;
        };
        GVAR(inputPressed) pushBackUnique _key;
        if (_key in GVAR(inputAllowedKeys)) exitWith {false};
        GVAR(inputSwallowed) pushBack _key;
        true
    }] call CBA_fnc_addDisplayHandler;

    // Runs after CBA's own KeyUp handler, which was on the display first - so by the time a key
    // is handed back here, CBA has already run its muted release.
    GVAR(inputEhUp) = ["KeyUp", {
        params ["", "_key"];

        // The press from before the lock is over. Its pending releases are muted by the frame
        // handler once CBA has disarmed them - which it does in this very event, before us.
        private _index = GVAR(inputPreHeld) find _key;
        if (_index > -1) exitWith {
            GVAR(inputPreHeld) deleteAt _index;
            false
        };

        _index = GVAR(inputPressed) find _key;
        if (_index > -1) then {GVAR(inputPressed) deleteAt _index};

        private _swallow = false;
        _index = GVAR(inputSwallowed) find _key;
        if (_index > -1) then {
            GVAR(inputSwallowed) deleteAt _index;
            _swallow = true;
        };

        if (!GVAR(inputLocked)) then {["drain"] call FUNC(releaseInput)};
        _swallow
    }] call CBA_fnc_addDisplayHandler;
};

// One frame handler for both halves of the lock's life: while locked it mutes pending
// releases whose press has ended, while draining it hands back whatever has come free.
if (GVAR(inputPfh) < 0) then {
    GVAR(inputPfh) = [{
        if (GVAR(inputLocked)) then {
            if (GVAR(mutePending) isEqualTo []) exitWith {};
            private _armed = missionNamespace getVariable [CBA_KEY_DOWN_ACTIVE, []];
            private _still = [];
            {
                if ((_x select 1) in _armed) then {_still pushBack _x} else {_x call FUNC(muteKeybind)};
            } forEach GVAR(mutePending);
            GVAR(mutePending) = _still;
        } else {
            ["drain"] call FUNC(releaseInput);
        };
    }, 0] call CBA_fnc_addPerFrameHandler;
};

////////////////////////////////////////////////////////////////////////////////
// CBA
////////////////////////////////////////////////////////////////////////////////

private _down = missionNamespace getVariable CBA_KEY_DOWN;
private _up = missionNamespace getVariable CBA_KEY_UP;
private _handlersDown = missionNamespace getVariable CBA_KEY_HANDLERS_DOWN;
private _handlersUp = missionNamespace getVariable CBA_KEY_HANDLERS_UP;
if (
    isNil "_down" || {isNil "_up"} || {isNil "_handlersDown"} || {isNil "_handlersUp"}
    || {!(_down isEqualType [])} || {!(_up isEqualType [])}
) exitWith {
    WARNING("CBA key dispatch not found - other mods' keybinds stay live while peeking");
};

private _armed = missionNamespace getVariable [CBA_KEY_DOWN_ACTIVE, []];
private _pass = GVAR(inputPassCba);
private _fnc_passes = {
    params ["_id"];
    (_pass findIf {(_id find _x) == 0}) > -1
};

// The keys of the keybinds that stay live are not swallowed above either. Those handlers have
// to run, and a handler that returns true on the mission display can keep CBA's from running at
// all - which left N, Page Up and Page Down, none of them bound to a walking action, dead while
// the arrow keys went on working. Letting them through gives nothing to the engine: our own
// keybinds return true, and that stops it acting on the key by itself.
{
    private _key = _forEachIndex;
    {
        if ([_x] call _fnc_passes) then {
            GVAR(inputAllowedKeys) pushBackUnique _key;
        } else {
            [_handlersDown, _x, _key] call FUNC(muteKeybind);
        };
    } forEach _x;
} forEach _down;

{
    private _key = _forEachIndex;
    {
        // CBA's own bookkeeping, which does nothing but clear its hold state - never touched
        if (!("_cbadefaultuphandler" in _x) && {!([_x] call _fnc_passes)}) then {
            // Left live only while its key is really still down. CBA keeps a release armed
            // for good when the release itself went to another display, and one of those must
            // not run live the first time a modifier comes up during the peek.
            if (_x in _armed && {_key in GVAR(heldKeys)}) then {
                GVAR(mutePending) pushBackUnique [_handlersUp, _x, _key, true];
            } else {
                [_handlersUp, _x, _key, true] call FUNC(muteKeybind);
            };
        };
    } forEach _x;
} forEach _up;
