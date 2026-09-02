#include "script_component.hpp"

class CfgPatches {
    class ADDON {
        name = COMPONENT_NAME;
        units[] = {};
        weapons[] = {CAM_ITEM};
        requiredVersion = REQUIRED_VERSION;
        // A3_Weapons_F_Enoch_Pistols_ESD ist die Contact-Erweiterung. Ohne sie gibt es kein
        // Spectrum Device, an das sich etwas anstecken liesse - also eine harte Abhaengigkeit.
        // opw_mirror liefert die gesamte Mechanik und muss vor uns geladen sein, damit die
        // Behaelter stehen, in die wir uns eintragen.
        //
        // Crows Electronic Warfare wird ausdruecklich NICHT gebraucht: die Muendungsslots und
        // die Antennen sind bereits Vanilla und dort schon scope = 2.
        requiredAddons[] = {"opw_mirror", "A3_Weapons_F_Enoch_Pistols_ESD"};
        author = "Miss Heda";
        url = ECSTRING(main,URL);
        VERSION_CONFIG;
    };
};

#include "CfgEventHandlers.hpp"
#include "CfgWeapons.hpp"
#include "gui.hpp"
