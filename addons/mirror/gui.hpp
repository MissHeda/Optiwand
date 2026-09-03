#include "\a3\ui_f\hpp\defineResincl.inc"

// ---------------------------------------------------------------------------------------
// What is left of the overlay.
//
// There used to be a whole monitor in here - housing, bezel, screws, brand plate, the feed
// blown up to a quarter of the screen and nine anchor positions to put it in. That is gone.
// The picture belongs on the device's own screen, which is the entire point of building the
// mod on the Spectrum Device, and a second screen floating over the world only ever
// competed with it.
//
// Three controls remain:
//
//   Feed      never seen. Arma keeps a render target alive only while something draws it,
//             and a hidden control draws nothing - so this one sits at zero opacity, one
//             pixel wide, purely to stay a consumer. Take it out and the device screen goes
//             black.
//   Readout   heading, tilt, zoom. Used to live in the panel's top bar, where nobody with
//             the device screen ever saw it.
//   Hints     the key legend, and the no-clearance report when there is one.
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
            // Invisible on purpose - see the note above. fnc_openView parks it in a corner
            // and pulls it to zero opacity; it must not be ctrlShow false.
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
