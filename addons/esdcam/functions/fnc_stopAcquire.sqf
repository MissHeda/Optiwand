#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Ends the picture build-up.
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
// By now the overlay may be gone, and then that had nothing to do. The next one is a fresh
// overlay with its readout faded out, whatever this was showing last.
GVAR(acqShown) = -1;

GVAR(acquire) = 0;
GVAR(acquired) = false;
GVAR(holding) = false;
