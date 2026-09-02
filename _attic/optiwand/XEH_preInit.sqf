#include "script_component.hpp"

ADDON = false;

// Register with the mirror component so every check there - in hand, aiming, deploying -
// treats this weapon exactly like the ESD based one. No logic is duplicated.
if (isNil QEGVAR(mirror,wandClasses)) then {EGVAR(mirror,wandClasses) = []};
EGVAR(mirror,wandClasses) pushBackUnique WAND_OPTIWAND;

// Dieses Modell hat einen echten Bildschirm mit eigenem Material und eigenen UVs, auf dem
// das Render-Target liegt. Also kein Monitor-Panel davor - das Bild sitzt am Geraet.
if (isNil QEGVAR(mirror,screenWands)) then {EGVAR(mirror,screenWands) = []};
EGVAR(mirror,screenWands) pushBackUnique WAND_OPTIWAND;

ADDON = true;
