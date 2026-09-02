#define COMPONENT mirror
#define COMPONENT_BEAUTIFIED Mirror Mechanics
#include "\z\opw\addons\main\script_mod.hpp"

// #define DEBUG_MODE_FULL
// #define DISABLE_COMPILE_CACHE
// #define ENABLE_PERFORMANCE_COUNTERS

#ifdef DEBUG_ENABLED_MIRROR
    #define DEBUG_MODE_FULL
#endif

#ifdef DEBUG_SETTINGS_MIRROR
    #define DEBUG_SETTINGS DEBUG_SETTINGS_MIRROR
#endif

#include "\z\opw\addons\main\script_macros.hpp"

////////////////////////////////////////////////////////////////////////////////
// Weapon / assets
////////////////////////////////////////////////////////////////////////////////

// Dieses Addon enthaelt keine Waffe mehr. Der Stab auf Basis des Spectrum Device ist
// entfallen - es gibt jetzt ein eigenes Modell, und zwei Geraete fuer dieselbe Aufgabe
// waeren nur Ballast. Welche Waffen als Spiegelstab zaehlen, steht zur Laufzeit in
// GVAR(wandClasses); eingetragen wird das vom jeweiligen Waffen-Addon selbst.

#define ICON_MIRROR     "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\scout_ca.paa"

// Screen mask drawn on top of the feed: opaque surround, rounded transparent centre.
// This is what gives the picture rounded corners and a vignette instead of a hard rectangle.
#define TEXTURE_SCREENMASK "\z\ace\addons\viewports\data\optic_window_ca.paa"

// Optional: one image of a device with a fully transparent screen cutout. Leave "" and the
// housing is built from procedural colours instead. If you set it, DEVICE_CUT_* say where the
// cutout sits inside that image as fractions of the image, and the feed is fitted into it -
// the image is then scaled so the cutout lands exactly on the feed.
//   e.g. a 1024x640 image whose cutout runs from px 96..928 across and 72..520 down gives
//   L 0.094  T 0.113  R 0.906  B 0.813
#define TEXTURE_DEVICE  ""
#define DEVICE_CUT_L    0.07
#define DEVICE_CUT_T    0.12
#define DEVICE_CUT_R    0.93
#define DEVICE_CUT_B    0.80

////////////////////////////////////////////////////////////////////////////////
// Render target / dialog
////////////////////////////////////////////////////////////////////////////////

#define RTT_NAME        QGVAR(rtt)

// Kantenlaenge des Render-Targets. 512 war auf dem bildschirmbreiten Monitor sichtbar
// ausgefranst, 1024 deutlich besser, 2048 die letzte Stufe, die noch etwas bringt.
//
// Warum ueberhaupt so viel: der Puffer ist quadratisch, das Bild darin hat aber das Format
// des Spielerbildschirms. Es wird also einmal in das Quadrat gestaucht und auf dem Monitor
// wieder auseinandergezogen - zweimal umgerechnet, und jedes Mal geht Schaerfe verloren.
// Ein Puffer im richtigen Seitenverhaeltnis waere sparsamer, aber Arma legt das Format des
// Render-Targets selbst fest; die Zahlen hier steuern nur die Groesse.
//
// Das laeuft nur, solange der Spiegel draussen ist - im Betrieb kostet es also nichts.
//
// Muss mit OPTIWAND_SCREEN im Waffen-Addon uebereinstimmen. Wer Bildrate braucht, setzt
// beide zurueck auf 1024.
#define RTT_SIZE        2048
#define IDD_MIRROR      91401

#define IDC_CURSORKILL  9140090
#define IDC_DEVICE      9140099
#define IDC_BODY        9140100
#define IDC_BEZEL       9140101
#define IDC_FEED        9140102
#define IDC_SCREENMASK  9140103
#define IDC_TOPBAR      9140105
#define IDC_TITLE       9140106
#define IDC_READOUT     9140108
#define IDC_BOTBAR      9140109
#define IDC_HINTS       9140110
#define IDC_BRAND       9140111
#define IDC_FAULT       9140115
#define IDC_IRTINT      9140116
#define IDC_SCREW_TL    9140120
#define IDC_SCREW_TR    9140121
#define IDC_SCREW_BL    9140122
#define IDC_SCREW_BR    9140123

