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

private _player = CURRENT_UNIT;
private _isDoor = GVAR(mode) isEqualTo MODE_DOOR;
private _now = diag_tickTime;

if (
    !alive _player
    || {lifeState _player isEqualTo "INCAPACITATED"}
    || {_player getVariable ["ACE_isUnconscious", false]}
    || {!isNull objectParent _player}
    // Walking away only ends door work - there the mirror hangs in one particular gap.
    // Freehand you are holding the device yourself, so you may walk with it; the camera is
    // re-placed on the player every frame further down.
    || {_isDoor && {(getPosASL _player) vectorDistance GVAR(anchorASL) > ABORT_DISTANCE}}
    || {isNull GVAR(camera)}
    // Right click brought us in, right click takes us back out: once the player leaves the
    // aimed view, the mirror is retracted.
    //
    // Held off for VIEW_GRACE after an ACE interaction deploy, which raises the device itself
    // - see the note in fnc_openView. Zero outside that case, so aiming behaves exactly as
    // it did.
    || {cameraView isNotEqualTo "GUNNER" && {_now > GVAR(viewGrace)}}
    || {isNull (uiNamespace getVariable [QGVAR(display), displayNull])}
    // The pause menu ends the peek. XEH_postInit already does this through OnGameInterrupt;
    // this catches the menu should that event ever be missed. It matters beyond tidiness:
    // Configure Addons is behind this menu, and rebinding a key while fnc_lockInput has CBA's
    // tables swapped would leave the old binding live after the peek.
    || {!isNull findDisplay 49}
    || {!([_player] call FUNC(wandReady))}
    // Something else closed the dialog holding the player still. Without it they would be
    // walking round with the keyboard half locked.
    || {GVAR(lockDialogOpen) && {isNull findDisplay IDD_LOCK}}
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

// The lock's dialog frees the mouse pointer, and it must not wander out of the window. Brought
// back long before it reaches the edge, as a fast flick covers a lot of screen in one frame. Not
// held in the very middle: anything else that opens on top of the dialog, an error message for
// one, still has to be clickable.
if (GVAR(lockDialogOpen)) then {
    getMousePosition params ["_mouseX", "_mouseY"];
    if (
        abs (_mouseX - 0.5) > safezoneW * MOUSE_RANGE
        || {abs (_mouseY - 0.5) > safezoneH * MOUSE_RANGE}
    ) then {
        setMousePosition [0.5, 0.5];
    };
};

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
    private _minDepth = [GVAR(depthDefault), DOOR_DEPTH_MIN] select _isDoor;
    private _maxDepth = [GVAR(depthDefault) + GVAR(freeExtend), GVAR(maxDepth) max GVAR(depthDefault)] select _isDoor;
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

    // The hand holding the device is the basis, with the offset from the settings on top:
    // forward along the look direction, sideways along the right vector, up along world Z.
    private _right = vectorNormalized ([_look select 0, _look select 1, 0] vectorCrossProduct [0, 0, 1]);
    GVAR(basePosASL) = ([_player] call FUNC(wandBase))
        vectorAdd [0, 0, GVAR(tipOffsetUp)]
        vectorAdd (_look vectorMultiply GVAR(tipOffsetForward))
        vectorAdd (_right vectorMultiply GVAR(tipOffsetRight));
    // The reach direction has to come along too, and for a long time it did not: it was set
    // once at deploy and left there, so the base swung round with the player while the head
    // went on extending along whatever direction had been current at the moment of deploy.
    // Deploy facing south, turn north, and the head is behind you - which is to say inside
    // you, with the camera looking at your own arms.
    GVAR(baseDir) = _look;
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
        private _hits = lineIntersectsSurfaces [_last, _target, _player, objNull, true, 5, "GEOM", "FIRE"];

        // A line that starts inside a solid part of a house reports a hit right at its start. Only
        // what lies ahead, within the distance travelled, counts as in the way.
        private _reach = vectorMagnitude _travel;
        private _along = vectorNormalized _travel;
        _hits = _hits select {
            private _ahead = ((_x select 0) vectorDiff _last) vectorDotProduct _along;
            _ahead > 0.01 && {_ahead <= _reach}
        };

        if (_hits isNotEqualTo []) then {
            private _hitASL = (_hits select 0) select 0;
            _target = _hitASL vectorDiff ((vectorNormalized _travel) vectorMultiply COLLISION_CLEARANCE);

            // Feed the achieved position back into the controls, otherwise reach and slide
            // keep counting up against a wall and the head jumps once it comes free
            if (_isDoor) then {
                private _rel = _target vectorDiff GVAR(basePosASL);
                GVAR(depth) = ((_rel vectorDotProduct GVAR(baseDir)) max DOOR_DEPTH_MIN) min (GVAR(maxDepth) max GVAR(depthDefault));
                if (GVAR(slideLimit) > 0) then {
                    GVAR(slide) = ((_rel vectorDotProduct GVAR(baseRight)) max (-GVAR(slideLimit))) min GVAR(slideLimit);
                };
            };

            TRACE_1("mirror head blocked",_hitASL);
        };
    };

    _wanted = _target;
};

