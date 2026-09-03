#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Ends the picture build-up and resets the device's transmit readout.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call opw_esdcam_fnc_stopAcquire
 *
 * Public: No
 */

if (GVAR(pfh) != -1) then {
    [GVAR(pfh)] call CBA_fnc_removePerFrameHandler;
    GVAR(pfh) = -1;
};

[false] call FUNC(showAcquire);

GVAR(acquire) = 0;
GVAR(acquired) = false;
GVAR(holding) = false;

// Resetting is mandatory, not cosmetic: if #EM_Transmit were left standing, the next time
// the device is raised the transmit overlay would sit over the spectrum with nobody
// transmitting - and it would do so even with no camera fitted.
missionNamespace setVariable ["#EM_Transmit", false];
missionNamespace setVariable ["#EM_Progress", 0];
