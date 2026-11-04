#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Whether a unit is holding a mirror wand. They are handgun slot weapons, so one has to be
 * the selected weapon - carrying it holstered does not count.
 * More than one model can be registered, see GVAR(wandClasses).
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * Wand in hand <BOOL>
 *
 * Example:
 * [CURRENT_UNIT] call opw_mirror_fnc_wandReady
 *
 * Public: No
 */

params ["_unit"];

if (!GVAR(requireItem)) exitWith {true};

[_unit] call FUNC(isWand)