// The sweep above only looks from where the head was last frame. Stepping up to a wall carries
// the base forward, and the head could end up past the wall with no line from its last position
// ever crossing it. So freehand the whole wand is checked as well, from the hand out to the head.
if (!_isDoor) then {
    private _out = _wanted vectorDiff GVAR(basePosASL);
    private _outDir = vectorNormalized _out;
    private _hits = (lineIntersectsSurfaces [GVAR(basePosASL), _wanted vectorAdd (_outDir vectorMultiply COLLISION_CLEARANCE), _player, objNull, true, 5, "GEOM", "FIRE"]) select {
        ((_x select 0) vectorDistance GVAR(basePosASL)) > 0.01
    };
    if (_hits isNotEqualTo []) then {
        _wanted = ((_hits select 0) select 0) vectorDiff (_outDir vectorMultiply COLLISION_CLEARANCE);
    };
};

if (_isDoor) then {
    // Follow the floor under the head rather than the floor at the door. A room behind a
    // threshold usually sits a few centimetres higher, which is what buries the camera
    // otherwise. Only re-probed once the head has actually shifted.
    if ((_wanted distance2D GVAR(lastProbeXY)) > PROBE_TOLERANCE) then {
        // The first probe starts high. The bottom of a door leaf can sit well below the floor behind
        // it, on a house standing on a solid base with steps up to the door.
        private _first = GVAR(lastProbeXY) isEqualTo [0, 0, 0];
        private _probeUp = [PROBE_UP, PROBE_FIRST] select _first;
        GVAR(lastProbeXY) = +_wanted;

        private _probeTop = [_wanted select 0, _wanted select 1, GVAR(floorZ) + _probeUp];
        private _probeBottom = [_wanted select 0, _wanted select 1, GVAR(floorZ) - PROBE_DOWN];
        private _floorHits = lineIntersectsSurfaces [_probeTop, _probeBottom, _player, objNull, true, 5, "GEOM", "FIRE"];

        // A probe that starts inside the geometry of a house reports a hit right at its start, and
        // nothing below that can be trusted: measured in game, the next hit was the ground under
        // the house. Taken as the floor, that first hit lifted the head a little further on every
        // probe, up to the roof. So the floor stays where it is, a little above the bottom of the
        // door if this is the first we hear of it.
        if (_floorHits isNotEqualTo []) then {
            private _height = ((_floorHits select 0) select 0) select 2;
            if (_height < (_probeTop select 2) - 0.01) then {
                GVAR(floorZ) = _height;
            } else {
                if (_first) then {GVAR(floorZ) = GVAR(floorZ) + PROBE_UP};
            };
        };
    };

    _wanted set [2, GVAR(floorZ) + GVAR(camHeight)];
};

GVAR(lastCamPosASL) = _wanted;

////////////////////////////////////////////////////////////////////////////////
// Room to work
////////////////////////////////////////////////////////////////////////////////
//
// Measured from what the head actually achieved after the sweep above, not from what was
// asked for. Aiming into a wall means the sweep stopped the head right in front of the
// operator's own face, and there is nothing worth showing from there.
//
// Door mode is exempt: the head is in the gap under the leaf, which is the whole point, and
// the reach there is short by design.
//
// The two thresholds are deliberately apart. One number would have the report flickering on
// and off while the operator drifts across it - coming on is stricter than going off.

if (!_isDoor && GVAR(requireClearance)) then {
    private _clear = _wanted vectorDistance GVAR(basePosASL);
    private _limit = [FREE_MIN_CLEAR, FREE_MIN_CLEAR * 1.25] select GVAR(faulted);
    [_clear < _limit] call FUNC(setFault);
} else {
    [false] call FUNC(setFault);
};

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

// Swivelled towards a wall, the head has to stay clear of it in that direction too, or the near
// edge of the view reaches through. At a door not back past the leaf, though.
private _ahead = (lineIntersectsSurfaces [_wanted, _wanted vectorAdd (_dir vectorMultiply COLLISION_CLEARANCE), _player, objNull, true, 5, "GEOM", "FIRE"]) select {
    ((_x select 0) vectorDistance _wanted) > 0.01
};
if (_ahead isNotEqualTo []) then {
    private _clear = ((_ahead select 0) select 0) vectorDistance _wanted;
    private _backed = _wanted vectorAdd (_dir vectorMultiply (_clear - COLLISION_CLEARANCE));
    if (!_isDoor || {((_backed vectorDiff GVAR(basePosASL)) vectorDotProduct GVAR(baseDir)) >= DOOR_DEPTH_MIN}) then {
        _wanted = _backed;
    };
};

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
