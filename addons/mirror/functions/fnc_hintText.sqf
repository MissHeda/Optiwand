#include "..\script_component.hpp"
#include "\a3\ui_f\hpp\defineDIKCodes.inc"
/*
 * Author: Miss Heda
 * Builds the key legend for the monitor from the player's own bindings. A group of keys left at
 * its default keeps its short name, ARROWS rather than four key names; one that was rebound
 * shows what it is bound to now.
 *
 * Arguments:
 * 0: Mode <NUMBER>
 *
 * Return Value:
 * Legend, as structured text <STRING>
 *
 * Example:
 * [MODE_FREE] call opw_mirror_fnc_hintText
 *
 * Public: No
 */

params ["_mode"];

#define PLAIN [false, false, false]
#define CTRL [false, true, false]

private _fnc_label = {
    params ["_default", "_keys"];

    private _changed = false;
    private _names = _keys apply {
        _x params ["_action", "_key", "_modifiers"];
        private _bound = (["OPW", _action] call CBA_fnc_getKeybind) param [5, [-1, PLAIN]];
        if (_bound isNotEqualTo [_key, _modifiers]) then {_changed = true};
        [_bound call CBA_fnc_localizeKey, "-"] select ((_bound select 0) < 0)
    };

    [_default, _names joinString " / "] select _changed
};

private _aim = ["ARROWS", [
    [QGVAR(headUp), DIK_UP, PLAIN], [QGVAR(headDown), DIK_DOWN, PLAIN],
    [QGVAR(headLeft), DIK_LEFT, PLAIN], [QGVAR(headRight), DIK_RIGHT, PLAIN]
]] call _fnc_label;
private _extend = ["CTRL+UP/DN", [[QGVAR(extend2), DIK_UP, CTRL], [QGVAR(retract2), DIK_DOWN, CTRL]]] call _fnc_label;
private _slide = ["CTRL+L/R", [[QGVAR(slideLeft2), DIK_LEFT, CTRL], [QGVAR(slideRight2), DIK_RIGHT, CTRL]]] call _fnc_label;
private _zoom = ["PGUP/PGDN", [[QGVAR(zoomIn2), DIK_PRIOR, PLAIN], [QGVAR(zoomOut2), DIK_NEXT, PLAIN]]] call _fnc_label;
private _night = ["N", [[QGVAR(nightVision), DIK_N, PLAIN]]] call _fnc_label;
private _recentre = ["R", [[QGVAR(recentre2), DIK_R, PLAIN]]] call _fnc_label;

if (_mode isEqualTo MODE_FREE) exitWith {
    format [LLSTRING(Feed_Hints_Free), _aim, _extend, _zoom, _night, _recentre]
};
format [LLSTRING(Feed_Hints), _aim, _extend, _slide, _zoom, _night, _recentre]
