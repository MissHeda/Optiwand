#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Schaltet die Restlichtverstaerkung der Kamera um. Die Kamera hat ihre eigene, es spielt
 * also keine Rolle, was der Spieler auf dem Kopf traegt.
 *
 * Arguments:
 * Keine
 *
 * Return Value:
 * Behandelt <BOOL>
 *
 * Example:
 * call opw_mirror_fnc_toggleNightVision
 *
 * Public: No
 */

if (!GVAR(active)) exitWith {false};

GVAR(nightVision) = !GVAR(nightVision);

// Zwei Haelften: der Effekt im Render-Target und ein Schleier ueber der Anzeige. Der
// Schleier macht den Schaltvorgang auch dort unmissverstaendlich, wo der Render-Effekt
// kaum etwas bewirkt.
RTT_NAME setPiPEffect [parseNumber GVAR(nightVision)];

private _ctrlIrTint = uiNamespace getVariable [QGVAR(ctrlIrTint), controlNull];
if (!isNull _ctrlIrTint) then {
    _ctrlIrTint ctrlShow GVAR(nightVision);
};

// Erzwingt, dass die Anzeige im selben Frame neu zeichnet
GVAR(readoutState) = [];

true
