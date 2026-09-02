#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Setzt Kopfschwenk, Ausfahrweite und Zoom auf die Ausgangslage zurueck.
 *
 * Arguments:
 * Keine
 *
 * Return Value:
 * Behandelt <BOOL>
 *
 * Example:
 * call opw_mirror_fnc_recentre
 *
 * Public: No
 */

if (!GVAR(active)) exitWith {false};

GVAR(yaw) = 0;
// Funktioniert in beiden Modi: an der Tuer ist basePitch der Ruhewinkel, freihand ist er
// null und GVAR(pitch) damit die Ablage auf die Blickrichtung.
GVAR(pitch) = GVAR(basePitch);
GVAR(depth) = GVAR(depthDefault);
GVAR(slide) = 0;
GVAR(fov) = GVAR(fovStart);

if (!isNull GVAR(camera)) then {
    GVAR(camera) camSetFov GVAR(fov);
    GVAR(camera) camCommit 0;
};

// Die Kollisionspruefung darf von der neuen Lage aus neu bewerten
GVAR(lastCamPosASL) = [];

true
