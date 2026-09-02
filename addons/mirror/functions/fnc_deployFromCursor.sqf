#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Scans whatever the operator is looking at and puts the mirror out.
 * Finds a door - the head goes in the door slit. Finds nothing - the head goes on the end of
 * the shaft, pointed wherever the operator was aiming, which is what you want for peering over
 * a wall or round a corner. Same monitor either way.
 *
 * Arguments:
 * 0: Suppress the failure feedback <BOOL> (default: false)
 *
 * Return Value:
 * Handled <BOOL>
 *
 * Example:
 * [] call opw_mirror_fnc_deployFromCursor
 *
 * Public: No
 */

params [["_silent", false, [false]]];


// Through aiming or the keybind. The monitor follows the setting.
GVAR(viaInteraction) = false;
if (GVAR(active)) exitWith {
    call FUNC(closeView);
    true
};

private _player = ACE_player;

if (!isNull objectParent _player) exitWith {false};
if (!([_player] call FUNC(wandReady))) exitWith {false};
if (!([_player, objNull, ["isNotInside", "isNotSwimming", "isNotSitting"]] call ACEFUNC(common,canInteractWith))) exitWith {false};

private _fnc_freehand = {
    if (!GVAR(allowFreehand)) exitWith {
        if (!_silent) then {[LLSTRING(Hint_NoDoor), 1.5] call ACEFUNC(common,displayTextStructured)};
        false
    };

    private _eyeASL = AGLToASL positionCameraToWorld [0, 0, 0];
    private _lookDir = vectorNormalized ((AGLToASL positionCameraToWorld [0, 0, 1]) vectorDiff _eyeASL);

    // Base sits below the eye, roughly where the wand is actually held
    private _baseASL = _eyeASL vectorAdd [0, 0, -FREE_BASE_DROP];
    private _reach = POLE_LENGTH;

    // The head goes on the end of a stick, not through the wall in front of it. Clamp the
    // reach to whatever is in the way, and refuse outright if there is no room to work.
    private _blocked = lineIntersectsSurfaces [_baseASL, _baseASL vectorAdd (_lookDir vectorMultiply _reach), _player, objNull, true, 1, "GEOM", "FIRE"];
    if (_blocked isNotEqualTo []) then {
        _reach = (_baseASL vectorDistance ((_blocked select 0) select 0)) - COLLISION_CLEARANCE;
    };

    // With no clearance the head cannot extend. Nothing happening at all reads as a broken
    // mod, so the device says so itself.
    //
    // Switchable: anyone who does not want the check gets the mirror deployed right up
    // against a wall too. The head then sits wherever there was still room.
    if (GVAR(requireClearance) && {_reach < FREE_MIN_CLEAR}) exitWith {
        [objNull, "", [], [], 0, MODE_FAULT] call FUNC(openView);
        true
    };

    _reach = _reach max DEPTH_MIN;

    [objNull, "", _baseASL, _lookDir, 0, MODE_FREE, _reach] call FUNC(openView);
    true
};

([] call FUNC(findDoor)) params ["_house", "_door", "_hitASL", "_normal"];

if (isNull _house) exitWith {call _fnc_freehand};

private _animations = ([_house, _door] call FUNC(getDoorAnimations)) select 0;
if (_animations isNotEqualTo [] && {(_house animationPhase (_animations select 0)) > DOOR_OPEN_PHASE}) then {
    _house = objNull;
};

// An open door is not a mistake, it just means there is no slit to work - hold the mirror up instead
if (isNull _house) exitWith {call _fnc_freehand};

([_house, _door, _hitASL, _normal] call FUNC(getDoorGeometry)) params ["_bottomASL", "_through", "_halfWidth"];

if (_bottomASL isEqualTo []) exitWith {call _fnc_freehand};

[_house, _door, _bottomASL, _through, _halfWidth, MODE_DOOR] call FUNC(startDeploy)
