#define CATEGORY_MIRROR LLSTRING(SettingCategory)

[
    QGVAR(requireItem), "CHECKBOX",
    [LSTRING(Setting_RequireItem), LSTRING(Setting_RequireItem_Description)],
    CATEGORY_MIRROR,
    [true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(allowFreehand), "CHECKBOX",
    [LSTRING(Setting_AllowFreehand), LSTRING(Setting_AllowFreehand_Description)],
    CATEGORY_MIRROR,
    [true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(deployTime), "SLIDER",
    [LSTRING(Setting_DeployTime), LSTRING(Setting_DeployTime_Description)],
    CATEGORY_MIRROR,
    [0, 15, 2.5, 1],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(maxDepth), "SLIDER",
    [LSTRING(Setting_MaxDepth), LSTRING(Setting_MaxDepth_Description)],
    CATEGORY_MIRROR,
    [0.05, 1.2, 0.5, 2],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(camHeight), "SLIDER",
    [LSTRING(Setting_CamHeight), LSTRING(Setting_CamHeight_Description)],
    CATEGORY_MIRROR,
    [0.02, 0.35, 0.09, 2],
    1
] call CBA_fnc_addSetting;

// Wann der externe Monitor mitkommt - getrennt nach Einsatzart, weil sich die beiden
// unterschiedlich anfuehlen: an der Tuer steht man ruhig und schaut, freihand haelt man das
// Geraet vor sich und will die Sicht frei haben.
//
// Aus by default: der Bildschirm am Geraet ist das, was das Ding ausmacht. Ueber die
// ACE-Interaktion kommt der Monitor trotzdem immer mit - dort zielt niemand, also kommt das
// Auge auch nicht nah genug an den kleinen Bildschirm heran.
// Ohne Freiraum kann der Kopf nicht ausfahren, und das Geraet sagt das auch. Wer die
// Meldung nicht will - weil die Einheit ohnehin nicht damit rechnet, durch Waende zu
// schauen -, schaltet die Pruefung ab und bringt den Spiegel ueberall aus.
[
    QGVAR(requireClearance), "CHECKBOX",
    [LSTRING(Setting_RequireClearance), LSTRING(Setting_RequireClearance_Description)],
    CATEGORY_MIRROR,
    [true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(guiMode), "LIST",
    [LSTRING(Setting_GuiMode), LSTRING(Setting_GuiMode_Description)],
    CATEGORY_MIRROR,
    [
        [0, 1, 2, 3],
        [LSTRING(GuiMode_Never), LSTRING(GuiMode_Door), LSTRING(GuiMode_Free), LSTRING(GuiMode_Always)],
        0
    ],
    0
] call CBA_fnc_addSetting;

// Drei Werte, die zusammengehoeren: die beiden Grenzen und der Startwert dazwischen.
//
// Der Startwert wird beim Ausbringen in die Grenzen gezwungen. Sonst koennte man mit einem
// Ausschnitt beginnen, den man mit Q und E nie wieder erreicht - das war vorher so, als der
// Grundwert ueber der Obergrenze liegen konnte.
[
    QGVAR(zoomNear), "SLIDER",
    [LSTRING(Setting_ZoomNear), LSTRING(Setting_ZoomNear_Description)],
    CATEGORY_MIRROR,
    [FOV_MIN, FOV_MAX, 0.10, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(zoomFar), "SLIDER",
    [LSTRING(Setting_ZoomFar), LSTRING(Setting_ZoomFar_Description)],
    CATEGORY_MIRROR,
    [FOV_MIN, FOV_MAX, 0.40, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(defaultFov), "SLIDER",
    [LSTRING(Setting_DefaultFov), LSTRING(Setting_DefaultFov_Description)],
    CATEGORY_MIRROR,
    [FOV_MIN, FOV_MAX, FOV_DEFAULT, 2],
    0
] call CBA_fnc_addSetting;

// Wie weit sich der Kopf im Freihandmodus ueber die Ausgangslage hinaus schieben laesst.
// Der Arm ist ausgestreckt, viel mehr als ein Nachfassen gibt die Haltung nicht her - wer es
// trotzdem weiter haben will, dreht hier. Die Wandpruefung stoppt weiterhin frueher, wenn
// etwas im Weg ist.
[
    QGVAR(freeExtend), "SLIDER",
    [LSTRING(Setting_FreeExtend), LSTRING(Setting_FreeExtend_Description)],
    CATEGORY_MIRROR,
    [0, 1.0, FREE_EXTEND, 2],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(feedScale), "SLIDER",
    [LSTRING(Setting_FeedScale), LSTRING(Setting_FeedScale_Description)],
    CATEGORY_MIRROR,
    [0.12, 0.7, 0.24, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(feedPosition), "LIST",
    [LSTRING(Setting_FeedPosition), LSTRING(Setting_FeedPosition_Description)],
    CATEGORY_MIRROR,
    [
        [0, 1, 2, 3, 4, 5, 6, 7, 8],
        [
            LSTRING(Anchor_TopLeft),    LSTRING(Anchor_TopCentre),    LSTRING(Anchor_TopRight),
            LSTRING(Anchor_MiddleLeft), LSTRING(Anchor_Centre),       LSTRING(Anchor_MiddleRight),
            LSTRING(Anchor_BottomLeft), LSTRING(Anchor_BottomCentre), LSTRING(Anchor_BottomRight)
        ],
        7
    ],
    0
] call CBA_fnc_addSetting;

// ---------------------------------------------------------------------------------------
// Feinversatz der Freihandkamera, relativ zur Blickrichtung.
//
// Als Einstellung statt als Konstante, weil sich das nur im Spiel beurteilen laesst: die
// Kamera darf weder im eigenen Modell stecken noch neben dem Geraet schweben. Drei Achsen,
// weil ein einzelner Wert das nicht trifft - beim letzten Versuch wanderte die Kamera zur
// Seite, obwohl sie nach hinten sollte.
// ---------------------------------------------------------------------------------------
[
    QGVAR(freeOffsetForward), "SLIDER",
    [LSTRING(Setting_OffsetForward), LSTRING(Setting_OffsetForward_Description)],
    CATEGORY_MIRROR,
    [-0.5, 1, 0.2, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(freeOffsetRight), "SLIDER",
    [LSTRING(Setting_OffsetRight), LSTRING(Setting_OffsetRight_Description)],
    CATEGORY_MIRROR,
    [-0.5, 0.5, 0, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(freeOffsetUp), "SLIDER",
    [LSTRING(Setting_OffsetUp), LSTRING(Setting_OffsetUp_Description)],
    CATEGORY_MIRROR,
    [-0.5, 0.5, 0, 2],
    0
] call CBA_fnc_addSetting;
