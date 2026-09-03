#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Drives the acquisition readout on the device's own screen.
 *
 * Why this exists at all: the device brings a transmit bar of its own - Progress, idc 4005 -
 * and #EM_Transmit / #EM_Progress already feed it. But Bohemia ships that control at w=0 h=0
 * and sizes it from their own script, so it came out too small to notice. Right click raised
 * the display and nothing on it looked like it was waiting for anything, so nobody could tell
 * they were meant to hold the mouse button.
 *
 * This is on the screen surface of the model, in the same Usertexture the picture lives in -
 * no second dialog, nothing floating in front of the world.
 *
 * Twelve segments switched with ctrlSetFade rather than one bar resized with
 * ctrlSetPosition. Fading these controls is proven - fnc_showFeed does it to the feed - while
 * resizing a control inside a render-to-texture area is not something that can be checked
 * from outside the game. Bohemia draws the traces on this very display the same way, out of a
 * row of pictures that are only shown and hidden.
 *
 * Arguments:
 * 0: Show <BOOL>
 * 1: Progress, 0..1 <NUMBER> (default: 0)
 *
 * Return Value:
 * None
 *
 * Example:
 * [true, 0.4] call opw_esdcam_fnc_showAcquire
 *
 * Public: No
 */

params [["_show", false, [false]], ["_progress", 0, [0]]];

private _display = uiNamespace getVariable [SPECTRUM_DISPLAY, displayNull];
if (isNull _display) exitWith {};

if (!_show) exitWith {
    if (GVAR(acqLit) isEqualTo -1) exitWith {};

    for "_i" from 0 to (ACQ_SEGMENTS - 1) do {
        private _seg = _display displayCtrl (IDC_ACQ_SEG + _i);
        private _track = _display displayCtrl (IDC_ACQ_TRACK + _i);
        if (!isNull _seg) then {_seg ctrlSetFade FADE_HIDE; _seg ctrlCommit 0};
        if (!isNull _track) then {_track ctrlSetFade FADE_HIDE; _track ctrlCommit 0};
    };

    private _label = _display displayCtrl IDC_ACQ_LABEL;
    if (!isNull _label) then {_label ctrlSetFade FADE_HIDE; _label ctrlCommit 0};

    GVAR(acqLit) = -1;
};

private _lit = round (_progress * ACQ_SEGMENTS);

// Coming up from hidden: the track and the label have to be faded in once. -1 is the "not on
// screen" marker, which is why it is not simply 0 - zero lit segments is a real state.
if (GVAR(acqLit) isEqualTo -1) then {
    for "_i" from 0 to (ACQ_SEGMENTS - 1) do {
        private _track = _display displayCtrl (IDC_ACQ_TRACK + _i);
        if (!isNull _track) then {_track ctrlSetFade FADE_SHOW; _track ctrlCommit 0};
    };
    GVAR(acqLit) = -2;      // forces the segment pass below to run even at _lit == 0
};

private _label = _display displayCtrl IDC_ACQ_LABEL;
if (!isNull _label) then {
    // Two different things to say, and the difference is the point of the whole control: with
    // nothing held the operator needs telling what to do, and once it is moving they need to
    // see that it is moving.
    private _text = if (_progress <= 0) then {
        LLSTRING(Acquire_Prompt)
    } else {
        format [LLSTRING(Acquire_Progress), round (_progress * 100)]
    };
    _label ctrlSetText _text;
    _label ctrlSetFade FADE_SHOW;
    _label ctrlCommit 0;
};

// Only touch what changed. This runs every frame while the button is held, and setting twelve
// fades a frame for no reason is exactly the kind of thing that shows up in a profile.
if (_lit isEqualTo GVAR(acqLit)) exitWith {};

private _from = 0 max (GVAR(acqLit) min _lit);
private _to = (ACQ_SEGMENTS - 1) min ((GVAR(acqLit) max _lit) - 1);
if (GVAR(acqLit) < 0) then {_from = 0; _to = ACQ_SEGMENTS - 1};

for "_i" from _from to _to do {
    private _seg = _display displayCtrl (IDC_ACQ_SEG + _i);
    if (!isNull _seg) then {
        // Spelled out rather than indexed off the boolean: FADE_SHOW and FADE_HIDE happen to
        // be 0 and 1, and a select on that reads as if the order were arbitrary when it is
        // not. Same shape fnc_showFeed uses.
        private _fade = FADE_HIDE;
        if (_i < _lit) then {_fade = FADE_SHOW};
        _seg ctrlSetFade _fade;
        _seg ctrlCommit 0;
    };
};

GVAR(acqLit) = _lit;
