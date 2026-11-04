#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Switches the monitor between the camera picture and the "no clearance" report.
 *
 * This used to be a deploy mode of its own, decided once when the operator right clicked,
 * and it had two things wrong with it. It refused before there was any picture to refuse -
 * you were told the shaft could not extend at the moment you raised the device, not at the
 * moment it would have shown you something. And a fault deploy got no per frame handler,
 * which meant nothing was left running that could close it again: right click was ignored
 * because the aim watcher stands down while the monitor is up, and Escape does nothing to a
 * title layer. The operator was stuck.
 *
 * So it is a state now, measured every frame in fnc_update from the reach the head actually
 * achieved. Step back from the wall and the picture comes up on its own; no redeploy, and
 * nothing to get stuck in.
 *
 * Arguments:
 * 0: Faulted <BOOL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [true] call opw_mirror_fnc_setFault
 *
 * Public: No
 */

params [["_faulted", false, [false]]];

if (!GVAR(active)) exitWith {};
if (_faulted isEqualTo GVAR(faulted)) exitWith {};

GVAR(faulted) = _faulted;

private _display = uiNamespace getVariable [QGVAR(display), displayNull];
if (isNull _display) exitWith {};

private _ctrlHints = _display displayCtrl IDC_HINTS;
private _ctrlReadout = _display displayCtrl IDC_READOUT;

// Two lines when faulted, one when not: the report takes the readout's row as well, and the
// readout has nothing worth saying while there is no picture anyway.
_ctrlReadout ctrlShow (!_faulted);

private _text = GVAR(hintText);
if (_faulted) then {
    _text = format ["%1<br/>%2", LLSTRING(Fault_NoClearance), LLSTRING(Feed_Hints_Fault)];
};

private _ctrlBand = _display displayCtrl IDC_OSD_BOTTOM;
_ctrlBand ctrlSetPosition ([GVAR(osdRect), GVAR(osdRectFault)] select _faulted);
_ctrlBand ctrlCommit 0;

_ctrlHints ctrlSetPosition ([GVAR(stripRect), GVAR(stripRectFault)] select _faulted);
_ctrlHints ctrlSetStructuredText parseText _text;
_ctrlHints ctrlCommit 0;

// The device addon takes the picture off the monitor while this is up - a live camera picture
// over a "no clearance" report would contradict itself.
[QGVAR(fault), [_faulted]] call CBA_fnc_localEvent;
