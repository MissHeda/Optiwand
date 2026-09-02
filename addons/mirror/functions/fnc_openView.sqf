#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Puts the mirror out: creates the render to texture camera, opens the monitor dialog and
 * hooks up the controls.
 * The camera renders into a texture instead of onto the screen (same technique as
 * ace_viewports_fnc_viewCreate by PabstMirror), so the world keeps rendering normally behind
 * the device. The dialog is what locks movement and weapon input while the wand is out.
 *
 * Three modes:
 *   MODE_DOOR   the head sits in the door slit, rides the floor and slides along the gap
 *   MODE_FREE   the head sits on the end of the shaft, wherever the operator pointed it -
 *               for looking over a wall or round a corner. No floor, no sideways slide.
 *   MODE_FAULT  no camera at all, just the device reporting it has no room to work. Better
 *               than nothing happening, which reads as a broken mod.
 *
 * Arguments:
 * 0: House <OBJECT> (objNull in free mode)
 * 1: Door selection name <STRING>
 * 2: Base position, ASL <ARRAY> - the door slit in door mode, the operator's eye in free mode
 * 3: Direction the head reaches along <ARRAY> - horizontal in door mode, full 3D in free mode
 * 4: Half width of the door <NUMBER>
 * 5: Mode <NUMBER> (default: MODE_DOOR)
 * 6: Fixed reach for free mode <NUMBER> (default: 1)
 *
 * Return Value:
 * None
 *
 * Example:
 * [_house, "door_1", _bottomASL, _through, 0.45, MODE_DOOR] call opw_mirror_fnc_openView
 *
 * Public: No
 */

params ["_house", "_door", "_basePosASL", "_reachDir", ["_halfWidth", PANEL_FALLBACK_HALF], ["_mode", MODE_DOOR], ["_reach", 1]];

if (!hasInterface) exitWith {};
if (GVAR(active)) exitWith {};
if (_mode isNotEqualTo MODE_FAULT && {_basePosASL isEqualTo [] || {_reachDir isEqualTo []}}) exitWith {};
if (_mode isEqualTo MODE_DOOR && {isNull _house}) exitWith {};

GVAR(active) = true;
GVAR(mode) = _mode;
GVAR(house) = _house;
GVAR(door) = _door;
GVAR(basePosASL) = _basePosASL;
GVAR(baseDir) = _reachDir;
GVAR(anchorASL) = getPosASL ACE_player;

// The head is aimed in spherical terms around the direction the shaft points
GVAR(baseAzimuth) = 0;
GVAR(baseRight) = [1, 0, 0];
if (_reachDir isNotEqualTo []) then {
    GVAR(baseAzimuth) = (_reachDir select 0) atan2 (_reachDir select 1);
    GVAR(baseRight) = vectorNormalized ([_reachDir select 0, _reachDir select 1, 0] vectorCrossProduct [0, 0, 1]);
};

if (_mode isEqualTo MODE_FREE) then {
    // Null, nicht der Blickwinkel beim Ausbringen: freihand ist GVAR(pitch) eine Ablage auf
    // die Blickrichtung, die fnc_update jeden Frame neu misst. Stuende hier der Startwinkel
    // drin, kaeme er zu jeder Messung noch einmal obendrauf und der Kopf zeigte doppelt so
    // steil wie das Geraet.
    GVAR(basePitch) = 0;
    GVAR(freeLookPitch) = asin (((_reachDir select 2) max -1) min 1);
    GVAR(depthDefault) = _reach;
    GVAR(slideLimit) = 0;

    // Kopf ein Stueck ueber die Stabachse setzen, sonst steht beim Hochschwenken das eigene
    // Modell im Bild.
    GVAR(basePosASL) = GVAR(basePosASL) vectorAdd [0, 0, FREE_CAM_LIFT];
} else {
    GVAR(basePitch) = PITCH_DEFAULT;
    GVAR(depthDefault) = DEPTH_DEFAULT min GVAR(maxDepth);
    GVAR(slideLimit) = 0 max (_halfWidth - SLIDE_MARGIN);
};

GVAR(yaw) = 0;
GVAR(pitch) = GVAR(basePitch);
GVAR(depth) = GVAR(depthDefault);
GVAR(slide) = 0;
// Grenzen einmal ordnen und merken, damit fnc_update sie nicht jeden Frame neu sortiert -
// und damit der Startwert garantiert dazwischen liegt.
GVAR(fovNear) = GVAR(zoomNear) min GVAR(zoomFar);
GVAR(fovFar) = GVAR(zoomNear) max GVAR(zoomFar);
GVAR(fovStart) = (GVAR(defaultFov) max GVAR(fovNear)) min GVAR(fovFar);
GVAR(fov) = GVAR(fovStart);
GVAR(nightVision) = false;
GVAR(axes) = [0, 0, 0, 0, 0];
GVAR(keyAxes) = createHashMap;
GVAR(readoutState) = [];
GVAR(nextDoorCheck) = 0;

