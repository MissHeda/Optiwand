#include "\a3\ui_f\hpp\defineResincl.inc"

// Forward declarations from ui_f so we are allowed to inherit from them
class RscPicture;
class RscObject;
class RscText;

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
//
// These are real 3D objects hung in front of the camera, so how far down and how large they
// land depends on the projection - which means this lift only holds at one field of view.
// Correcting it at runtime was tried and taken out again: ctrlSetPosition does move the
// objects, but the engine writes the config position back every frame, and re-applying it
// every frame from a per frame handler still came out wrong in game. If someone wants to
// pick that up again, the entry points are idc 10 (Screen) and 11 (Model) on the
// RscWeaponSpectrumAnalyzerGeneric display.
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

                            // ---------------------------------------------------------
                            // Acquisition readout.
                            //
                            // The device already has a transmit bar - Progress, idc 4005 -
                            // and we already drive it through #EM_Transmit and #EM_Progress.
                            // The trouble is that Bohemia ships it as w=0 h=0 and sizes it
                            // from script, so it comes out too small to notice: right click
                            // brought the display up and nothing looked like it was waiting
                            // for anything. Nobody could tell they were meant to hold the
                            // mouse button.
                            //
                            // So: a legible one, on the device's own screen and nowhere else.
                            // No second dialog, no overlay in front of the world - these are
                            // controls inside the same Usertexture the feed lives in, drawn
                            // onto the screen surface of the model.
                            //
                            // Twelve separate segments rather than one bar that gets resized.
                            // ctrlSetFade on these controls is proven to work - fnc_showFeed
                            // does it to the feed above - and Bohemia builds the traces on
                            // this very display the same way, out of a row of pictures
                            // (LineOld00..LineOldNN) that are only shown and hidden. Sizing a
                            // control inside a render-to-texture area from script is the part
                            // nobody can be sure of, so it is not relied on.
                            // ---------------------------------------------------------
                            class OPW_AcqLabel: RscText {
                                idc = IDC_ACQ_LABEL;
                                x = "(0.083 * 1 + 0)";
                                y = "(0.430 * 1.05 + 0)";
                                w = "(0.833 * 1)";
                                h = "(0.080 * 1.05)";
                                text = "";
                                colorText[] = {0.42,0.82,0.55,1};
                                colorBackground[] = {0,0,0,0};
                                style = ST_CENTER;
                                sizeEx = 0.055;
                                shadow = 0;
                                fade = 1;
                            };

                            // The unlit track, and the base class for both rows.
                            //
                            // Declared before the lit segments on purpose, twice over: order
                            // in a Controls block is draw order, so anything later sits on
                            // top - the other way round the track painted over the fill and
                            // the bar never appeared to move - and a config class cannot
                            // inherit from a sibling declared after it.
                            //
                            // Twelve steps rather than one growing green smear, which is also
                            // what makes it readable at a glance on a small screen.
                            class OPW_AcqTrack00: RscPicture {
                                idc = IDC_ACQ_TRACK;
                                y = "(0.545 * 1.05 + 0)";
                                w = "(0.038 * 1)";
                                h = "(0.045 * 1.05)";
                                x = "(0.2330 * 1 + 0)";
                                text = "#(argb,8,8,3)color(0.10,0.13,0.11,1)";
                                colorText[] = {1,1,1,1};
                                shadow = 0;
                                fade = 1;
                            };
                            class OPW_AcqTrack01: OPW_AcqTrack00 { idc = 71051; x = "(0.2774 * 1 + 0)"; };
                            class OPW_AcqTrack02: OPW_AcqTrack00 { idc = 71052; x = "(0.3218 * 1 + 0)"; };
                            class OPW_AcqTrack03: OPW_AcqTrack00 { idc = 71053; x = "(0.3662 * 1 + 0)"; };
                            class OPW_AcqTrack04: OPW_AcqTrack00 { idc = 71054; x = "(0.4107 * 1 + 0)"; };
                            class OPW_AcqTrack05: OPW_AcqTrack00 { idc = 71055; x = "(0.4551 * 1 + 0)"; };
                            class OPW_AcqTrack06: OPW_AcqTrack00 { idc = 71056; x = "(0.4995 * 1 + 0)"; };
                            class OPW_AcqTrack07: OPW_AcqTrack00 { idc = 71057; x = "(0.5439 * 1 + 0)"; };
                            class OPW_AcqTrack08: OPW_AcqTrack00 { idc = 71058; x = "(0.5883 * 1 + 0)"; };
                            class OPW_AcqTrack09: OPW_AcqTrack00 { idc = 71059; x = "(0.6327 * 1 + 0)"; };
                            class OPW_AcqTrack10: OPW_AcqTrack00 { idc = 71060; x = "(0.6771 * 1 + 0)"; };
                            class OPW_AcqTrack11: OPW_AcqTrack00 { idc = 71061; x = "(0.7216 * 1 + 0)"; };

                            // The lit fill, same geometry, over the track.
                            class OPW_AcqSeg00: OPW_AcqTrack00 {
                                idc = IDC_ACQ_SEG;
                                text = "#(argb,8,8,3)color(0.42,0.82,0.55,1)";
                            };
                            class OPW_AcqSeg01: OPW_AcqSeg00 { idc = 71031; x = "(0.2774 * 1 + 0)"; };
                            class OPW_AcqSeg02: OPW_AcqSeg00 { idc = 71032; x = "(0.3218 * 1 + 0)"; };
                            class OPW_AcqSeg03: OPW_AcqSeg00 { idc = 71033; x = "(0.3662 * 1 + 0)"; };
                            class OPW_AcqSeg04: OPW_AcqSeg00 { idc = 71034; x = "(0.4107 * 1 + 0)"; };
                            class OPW_AcqSeg05: OPW_AcqSeg00 { idc = 71035; x = "(0.4551 * 1 + 0)"; };
                            class OPW_AcqSeg06: OPW_AcqSeg00 { idc = 71036; x = "(0.4995 * 1 + 0)"; };
                            class OPW_AcqSeg07: OPW_AcqSeg00 { idc = 71037; x = "(0.5439 * 1 + 0)"; };
                            class OPW_AcqSeg08: OPW_AcqSeg00 { idc = 71038; x = "(0.5883 * 1 + 0)"; };
                            class OPW_AcqSeg09: OPW_AcqSeg00 { idc = 71039; x = "(0.6327 * 1 + 0)"; };
                            class OPW_AcqSeg10: OPW_AcqSeg00 { idc = 71040; x = "(0.6771 * 1 + 0)"; };
                            class OPW_AcqSeg11: OPW_AcqSeg00 { idc = 71041; x = "(0.7216 * 1 + 0)"; };
                        };
                    };
                };
            };
        };
    };
};
