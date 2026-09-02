#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Puts the mirror out: creates the render to texture camera, raises the overlay and hooks
 * up the controls.
 * The camera renders into a texture instead of onto the screen (same technique as
 * ace_viewports_fnc_viewCreate by PabstMirror), so the world keeps rendering normally behind
 * the device. The overlay is a title layer, not a dialog, so the player keeps moving.
 *
 * Three modes:
 *   MODE_DOOR   the head sits in the door slit, rides the floor and slides along the gap
 *   MODE_FREE   the head sits on the end of the shaft, wherever the operator pointed it -
 *               for looking over a wall or round a corner. No floor, no sideways slide.
 *
 * There is no fault mode any more. Having no room to work is a state the head can be in and
 * come out of again, so it is measured every frame in fnc_update and shown through
 * fnc_setFault - see the note there for why the old mode had to go.
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
if (_basePosASL isEqualTo [] || {_reachDir isEqualTo []}) exitWith {};
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
    // Zero, not the look angle at deploy time: in freehand mode GVAR(pitch) is an offset on
    // the look direction, which fnc_update measures fresh every frame. Were the starting
    // angle stored here it would be added on top of every measurement, and the head would
    // point twice as steeply as the device.
    GVAR(basePitch) = 0;
    GVAR(freeLookPitch) = asin (((_reachDir select 2) max -1) min 1);
    GVAR(depthDefault) = _reach;
    GVAR(slideLimit) = 0;

    // Lift the head a little above the shaft axis, or the model itself stands in the picture
    // when swivelling up.
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
// Order the limits once and remember them, so fnc_update does not re-sort them every frame -
// and so the starting value is guaranteed to sit between them.
GVAR(fovNear) = GVAR(zoomNear) min GVAR(zoomFar);
GVAR(fovFar) = GVAR(zoomNear) max GVAR(zoomFar);
GVAR(fovStart) = (GVAR(defaultFov) max GVAR(fovNear)) min GVAR(fovFar);
GVAR(fov) = GVAR(fovStart);
GVAR(nightVision) = false;
// Cleared here rather than in fnc_setFault: that one only acts on a change, so it has to
// start from a known state or the first real measurement is swallowed as "no change".
GVAR(faulted) = false;
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

GVAR(camera) = "camera" camCreate (ASLToAGL _basePosASL);
GVAR(camera) cameraEffect ["INTERNAL", "BACK", RTT_NAME];
RTT_NAME setPiPEffect [0];
GVAR(camera) camSetFov GVAR(fov);
GVAR(camera) camCommit 0;

////////////////////////////////////////////////////////////////////////////////
// Monitor
////////////////////////////////////////////////////////////////////////////////

// Title layer rather than dialog.
//
// A dialog captures every input - the player stood fixed in place for as long as the mirror
// was out. An RscTitles layer draws the same thing but leaves walking, looking around and
// the weapon free. The keys in turn come from CBA keybinds rather than from the display.
//
// cutRsc creates the display within the same frame; its onLoad puts it into the uiNamespace,
// which is why it can be picked up immediately afterwards.
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
// The size must match FEED_TEXTURE in the device addon: both bind the same render target,
// and the number in the texture string tells Arma how large a buffer to allocate for it.
// Two different figures under the same name is a coin toss over which one wins.
private _feedTexture = format ["#(argb,%1,%1,1)r2t(%2,1)", RTT_SIZE, RTT_NAME];

// The chosen text is remembered: the no-panel branch sets it a second time straight after,
// larger and white.
private _hintText = "";

_ctrlFault ctrlShow false;

private _titleText = "";
switch (_mode) do {
    case MODE_FREE: {
        _titleText = LLSTRING(Feed_Title_Free);
        _hintText = LLSTRING(Feed_Hints_Free);
    };
    default {
        _titleText = LLSTRING(Feed_Title);
        _hintText = LLSTRING(Feed_Hints);
    };
};

(_display displayCtrl IDC_FEED) ctrlSetText _feedTexture;
(_display displayCtrl IDC_TITLE) ctrlSetText _titleText;
(_display displayCtrl IDC_HINTS) ctrlSetStructuredText parseText _hintText;

// fnc_setFault redraws these when the head runs out of room, so it needs the pieces the
// layout produced here rather than working them out a second time.
GVAR(screenRect) = [_screenX, _screenY, _screenW, _screenH];
GVAR(feedTexture) = _feedTexture;
GVAR(titleText) = _titleText;
GVAR(hintText) = _hintText;

private _housing = [
    IDC_BODY, IDC_BEZEL, IDC_TOPBAR, IDC_TITLE, IDC_READOUT, IDC_BOTBAR, IDC_HINTS,
    IDC_BRAND, IDC_SCREW_TL, IDC_SCREW_TR, IDC_SCREW_BL, IDC_SCREW_BR
];

