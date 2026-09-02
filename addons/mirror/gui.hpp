#include "\a3\ui_f\hpp\defineResincl.inc"

// The monitor is a real dialog, not an RscTitles layer: while the wand is deployed the
// operator is crouched at the door with both hands on the thing, so movement, weapon and
// interaction input are all locked out. The mouse cursor is killed with an invisible
// full screen map control carrying ACE's blank cursor - same trick ace_common's progress
// bar uses.
//
// Layout is done in fnc_openView from one screen rect, so the feed always keeps the
// screen's aspect ratio no matter the resolution or the feed size setting.

#define OPW_FONT        "RobotoCondensed"
#define OPW_FONT_BOLD   "RobotoCondensedBold"

#define OPW_ACCENT      { 0.42, 0.82, 0.55, 1 }
#define OPW_NONE        { 0, 0, 0, 0 }

#define OPW_SHELL       "#(argb,8,8,3)color(0.145,0.152,0.148,0.99)"
#define OPW_BEZELCOL    "#(argb,8,8,3)color(0.045,0.052,0.048,1)"
#define OPW_STRIP       "#(argb,8,8,3)color(0.085,0.092,0.088,1)"
#define OPW_SCREW       "#(argb,8,8,3)color(0.055,0.060,0.057,1)"
#define OPW_DEAD        "#(argb,8,8,3)color(0,0,0,1)"

class ctrlMapEmpty;

class GVAR(dialog) {
    idd = IDD_MIRROR;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = QUOTE(uiNamespace setVariable [ARR_2(QQGVAR(display),_this select 0)];);
    onUnload = QUOTE(uiNamespace setVariable [ARR_2(QQGVAR(display),displayNull)]; call FUNC(closeView););
    objects[] = {};

    class controlsBackground {
        // Invisible, only there to carry a blank map cursor so no arrow shows on screen
        class CursorKill: ctrlMapEmpty {
            idc = IDC_CURSORKILL;
            moving = 0;
            fade = 1;
            font = OPW_FONT;
            text = "";
            sizeEx = 0;
            lineSpacing = 0;
            style = ST_PICTURE;
            type = CT_MAP_MAIN;
            size = 1;
            colorBackground[] = OPW_NONE;
            colorText[] = OPW_NONE;
            x = "safeZoneX";
            y = "safeZoneY";
            w = "safeZoneW";
            h = "safeZoneH";
        };
    };

    class controls {
        // ---- chassis -----------------------------------------------------------
        // Custom device image, if one is configured. Drawn first so everything sits on top.
        class Device {
            idc = IDC_DEVICE;
            type = CT_STATIC;
            style = ST_PICTURE;
            text = TEXTURE_DEVICE;
            colorText[] = { 1, 1, 1, 1 };
            colorBackground[] = OPW_NONE;
            font = OPW_FONT;
            sizeEx = 0.02;
            x = 0.3; y = 0.6; w = 0.4; h = 0.3;
        };
        class Body {
            idc = IDC_BODY;
            type = CT_STATIC;
            style = ST_PICTURE;
            text = OPW_SHELL;
            colorText[] = { 1, 1, 1, 1 };
            colorBackground[] = OPW_NONE;
            font = OPW_FONT;
            sizeEx = 0.02;
            x = 0.3; y = 0.6; w = 0.4; h = 0.3;
        };
        class Bezel: Body {
            idc = IDC_BEZEL;
            text = OPW_BEZELCOL;
        };

        class ScrewTL: Body {
            idc = IDC_SCREW_TL;
            text = OPW_SCREW;
        };
        class ScrewTR: ScrewTL { idc = IDC_SCREW_TR; };
        class ScrewBL: ScrewTL { idc = IDC_SCREW_BL; };
        class ScrewBR: ScrewTL { idc = IDC_SCREW_BR; };

