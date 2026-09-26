#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Puts the mirror out: creates the render to texture camera, raises the overlay and hooks
 * up the controls. The picture appears on the device's own screen - the device addon listens
 * for the deployed event below and puts the render target there.
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
// Raise the device
////////////////////////////////////////////////////////////////////////////////
//
// The picture lives on the device's own screen, and that screen only exists while the device
// is up: Arma opens RscWeaponSpectrumAnalyzerGeneric when the weapon is raised, and the
// device addon needs it open to put the render target on it.
//
// Aiming gets there by itself - right click is what deploys. The ACE interaction does not:
// nobody is aiming when they pick an action out of the menu. That path used to be covered by
// the monitor panel, and with the panel gone it showed nothing at all - worse, fnc_update
// ends the session on `cameraView isNotEqualTo "GUNNER"`, so an interaction deploy closed
// again on its very first frame. It was broken before the panel went; the panel just hid it.
//
// So the interaction raises the device itself, and everything downstream is the same session
// the right click would have opened.
// A grace window with it, and that part is not decoration. fnc_update ends the session on
// `cameraView isNotEqualTo "GUNNER"`, and it is called once at the bottom of this very
// function - the same frame as the switchCamera above. Whether the engine has switched by
// then is not something that can be checked from outside the game, and if it has not, the
// session closes on the frame it opened. So the check is held off briefly; anything that
// still is not in the aimed view once the window passes gets closed as before.
GVAR(viewGrace) = 0;
if (GVAR(viaInteraction) && {cameraView isNotEqualTo "GUNNER"}) then {
    GVAR(viewBefore) = cameraView;
    ACE_player switchCamera "GUNNER";
    GVAR(viewGrace) = diag_tickTime + VIEW_GRACE;
};

////////////////////////////////////////////////////////////////////////////////
// Camera
////////////////////////////////////////////////////////////////////////////////

GVAR(camera) = "camera" camCreate (ASLToAGL _basePosASL);
GVAR(camera) cameraEffect ["INTERNAL", "BACK", RTT_NAME];
RTT_NAME setPiPEffect [0];
GVAR(camera) camSetFov GVAR(fov);
GVAR(camera) camCommit 0;

////////////////////////////////////////////////////////////////////////////////
// Overlay
////////////////////////////////////////////////////////////////////////////////
//
// A title layer with three controls and no panel. The picture goes on the device's own
// screen; all that is out here is the readout, the key legend, and an invisible feed control
// that exists only to keep the render target alive - see gui.hpp.
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

// The size must match FEED_TEXTURE in the device addon: both bind the same render target,
// and the number in the texture string tells Arma how large a buffer to allocate for it.
// Two different figures under the same name is a coin toss over which one wins.
private _feedTexture = format ["#(argb,%1,%1,1)r2t(%2,1)", RTT_SIZE, RTT_NAME];

// Faded out, not hidden. Arma keeps a render target alive only while something draws it, and
// a hidden control draws nothing - at zero opacity it still counts as a consumer and is
// invisible all the same.
private _feed = _display displayCtrl IDC_FEED;
_feed ctrlSetText _feedTexture;
_feed ctrlSetFade 1;
_feed ctrlCommit 0;

// Two lines along the bottom edge: the readout above, the legend below. Both in safezone
// units, so they sit in the same place whatever the resolution.
//
// They cannot go into the camera picture itself. The render target is a camera's output and
// Arma offers no way to draw into one - drawIcon3D and friends draw onto the player's
// screen, not into a render target. Hence a strip down here rather than an overlay on the
// picture.
private _lineH = 0.030 * safezoneH;
private _stripW = 0.7 * safezoneW;
private _stripX = safezoneX + (safezoneW - _stripW) / 2;
private _legendY = safezoneY + safezoneH - _lineH - 0.045 * safezoneH;
private _readoutY = _legendY - _lineH;

GVAR(stripRect) = [_stripX, _legendY, _stripW, _lineH];
// The no-clearance report is two lines, so it takes the readout's row as well.
GVAR(stripRectFault) = [_stripX, _readoutY, _stripW, _lineH * 2];

private _ctrlReadout = _display displayCtrl IDC_READOUT;
_ctrlReadout ctrlSetPosition [_stripX, _readoutY, _stripW, _lineH];
_ctrlReadout ctrlCommit 0;
uiNamespace setVariable [QGVAR(ctrlReadout), _ctrlReadout];

private _hintText = [LLSTRING(Feed_Hints), LLSTRING(Feed_Hints_Free)] select (_mode isEqualTo MODE_FREE);
GVAR(hintText) = _hintText;

private _hints = _display displayCtrl IDC_HINTS;
_hints ctrlSetPosition GVAR(stripRect);
_hints ctrlSetStructuredText parseText _hintText;
_hints ctrlCommit 0;

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

// Take the keyboard - on the next frame, not this one. The deploy keybind gets here from
// inside CBA's key dispatch, and muting handlers halfway through CBA walking the very list
// they sit in would split that one key press: handlers ahead of ours run, those after it are
// silenced, and their releases are armed muted. A frame later the press is fully dispatched.
// Last of the setup on purpose: anything above that bails out has not locked anything.
[{
    if (GVAR(active)) then {[true] call FUNC(lockInput)};
}] call CBA_fnc_execNextFrame;

// Unconditional, and it has to stay that way. fnc_update is the only thing that ever closes
// the monitor again - leaving a deploy without one is what used to trap the operator.
GVAR(pfhId) = [{call FUNC(update)}, 0, []] call CBA_fnc_addPerFrameHandler;
// Aim the camera straight away so the first rendered frame is already correct
call FUNC(update);
