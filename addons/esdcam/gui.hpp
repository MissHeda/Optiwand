// Vorwaertsdeklarationen aus ui_f, damit wir davon erben duerfen
class RscPicture;
class RscObject;

// ---------------------------------------------------------------------------------------
// Die Anzeige des Spectrum Device erweitern.
//
// Arma fuehrt Configs gleichen Namens zusammen, statt sie zu ersetzen - die Vanilla-Controls
// (Kompass, Linien, Beschriftungen) bleiben also stehen, wir haengen nur eigene daneben.
//
// Bei jeder wieder aufgemachten Klasse MUSS die Vererbung mitgeschrieben werden. Ohne
// ": RscObject" wird die Elternklasse nicht beibehalten, sondern entfernt; das RPT meldet
// das als "Updating base class 'RscObject'->''". Der Bildschirm verliert dann alles, was er
// von RscObject erbt.
//
// Nichts davon wird zur Laufzeit erzeugt: die Controls stehen fest in der Config und werden
// nur ein- und ausgeblendet. Im Betrieb kostet das nichts.
// ---------------------------------------------------------------------------------------
// Wie weit das Geraet im Bild angehoben wird.
//
// Vanilla setzt position[] = {0,-0.04,0.2} und positionBack[] = {0,0,0.2}; damit sitzt es
// so tief, dass die Scheibe am unteren Bildrand abgeschnitten wird. Hier beide um 0.075
// angehoben. Groesserer Mittelwert = weiter oben.
//
// Ausgerechnet statt gerechnet: rapify wertet in Arrays keine Ausdruecke aus, "-0.04 +
// 0.075" laesst den Build mit "invalid macro result" scheitern.
#define OPW_POS {0, 0.035, 0.2}
#define OPW_POS_BACK {0, 0.075, 0.2}

class RscIngameUI {
    class RscWeaponSpectrumAnalyzerGeneric {
        class Objects {
            // Gehaeuse und Scheibe sind zwei getrennte Objekte im selben Display. Beide
            // erben von RscObject - die Vererbung MUSS beim Wiederaufmachen mitgeschrieben
            // werden, sonst entfernt Arma sie (RPT: "Updating base class 'RscObject'->''").
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

                            // Masse uebernommen aus der Vanilla-Gruppe "Selected", damit das
                            // Bild genau die Flaeche fuellt, auf der sonst das Spektrum liegt.
                            class OPW_Feed: RscPicture {
                                idc = IDC_FEED;
                                x = "(0.083 * 1 + 0)";
                                y = "(0.200 * 1.05 + 0)";
                                w = "(0.833 * 1)";
                                h = "(0.704 * 1.05)";
                                text = FEED_TEXTURE;
                                colorText[] = {1,1,1,1};
                                fade = 1;               // startet unsichtbar
                                shadow = 0;
                            };

                            // Darueber das Rauschbild, das Bohemia fuer Kamerabilder benutzt.
                            // Bewusst deren eigenes Material: so sieht der Kamerabetrieb nach
                            // demselben Geraet aus und nicht nach einem Fremdkoerper.
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