        // ---- screen ------------------------------------------------------------
        class Feed: Body {
            idc = IDC_FEED;
            text = OPW_DEAD;
            colorBackground[] = { 0, 0, 0, 1 };
        };
        // The intensifier wash. setPiPEffect is meant to do this on the render target itself,
        // but it cannot be verified from outside the game, so the visible half of the effect
        // lives here where it is guaranteed to draw. Hidden until the operator switches it on.
        class IrTint: Body {
            idc = IDC_IRTINT;
            text = "#(argb,8,8,3)color(0.16,0.90,0.34,0.34)";
        };

        // Rounded corners plus vignette, so the picture reads as a screen and not a rectangle
        class ScreenMask: Body {
            idc = IDC_SCREENMASK;
            text = TEXTURE_SCREENMASK;
            colorText[] = { 1, 1, 1, 1 };
        };
        // Shown instead of a picture when the device reports it cannot be worked here
        class Fault {
            idc = IDC_FAULT;
            type = CT_STRUCTURED_TEXT;
            style = ST_CENTER;
            text = "";
            colorBackground[] = OPW_NONE;
            shadow = 0;
            size = 0.024;
            x = 0.3; y = 0.6; w = 0.4; h = 0.3;
            class Attributes {
                font = OPW_FONT_BOLD;
                color = "#c98a5a";
                align = "center";
                valign = "middle";
                shadow = 0;
                size = "1";
            };
        };

        // ---- status bar --------------------------------------------------------
        class TopBar: Body {
            idc = IDC_TOPBAR;
            text = OPW_STRIP;
        };
        class Title {
            idc = IDC_TITLE;
            type = CT_STATIC;
            style = ST_CENTER;
            text = "";
            colorText[] = OPW_ACCENT;
            colorBackground[] = OPW_NONE;
            font = OPW_FONT_BOLD;
            sizeEx = 0.023;
            shadow = 0;
            x = 0.3; y = 0.57; w = 0.2; h = 0.03;
        };
        // ---- control legend ----------------------------------------------------
        class BottomBar: Body {
            idc = IDC_BOTBAR;
            text = OPW_STRIP;
        };
        class Hints {
            idc = IDC_HINTS;
            type = CT_STRUCTURED_TEXT;
            style = ST_CENTER;
            text = "";
            colorBackground[] = OPW_NONE;
            shadow = 0;
            // Inside the panel the legend sits on a dark background and can stay small and
            // muted. Without the panel it floats over the world - fnc_openView then sets it
            // larger and white, and only there.
            size = 0.019;
            x = 0.3; y = 0.9; w = 0.4; h = 0.05;
            class Attributes {
                font = OPW_FONT;
                color = "#8b998d";
                align = "center";
                valign = "middle";
                shadow = 0;
                size = "1";
            };
        };
        class Brand {
            idc = IDC_BRAND;
            type = CT_STATIC;
            style = ST_CENTER;
            text = "OPW-1  OPTIWAND";
            colorText[] = { 0.45, 0.49, 0.46, 1 };
            colorBackground[] = OPW_NONE;
            font = OPW_FONT_BOLD;
            sizeEx = 0.016;
            shadow = 0;
            x = 0.3; y = 0.93; w = 0.4; h = 0.02;
        };
    };
};

// ---------------------------------------------------------------------------------------
// The same controls again, as a title layer.
//
// A dialog captures every input - which is exactly why the player was pinned in place by
// it. An RscTitles layer draws the same picture but takes no input: walking, looking around
// and the weapon all stay free. The keys in turn no longer come from displayAddEventHandler
// but from CBA keybinds (see XEH_postInit).
//
// duration is deliberately enormous: the layer should stand until fnc_closeView takes it
// away, not time out on its own.
// ---------------------------------------------------------------------------------------
class RscTitles {
    class GVAR(layer): GVAR(dialog) {
        idd = IDD_MIRROR;
        duration = 1e11;
        fadeIn = 0;
        fadeOut = 0;
        // No closeView in onUnload. With the dialog that was the emergency brake for
        // Escape; here closeView removes the layer itself, and a call back from it would
        // loop.
        onLoad = QUOTE(uiNamespace setVariable [ARR_2(QQGVAR(display),_this select 0)];);
        onUnload = QUOTE(uiNamespace setVariable [ARR_2(QQGVAR(display),displayNull)];);
    };
};
