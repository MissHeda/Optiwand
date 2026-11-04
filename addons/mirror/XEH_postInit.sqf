#include "script_component.hpp"
#include "\a3\ui_f\hpp\defineDIKCodes.inc"

if (!hasInterface) exitWith {};

["CBA_settingsInitialized", {
    // One cached ACE action, re-used by every door helper we spawn.
    GVAR(action) = [
        QGVAR(deploy),
        LLSTRING(Action_Deploy),
        ICON_MIRROR,
        {_this call FUNC(deploy)},
        {_this call FUNC(canDeploy)},
        {},
        [],
        [0, 0, 0],
        ACTION_DISTANCE,
        [false, false, false, false, true]
    ] call ACEFUNC(interact_menu,createAction);

    ["ace_interactMenuOpened", {_this call FUNC(handleInteractMenuOpened)}] call CBA_fnc_addEventHandler;

    // Aiming down sight with the wand out is the third, and most natural, way in.
    // The watcher only exists while the wand is actually in hand - no idle cost otherwise.
    ["weapon", {
        params ["", "_weapon"];
        call FUNC(closeView);

        if (_weapon in GVAR(wandClasses)) then {
            if (GVAR(aimPfhId) < 0) then {
                GVAR(aimPfhId) = [{call FUNC(watchAim)}, 0.1, []] call CBA_fnc_addPerFrameHandler;
            };
        } else {
            if (GVAR(aimPfhId) >= 0) then {
                [GVAR(aimPfhId)] call CBA_fnc_removePerFrameHandler;
                GVAR(aimPfhId) = -1;
            };
            GVAR(aimLatched) = false;
        };
    }, true] call CBA_fnc_addPlayerEventHandler;
}] call CBA_fnc_addEventHandler;

// Second way in: hold the wand, look at a door, press the key. No default binding, so it
// cannot stomp on anything - set it under Configure Addons > Optiwand.
["OPW", "Optiwand"] call CBA_fnc_registerKeybindModPrettyName;

[
    "OPW",
    QGVAR(deploy),
    [LLSTRING(Keybind_Deploy), LLSTRING(Keybind_Deploy_Description)],
    {call FUNC(deployFromCursor)},
    {false},
    [0, [false, false, false]] // unbound by default
] call CBA_fnc_addKeybind;

// Never leave a camera or a hijacked render target behind
["ace_unconscious", {
    params ["_unit"];
    if (_unit isEqualTo ACE_player) then {call FUNC(closeView)};
}] call CBA_fnc_addEventHandler;

["ace_playerChanged", {call FUNC(closeView)}] call CBA_fnc_addEventHandler;

// Never let a camera, a render target or a modal dialog outlive the mission
addMissionEventHandler ["Ended", {call FUNC(closeView)}];

["unit", {call FUNC(closeView)}] call CBA_fnc_addPlayerEventHandler;

// Opening the pause menu ends the peek. Bohemia's RscDisplayInterrupt and
// RscDisplayMPInterrupt raise OnGameInterrupt from their onLoad, which also runs while a
// single player game is paused and no frame handler is ticking. The peek has to be over by
// the time Configure Addons can be reached - see fnc_lockInput.
//
// It also ends the keyboard lock's drain on the spot rather than waiting it out: every key
// released while the menu has focus goes to the menu, so nothing held is ever coming up on the
// mission display again. Wrapped in missionNamespace because in single player Bohemia raises
// the event from inside BIS_fnc_initDisplay's uiNamespace block - without it every GVAR in
// here would read the wrong namespace and the whole thing would quietly do nothing.
[missionNamespace, "OnGameInterrupt", {
    with missionNamespace do {
        call FUNC(closeView);
        GVAR(heldKeys) = [];
        GVAR(inputPressed) = [];
        GVAR(inputSwallowed) = [];
        ["final"] call FUNC(releaseInput);
    };
}] call BIS_fnc_addScriptedEventHandler;

// Which keys are down right now, kept all the time for fnc_lockInput: a key already held when
// the lock starts has had its press reach the engine, and swallowing only its release would
// leave it stuck. Two array operations per key press - nothing else runs here.
["KeyDown", {
    GVAR(heldKeys) pushBackUnique (_this select 1);
    false
}] call CBA_fnc_addDisplayHandler;

["KeyUp", {
    private _index = GVAR(heldKeys) find (_this select 1);
    if (_index > -1) then {GVAR(heldKeys) deleteAt _index};
    false
}] call CBA_fnc_addDisplayHandler;

// Mouse buttons too, filed the way CBA files them, so the lock can tell a release that is
// genuinely still held - an ACE menu opened on a mouse button - from one left armed by a press
// whose release went to some other display.
["MouseButtonDown", {
    GVAR(heldKeys) pushBackUnique (CBA_MOUSE_OFFSET + (_this select 1));
    false
}] call CBA_fnc_addDisplayHandler;

["MouseButtonUp", {
    private _index = GVAR(heldKeys) find (CBA_MOUSE_OFFSET + (_this select 1));
    if (_index > -1) then {GVAR(heldKeys) deleteAt _index};
    false
}] call CBA_fnc_addDisplayHandler;

