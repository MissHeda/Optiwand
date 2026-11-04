#include "script_component.hpp"

class CfgPatches {
    class ADDON {
        name = COMPONENT_NAME;
        // This addon is pure mechanics - devices register themselves (see opw_esdcam).
        units[] = {};
        weapons[] = {};
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {"opw_main", "A3_Ui_F"};
        author = "Miss Heda";
        url = ECSTRING(main,URL);
        VERSION_CONFIG;
    };
};

#include "CfgEventHandlers.hpp"
#include "gui.hpp"

// A cursor with nothing to see, for the lock's dialog - see fnc_lockDialog.
class CfgWrapperUI {
    class Cursors {
        class Arrow;
        class GVAR(blank): Arrow {
            texture = "#(argb,8,8,3)color(0,0,0,0,ca)";
        };
    };
};
