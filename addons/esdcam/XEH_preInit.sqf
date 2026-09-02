#include "script_component.hpp"

ADDON = false;

#include "XEH_PREP.hpp"
#include "initSettings.inc.sqf"

// Laufzeitzustand des Bildaufbaus
GVAR(pfh) = -1;
GVAR(acquire) = 0;
GVAR(acquired) = false;
GVAR(holding) = false;

uiNamespace setVariable [QGVAR(hidden), []];   // [Control, urspruenglicher Fade]

// Das Spectrum Device beim Spiegel-Teil als Stab anmelden - aber nur mit Kamerakopf.
//
// Der Eintrag in wandMuzzle ist der entscheidende: ohne ihn wuerde jedes Zielen mit dem
// Geraet unseren Monitor aufziehen, auch mit einer Antenne drin. So bleibt das Geraet ohne
// Kamera genau das, was es in Vanilla ist, und Crows Electronic Warfare merkt nichts davon.
//
// Die isNil-Abfragen sind Absicherung fuer den Fall, dass dieses Addon vor dem Spiegel-Teil
// laeuft - dessen preInit legt dieselben Behaelter an.
if (isNil QEGVAR(mirror,wandClasses)) then {EGVAR(mirror,wandClasses) = []};
if (isNil QEGVAR(mirror,wandMuzzle)) then {EGVAR(mirror,wandMuzzle) = createHashMap};

{
    EGVAR(mirror,wandClasses) pushBackUnique _x;
    EGVAR(mirror,wandMuzzle) set [_x, CAM_ITEM];
} forEach [
    "hgun_esd_01_F",
    "hgun_esd_01_antenna_01_F",
    "hgun_esd_01_antenna_02_F",
    "hgun_esd_01_antenna_03_F"
];

// Bewusst NICHT in screenWands eingetragen. Dort stehen Staebe, die das Render-Target auf
// ihrem eigenen Modell tragen - fuer die bleibt der Monitor aus, weil das Bild schon am
// Geraet ist. Das Spectrum Device kann das nicht, also ist der Monitor hier die Anzeige.

ADDON = true;
