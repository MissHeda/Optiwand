#include "script_component.hpp"

if (!hasInterface) exitWith {};

// ---------------------------------------------------------------------------------------
// Put the picture on the device screen as soon as the mirror component deploys.
//
// The mirror component already raises events on deploy and retract - we only listen, and
// nothing has to change over there. By that point its camera is already rendering to
// opw_mirror_rtt, so we are just showing the same target in a second place.
//
// The display comes from the uiNamespace: BIS_fnc_initDisplay stores it there under the
// display's scriptName. That is why no onLoad of our own and no polling loop is needed.
// ---------------------------------------------------------------------------------------

#define HIDE_LIST [IDC_LINES, IDC_LABELS_V, IDC_LABELS_H, IDC_SIGNAL_TEXT, \
                   IDC_NO_ANTENNA, IDC_SELECTED, IDC_FOCUS, IDC_SELECTED_TEXT]

[QEGVAR(mirror,deployed), {
    params ["", "", "", ["_mode", -1, [0]]];

    if (!GVAR(useDeviceScreen)) exitWith {};
    if (!(ESD_WEAPON_PREFIX in (currentWeapon ACE_player))) exitWith {};

    private _display = uiNamespace getVariable [SPECTRUM_DISPLAY, displayNull];
    if (isNull _display) exitWith {
        diag_log text "OPW-ESDCAM  device display not open, picture stays on the monitor";
    };

    // Put the device where the player can read it, whatever field of view they run - and
    // keep putting it there. Arma re-applies the position from the config every frame, so a
    // single call is visibly overwritten a frame later.
    call FUNC(fitDeviceScreen);
    if (GVAR(fitPfh) isEqualTo -1) then {
        GVAR(fitPfh) = [{call FUNC(fitDeviceScreen)}, 0] call CBA_fnc_addPerFrameHandler;
    };

    // Mute the spectrum side. The original fade is remembered rather than assumed - some of
    // these controls are hidden by default and should be hidden again afterwards.
    //
    // IDC_PROGRESS is deliberately NOT in the list: that is the progress bar, which we are
    // about to use for the picture build-up.
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
    // At a door there is no build-up.
    //
    // There you slide the mirror under the leaf and want to see what is behind it at once -
    // having to hold a key while kneeling in a doorway is exactly the wrong moment for it.
    // Freehand is the other way round: you are standing still and can spare the second, and
    // the transmit bar is what gives the act any weight.
    GVAR(acquired) = !GVAR(requireAcquire) || {_mode isEqualTo MODE_DOOR};

    [GVAR(acquired)] call FUNC(showFeed);

    if (!GVAR(acquired)) then {
        missionNamespace setVariable ["#EM_Transmit", false];
        missionNamespace setVariable ["#EM_Progress", 0];
        GVAR(pfh) = [FUNC(acquireTick), 0] call CBA_fnc_addPerFrameHandler;
    };
}] call CBA_fnc_addEventHandler;

// The head ran out of room, or found some again. The mirror component reports it as a state
// rather than refusing the deploy, so all that is needed here is to take the picture off the
// screen and put it back - the operator stays in control the whole time.
[QEGVAR(mirror,fault), {
    params [["_faulted", false, [false]]];

    if (!GVAR(useDeviceScreen)) exitWith {};

    if (_faulted) exitWith {
        [false] call FUNC(showFeed);
    };

    // Only back on if it had been acquired in the first place - a fault clearing must not
    // hand out a picture the operator has not held the button for yet.
    if (GVAR(acquired)) then {
        [true] call FUNC(showFeed);
    };
}] call CBA_fnc_addEventHandler;

[QEGVAR(mirror,retracted), {
    call FUNC(stopAcquire);

    // Hand the device back to Arma's own placement. Nothing to undo - the engine writes the
    // config position every frame anyway, so it is back where it was on the next one.
    if (GVAR(fitPfh) != -1) then {
        [GVAR(fitPfh)] call CBA_fnc_removePerFrameHandler;
        GVAR(fitPfh) = -1;
    };

    // The display may already be gone by now - then its controls are gone with it, and
    // isNull catches that instead of throwing an error.
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
// Holding the left mouse button builds the picture up.
//
// Through CBA_fnc_addDisplayHandler rather than through a dialog - there is no dialog any
// more, and these handlers fire while peeking too. Both return false so the button is passed
// on; swallowing it would take it away from everything else.
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
// Whether the overlay's monitor panel stays away.
//
// screenWands is the list of devices that carry the picture on their own model - for those
// the mirror component holds its monitor back and shows only the key legend. Anyone who
// would rather have the monitor turns the setting off.
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
