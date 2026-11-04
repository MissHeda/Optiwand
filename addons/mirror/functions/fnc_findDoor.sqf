#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Looks for a door along a ray. With no arguments that is the player's line of sight; with
 * a start and a direction it is any ray at all - which lets the caller sweep all the way
 * round instead of depending on where the player looks.
 * The raycast follows ACE3's ace_interaction_fnc_getDoor (commy2, Phyma) so we pick up
 * exactly the doors ACE's own "open door" interaction works on, including modded houses.
 *
 * Arguments:
 * 0: Search distance <NUMBER> (default: DOOR_REACH_DISTANCE)
 * 1: Start position AGL <ARRAY> (default: [] - the camera)
 * 2: Direction, normalised <ARRAY> (default: [] - the view direction)
 *
 * Return Value:
 * 0: House <OBJECT>
 * 1: Door selection name <STRING>
 * 2: Hit position ASL <ARRAY>
 * 3: Door surface normal <ARRAY>
 *
 * Example:
 * [] call opw_mirror_fnc_findDoor
 *
 * Public: No
 */

#define NO_DOOR [objNull, "", [], []]

params [["_distance", DOOR_REACH_DISTANCE, [0]], ["_fromAGL", [], [[]]], ["_dirAGL", [], [[]]]];

private _posCamAGL = _fromAGL;
private _posEndAGL = [];

if (_fromAGL isEqualTo [] || {_dirAGL isEqualTo []}) then {
    _posCamAGL = positionCameraToWorld [0, 0, 0];
    _posEndAGL = positionCameraToWorld [0, 0, _distance];
} else {
    _posEndAGL = _posCamAGL vectorAdd (_dirAGL vectorMultiply _distance);
};

private _intersections = lineIntersectsSurfaces [AGLToASL _posCamAGL, AGLToASL _posEndAGL, cameraOn, objNull, true, 1, "GEOM"];
if (_intersections isEqualTo []) exitWith {NO_DOOR};

(_intersections select 0) params ["_hitASL", "_normal", "_object", "_parent"];

private _house = _object;
if (isNull _house) then {_house = _parent};

if (isNull _house) exitWith {NO_DOOR};
// A house with no type is the bugged shithouse - same guard ACE uses
if (typeOf _house isEqualTo "") exitWith {NO_DOOR};
if (_house isKindOf "AllVehicles") exitWith {NO_DOOR};

private _hits = [_house, "GEOM"] intersect [_posCamAGL, _posEndAGL];
if (_hits isEqualTo []) exitWith {NO_DOOR};

(_hits select 0) params ["_name", "_nameDistance"];
private _selection = toLowerANSI _name;
if (_selection isEqualTo "") exitWith {NO_DOOR};

// The selection has to be what the line hit first. It goes on through the house, so aimed at a
// plain wall it finds a door in the room behind, and the head would come out through the wall.
if (abs (_nameDistance - ((AGLToASL _posCamAGL) vectorDistance _hitASL)) > DOOR_HIT_TOLERANCE) exitWith {NO_DOOR};

// Windows open and animate just like doors, so the animation test below is not enough on
// its own. Anything that says it is a window is not a door - the mirror is not meant to be
// poked through those, that is what freehand mode is for.
if (({(_selection find _x) != -1} count WINDOW_TOKENS) > 0) exitWith {
    TRACE_1("window, not a door",_selection);
    NO_DOOR
};

// Glass panes and handles are separate selections named after their door
// ("door_1_glass", "door_2_handle", ...), so walk back towards the door itself.
private _candidates = [_selection];
private _tokens = _selection splitString "_";
if (count _tokens > 1) then {
    _candidates pushBackUnique ((_tokens select 0) + "_" + (_tokens select 1));
};

private _door = "";
{
    if ((([_house, _x] call FUNC(getDoorAnimations)) select 0) isNotEqualTo []) exitWith {
        _door = _x;
    };
} forEach _candidates;

// No animation source means it is a wall, a window or a prop - not a door
if (_door isEqualTo "") exitWith {NO_DOOR};

TRACE_3("found door",_house,_door,_normal);

[_house, _door, _hitASL, _normal]