// ---------------------------------------------------------------------------------------
// Steuerung
//
// The controls run through CBA keybinds rather than display handlers: the overlay is a
// title layer, which gets no input focus and would never see a key press.
//
// It also has to work this way round, because the player may keep moving while peeking. These
// keys share the keyboard with the normal controls, and through CBA every one of them can
// be remapped.
//
// Arma binds the arrow keys by default as a duplicate of WASD (forward/back/turn). Anyone
// walking with WASD will never notice; anyone who walks with the arrow keys remaps one
// side or the other.
//
// Held keys only latch an axis - the actual movement happens in fnc_update, frame rate
// independently.
// ---------------------------------------------------------------------------------------

private _fnc_addAxis = {
    params ["_name", "_title", "_axis", "_value", "_key", ["_mods", [false, false, false]]];
    [
        "OPW", _name, [_title, ""],
        compile format [
            "if (!%1) exitWith {false}; (%2) set [%3, %4]; true",
            QGVAR(active), QGVAR(axes), _axis, _value
        ],
        // On release only zero the axis if this key is actually the one driving it -
        // otherwise letting go of left would kill an already held right.
        compile format [
            "if (!%1) exitWith {false}; if (((%2) select %3) isEqualTo %4) then {(%2) set [%3, 0]}; true",
            QGVAR(active), QGVAR(axes), _axis, _value
        ],
        [_key, _mods]
    ] call CBA_fnc_addKeybind;
};

#define MOD_NONE [false, false, false]
#define MOD_CTRL [false, true, false]

{
    _x call _fnc_addAxis;
} forEach [
    // Swivel the head: bare arrow keys
    [QGVAR(headUp),     LLSTRING(Keybind_HeadUp),     AXIS_PITCH, 1,  DIK_UP,    MOD_NONE],
    [QGVAR(headDown),   LLSTRING(Keybind_HeadDown),   AXIS_PITCH, -1, DIK_DOWN,  MOD_NONE],
    [QGVAR(headLeft),   LLSTRING(Keybind_HeadLeft),   AXIS_YAW,   -1, DIK_LEFT,  MOD_NONE],
    [QGVAR(headRight),  LLSTRING(Keybind_HeadRight),  AXIS_YAW,   1,  DIK_RIGHT, MOD_NONE],

    // Moving the shaft: the same arrow keys with Ctrl. Stays under one hand, and the
    // mapping matches the swivel - up extends, left slides left. The 2 in the names is the
    // same as on the zoom below: older bindings of these were still stored in profiles.
    [QGVAR(extend2),    LLSTRING(Keybind_Extend),     AXIS_DEPTH, 1,  DIK_UP,    MOD_CTRL],
    [QGVAR(retract2),   LLSTRING(Keybind_Retract),    AXIS_DEPTH, -1, DIK_DOWN,  MOD_CTRL],
    [QGVAR(slideLeft2), LLSTRING(Keybind_SlideLeft),  AXIS_SLIDE, -1, DIK_LEFT,  MOD_CTRL],
    [QGVAR(slideRight2), LLSTRING(Keybind_SlideRight), AXIS_SLIDE, 1,  DIK_RIGHT, MOD_CTRL],

    // Zoom on Page Up/Down, not on the numpad.
    //
    // The action names carry a 2: CBA remembers a binding under its action name for the
    // life of the profile, and a changed default never reaches anyone who already has the
    // old one stored. Renaming is the only way to hand out a new default, at the cost of
    // resetting these two bindings once.
    [QGVAR(zoomIn2),    LLSTRING(Keybind_ZoomIn),     AXIS_FOV,   -1, DIK_PRIOR, MOD_NONE],
    [QGVAR(zoomOut2),   LLSTRING(Keybind_ZoomOut),    AXIS_FOV,   1,  DIK_NEXT,  MOD_NONE]
];

// ---------------------------------------------------------------------------------------
// Numpad + and - while the monitor is up.
//
// Those are Arma's own zoom, and the overlay is a title layer, which takes no input focus -
// so the game goes on acting on them underneath us. On the Spectrum Device that pulls the
// whole view in and out from under the picture.
//
// A CBA keybind that returns true consumes the key, which is what stops the engine acting on
// it. Returning false while the monitor is down leaves Arma's zoom exactly as it was during
// normal play - this only ever bites while peeking.
// ---------------------------------------------------------------------------------------
{
    _x params ["_name", "_key"];
    [
        "OPW", _name,
        [LLSTRING(Keybind_BlockZoom), LLSTRING(Keybind_BlockZoom_Description)],
        {GVAR(active)},
        {GVAR(active)},
        [_key, MOD_NONE]
    ] call CBA_fnc_addKeybind;
} forEach [
    [QGVAR(blockZoomIn), DIK_ADD],
    [QGVAR(blockZoomOut), DIK_SUBTRACT]
];

[
    "OPW", QGVAR(nightVision),
    [LLSTRING(Keybind_NightVision), ""],
    {call FUNC(toggleNightVision)},
    {GVAR(active)},
    [DIK_N, MOD_NONE],
    false // one toggle per press, however long it is held
] call CBA_fnc_addKeybind;

// R rather than Delete. Reloading does nothing with the device in hand, so the key is
// free - and it sits where the hand already rests while walking. Recentre2 for the same reason
// as zoomIn2: the old Delete binding was still stored in profiles.
[
    "OPW", QGVAR(recentre2),
    [LLSTRING(Keybind_Recentre), ""],
    {call FUNC(recentre)},
    {GVAR(active)},
    [DIK_R, MOD_NONE],
    false
] call CBA_fnc_addKeybind;
