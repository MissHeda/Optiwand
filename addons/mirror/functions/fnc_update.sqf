#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Per frame handler while the mirror is out: applies the held keys, keeps the head out of solid geometry, aims the camera and refreshes the monitor.
 *
 * This is the only thing in the mod that runs every frame, so everything that does not have
 * to happen every frame is gated: the floor probe on distance moved, the collision sweep on
 * the head actually moving, the door check on a timer, and the readout on its numbers
 * changing. Idle, this is a handful of comparisons and two setters.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call opw_mirror_fnc_update
 *
 * Public: No
 */

if (!GVAR(active)) exitWith {};

private _player = ACE_player;
private _isDoor = GVAR(mode) isEqualTo MODE_DOOR;
private _now = diag_tickTime;

if (
    !alive _player
    || {_player getVariable ["ACE_isUnconscious", false]}
    || {!isNull objectParent _player}
    // Walking away only ends door work - there the mirror hangs in one particular gap.
    // Freehand you are holding the device yourself, so you may walk with it; the camera is
    // re-placed on the player every frame further down.
    || {_isDoor && {(getPosASL _player) vectorDistance GVAR(anchorASL) > ABORT_DISTANCE}}
    || {isNull GVAR(camera)}
    // Right click brought us in, right click takes us back out: once the player leaves the
    // aimed view, the mirror is retracted.
    || {cameraView isNotEqualTo "GUNNER"}
    || {isNull (uiNamespace getVariable [QGVAR(display), displayNull])}
    || {!([_player] call FUNC(wandReady))}
) exitWith {
    call FUNC(closeView);
};

// Someone just opened the door on you. Four times a second is plenty for a door swinging.
if (_isDoor && {_now > GVAR(nextDoorCheck)}) then {
    GVAR(nextDoorCheck) = _now + 0.25;

    private _animations = ([GVAR(house), GVAR(door)] call FUNC(getDoorAnimations)) select 0;
    if (_animations isNotEqualTo [] && {(GVAR(house) animationPhase (_animations select 0)) > DOOR_OPEN_PHASE}) then {
        call FUNC(closeView);
    };
};

if (!GVAR(active)) exitWith {};

private _delta = (_now - GVAR(lastTick)) min 0.25;
GVAR(lastTick) = _now;

private _yawLimit = GVAR(yawLimit);
GVAR(pitchLimits) params ["_pitchMin", "_pitchMax"];

////////////////////////////////////////////////////////////////////////////////
// Held keys
////////////////////////////////////////////////////////////////////////////////

GVAR(axes) params ["_inYaw", "_inPitch", "_inDepth", "_inFov", "_inSlide"];

if (_inYaw != 0) then {
    GVAR(yaw) = ((GVAR(yaw) + _inYaw * RATE_YAW * _delta) max (-_yawLimit)) min _yawLimit;
};
if (_inPitch != 0) then {
    GVAR(pitch) = ((GVAR(pitch) + _inPitch * RATE_PITCH * _delta) max _pitchMin) min _pitchMax;
};
// Sliding sideways is door work - in freehand mode there is no gap to slide along.
if (_inSlide != 0 && {_isDoor} && {GVAR(slideLimit) > 0}) then {
    GVAR(slide) = ((GVAR(slide) + _inSlide * RATE_SLIDE * _delta) max (-GVAR(slideLimit))) min GVAR(slideLimit);
};

// Extending works in both modes, only with different room. At a door you push the head
// through the gap, which can go far. Freehand it hangs off an outstretched arm - there is
// only a handspan of regrip in that, and the posture allows no more.
if (_inDepth != 0) then {
    // Freehand only goes forward and back to the starting point. Pulling in further would
    // mean pushing the head into the shaft and into your own hand - at which point the
    // camera sits inside the model.
    private _minDepth = [GVAR(depthDefault), DEPTH_MIN] select _isDoor;
    private _maxDepth = [GVAR(depthDefault) + GVAR(freeExtend), GVAR(maxDepth)] select _isDoor;
    GVAR(depth) = ((GVAR(depth) + _inDepth * RATE_DEPTH * _delta) max _minDepth) min _maxDepth;
};
// Zooming out only goes back to the starting point. Beyond that the view gets so wide that
// a target a few metres away looks like it is on the horizon - the same reasoning as for
// extending, which also only goes out and back.
if (_inFov != 0) then {
    GVAR(fov) = ((GVAR(fov) + _inFov * RATE_ZOOM_KEY * _delta) max GVAR(fovNear)) min GVAR(fovFar);
    GVAR(camera) camSetFov GVAR(fov);
    GVAR(camera) camCommit 0;
};

