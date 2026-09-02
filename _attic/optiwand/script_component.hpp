#define COMPONENT optiwand
#define COMPONENT_BEAUTIFIED Optiwand
#include "\z\opw\addons\main\script_mod.hpp"
#include "\z\opw\addons\main\script_macros.hpp"

// Flip this off again if the model ever goes missing - the addon then loads and does
// nothing, so a missing p3d cannot spam the RPT.
#define MODEL_READY

#define WAND_OPTIWAND   "opw_Optiwand"
#define OPTIWAND_MODEL  QPATHTOF(model\mirrorgun.p3d)

// Das Bild liegt jetzt im eigenen PBO. Vorher zeigte es auf eine Contact-Datei, was beim
// Anschauen im Inventar einen Pfadfehler gab - und die letzte Abhaengigkeit von fremden
// Daten war. Es ist noch ein Platzhalter: das Bild stammt vom alten Stab, nicht von diesem
// Modell. Ein sauberer Render davon kann es jederzeit ersetzen, gleicher Dateiname.
#define OPTIWAND_PIC    QPATHTOF(data\ui\gear_optiwand_ca.paa)

// Must match RTT_NAME in the mirror component. Written out in full because the render target
// name has to sit inside the texture string.
#define OPTIWAND_SCREEN "#(argb,2048,2048,1)r2t(opw_mirror_rtt,1)"
