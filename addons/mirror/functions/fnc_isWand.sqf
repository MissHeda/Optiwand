#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Ob die Waffe in der Hand als Spiegelstab zaehlt.
 *
 * Zwei Stufen: die Klasse muss eingetragen sein, und falls fuer sie ein Muendungsaufsatz
 * hinterlegt ist, muss auch der sitzen. Letzteres gibt es wegen des Spectrum Device - ohne
 * Kamerakopf ist das ein Spektrumanalysator und soll sich auch weiter so verhalten, sonst
 * wuerde jedes Zielen damit unseren Monitor aufziehen.
 *
 * Arguments:
 * 0: Einheit <OBJECT>
 *
 * Return Value:
 * Zaehlt als Stab <BOOL>
 *
 * Example:
 * [ACE_player] call opw_mirror_fnc_isWand
 *
 * Public: No
 */

params ["_unit"];

private _weapon = currentWeapon _unit;
if !(_weapon in GVAR(wandClasses)) exitWith {false};

private _needed = GVAR(wandMuzzle) getOrDefault [_weapon, ""];
if (_needed isEqualTo "") exitWith {true};

// handgunItems liefert [Muendung, Zeiger, Optik, Magazin]. Alle bisherigen Staebe sitzen
// im Pistolenslot, und nur fuer die wird ueberhaupt ein Aufsatz verlangt.
_needed isEqualTo ((handgunItems _unit) param [0, ""])
