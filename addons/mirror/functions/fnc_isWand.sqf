#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Whether the weapon in hand counts as a mirror wand.
 *
 * Two stages: the class has to be registered, and if a muzzle attachment is recorded for
 * it, that has to be fitted as well. The second stage exists because of the Spectrum
 * Device - without a camera head it is a spectrum analyser and should keep behaving like
 * one, or every time you aimed it our view would come up.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * Counts as a wand <BOOL>
 *
 * Example:
 * [CURRENT_UNIT] call opw_mirror_fnc_isWand
 *
 * Public: No
 */

params ["_unit"];

private _weapon = currentWeapon _unit;
if !(_weapon in GVAR(wandClasses)) exitWith {false};

private _needed = GVAR(wandMuzzle) getOrDefault [_weapon, ""];
if (_needed isEqualTo "") exitWith {true};

// handgunItems returns [muzzle, pointer, optic, magazine]. Every wand so far sits in the
// handgun slot, and those are the only ones an attachment is demanded for.
_needed isEqualTo ((handgunItems _unit) param [0, ""])