// localize once, not once a frame
GVAR(hudLabels) = [LLSTRING(HUD_Heading), LLSTRING(HUD_Tilt), LLSTRING(HUD_Zoom)];

GVAR(lastTick) = diag_tickTime;

// Mode constant, so fnc_update does not rebuild these arrays every frame
GVAR(yawLimit) = [FREE_YAW_LIMIT, YAW_LIMIT] select (_mode isEqualTo MODE_DOOR);
GVAR(pitchLimits) = [[FREE_PITCH_MIN, FREE_PITCH_MAX], [PITCH_MIN, PITCH_MAX]] select (_mode isEqualTo MODE_DOOR);

GVAR(lastAppliedPos) = [];
GVAR(lastAppliedDir) = [];


// Floor tracking, door mode only. The sill and the floor on the far side are usually not the
// same height, so the head keeps re-probing for the floor underneath itself as it moves.
GVAR(floorZ) = if (_basePosASL isEqualTo []) then {0} else {_basePosASL select 2};
GVAR(lastProbeXY) = [0, 0, 0];

// Free mode sweeps out from the eye, which is guaranteed clear air. Door mode starts inside
// the doorway, which is open by definition, so its first frame is taken on trust.
GVAR(lastCamPosASL) = [[], _basePosASL] select (_mode isEqualTo MODE_FREE);

////////////////////////////////////////////////////////////////////////////////
// Camera
////////////////////////////////////////////////////////////////////////////////

// A fault has nothing to show, so it gets no camera and no render target
if (_mode isNotEqualTo MODE_FAULT) then {
    GVAR(camera) = "camera" camCreate (ASLToAGL _basePosASL);
    GVAR(camera) cameraEffect ["INTERNAL", "BACK", RTT_NAME];
    RTT_NAME setPiPEffect [0];
    GVAR(camera) camSetFov GVAR(fov);
    GVAR(camera) camCommit 0;
};

////////////////////////////////////////////////////////////////////////////////
// Monitor
////////////////////////////////////////////////////////////////////////////////

// Titelebene statt Dialog.
//
// Ein Dialog faengt jede Eingabe ab - der Spieler stand damit fest, solange der Spiegel
// draussen war. Eine RscTitles-Ebene zeichnet dasselbe, laesst aber Laufen, Umsehen und
// Waffe frei. Die Tasten kommen dafuer nicht mehr vom Display, sondern von CBA-Keybinds.
//
// cutRsc legt die Anzeige noch im selben Frame an; ihr onLoad traegt sie in den uiNamespace
// ein, weshalb sie direkt danach schon abholbar ist.
private _layer = QGVAR(layer) call BIS_fnc_rscLayer;
_layer cutRsc [QGVAR(layer), "PLAIN", 0, false];

private _display = uiNamespace getVariable [QGVAR(display), displayNull];
if (isNull _display) exitWith {
    ERROR("mirror overlay failed to open");
    call FUNC(closeView);
};

// Kill the mouse pointer - a floating arrow ruins the illusion completely.
// This is a full screen map control, which is the only way Arma offers to swap the cursor.
// A live map control also takes mouse input and starts a drag on button down, so it is
// disabled straight afterwards: it still paints, it just cannot capture the mouse any more.
private _cursorKill = _display displayCtrl IDC_CURSORKILL;
if (!isNull _cursorKill) then {
    _cursorKill ctrlMapCursor ["", "ace_common_blank"];
    _cursorKill ctrlEnable false;
};

// The render target always inherits the main video aspect ratio, so size the screen to match.
// Vertical sizes below are fractions of safezoneH; horizontal ones go through the same
// conversion, so a control meant to be square comes out square instead of stretched.
private _screenAR = getResolution select 4;
private _fnc_sq = {(_this) * _screenAR * 0.75};

private _screenH = ((GVAR(feedScale) * safezoneH) max 0.1) min (0.75 * safezoneH);
private _screenW = _screenH call _fnc_sq;

private _padY = 0.013 * safezoneH;
private _padX = _padY call _fnc_sq;
private _barY = 0.030 * safezoneH;
private _botY = 0.044 * safezoneH;