// A wand that brings its own screen needs no panel in front of it - the picture sits on the
// device in your hand. Anyone who wants it anyway turns the monitor setting on.
//
// The overlay layer comes up either way: it carries the key legend.
//
// When the monitor comes along. Through the ACE interaction always - nobody is aiming
// there, so the screen on the device stays too small to make anything out.
private _wantPanel = GVAR(viaInteraction) || {
    switch (GVAR(guiMode)) do {
        case 1: {_mode isEqualTo MODE_DOOR};
        case 2: {_mode isEqualTo MODE_FREE};
        case 3: {true};
        default {false};
    }
};

GVAR(panelShown) = !((currentWeapon ACE_player) in GVAR(screenWands) && {!_wantPanel});

if (!GVAR(panelShown)) then {
    {
        (_display displayCtrl _x) ctrlShow false;
    } forEach (_housing + [IDC_SCREENMASK]);
    _ctrlFault ctrlShow false;

    // The feed control is faded out, not hidden. Arma only keeps a render target alive while
    // something draws it, and a hidden control draws nothing. Pulled to zero opacity it still
    // counts as a consumer and is invisible all the same.
    private _feed = _display displayCtrl IDC_FEED;
    _feed ctrlSetFade 1;
    _feed ctrlCommit 0;

    // Night vision must show nothing here. The IR wash sits on the panel's screen area, and
    // that area is invisible but still present - switched on it slapped a large green block
    // into the middle of the view. On the device screen setPiPEffect already does the
    // tinting anyway, directly in the render target.
    uiNamespace setVariable [QGVAR(ctrlIrTint), controlNull];

    // Key legend as a thin strip along the bottom edge.
    //
    // It cannot be written into the camera picture itself: the render target is a camera's
    // output, and Arma offers no way to draw into one - drawIcon3D and friends draw onto the
    // player's screen, not into a render target. So the strip sits down there, in the
    // device's own style, rather than covering the picture.
    //
    // In the fault case the same strip carries the error message. It cannot live on the
    // device screen for the same reason, and an ACE notification would have struck the wrong
    // note.
    // Text only, no bar behind it. With a background it looked like a leftover piece of
    // panel that had no business being there.
    //
    // Two rectangles, because the fault message is two lines and needs the room. Both are
    // worked out here and handed to fnc_setFault, which switches between them.
    private _stripH = 0.030 * safezoneH;
    private _stripHFault = _stripH * 2.2;
    private _stripW = 0.6 * safezoneW;
    private _stripX = safezoneX + (safezoneW - _stripW) / 2;
    private _stripY = safezoneY + safezoneH - _stripH - 0.045 * safezoneH;
    private _stripYFault = safezoneY + safezoneH - _stripHFault - 0.045 * safezoneH;

    GVAR(stripRect) = [_stripX, _stripY, _stripW, _stripH];
    GVAR(stripRectFault) = [_stripX, _stripYFault, _stripW, _stripHFault];

    (_display displayCtrl IDC_BOTBAR) ctrlShow false;

    private _hints = _display displayCtrl IDC_HINTS;
    _hints ctrlShow true;
    _hints ctrlSetPosition [_stripX, _stripY, _stripW, _stripH];
    _hints ctrlCommit 0;

    // Larger, white and with a shadow - but only here. Inside the panel the same legend sits
    // on a dark background and was right as it was. The size comes as a factor in the text
    // rather than as a control property, so the config stays untouched.
    //
    // The green key names override the colour within their own span and inherit the size
    // from here.
    _hints ctrlSetStructuredText parseText (format [
        "<t size='1.9' color='#ffffff' shadow='1'>%1</t>", _hintText
    ]);
} else {
    // Full panel. That also applies to any wand with no screen of its own - without the
    // panel there would simply be nothing to look at.
    {
        (_display displayCtrl _x) ctrlShow true;
    } forEach _housing;
};

uiNamespace setVariable [QGVAR(ctrlReadout), _display displayCtrl IDC_READOUT];

////////////////////////////////////////////////////////////////////////////////
// Input
////////////////////////////////////////////////////////////////////////////////

// No display handlers here any more.
//
// A title layer gets no input focus, so it could not see a key press in any case. The
// controls now live on CBA keybinds, registered in XEH_postInit and remappable in the
// settings - which is necessary here, because the player keeps walking while peeking and
// the keys can collide with the normal bindings.
//
// Ending is handled by the aimed view itself: fnc_update closes as soon as the player
// leaves it. Right click brings you in and back out, with no special case at all.

playSound "ACE_Sound_Click";
[QGVAR(deployed), [ACE_player, _house, _door, _mode]] call CBA_fnc_localEvent;

// Unconditional, and it has to stay that way. fnc_update is the only thing that ever closes
// the monitor again - leaving a deploy without one is what used to trap the operator.
GVAR(pfhId) = [{call FUNC(update)}, 0, []] call CBA_fnc_addPerFrameHandler;
// Aim the camera straight away so the first rendered frame is already correct
call FUNC(update);
