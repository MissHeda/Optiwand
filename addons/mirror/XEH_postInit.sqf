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

// ---------------------------------------------------------------------------------------
// Steuerung
//
// Frueher hingen die Tasten an den KeyDown-Handlern des Dialogs. Der Dialog ist weg - eine
// Titelebene bekommt keinen Eingabefokus -, also laufen sie jetzt ueber CBA-Keybinds.
//
// Das ist ohnehin die bessere Loesung: der Spieler bewegt sich waehrend des Spaehens weiter,
// die Tasten teilen sich also die Tastatur mit der normalen Steuerung. Ueber CBA laesst sich
// jede davon umlegen.
//
// Die Pfeiltasten sind in Arma ab Werk doppelt belegt (Vorwaerts/Rueckwaerts/Drehen). Wer
// mit WASD laeuft, merkt davon nichts; wer die Pfeiltasten zum Laufen benutzt, legt hier
// oder dort um.
//
// Gehaltene Tasten rasten nur eine Achse ein - bewegt wird in fnc_update, bildratenunabhaengig.
// ---------------------------------------------------------------------------------------

private _fnc_addAxis = {
    params ["_name", "_title", "_axis", "_value", "_key", ["_mods", [false, false, false]]];
    [
        "OPW", _name, [_title, ""],
        compile format [
            "if (!%1) exitWith {false}; (%2) set [%3, %4]; true",
            QGVAR(active), QGVAR(axes), _axis, _value
        ],
        // Beim Loslassen nur dann nullen, wenn diese Taste die Achse auch wirklich treibt -
        // sonst wuerde das Loslassen von Links eine bereits gedrueckte Rechts-Taste abwuergen.
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
    // Kopf schwenken: blanke Pfeiltasten
    [QGVAR(headUp),     LLSTRING(Keybind_HeadUp),     AXIS_PITCH, 1,  DIK_UP,    MOD_NONE],
    [QGVAR(headDown),   LLSTRING(Keybind_HeadDown),   AXIS_PITCH, -1, DIK_DOWN,  MOD_NONE],
    [QGVAR(headLeft),   LLSTRING(Keybind_HeadLeft),   AXIS_YAW,   -1, DIK_LEFT,  MOD_NONE],
    [QGVAR(headRight),  LLSTRING(Keybind_HeadRight),  AXIS_YAW,   1,  DIK_RIGHT, MOD_NONE],

    // Stab bewegen: dieselben Pfeiltasten mit Strg. Bleibt unter einer Hand, und die
    // Zuordnung ist dieselbe wie beim Schwenken - hoch faehrt aus, links schiebt links.
    [QGVAR(extend),     LLSTRING(Keybind_Extend),     AXIS_DEPTH, 1,  DIK_UP,    MOD_CTRL],
    [QGVAR(retract),    LLSTRING(Keybind_Retract),    AXIS_DEPTH, -1, DIK_DOWN,  MOD_CTRL],
    [QGVAR(slideLeft),  LLSTRING(Keybind_SlideLeft),  AXIS_SLIDE, -1, DIK_LEFT,  MOD_CTRL],
    [QGVAR(slideRight), LLSTRING(Keybind_SlideRight), AXIS_SLIDE, 1,  DIK_RIGHT, MOD_CTRL],

    // Zoom auf Bild auf/ab. Das Numpad bleibt damit frei fuer den Sichtfeld-Zoom von Arma
    // selbst - der haelt den Monitor herangezogen, und das soll er auch weiter tun.
    [QGVAR(zoomIn),     LLSTRING(Keybind_ZoomIn),     AXIS_FOV,   -1, DIK_PRIOR, MOD_NONE],
    [QGVAR(zoomOut),    LLSTRING(Keybind_ZoomOut),    AXIS_FOV,   1,  DIK_NEXT,  MOD_NONE]
];

[
    "OPW", QGVAR(nightVision),
    [LLSTRING(Keybind_NightVision), ""],
    {call FUNC(toggleNightVision)},
    {false},
    [DIK_N, MOD_NONE]
] call CBA_fnc_addKeybind;

// R statt Entf. Nachladen tut mit dem Geraet in der Hand ohnehin nichts, die Taste ist
// also frei - und sie liegt da, wo die Hand beim Laufen sowieso ist.
[
    "OPW", QGVAR(recentre),
    [LLSTRING(Keybind_Recentre), ""],
    {call FUNC(recentre)},
    {false},
    [DIK_R, MOD_NONE]
] call CBA_fnc_addKeybind;
