#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Where the wand starts, for placing the freehand head: the hand holding it.
 *
 * Measured from the hand rather than the eye so the head stays on the end of the wand you can
 * see, whatever the stance, lean or weapon sway. A unit without that memory point gets the old
 * estimate below the eye, so the peek still works.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * Position, ASL <ARRAY>
 *
 * Example:
 * [CURRENT_UNIT] call opw_mirror_fnc_wandBase
 *
 * Public: No
 */

params ["_unit"];

private _hand = _unit selectionPosition "righthand";
if (_hand isEqualTo [0, 0, 0]) exitWith {
    (eyePos _unit) vectorAdd [0, 0, -FREE_BASE_DROP]
};

_unit modelToWorldVisualWorld _hand
