#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Fades the camera picture on the field monitor in or out.
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

private _ctrl = (uiNamespace getVariable [QEGVAR(mirror,display), displayNull]) displayCtrl IDC_MONITOR_FEED;
if (isNull _ctrl) exitWith {};

private _fade = FADE_HIDE;
if (_show) then {_fade = FADE_SHOW};
_ctrl ctrlSetFade _fade;
_ctrl ctrlCommit 0;