private _bodyW = _screenW + 2 * _padX;
private _bodyH = _screenH + 2 * _padY + _barY + _botY;

private _bodyX = 0;
private _bodyY = 0;

// Nine anchors on a grid, read left to right and top to bottom
private _col = GVAR(feedPosition) % 3;
private _row = floor (GVAR(feedPosition) / 3);
private _marginX = 0.015;
private _marginY = 0.04 * safezoneH;

_bodyX = switch (_col) do {
    case 0: {safezoneX + _marginX};
    case 2: {safezoneX + safezoneW - _bodyW - _marginX};
    default {safezoneX + 0.5 * (safezoneW - _bodyW)};
};

_bodyY = switch (_row) do {
    case 0: {safezoneY + _marginY};
    case 1: {safezoneY + 0.5 * (safezoneH - _bodyH)};
    default {safezoneY + safezoneH - _bodyH - _marginY};
};

// Keep the whole device on screen even at silly feed sizes
_bodyX = (_bodyX max safezoneX) min (safezoneX + safezoneW - _bodyW);
_bodyY = (_bodyY max safezoneY) min (safezoneY + safezoneH - _bodyH);

private _screenX = _bodyX + _padX;
private _screenY = _bodyY + _barY + _padY * 0.4;

// The legend strip mirrors the title strip exactly: same inset from the bezel, same height.
// Deriving it from _barY rather than picking numbers out of _botY is the whole point - the
// two strips are supposed to look like the same piece of the same device.
private _bezelBottom = _screenY + _screenH + _padY * 0.4;
private _legendY = _bezelBottom + _barY * 0.12;
private _legendH = _barY * 0.76;

// Badge sits in whatever the strip leaves, centred by its own valign
private _brandY = _legendY + _legendH + _barY * 0.12;
private _brandH = (_bodyY + _bodyH) - _brandY;

private _screwW = (0.005 * safezoneH) call _fnc_sq;
private _screwH = 0.005 * safezoneH;
private _screwIX = 0.35 * _padX;
private _screwIY = 0.35 * _padY;

{
    _x params ["_idc", "_position"];
    private _ctrl = _display displayCtrl _idc;
    _ctrl ctrlSetPosition _position;
    _ctrl ctrlCommit 0;
} forEach [
    [IDC_BODY,       [_bodyX, _bodyY, _bodyW, _bodyH]],
    [IDC_BEZEL,      [_screenX - _padX * 0.4, _screenY - _padY * 0.4, _screenW + _padX * 0.8, _screenH + _padY * 0.8]],
    [IDC_FEED,       [_screenX, _screenY, _screenW, _screenH]],
    [IDC_IRTINT,     [_screenX, _screenY, _screenW, _screenH]],
    [IDC_SCREENMASK, [_screenX, _screenY, _screenW, _screenH]],
    [IDC_TOPBAR,     [_bodyX + _padX * 0.5, _bodyY + _barY * 0.12, _bodyW - _padX, _barY * 0.76]],
    [IDC_TITLE,      [_bodyX, _bodyY + _barY * 0.12, _bodyW, _barY * 0.76]],
    [IDC_READOUT,    [_bodyX + _bodyW * 0.5, _bodyY + _barY * 0.12, _bodyW * 0.5 - _padX, _barY * 0.76]],
    [IDC_SCREW_TL,   [_bodyX + _screwIX, _bodyY + _screwIY, _screwW, _screwH]],
    [IDC_SCREW_TR,   [_bodyX + _bodyW - _screwIX - _screwW, _bodyY + _screwIY, _screwW, _screwH]],
    [IDC_SCREW_BL,   [_bodyX + _screwIX, _bodyY + _bodyH - _screwIY - _screwH, _screwW, _screwH]],
    [IDC_SCREW_BR,   [_bodyX + _bodyW - _screwIX - _screwW, _bodyY + _bodyH - _screwIY - _screwH, _screwW, _screwH]],
    [IDC_BOTBAR,     [_bodyX + _padX * 0.5, _legendY, _bodyW - _padX, _legendH]],
    [IDC_HINTS,      [_bodyX, _legendY, _bodyW, _legendH]],
    [IDC_BRAND,      [_bodyX, _brandY, _bodyW, _brandH]]
];

