#include "script_component.hpp"

if (!hasInterface) exitWith {};

// ---------------------------------------------------------------------------------------
// Bild auf die Scheibe des Geraets legen, sobald der Spiegel-Teil ausbringt.
//
// Der Spiegel-Teil ruft beim Ausbringen und beim Einholen bereits Ereignisse - wir hoeren
// nur zu und muessen dort nichts aendern. Zu diesem Zeitpunkt laeuft seine Kamera schon auf
// opw_mirror_rtt, wir zeigen dasselbe Ziel also nur zusaetzlich an.
//
// Das Display holen wir aus dem uiNamespace: BIS_fnc_initDisplay legt es dort unter dem
// scriptName der Anzeige ab. Deshalb braucht es keinen eigenen onLoad und keine Schleife.
// ---------------------------------------------------------------------------------------

#define HIDE_LIST [IDC_LINES, IDC_LABELS_V, IDC_LABELS_H, IDC_SIGNAL_TEXT, \
                   IDC_NO_ANTENNA, IDC_SELECTED, IDC_FOCUS, IDC_SELECTED_TEXT]

[QEGVAR(mirror,deployed), {
    params ["", "", "", ["_mode", -1, [0]]];

    if (!GVAR(useDeviceScreen)) exitWith {};
    if (!(ESD_WEAPON_PREFIX in (currentWeapon ACE_player))) exitWith {};

    private _display = uiNamespace getVariable [SPECTRUM_DISPLAY, displayNull];
    if (isNull _display) exitWith {
        diag_log text "OPW-ESDCAM  Geraeteanzeige nicht offen, Bild bleibt auf dem Monitor";
    };

    // Spektrumteil stummschalten. Der urspruengliche Fade wird gemerkt, nicht angenommen -
    // einige dieser Controls sind von Haus aus versteckt und sollen es danach wieder sein.
    //
    // IDC_PROGRESS steht bewusst NICHT in der Liste: das ist der Fortschrittsbalken, den
    // wir gleich fuer den Bildaufbau brauchen.
    private _hidden = [];
    {
        private _ctrl = _display displayCtrl _x;
        if (!isNull _ctrl) then {
            _hidden pushBack [_ctrl, ctrlFade _ctrl];
            _ctrl ctrlSetFade FADE_HIDE;
            _ctrl ctrlCommit 0;
        };
    } forEach HIDE_LIST;
    uiNamespace setVariable [QGVAR(hidden), _hidden];

    GVAR(acquire) = 0;
    GVAR(holding) = false;
    // An der Tuer entfaellt der Aufbau.
    //
    // Dort schiebt man den Spiegel unter das Blatt und will sofort sehen, was dahinter ist -
    // erst noch eine Taste halten zu muessen, waehrend man im Tuerrahmen kniet, ist genau
    // der falsche Moment. Freihand ist es umgekehrt: da steht man und kann sich die Sekunde
    // nehmen, und der Sendebalken gibt dem Ganzen erst sein Gewicht.
    GVAR(acquired) = !GVAR(requireAcquire) || {_mode isEqualTo MODE_DOOR};

    [GVAR(acquired)] call FUNC(showFeed);

    if (!GVAR(acquired)) then {
        missionNamespace setVariable ["#EM_Transmit", false];
        missionNamespace setVariable ["#EM_Progress", 0];
        GVAR(pfh) = [FUNC(acquireTick), 0] call CBA_fnc_addPerFrameHandler;
    };
}] call CBA_fnc_addEventHandler;

[QEGVAR(mirror,retracted), {
    call FUNC(stopAcquire);

    // Die Anzeige kann inzwischen zu sein - dann sind ihre Controls ohnehin weg und isNull
    // faengt das ab, statt eine Fehlermeldung zu erzeugen.
    {
        _x params ["_ctrl", "_fade"];
        if (!isNull _ctrl) then {
            _ctrl ctrlSetFade _fade;
            _ctrl ctrlCommit 0;
        };
    } forEach (uiNamespace getVariable [QGVAR(hidden), []]);
    uiNamespace setVariable [QGVAR(hidden), []];

    [false] call FUNC(showFeed);
}] call CBA_fnc_addEventHandler;

// ---------------------------------------------------------------------------------------
// Linke Maustaste halten baut das Bild auf.
//
// Ueber CBA_fnc_addDisplayHandler statt ueber einen Dialog - den gibt es nicht mehr, und
// diese Handler greifen auch waehrend des Spaehens. Beide geben false zurueck: die Taste
// soll durchgereicht werden, sonst schluckt sie das Geraet fuer alles andere mit.
// ---------------------------------------------------------------------------------------
["MouseButtonDown", {
    params ["", "_button"];
    if (_button isEqualTo 0 && {EGVAR(mirror,active)}) then {
        GVAR(holding) = true;
    };
    false
}] call CBA_fnc_addDisplayHandler;

["MouseButtonUp", {
    params ["", "_button"];
    if (_button isEqualTo 0) then {
        GVAR(holding) = false;
    };
    false
}] call CBA_fnc_addDisplayHandler;

// ---------------------------------------------------------------------------------------
// Ob der Monitor der Titelebene wegbleibt.
//
// screenWands ist die Liste der Geraete, die das Bild auf dem eigenen Modell tragen - fuer
// die haelt der Spiegel-Teil seinen Monitor zurueck und zeigt nur noch die Tastenzeile.
// Wer den Monitor doch lieber haette, schaltet die Einstellung ab.
// ---------------------------------------------------------------------------------------
["CBA_settingsInitialized", {
    private _classes = [
        "hgun_esd_01_F",
        "hgun_esd_01_antenna_01_F",
        "hgun_esd_01_antenna_02_F",
        "hgun_esd_01_antenna_03_F"
    ];
    if (GVAR(useDeviceScreen)) then {
        {EGVAR(mirror,screenWands) pushBackUnique _x} forEach _classes;
    } else {
        {
            private _i = EGVAR(mirror,screenWands) find _x;
            if (_i > -1) then {EGVAR(mirror,screenWands) deleteAt _i};
        } forEach _classes;
    };
}] call CBA_fnc_addEventHandler;
