#include "\a3\ui_f\hpp\defineResincl.inc"

// ---------------------------------------------------------------------------------------
// The overlay: a field monitor over the world, with two lines of text on its screen.
//
//   Screen    the monitor's dark screen, there for whenever no picture is on it.
//   Feed      the camera picture. Arma keeps a render target alive only while something draws
//             it, and a hidden control draws nothing - so while there is no picture it sits at
//             full fade, never ctrlShow false. Take it out and the picture goes black.
//   Monitor   the housing and the glass, one picture rendered by tools/render_monitor.py, with
//             a hole for the feed to show through. Drawn in this order, so last on top.
//   Acq*      the picture build-up on the dark screen: what to do, then a bar. The device
//             addon drives them, fnc_openView places them.
//   Readout   heading, tilt, zoom.
//   Hints     the key legend, and the no-clearance report when there is one.
//
// fnc_openView sizes and places all of them.
//
// It is an RscTitles layer and nothing else. There is no dialog class any more, and no full
// screen map control to blank the cursor either: a title layer never gets a cursor to begin
// with, but a map control in one tells Arma that a UI wants the mouse, and that released the
// pointer - on a borderless window with a second monitor it let the mouse walk out of the
// game. It only ever happened while aiming, because that is when this layer is up.
// ---------------------------------------------------------------------------------------

#define OPW_FONT        "RobotoCondensed"
#define OPW_FONT_BOLD   "RobotoCondensedBold"

#define OPW_NONE        { 0, 0, 0, 0 }
#define OPW_OSD         { 0, 0, 0, 0.55 }
#define OPW_DEAD        "#(argb,8,8,3)color(0,0,0,1)"

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
            class Screen {
                idc = IDC_SCREEN;
                type = CT_STATIC;
                style = ST_PICTURE;
                text = "#(argb,8,8,3)color(0.015,0.017,0.02,1)";
                colorText[] = { 1, 1, 1, 1 };
                colorBackground[] = OPW_NONE;
                font = OPW_FONT;
                sizeEx = 0.02;
                x = 0; y = 0; w = 0.001; h = 0.001;
            };

            class Feed: Screen {
                idc = IDC_FEED;
                text = OPW_DEAD;
            };

            class Monitor: Screen {
                idc = IDC_MONITOR;
                text = MONITOR_TEXTURE;
            };

            class AcqTrack: Screen {
                idc = IDC_ACQ_TRACK;
                text = "#(argb,8,8,3)color(0.10,0.13,0.11,1)";
                fade = 1;
            };

            class AcqFill: Screen {
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

            class Readout {
                idc = IDC_READOUT;
                type = CT_STRUCTURED_TEXT;
                style = ST_CENTER;
                text = "";
                colorBackground[] = OPW_OSD;
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
                colorBackground[] = OPW_OSD;
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