private _ctrlFault = _display displayCtrl IDC_FAULT;
private _ctrlIrTint = _display displayCtrl IDC_IRTINT;
_ctrlIrTint ctrlShow false;
uiNamespace setVariable [QGVAR(ctrlIrTint), _ctrlIrTint];
// Die Groesse muss mit OPTIWAND_SCREEN im Waffen-Addon uebereinstimmen: beide binden
// dasselbe Render-Target, und die Zahl im Texturstring sagt Arma, wie gross der Puffer
// dafuer angelegt wird. Zwei verschiedene Angaben auf denselben Namen sind ein Wuerfeln
// darum, welche gewinnt.
private _feedTexture = format ["#(argb,%1,%1,1)r2t(%2,1)", RTT_SIZE, RTT_NAME];

// Der gewaehlte Text wird gemerkt: der Zweig ohne Panel setzt ihn gleich noch einmal, dann
// groesser und weiss.
private _hintText = "";

switch (_mode) do {
    case MODE_FAULT: {
        (_display displayCtrl IDC_FEED) ctrlSetText "#(argb,8,8,3)color(0.02,0.02,0.02,1)";
        (_display displayCtrl IDC_TITLE) ctrlSetText LLSTRING(Feed_Title_Fault);
        _hintText = LLSTRING(Feed_Hints_Fault);
        (_display displayCtrl IDC_HINTS) ctrlSetStructuredText parseText _hintText;
        _ctrlFault ctrlSetPosition [_screenX, _screenY, _screenW, _screenH];
        _ctrlFault ctrlSetStructuredText parseText LLSTRING(Fault_NoClearance);
        _ctrlFault ctrlCommit 0;
    };
    case MODE_FREE: {
        (_display displayCtrl IDC_FEED) ctrlSetText _feedTexture;
        (_display displayCtrl IDC_TITLE) ctrlSetText LLSTRING(Feed_Title_Free);
        _hintText = LLSTRING(Feed_Hints_Free);
        (_display displayCtrl IDC_HINTS) ctrlSetStructuredText parseText _hintText;
        _ctrlFault ctrlShow false;
    };
    default {
        (_display displayCtrl IDC_FEED) ctrlSetText _feedTexture;
        (_display displayCtrl IDC_TITLE) ctrlSetText LLSTRING(Feed_Title);
        _hintText = LLSTRING(Feed_Hints);
        (_display displayCtrl IDC_HINTS) ctrlSetStructuredText parseText _hintText;
        _ctrlFault ctrlShow false;
    };
};

private _housing = [
    IDC_BODY, IDC_BEZEL, IDC_TOPBAR, IDC_TITLE, IDC_READOUT, IDC_BOTBAR, IDC_HINTS,
    IDC_BRAND, IDC_SCREW_TL, IDC_SCREW_TR, IDC_SCREW_BL, IDC_SCREW_BR
];

// Ein Stab, der seinen Bildschirm selbst mitbringt, braucht kein Panel davor - das Bild
// sitzt am Geraet in der Hand. Wer es trotzdem will, schaltet die Einstellung "Use GUI" ein.
//
// Der Dialog geht in jedem Fall auf: er faengt die Tasten ab. Ohne ihn steckt der Spiegel
// unter der Tuer und laesst sich weder steuern noch schliessen.
// Wann der Monitor mitkommt. Ueber die ACE-Interaktion immer - dort zielt niemand, also
// bleibt der Bildschirm am Geraet zu klein, um etwas zu erkennen.
private _wantPanel = GVAR(viaInteraction) || {
    switch (GVAR(guiMode)) do {
        case 1: {_mode isEqualTo MODE_DOOR};
        case 2: {_mode isEqualTo MODE_FREE};
        case 3: {true};
        default {false};
    }
};

