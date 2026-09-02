#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Right click to deploy. Aiming down sight with the wand in hand casts for a door and opens
 * the monitor if it finds one. Nothing happens if it does not, so it costs nothing to try -
 * the same reflex the vanilla Spectrum Device trains, where aiming brings up its own screen.
 *
 * Edge triggered: the view has to leave the aimed state before it can fire again, otherwise
 * closing the monitor while still holding right mouse would reopen it immediately.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call opw_mirror_fnc_watchAim
 *
 * Public: No
 */

// While the monitor is up the latch is owned by fnc_closeView - do not touch it
if (GVAR(active)) exitWith {};

private _player = ACE_player;

// Cheap early out - this runs whether or not the wand is out
// Prueft auch den Muendungsaufsatz, wo einer verlangt wird - das Spectrum Device ohne
// Kamerakopf soll beim Zielen weiter sein eigenes Spektrum zeigen und nicht unseren Monitor.
if (!([_player] call FUNC(isWand))) exitWith {
    GVAR(aimLatched) = false;
};

private _aiming = (cameraView isEqualTo "GUNNER") && {isNull objectParent _player};

if (!_aiming) exitWith {
    GVAR(aimLatched) = false;
    GVAR(viewBefore) = cameraView;
};

if (GVAR(aimLatched)) exitWith {};

GVAR(aimLatched) = true;

// Silent: no "no door here" nagging every time the operator happens to aim
[true] call FUNC(deployFromCursor);