////////////////////////////////////////////////////////////////////////////////
// Freehand: follow the player
////////////////////////////////////////////////////////////////////////////////
//
// At a door the anchor point stays put - the gap does not wander. Freehand the player is
// holding the device, so the anchor has to come fresh from eye and look direction every
// frame. Without that the camera would simply be left behind the moment you walk off.
//
// yaw and pitch from the keys are offsets on that look direction, not absolute angles: the
// device points where the player points, and the keys swivel the head on top of that.

if (!_isDoor) then {
    private _look = _player weaponDirection (currentWeapon _player);
    if (_look isEqualTo [0, 0, 0]) then {
        _look = getCameraViewDirection _player;
    };

    // The eye is the basis, with the offset from the settings on top: forward along the look
    // direction, sideways along the right vector, up along world Z.
    private _right = vectorNormalized ([_look select 0, _look select 1, 0] vectorCrossProduct [0, 0, 1]);
    GVAR(basePosASL) = (eyePos _player)
        vectorAdd [0, 0, FREE_CAM_LIFT - FREE_BASE_DROP + GVAR(freeOffsetUp)]
        vectorAdd (_look vectorMultiply GVAR(freeOffsetForward))
        vectorAdd (_right vectorMultiply GVAR(freeOffsetRight));
    GVAR(baseAzimuth) = (_look select 0) atan2 (_look select 1);
    GVAR(baseRight) = _right;
    GVAR(freeLookPitch) = asin (((_look select 2) max -1) min 1);
};

////////////////////////////////////////////////////////////////////////////////
// Where the head wants to be
////////////////////////////////////////////////////////////////////////////////

private _wanted = GVAR(basePosASL)
    vectorAdd (GVAR(baseDir) vectorMultiply GVAR(depth))
    vectorAdd (GVAR(baseRight) vectorMultiply GVAR(slide));

////////////////////////////////////////////////////////////////////////////////
// Do not push the head into anything solid
////////////////////////////////////////////////////////////////////////////////

private _last = GVAR(lastCamPosASL);

if (_last isNotEqualTo []) then {
    // In door mode the sweep runs flat, at the height the head is already at. Doing it
    // diagonally would snag on every sill the moment the floor probe lifts the head over the
    // threshold. Free mode has no floor to follow, so there it sweeps in full 3D.
    private _target = if (_isDoor) then {
        [_wanted select 0, _wanted select 1, _last select 2]
    } else {
        +_wanted
    };
    private _travel = _target vectorDiff _last;

    // Standing still costs nothing - no raycast unless the head actually moved
    if (vectorMagnitude _travel > 0.001) then {
        private _blocked = lineIntersectsSurfaces [_last, _target, _player, objNull, true, 1, "GEOM", "FIRE"];

        if (_blocked isNotEqualTo []) then {
            private _hitASL = (_blocked select 0) select 0;
            _target = _hitASL vectorDiff ((vectorNormalized _travel) vectorMultiply COLLISION_CLEARANCE);

            // Feed the achieved position back into the controls, otherwise reach and slide
            // keep counting up against a wall and the head jumps once it comes free
            if (_isDoor) then {
                private _rel = _target vectorDiff GVAR(basePosASL);
                GVAR(depth) = ((_rel vectorDotProduct GVAR(baseDir)) max DEPTH_MIN) min GVAR(maxDepth);
                if (GVAR(slideLimit) > 0) then {
                    GVAR(slide) = ((_rel vectorDotProduct GVAR(baseRight)) max (-GVAR(slideLimit))) min GVAR(slideLimit);
                };
            };

            TRACE_1("mirror head blocked",_hitASL);
        };
    };

    _wanted = _target;
};

