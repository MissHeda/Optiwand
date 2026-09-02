#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Works out where the mirror head goes: the middle of the door slit, plus the direction
 * that points through the door and away from the operator, plus how far the head can be
 * slid sideways before it runs into the frame.
 *
 * Arguments:
 * 0: House <OBJECT>
 * 1: Door selection name <STRING>
 * 2: Hit position ASL <ARRAY>
 * 3: Door surface normal <ARRAY>
 *
 * Return Value:
 * 0: Middle of the bottom edge of the door, ASL <ARRAY> ([] on failure)
 * 1: Horizontal unit vector through the door <ARRAY>
 * 2: Half width of the door <NUMBER>
 *
 * Example:
 * [_house, "door_1", _hitASL, _normal] call opw_mirror_fnc_getDoorGeometry
 *
 * Public: No
 */

params ["_house", "_door", "_hitASL", "_normal"];

#define NO_GEOMETRY [[], [], 0]

if (isNull _house || {_hitASL isEqualTo []}) exitWith {NO_GEOMETRY};

private _player = ACE_player;
private _camASL = AGLToASL positionCameraToWorld [0, 0, 0];
private _rayDir = _hitASL vectorDiff _camASL;
_rayDir set [2, 0];
if (vectorMagnitude _rayDir < 0.01) exitWith {NO_GEOMETRY};
_rayDir = vectorNormalized _rayDir;

// Prefer the door's own surface normal so the mirror starts square to the door.
// A near horizontal normal means we clipped a frame or a step - fall back to the look direction.
private _through = +_normal;
if (count _through < 3) then {_through = +_rayDir};
_through set [2, 0];
if (vectorMagnitude _through < 0.35) then {_through = +_rayDir};
_through = vectorNormalized _through;

// Normals point back at the shooter, so flip it to face into the far room
if ((_through vectorDotProduct _rayDir) < 0) then {
    _through = _through vectorMultiply -1;
};

private _span = [_house, _door, _hitASL, _through] call FUNC(getPanelSpan);

private _bottomASL = [];
private _halfWidth = PANEL_FALLBACK_HALF;

if (_span isEqualTo []) then {
    // Sampling came up empty - put the head under the aim point and probe for the floor
    private _probeTop = (_hitASL vectorAdd [0, 0, 0.45]) vectorAdd (_through vectorMultiply -0.3);
    private _floorHits = lineIntersectsSurfaces [_probeTop, _probeTop vectorAdd [0, 0, -3], _player, objNull, true, 1, "GEOM", "VIEW"];
    private _floorZ = if (_floorHits isEqualTo []) then {
        (getPosASL _player) select 2
    } else {
        ((_floorHits select 0) select 0) select 2
    };
    _bottomASL = [_hitASL select 0, _hitASL select 1, _floorZ];
} else {
    _span params ["_pos", "_half"];
    _bottomASL = _pos;
    _halfWidth = _half;
};

// A door reaches the floor. Anything whose bottom edge sits well above the operator's feet
// is a window, a hatch or a hole in a wall - none of which the mirror slides under.
// This also covers the floor above and below, which are further off than any sill.
private _sill = (_bottomASL select 2) - ((getPosASL _player) select 2);
if (_sill > DOOR_SILL_MAX || {_sill < -0.6}) exitWith {
    TRACE_1("bottom edge too high for a door",_sill);
    NO_GEOMETRY
};

[_bottomASL, _through, _halfWidth]
