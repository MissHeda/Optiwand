#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Brings the camera picture on the field monitor up, or takes it off for the dark screen.
 *
 * Arguments:
 * 0: Show <BOOL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [true] call opw_esdcam_fnc_showFeed
 *
 * Public: No
 */

params [["_show", false, [false]]];

private _display = uiNamespace getVariable [QEGVAR(mirror,display), displayNull];
if (isNull _display) exitWith {};

(_display displayCtrl IDC_MONITOR_SCREEN) ctrlShow (!_show);

// Parked rather than hidden while there is no picture: a render target needs something drawing it.
EGVAR(mirror,screenRect) params ["_x0", "_y0", "_w0", "_h0"];
private _feed = _display displayCtrl IDC_MONITOR_FEED;
_feed ctrlSetPosition ([[_x0, _y0, 0.001, 0.001], [_x0, _y0, _w0, _h0]] select _show);
_feed ctrlCommit 0;
