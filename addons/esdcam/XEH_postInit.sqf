#include "script_component.hpp"

if (!hasInterface) exitWith {};

// ---------------------------------------------------------------------------------------
// The mirror component raises events on deploy and retract - we only listen. By the time of the
// deploy its camera is rendering and its monitor is up. What is left to do here is deciding
// when the picture comes up.
// ---------------------------------------------------------------------------------------

[QEGVAR(mirror,deployed), {
    params ["", "", "", ["_mode", -1, [0]]];

    if (!(ESD_WEAPON_PREFIX in (currentWeapon ACE_player))) exitWith {};

    GVAR(acquire) = 0;
    GVAR(holding) = false;
    // At a door there is no build-up.
    //
    // There you slide the mirror under the leaf and want to see what is behind it at once -
    // having to hold a key while kneeling in a doorway is exactly the wrong moment for it.
    // Freehand is the other way round: you are standing still and can spare the second, and
    // the bar is what gives the act any weight.
    GVAR(acquired) = !GVAR(requireAcquire) || {_mode isEqualTo MODE_DOOR};

    [GVAR(acquired)] call FUNC(showFeed);

    if (!GVAR(acquired)) then {
        // Up straight away, before a single frame of the handler, so right click puts "HOLD"
        // on the screen instead of an empty monitor that looks like nothing happened.
        [true, 0] call FUNC(showAcquire);
        GVAR(pfh) = [FUNC(acquireTick), 0] call CBA_fnc_addPerFrameHandler;
    };
}] call CBA_fnc_addEventHandler;

// The head ran out of room, or found some again. The mirror component reports it as a state
// rather than refusing the deploy, so all that is needed here is to take the picture off the
// screen and put it back - the operator stays in control the whole time.
[QEGVAR(mirror,fault), {
    params [["_faulted", false, [false]]];

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
}] call CBA_fnc_addEventHandler;

// The device's own housing and screen stay out of the aimed view for as long as it is in hand -
// see fnc_hideDevice.
["weapon", {
    params ["", "_weapon"];
    [_weapon in EGVAR(mirror,wandClasses)] call FUNC(hideDevice);
}, true] call CBA_fnc_addPlayerEventHandler;

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
