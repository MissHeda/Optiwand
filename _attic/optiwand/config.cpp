#include "script_component.hpp"

class CfgPatches {
    class ADDON {
        name = COMPONENT_NAME;
#ifdef MODEL_READY
        units[] = {"OPW_Item_Optiwand"};
        weapons[] = {WAND_OPTIWAND};
#else
        units[] = {};
        weapons[] = {};
#endif
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {"opw_mirror"};
        author = "Miss Heda";
        url = ECSTRING(main,URL);
        VERSION_CONFIG;
    };
};

#ifdef MODEL_READY
#include "CfgEventHandlers.hpp"
#include "CfgWeapons.hpp"
#include "CfgVehicles.hpp"
#endif
