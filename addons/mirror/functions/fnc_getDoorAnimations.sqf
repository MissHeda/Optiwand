#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Returns the animation sources belonging to a door selection.
 * Ported from ACE3's ace_interaction_fnc_getDoorAnimations (commy2, Phyma) so that a door
 * we consider "closed" is the same door ACE considers closed. Results are cached per
 * building type because animationNames is not cheap.
 *
 * Arguments:
 * 0: House <OBJECT>
 * 1: Door selection name <STRING>
 *
 * Return Value:
 * 0: Animations <ARRAY>
 * 1: Locked variables <ARRAY>
 *
 * Example:
 * [cursorObject, "door_1"] call opw_mirror_fnc_getDoorAnimations
 *
 * Public: No
 */

params ["_house", "_door"];

if (isNull _house || {_door isEqualTo ""}) exitWith {[[], []]};

if (isNil QGVAR(doorAnimCache)) then {GVAR(doorAnimCache) = createHashMap};

private _cacheKey = format ["%1$%2", typeOf _house, _door];
private _cached = GVAR(doorAnimCache) get _cacheKey;
if (!isNil "_cached") exitWith {_cached};

private _animations = [];
private _lockedVariables = [];
private _doorLength = count _door;

{
    private _animName = toLowerANSI _x;
    private _index = _animName find _door;

    // Reject "door_1" matching "door_11_rot"
    if (_index != -1 && {!((_animName select [_index + _doorLength, 1]) in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])}) then {
        if (((_animName find "disabled") != -1) || {(_animName find "locked") != -1}) then {
            _lockedVariables pushBack _animName;
        } else {
            _animations pushBack _animName;
        };
    };
} forEach (animationNames _house);

private _result = [_animations, _lockedVariables];
GVAR(doorAnimCache) set [_cacheKey, _result];

_result
