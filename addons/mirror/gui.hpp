#include "\a3\ui_f\hpp\defineResincl.inc"

// ---------------------------------------------------------------------------------------
// The overlay: a field monitor over the world, with two lines of text on its screen.
//
//   Backing   solid behind the feed, so nothing of the world can come through the picture.
//   Feed      the camera picture. Arma keeps a render target alive only while something draws
//             it, so this one is never hidden: with no picture on, fnc_showFeed in the device
//             addon parks it at a single pixel. Take it out and the picture goes black.
//   Screen    the monitor's dark screen, for whenever no picture is on. A solid background
//             rather than a picture: a coloured picture over the feed still let it show through.
//   Monitor   the housing and the glass, one picture rendered by tools/render_monitor.py, with
//             a hole for the feed to show through. Drawn in this order, so last on top.
//   Acq*      the picture build-up on the dark screen: what to do, then a bar. The device
//             addon drives them, fnc_openView places them.
//   Osd*      the dark bands the two lines of text sit on.
//   Readout   heading, tilt, zoom.
//   Hints     the key legend, and the no-clearance report when there is one.
//
// fnc_openView sizes and places all of them.
//
// It is an RscTitles layer, and carries no input of its own: a map control in one tells Arma
// that a UI wants the mouse, and that released the pointer - on a borderless window with a second
// monitor it let the mouse walk out of the game. Taking the input is the job of the dialog below,
// which keeps the pointer in the window itself.
// ---------------------------------------------------------------------------------------

#define OPW_FONT        "RobotoCondensed"
#define OPW_FONT_BOLD   "RobotoCondensedBold"

#define OPW_NONE        { 0, 0, 0, 0 }
#define OPW_DEAD        "#(argb,8,8,3)color(0,0,0,1)"

class ctrlMapEmpty;

// Nothing to see in this one: it only takes keyboard and mouse away from the game during a locked
// peek - see fnc_lockDialog. The map is disabled there, and only carries a blank cursor.
class GVAR(lockDialog) {
    idd = IDD_LOCK;
    movingEnable = 0;
    enableSimulation = 1;
    objects[] = {};

    class controlsBackground {
        class Cursor: ctrlMapEmpty {
            idc = IDC_LOCK_CURSOR;
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
    class controls {};
};

class RscTitles {
    class GVAR(layer) {
        idd = -1;
        duration = 1e11;
        fadeIn = 0;
        fadeOut = 0;
        movingEnable = 0;
        enableSimulation = 1;
        objects[] = {};
        onLoad = QUOTE(uiNamespace setVariable [ARR_2(QQGVAR(display),_this select 0)];);
        onUnload = QUOTE(uiNamespace setVariable [ARR_2(QQGVAR(display),displayNull)];);

        class controls {
            class Backing {
                idc = IDC_BACKING;
                type = CT_STATIC;
                style = ST_LEFT;
                text = "";
                colorText[] = { 1, 1, 1, 1 };
                colorBackground[] = { 0.015, 0.017, 0.02, 1 };
                font = OPW_FONT;
                sizeEx = 0.02;
                x = 0; y = 0; w = 0.001; h = 0.001;
            };

            class Feed {
                idc = IDC_FEED;
                type = CT_STATIC;
                style = ST_PICTURE;
                text = OPW_DEAD;
                colorText[] = { 1, 1, 1, 1 };
                colorBackground[] = OPW_NONE;
                font = OPW_FONT;
                sizeEx = 0.02;
                x = 0; y = 0; w = 0.001; h = 0.001;
            };

            class Screen: Backing {
                idc = IDC_SCREEN;
            };

            class Monitor: Feed {
                idc = IDC_MONITOR;
                text = MONITOR_TEXTURE;
            };

            class AcqTrack: Feed {
                idc = IDC_ACQ_TRACK;
                text = "#(argb,8,8,3)color(0.10,0.13,0.11,1)";
                fade = 1;
            };

            class AcqFill: Feed {
                idc = IDC_ACQ_FILL;
                text = "#(argb,8,8,3)color(0.42,0.82,0.55,1)";
                fade = 1;
            };

            class AcqLabel {
                idc = IDC_ACQ_LABEL;
                type = CT_STATIC;
                style = ST_CENTER;
                text = "";
                colorText[] = { 0.42, 0.82, 0.55, 1 };
                colorBackground[] = OPW_NONE;
                font = OPW_FONT_BOLD;
                sizeEx = 0.05;
                shadow = 0;
                fade = 1;
                x = 0; y = 0; w = 0.001; h = 0.001;
            };

            class OsdTop: Feed {
                idc = IDC_OSD_TOP;
                text = "#(argb,8,8,3)color(0,0,0,0.55)";
            };

            class OsdBottom: OsdTop {
                idc = IDC_OSD_BOTTOM;
            };

            class Readout {
                idc = IDC_READOUT;
                type = CT_STRUCTURED_TEXT;
                style = ST_CENTER;
                text = "";
                colorBackground[] = OPW_NONE;
                shadow = 0;
                size = 0.026;
                x = 0.3; y = 0.9; w = 0.4; h = 0.03;
                class Attributes {
                    font = OPW_FONT_BOLD;
                    color = "#ffffff";
                    align = "center";
                    valign = "middle";
                    shadow = 1;
                };
            };

            class Hints {
                idc = IDC_HINTS;
                type = CT_STRUCTURED_TEXT;
                style = ST_CENTER;
                text = "";
                colorBackground[] = OPW_NONE;
                shadow = 0;
                size = 0.026;
                x = 0.3; y = 0.94; w = 0.4; h = 0.03;
                class Attributes {
                    font = OPW_FONT;
                    color = "#ffffff";
                    align = "center";
                    valign = "middle";
                    shadow = 1;
                };
            };
        };
    };
};