////////////////////////////////////////////////////////////////////////////////
// Door detection
////////////////////////////////////////////////////////////////////////////////

// How far in front of the camera we look for a door (same idea as ACE's door reach)
#define DOOR_REACH_DISTANCE (((AGLToASL positionCameraToWorld [0, 0, 0]) vectorDistance (ACE_player modelToWorldWorld (ACE_player selectionPosition "Head"))) + 2)

// Wie weit um den Spieler herum nach einer Tuer gesucht wird, und in welcher Hoehe.
// Die Suche haengt bewusst nicht am Blick: wer neben einer Tuer steht, soll den Spiegel
// anbieten koennen, ohne sie erst anzuvisieren. Abgetastet wird ein Faecher aus
// DOOR_SEARCH_RAYS Strahlen rundherum.
#define DOOR_SEARCH_RADIUS  3.2
#define DOOR_SEARCH_HEIGHT  0.9
#define DOOR_SEARCH_RAYS    12

// Interact-menu action point sits this far above the bottom edge of the door
#define ACTION_HEIGHT       0.06
// Interaction radius of the action point. Muss mindestens so weit reichen wie die Suche
// oben, sonst findet der Faecher eine Tuer, die das ACE-Menue dann nicht mehr anzeigt.
#define ACTION_DISTANCE     3.6

////////////////////////////////////////////////////////////////////////////////
// Door measuring
////////////////////////////////////////////////////////////////////////////////

// Sampling resolution when walking along a door to find its edges
#define PANEL_STEP          0.08
// Give up past this - no door leaf is 1.4 m from its own centre
#define PANEL_MAX           1.44
// Half length of the ray pushed through the door while sampling
#define PANEL_PROBE_REACH   0.4
// Used when sampling fails and we fall back to the aim point
#define PANEL_FALLBACK_HALF 0.35

// Selections that say outright they are not a door
#define WINDOW_TOKENS       ["window", "okno", "vitrine", "shutter"]

// A door reaches the floor, a window does not. Anything whose bottom edge sits higher
// than this above the operator's feet is a window and gets handed to freehand instead.
#define DOOR_SILL_MAX       0.45

////////////////////////////////////////////////////////////////////////////////
// Mirror head
////////////////////////////////////////////////////////////////////////////////

#define YAW_LIMIT           95
#define PITCH_MIN           (-35)
#define PITCH_MAX           55
#define PITCH_DEFAULT       8
// Deploy modes
#define MODE_DOOR           0
#define MODE_FREE           1
// Nothing to show, just the device reporting it cannot be worked here
#define MODE_FAULT          2

// Freehand: the head sits on the end of the shaft. Base drops below the eye, roughly where
// the wand is actually held, and the reach is fixed - no pushing it further out from there.
#define FREE_BASE_DROP      0.22
// How far out the head sits in freehand mode, before anything in the way shortens it.
//
// Stand vorher: 1.25 m. Das ist ueber einen halben Meter jenseits der Stabspitze, der Kopf
// schwebte also frei in der Luft statt am Geraet zu sitzen. Gemessen: ausgestreckter Arm ab
// Handhoehe rund 0.2 m plus 0.41 m Stablaenge. 0.55 setzt den Kopf knapp vor die Spitze,
// wo bei einem Spiegelstab auch der Spiegel sitzt.
// 0.55 sass noch knapp hinter der Spitze, im Spiel nachgemessen fehlten 10 cm.
// Grundreichweite im Freihandmodus. Der Feinversatz liegt in den Einstellungen
// (freeOffset*), damit er sich im Spiel ausprobieren laesst statt hier geraten.
#define POLE_LENGTH         0.65