if (_isDoor) then {
    // Follow the floor under the head rather than the floor at the door. A room behind a
    // threshold usually sits a few centimetres higher, which is what buries the camera
    // otherwise. Only re-probed once the head has actually shifted.
    if ((_wanted distance2D GVAR(lastProbeXY)) > PROBE_TOLERANCE) then {
        GVAR(lastProbeXY) = +_wanted;

        private _probeTop = [_wanted select 0, _wanted select 1, GVAR(floorZ) + PROBE_UP];
        private _probeBottom = [_wanted select 0, _wanted select 1, GVAR(floorZ) - PROBE_DOWN];
        private _floorHits = lineIntersectsSurfaces [_probeTop, _probeBottom, _player, objNull, true, 1, "GEOM", "FIRE"];

        if (_floorHits isNotEqualTo []) then {
            GVAR(floorZ) = ((_floorHits select 0) select 0) select 2;
        };
    };

    _wanted set [2, GVAR(floorZ) + GVAR(camHeight)];
};

GVAR(lastCamPosASL) = _wanted;

////////////////////////////////////////////////////////////////////////////////
// Aim the mirror head
////////////////////////////////////////////////////////////////////////////////

private _azimuth = GVAR(baseAzimuth) + GVAR(yaw);

// At a door GVAR(pitch) is the angle itself. Freehand it is the offset on the look
// direction measured fresh above every frame - otherwise the head would stay put while you
// look around, even though the device in your hand moves with you.
private _pitch = [
    GVAR(pitch),
    ((GVAR(freeLookPitch) + GVAR(pitch)) max FREE_PITCH_MIN) min FREE_PITCH_MAX
] select (!_isDoor);
private _cosPitch = cos _pitch;

private _dir = [(sin _azimuth) * _cosPitch, (cos _azimuth) * _cosPitch, sin _pitch];

// Nothing on the wand moved this frame, so there is nothing to tell the engine
if (_wanted isNotEqualTo GVAR(lastAppliedPos) || {_dir isNotEqualTo GVAR(lastAppliedDir)}) then {
    private _right = vectorNormalized (_dir vectorCrossProduct [0, 0, 1]);

    GVAR(camera) setPosASL _wanted;
    GVAR(camera) setVectorDirAndUp [_dir, vectorNormalized (_right vectorCrossProduct _dir)];

    GVAR(lastAppliedPos) = _wanted;
    GVAR(lastAppliedDir) = _dir;
};

////////////////////////////////////////////////////////////////////////////////
// Monitor
////////////////////////////////////////////////////////////////////////////////

private _ctrlReadout = uiNamespace getVariable [QGVAR(ctrlReadout), controlNull];
if (isNull _ctrlReadout) exitWith {};

// parseText allocates, so only touch the readout when a displayed number actually changed
private _snapshot = [
    round ((_azimuth + 360) % 360),
    round _pitch,
    // Measured against your own base value rather than a fixed one: 1.0x therefore means
    // "as wide as you set it", not "as wide as my number".
    round ((GVAR(fovStart) / GVAR(fov)) * 10),
    GVAR(nightVision)
];

if (_snapshot isEqualTo GVAR(readoutState)) exitWith {};
GVAR(readoutState) = _snapshot;

_snapshot params ["_heading", "_tilt", "_zoomTenths", "_ir"];
GVAR(hudLabels) params ["_labelAz", "_labelTilt", "_labelZoom"];

_ctrlReadout ctrlSetStructuredText parseText format [
    "<t color='#6fc78c'>%1</t> %2   <t color='#6fc78c'>%3</t> %4   <t color='#6fc78c'>%5</t> %6x%7",
    _labelAz, _heading,
    _labelTilt, _tilt,
    _labelZoom, _zoomTenths / 10,
    ["", "   <t color='#7fd48f'>IR</t>"] select _ir
];
