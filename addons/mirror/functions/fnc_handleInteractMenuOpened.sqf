#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Spawns and keeps alive the invisible helper object that carries the mirror action.
 * Same trick ACE3 uses for building UserActions (ace_interact_menu_fnc_userActions_addHouseActions
 * by PabstMirror): the interact menu only renders actions that sit on an object, so we park a
 * local ACE_LogicDummy in the door slit and hang our action on it.
 *
 * Arguments:
 * 0: Interact menu type, 0 = world, 1 = self <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [0] call opw_mirror_fnc_handleInteractMenuOpened
 *
 * Public: No
 */

params ["_interactionType"];

if (_interactionType != 0) exitWith {};
if (GVAR(active)) exitWith {};
if (!isNull objectParent ACE_player) exitWith {};
if (!([ACE_player] call FUNC(wandReady))) exitWith {};

// A leftover scan would keep spawning helpers, so never run two
if (GVAR(scanPfhId) >= 0) then {
    [GVAR(scanPfhId)] call CBA_fnc_removePerFrameHandler;
};

GVAR(lastScan) = [[0, 0, 0], [0, 0, 0]];

GVAR(scanPfhId) = [{
    params ["", "_pfhId"];

    if (!ACEGVAR(interact_menu,keyDown) || {isNull ACE_player} || {GVAR(active)}) exitWith {
        [_pfhId] call CBA_fnc_removePerFrameHandler;
        GVAR(scanPfhId) = -1;
        deleteVehicle GVAR(helper);
        GVAR(helper) = objNull;
    };

    // A second pass from the same spot finds the same door, so the search only runs when the
    // player has actually moved. This used to hang off the view direction - now off the
    // position, because the search itself no longer depends on where you look.
    private _camAGL = getPosATL ACE_player;
    private _aheadAGL = _camAGL;

    // exitWith inside a then block only leaves that block, so the verdict is carried out
    private _unmoved = false;

    if (!isNull GVAR(helper)) then {
        GVAR(lastScan) params ["_scanPos"];
        _unmoved = (_camAGL distance _scanPos) < 0.15;
    };

    if (_unmoved) exitWith {};

    GVAR(lastScan) = [_camAGL, _aheadAGL];

    // A fan all the way round, at door handle height. The nearest door wins - whether the
    // player happens to be looking at it or standing with their back to it.
    private _originAGL = ACE_player modelToWorldVisual [0, 0, DOOR_SEARCH_HEIGHT];
    private _best = [objNull, "", [], []];
    private _bestDist = 1e6;

    for "_i" from 0 to (DOOR_SEARCH_RAYS - 1) do {
        private _a = _i * 360 / DOOR_SEARCH_RAYS;
        private _found = [DOOR_SEARCH_RADIUS, _originAGL, [sin _a, cos _a, 0]] call FUNC(findDoor);

        if (!isNull (_found select 0)) then {
            private _d = _originAGL distance (ASLToAGL (_found select 2));
            if (_d < _bestDist) then {
                _bestDist = _d;
                _best = _found;
            };
        };
    };

    _best params ["_house", "_door", "_hitASL", "_normal"];

    private _bottomASL = [];
    private _through = [];
    private _halfWidth = PANEL_FALLBACK_HALF;

    if (!isNull _house) then {
        ([_house, _door, _hitASL, _normal] call FUNC(getDoorGeometry)) params ["_pos", "_dir", "_half"];
        _bottomASL = _pos;
        _through = _dir;
        _halfWidth = _half;
    };

    if (_bottomASL isEqualTo []) exitWith {
        // Nothing to offer - park the helper out of the interact menu's search radius
        if (!isNull GVAR(helper)) then {
            GVAR(helper) setPosASL [0, 0, -5000];
        };
    };

    if (isNull GVAR(helper)) then {
        GVAR(helper) = "ACE_LogicDummy" createVehicleLocal [0, 0, 0];
        [GVAR(helper), 0, [], GVAR(action)] call ACEFUNC(interact_menu,addActionToObject);
        TRACE_1("helper created",GVAR(helper));
    };

    GVAR(helper) setVariable [QGVAR(house), _house];
    GVAR(helper) setVariable [QGVAR(door), _door];
    GVAR(helper) setVariable [QGVAR(bottomASL), _bottomASL];
    GVAR(helper) setVariable [QGVAR(through), _through];
    GVAR(helper) setVariable [QGVAR(halfWidth), _halfWidth];
    GVAR(helper) setPosASL (_bottomASL vectorAdd [0, 0, ACTION_HEIGHT]);
}, 0.15, []] call CBA_fnc_addPerFrameHandler;
