#include "script_component.hpp"

class CfgPatches {
    class ADDON {
        name = COMPONENT_NAME;
        units[] = {};
        weapons[] = {CAM_ITEM};
        requiredVersion = REQUIRED_VERSION;
        // A3_Weapons_F_Enoch_Pistols_ESD is the Contact platform. Without it there is no
        // Spectrum Device to attach anything to, so this is a hard dependency.
        // opw_mirror carries all of the mechanics and has to load before us, so the
        // containers we register into already exist.

        requiredAddons[] = {"opw_mirror", "A3_Weapons_F_Enoch_Pistols_ESD"};
        author = "Miss Heda";
        url = ECSTRING(main,URL);
        VERSION_CONFIG;
    };
};

#include "CfgEventHandlers.hpp"
#include "CfgWeapons.hpp"