// Refuse to deploy if there is less clear air than this in front of the operator
#define FREE_MIN_CLEAR      0.35

// Wie weit der Kopf ueber der Stabachse sitzt. Ohne das schaut die Kamera beim Hochschwenken
// am eigenen Modell entlang - der Stab steht dann mitten im Bild. Ein paar Zentimeter
// darueber, und das Geraet bleibt unterhalb des Blickfelds.
#define FREE_CAM_LIFT       0.08

// Wie weit sich der Kopf im Freihandmodus ueber die Ausgangslage hinaus schieben laesst.
// Bewusst klein: der Arm ist ausgestreckt, viel mehr als ein Nachfassen um Handbreite gibt
// die Haltung nicht her. Die Wandpruefung greift trotzdem und stoppt frueher, wenn etwas
// im Weg ist.
#define FREE_EXTEND         0.25

// How far around the operator loose shafts are hunted down after a detach
#define SHAFT_SWEEP_RANGE   8
// A mirror on a stick does not look backwards
#define FREE_YAW_LIMIT      100
#define FREE_PITCH_MIN      (-75)
#define FREE_PITCH_MAX      75

#define DEPTH_MIN           0.02
#define DEPTH_DEFAULT       0.14
// camSetFov: kleinere Zahl = staerker gezoomt. 0.75 entspricht ungefaehr der normalen
// Spielansicht.
//
// 0.75 war als Grundwert zu eng - man schiebt den Spiegel unter eine Tuer, um moeglichst
// viel vom Raum zu sehen, nicht um jemanden anzuvisieren. 1.15 war dann zu weit: oberhalb
// von etwa 1.2 zieht Arma das Bild sichtbar auseinander, gerade Kanten werden krumm und es
// sieht aus wie eine Tuerspion-Linse. 0.90 ist spuerbar weiter als normal und noch ohne
// Verzerrung; die Obergrenze bleibt knapp unter der Schmerzgrenze.
// Ich habe hier lange in der falschen Groessenordnung gesucht. Die Werte 0.75 bis 1.15
// stammen aus der Vorstellung, ein Render-Target verhalte sich wie die Hauptansicht - tut es
// nicht. Im Spiel gemessen: bei 0.82 sah ein Ziel in wenigen Metern Entfernung aus wie auf
// zwanzig. Das ist rund der Faktor vier, also gehoert der Grundwert eine Groessenordnung
// tiefer.
//
// 0.22 ist der neue Ausgangspunkt. Die Untergrenze liegt bewusst weit darunter, damit die
// Einstellung Luft nach beiden Seiten hat und nicht wieder an einem von mir geratenen Rand
// anschlaegt.
#define FOV_MIN             0.05
#define FOV_MAX             1.20
#define FOV_DEFAULT         0.22

// Keep the head clear of the door frame when sliding sideways
#define SLIDE_MARGIN        0.17

#define RATE_YAW            55
#define RATE_PITCH          40
#define RATE_DEPTH          0.25
#define RATE_SLIDE          0.25
#define RATE_ZOOM_KEY       0.35

////////////////////////////////////////////////////////////////////////////////
// Keeping the head out of solid geometry
////////////////////////////////////////////////////////////////////////////////

// Floor is re-probed once the head has moved further than this
#define PROBE_TOLERANCE     0.02
// Probe window around the expected floor height
#define PROBE_UP            0.3
#define PROBE_DOWN          0.9
// Stop this far short of whatever the head ran into
#define COLLISION_CLEARANCE 0.09

////////////////////////////////////////////////////////////////////////////////
// Session
////////////////////////////////////////////////////////////////////////////////

// Auto-retract once the operator steps away from where they deployed
#define ABORT_DISTANCE      1.5
// A door counts as "open" from this animation phase up
#define DOOR_OPEN_PHASE     0.25

// Axis indices for GVAR(axes)
#define AXIS_YAW            0
#define AXIS_PITCH          1
#define AXIS_DEPTH          2
#define AXIS_FOV            3
#define AXIS_SLIDE          4
