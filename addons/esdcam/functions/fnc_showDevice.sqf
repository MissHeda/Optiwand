#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Puts back what fnc_hideDevice took out of the aimed view.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call opw_esdcam_fnc_showDevice
 *
 * Public: No
 */

{
    _x params ["_ctrl", "_scale"];
    if (!isNull _ctrl) then {
        _ctrl ctrlSetModelScale _scale;
        _ctrl ctrlShow true;
    };
} forEach GVAR(deviceScales);
GVAR(deviceScales) = [];
