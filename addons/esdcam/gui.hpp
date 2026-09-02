// Forward declarations from ui_f so we are allowed to inherit from them
class RscPicture;
class RscObject;

// ---------------------------------------------------------------------------------------
// Extend the Spectrum Device display.
//
// Arma merges configs of the same name rather than replacing them, so the vanilla controls
// (compass, traces, labels) stay put and we only hang our own alongside.
//
// Every class reopened here MUST carry its inheritance. Without ": RscObject" the parent is
// not kept but removed; the RPT reports it as "Updating base class 'RscObject'->''", and
// the screen then loses everything it inherits from RscObject.
//
// None of this is created at runtime: the controls sit in the config and are only faded in
// and out. That costs nothing while playing.
// ---------------------------------------------------------------------------------------
// How far the device is lifted within the view.
//
// Vanilla sets position[] = {0,-0.04,0.2} and positionBack[] = {0,0,0.2}, which puts it low
// enough that the screen is clipped by the bottom edge. Both are raised by 0.075 here. A
// larger middle value means higher up.
//
// Worked out rather than calculated: rapify does not evaluate expressions inside arrays, so
// "-0.04 + 0.075" fails the build with "invalid macro result".
#define OPW_POS {0, 0.035, 0.2}
#define OPW_POS_BACK {0, 0.075, 0.2}

class RscIngameUI {
    class RscWeaponSpectrumAnalyzerGeneric {
        class Objects {
            // Housing and screen are two separate objects in the same display. Both inherit
            // from RscObject - that inheritance MUST be written out when reopening them, or
            // Arma drops it (RPT: "Updating base class 'RscObject'->''").
            class Model: RscObject {
                position[] = OPW_POS;
                positionBack[] = OPW_POS_BACK;
            };

            class Screen: RscObject {
                position[] = OPW_POS;
                positionBack[] = OPW_POS_BACK;

                class Areas {
                    class Usertexture {
                        class Controls {

                            // Dimensions taken from the vanilla "Selected" group, so the
                            // picture fills exactly the area the spectrum normally occupies.
                            class OPW_Feed: RscPicture {
                                idc = IDC_FEED;
                                x = "(0.083 * 1 + 0)";
                                y = "(0.200 * 1.05 + 0)";
                                w = "(0.833 * 1)";
                                h = "(0.704 * 1.05)";
                                text = FEED_TEXTURE;
                                colorText[] = {1,1,1,1};
                                fade = 1;               // starts hidden
                                shadow = 0;
                            };

                            // Over it, the grain overlay Bohemia uses for camera feeds.
                            // Deliberately their own asset: that way the camera mode looks
                            // like the same device rather than something bolted on.
                            class OPW_FeedGrain: RscPicture {
                                idc = IDC_FEED_GRAIN;
                                x = "(0.083 * 1 + 0)";
                                y = "(0.200 * 1.05 + 0)";
                                w = "(0.833 * 1)";
                                h = "(0.704 * 1.05)";
                                text = "\a3\Ui_f\data\IGUI\RscTitles\Static\FeedStatic_00_CA.paa";
                                colorText[] = {0.32,0.99,0.79,0.14};
                                fade = 1;
                                shadow = 0;
                            };
                        };
                    };
                };
            };
        };
    };
};
