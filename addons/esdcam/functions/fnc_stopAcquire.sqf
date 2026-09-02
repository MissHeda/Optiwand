#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Beendet den Bildaufbau und setzt die Sendeanzeige des Geraets zurueck.
 *
 * Arguments:
 * Keine
 *
 * Return Value:
 * Keiner
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

GVAR(acquire) = 0;
GVAR(acquired) = false;
GVAR(holding) = false;

// Zuruecksetzen ist Pflicht, nicht Kosmetik: bliebe #EM_Transmit stehen, laege beim
// naechsten Hochnehmen des Geraets der Sendeschleier ueber dem Spektrum, ohne dass
// jemand sendet - und das waere dann auch ohne Kameraaufsatz so.
missionNamespace setVariable ["#EM_Transmit", false];
missionNamespace setVariable ["#EM_Progress", 0];
