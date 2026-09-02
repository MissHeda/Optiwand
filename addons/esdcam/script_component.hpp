#define COMPONENT esdcam
#define COMPONENT_BEAUTIFIED ESD Camera
#include "\z\opw\addons\main\script_mod.hpp"
#include "\z\opw\addons\main\script_macros.hpp"

// ---------------------------------------------------------------------------------------
// Kameraaufsatz fuer das Spectrum Device aus der Contact-Erweiterung.
//
// Aus dessen eigener Config abgelesen (a3\Weapons_F_Enoch\Pistols\ESD_01\config.bin):
//
//   hgun_esd_01_base_F   weaponInfoType = "RscWeaponSpectrumAnalyzerGeneric"
//                        WeaponSlotsInfo > MuzzleSlot / MuzzleSlot2 / MuzzleSlot3
//   muzzle_antenna_0*_f  class EM { antenna = ... }, Basis muzzle_antenna_base_01_F
//
// Wir haengen in MuzzleSlot - denselben Platz, den sonst die Richtantenne belegt. Damit ist
// die Kamera eine echte Alternative zur Antenne und keine zweite Waffe.
//
// ---------------------------------------------------------------------------------------
// Das Bild liegt auf der Scheibe des Geraets
//
// Die Geraeteanzeige zeichnet ihre Controls ueber "class Areas > Usertexture" auf ein
// echtes 3D-Modell (analyzer_screen.p3d). Da hinein haengen wir das Kamerabild - zwischen
// den Kompass und die Signalanzeige von Bohemia, also genau dorthin, wo es hingehoert.
//
// Wichtig: die gesperrte Steuerung steht dem nicht im Weg. Der Dialog aus fnc_openView
// faengt zwar Tastatur und Maus ab, wirft den Spieler aber NICHT aus dem Zielen - das
// Geraet bleibt in der Hand und seine Anzeige offen. Ich hatte das Gegenteil behauptet;
// im Spiel ist unten am Bildrand das Geraet weiterhin zu sehen.
//
// Eine eigene Kamera braucht es dafuer nicht: der Spiegel-Teil betreibt bereits eine und
// rendert nach opw_mirror_rtt. Wir zeigen dasselbe Ziel nur an einer zweiten Stelle an.
// ---------------------------------------------------------------------------------------

// Muss zu RTT_NAME und RTT_SIZE in addons\mirror\script_component.hpp passen.
#define FEED_TEXTURE "#(argb,2048,2048,1)r2t(opw_mirror_rtt,1)"

// Eigene Controls. Hoch genug, dass sie keiner Vanilla-Vergabe in die Quere kommen:
// belegt sind dort 10/11, 999, 1994-1999, 3000-3xxx, 4000-4005, 5500-5802, 6700-6714.
#define IDC_FEED 71010
#define IDC_FEED_GRAIN 71012

// Vanilla-Controls, die im Kamerabetrieb weg muessen. Aus ui_f_enoch abgelesen: das Bild
// deckt die Plotflaeche ab, die Beschriftungen liegen aber daneben - LabelsV links davon,
// LabelsH und der ausgewaehlte Text darunter. Die blieben sonst stehen und wuerden zu einem
// Kamerabild dBm und MHz anzeigen.
#define IDC_LINES 1999
#define IDC_LABELS_V 5550
#define IDC_LABELS_H 5650
#define IDC_SIGNAL_TEXT 5802
#define IDC_NO_ANTENNA 1998
#define IDC_SELECTED 4000
#define IDC_FOCUS 4002
#define IDC_PROGRESS 4005
#define IDC_SELECTED_TEXT 4001

// Der Kompass bleibt bewusst an. Er sitzt oberhalb der Plotflaeche und ist der Grund,
// warum das Ganze nach Werkszustand aussieht statt nach Aufsatz.
#define IDC_COMPASS 5700

#define SPECTRUM_DISPLAY "RscWeaponSpectrumAnalyzerGeneric"

// Faengt alle Varianten des Geraets ab: hgun_esd_01_F selbst und die drei mit fest
// verbauter Antenne.
#define ESD_WEAPON_PREFIX "hgun_esd_"

// Muss zu MODE_DOOR in addons\mirror\script_component.hpp passen. Der Spiegel-Teil
// schickt den Modus im deployed-Ereignis mit.
#define MODE_DOOR 0

#define FADE_SHOW 0
#define FADE_HIDE 1

// Zwei Schreibweisen desselben Namens: die Klasse wird unquotiert deklariert, ueberall
// sonst - weapons[], compatibleItems[], Vergleiche im Skript - steht die Zeichenkette.
#define CAM_ITEM_CLASS opw_muzzle_camera
#define CAM_ITEM QUOTE(CAM_ITEM_CLASS)

// Eigenes Modell: die Schwanenhalskamera aus mia.blend, ueber tools/blender_camhead.py
// ausgerichtet und exportiert. 42 cm lang, Stecker im Ursprung, Kopf nach -X - dieselbe
// Lage wie die drei Vanilla-Antennen, gemessen aus deren p3d.
#define CAM_MODEL QPATHTOF(model\camhead.p3d)

// Inventarbild noch von der Vanilla-Antenne. Liegt in Contact, das wir ohnehin voraussetzen,
// also kein fehlender Pfad - aber ein Platzhalter, bis ein Render des eigenen Modells da ist.
#define CAM_PICTURE "\a3\Weapons_F_Enoch\Pistols\ESD_01\data\ui\gear_muzzle_antenna_01_ca.paa"
