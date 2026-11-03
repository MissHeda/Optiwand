#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Keeps the Spectrum Device's own housing and screen out of the aimed view while the device has
 * the camera fitted. The picture is on the field monitor, and only the attachment is left of the
 * device.
 *
 * They are two 3D objects on the display the engine opens the moment the device is raised, which
 * comes well before a peek starts, and which closes after it has ended. So this is not tied to
 * the peek: it runs per frame for as long as the device is in hand, and has them gone on the
 * first frame they exist. The weapon event in XEH_postInit starts and stops it. With an antenna
 * fitted nothing is touched, and taking the camera off while holding the device brings them back.
 *
 * Arguments:
 * 0: Device in hand <BOOL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [true] call opw_esdcam_fnc_hideDevice
 *
 * Public: No
 */

params [["_inHand", false, [false]]];

if (_inHand) exitWith {
    if (GVAR(devicePfh) != -1) exitWith {};

    GVAR(devicePfh) = [{
        private _display = uiNamespace getVariable [SPECTRUM_DISPLAY, displayNull];
        if (isNull _display) exitWith {GVAR(deviceScales) = []};

        if (!([ACE_player] call EFUNC(mirror,isWand))) exitWith {call FUNC(showDevice)};

        {
            private _ctrl = _display displayCtrl _x;
            if (!isNull _ctrl && {ctrlShown _ctrl}) then {
                // Shrunk as well: whether a 3D object honours ctrlShow in every engine state
                // cannot be told from outside the game, and a shrunken one is out of sight
                // regardless.
                GVAR(deviceScales) pushBack [_ctrl, ctrlModelScale _ctrl];
                _ctrl ctrlSetModelScale DEVICE_HIDDEN_SCALE;
                _ctrl ctrlShow false;
            };
        } forEach [IDC_DEVICE_MODEL, IDC_DEVICE_SCREEN];
    }, 0] call CBA_fnc_addPerFrameHandler;
};

if (GVAR(devicePfh) != -1) then {
    [GVAR(devicePfh)] call CBA_fnc_removePerFrameHandler;
    GVAR(devicePfh) = -1;
};

call FUNC(showDevice);
