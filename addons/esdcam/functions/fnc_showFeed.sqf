#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Blendet das Kamerabild auf der Gerätescheibe ein oder aus.
 *
 * Arguments:
 * 0: Anzeigen <BOOL>
 *
 * Return Value:
 * Keiner
 *
 * Example:
 * [true] call opw_esdcam_fnc_showFeed
 *
 * Public: No
 */

params [["_show", false, [false]]];

private _display = uiNamespace getVariable [SPECTRUM_DISPLAY, displayNull];
if (isNull _display) exitWith {};

private _fade = FADE_HIDE;
if (_show) then {_fade = FADE_SHOW};
{
    private _ctrl = _display displayCtrl _x;
    if (!isNull _ctrl) then {
        _ctrl ctrlSetFade _fade;
        _ctrl ctrlCommit 0;
    };
} forEach [IDC_FEED, IDC_FEED_GRAIN];
