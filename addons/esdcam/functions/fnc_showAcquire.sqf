#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Drives the acquisition readout on the field monitor's dark screen: what to do while nothing
 * is held, and a filling bar once it is.
 *
 * Arguments:
 * 0: Show <BOOL>
 * 1: Progress, 0..1 <NUMBER> (default: 0)
 *
 * Return Value:
 * None
 *
 * Example:
 * [true, 0.4] call opw_esdcam_fnc_showAcquire
 *
 * Public: No
 */

params [["_show", false, [false]], ["_progress", 0, [0]]];

private _display = uiNamespace getVariable [QEGVAR(mirror,display), displayNull];
if (isNull _display) exitWith {};

private _label = _display displayCtrl IDC_MONITOR_ACQ_LABEL;
private _track = _display displayCtrl IDC_MONITOR_ACQ_TRACK;
private _fill = _display displayCtrl IDC_MONITOR_ACQ_FILL;

if (!_show) exitWith {
    if (GVAR(acqShown) isEqualTo -1) exitWith {};
    {
        _x ctrlSetFade FADE_HIDE;
        _x ctrlCommit 0;
    } forEach [_label, _track, _fill];
    GVAR(acqShown) = -1;
};

// Whole percents: this runs every frame while the button is held, and nothing on screen can
// show less than that.
private _percent = round (_progress * 100);
if (_percent isEqualTo GVAR(acqShown)) exitWith {};
GVAR(acqShown) = _percent;

// Two different things to say, and the difference is the point of the whole control: with
// nothing held the operator needs telling what to do, and once it is moving they need to see
// that it is moving.
private _text = if (_percent <= 0) then {
    LLSTRING(Acquire_Prompt)
} else {
    format [LLSTRING(Acquire_Progress), _percent]
};
_label ctrlSetText _text;

ctrlPosition _track params ["_x0", "_y0", "_w0", "_h0"];
_fill ctrlSetPosition [_x0, _y0, _w0 * _progress, _h0];

{
    _x ctrlSetFade FADE_SHOW;
    _x ctrlCommit 0;
} forEach [_label, _track, _fill];