if ((currentWeapon ACE_player) in GVAR(screenWands) && {!_wantPanel}) then {
    {
        (_display displayCtrl _x) ctrlShow false;
    } forEach (_housing + [IDC_SCREENMASK]);
    _ctrlFault ctrlShow false;

    // Das Feed-Control wird ausgeblendet, nicht versteckt. Arma haelt ein Render-Target nur
    // am Leben, solange etwas es zeichnet, und ein verstecktes Control zeichnet nichts. Auf
    // Deckkraft null gezogen zaehlt es weiter als Abnehmer und ist trotzdem unsichtbar.
    private _feed = _display displayCtrl IDC_FEED;
    _feed ctrlSetFade 1;
    _feed ctrlCommit 0;

    // Nachtsicht darf hier nichts einblenden. Der IR-Schleier liegt auf der Bildschirm-
    // flaeche des Panels, und die ist zwar unsichtbar, aber immer noch da - eingeschaltet
    // klatschte er als grosser gruener Klotz mitten ins Bild. Auf dem Modellbildschirm
    // erledigt setPiPEffect die Faerbung ohnehin schon, direkt im Render-Target.
    uiNamespace setVariable [QGVAR(ctrlIrTint), controlNull];

    // Tastenbelegung als schmale Leiste am unteren Bildrand.
    //
    // Ins Kamerabild selbst laesst sie sich nicht hineinschreiben: das Render-Target ist die
    // Ausgabe einer Kamera, und Arma bietet keinen Weg, dort etwas hineinzuzeichnen -
    // drawIcon3D und Konsorten zeichnen auf den Bildschirm des Spielers, nicht in ein
    // Render-Target. Also sitzt die Leiste dort, im Stil des Geraets, statt das Bild auf dem
    // Monitor zu ueberdecken.
    //
    // Im Stoerungsfall traegt dieselbe Leiste die Fehlermeldung. Auf dem Modellbildschirm
    // kann sie aus demselben Grund nicht stehen, und eine ACE-Benachrichtigung waere aus dem
    // Ton gefallen.
    // Nur die Schrift, kein Balken dahinter. Mit Hintergrund sah es aus wie ein
    // uebriggebliebenes Stueck Panel, das dort nichts zu suchen hat.
    private _fault = _mode isEqualTo MODE_FAULT;
    private _stripH = (0.030 * safezoneH) * ([1, 2.2] select _fault);
    private _stripW = 0.6 * safezoneW;
    private _stripX = safezoneX + (safezoneW - _stripW) / 2;
    private _stripY = safezoneY + safezoneH - _stripH - 0.045 * safezoneH;

    (_display displayCtrl IDC_BOTBAR) ctrlShow false;

    private _hints = _display displayCtrl IDC_HINTS;
    _hints ctrlShow true;
    _hints ctrlSetPosition [_stripX, _stripY, _stripW, _stripH];
    _hints ctrlCommit 0;

    // Groesser, weiss und mit Schatten - aber nur hier. Im Panel sitzt dieselbe Legende auf
    // dunklem Grund und war so, wie sie war, richtig. Die Groesse kommt als Faktor im Text
    // statt als Controleigenschaft, damit die Konfiguration unangetastet bleibt.
    //
    // Die gruenen Tastennamen ueberschreiben die Farbe innerhalb ihres eigenen Abschnitts,
    // die Groesse erben sie von hier.
    private _fnc_big = {
        format ["<t size='1.9' color='#ffffff' shadow='1'>%1</t>", _this]
    };

    if (_fault) then {
        _hintText = format ["%1<br/>%2", LLSTRING(Fault_NoClearance), LLSTRING(Feed_Hints_Fault)];
    };

    _hints ctrlSetStructuredText parseText (_hintText call _fnc_big);
} else {
    // Volles Panel. Das gilt auch fuer den Spectrum-Stab, der gar keinen eigenen Bildschirm
    // hat - bei dem waere ohne Panel schlicht nichts zu sehen.
    {
        (_display displayCtrl _x) ctrlShow true;
    } forEach _housing;
};

uiNamespace setVariable [QGVAR(ctrlReadout), _display displayCtrl IDC_READOUT];

////////////////////////////////////////////////////////////////////////////////
// Input
////////////////////////////////////////////////////////////////////////////////

// Hier stehen keine Display-Handler mehr.
//
// Eine Titelebene bekommt keinen Eingabefokus, also koennte sie ohnehin keine Taste sehen.
// Die Steuerung liegt jetzt auf CBA-Keybinds, die in XEH_postInit angemeldet werden und
// sich in den Einstellungen umlegen lassen - was hier noetig ist, weil der Spieler waehrend
// des Spaehens weiterlaeuft und die Tasten sich mit den normalen Belegungen ueberschneiden
// koennen.
//
// Beendet wird ueber das Zielen selbst: fnc_update schliesst, sobald der Spieler die
// Zielansicht verlaesst. Rechtsklick bringt einen rein und wieder raus, ganz ohne Sonderfall.

playSound "ACE_Sound_Click";
[QGVAR(deployed), [ACE_player, _house, _door, _mode]] call CBA_fnc_localEvent;

// A fault screen has no camera to drive, so it needs no per frame handler either
if (_mode isNotEqualTo MODE_FAULT) then {
    GVAR(pfhId) = [{call FUNC(update)}, 0, []] call CBA_fnc_addPerFrameHandler;
    // Aim the camera straight away so the first rendered frame is already correct
    call FUNC(update);
};
