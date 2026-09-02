#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Baut das Bild auf, solange die linke Maustaste gehalten wird, und treibt dabei die
 * Sendeanzeige des Geraets.
 *
 * #EM_Transmit und #EM_Progress sind Engine-Variablen des Spectrum Device: Bohemia zeichnet
 * daraus selbst den Sendeschleier und den Fortschrittsbalken auf der Scheibe. Wir muessen
 * also nichts nachbauen - dieselben zwei Variablen benutzt auch Crows Electronic Warfare.
 *
 * Arguments:
 * Keine (als Frame-Handler aufgerufen)
 *
 * Return Value:
 * Keiner
 *
 * Example:
 * call opw_esdcam_fnc_acquireTick
 *
 * Public: No
 */

// Der Spiegel-Teil raeumt beim Einholen selbst auf und schickt uns sein Ereignis. Kommt der
// Handler trotzdem noch einmal dran - Tod, Missionsende -, beendet er sich hier selbst.
if (!EGVAR(mirror,active)) exitWith {
    call FUNC(stopAcquire);
};

if (GVAR(acquired)) exitWith {};

private _delta = diag_deltaTime;
private _step = _delta / (GVAR(acquireTime) max 0.1);

if (GVAR(holding)) then {
    GVAR(acquire) = (GVAR(acquire) + _step) min 1;
} else {
    // Loslassen faellt schneller zurueck als der Aufbau steigt. Sonst laesst sich der Balken
    // durch kurzes Antippen im Sekundentakt hochtragen, und das Halten waere sinnlos.
    GVAR(acquire) = (GVAR(acquire) - _step * 2) max 0;
};

missionNamespace setVariable ["#EM_Transmit", GVAR(holding)];
missionNamespace setVariable ["#EM_Progress", GVAR(acquire)];

if (GVAR(acquire) >= 1) then {
    GVAR(acquired) = true;
    missionNamespace setVariable ["#EM_Transmit", false];
    missionNamespace setVariable ["#EM_Progress", 0];
    [true] call FUNC(showFeed);
};
