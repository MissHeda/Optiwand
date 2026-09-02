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
    // Weglaufen beendet nur die Tuerarbeit - dort haengt der Spiegel in einem bestimmten
    // Spalt. Freihand haelt man das Geraet selbst, also darf man damit auch gehen; die
    // Kamera wird weiter unten jeden Frame neu an den Spieler gesetzt.
    || {_isDoor && {(getPosASL _player) vectorDistance GVAR(anchorASL) > ABORT_DISTANCE}}
    || {isNull GVAR(camera)}
    // Rechtsklick hat uns hereingebracht, Rechtsklick bringt uns wieder heraus: verlaesst
    // der Spieler die Zielansicht, ist der Spiegel eingeholt. Frueher hing das an einem
    // Maus-Handler des Dialogs - den gibt es nicht mehr.
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
// Seitlich schieben ist Tuerarbeit - im Freihandmodus gibt es keinen Spalt, an dem entlang.
if (_inSlide != 0 && {_isDoor} && {GVAR(slideLimit) > 0}) then {
    GVAR(slide) = ((GVAR(slide) + _inSlide * RATE_SLIDE * _delta) max (-GVAR(slideLimit))) min GVAR(slideLimit);
};

// Ausfahren geht in beiden Modi, nur mit unterschiedlichem Spielraum. An der Tuer schiebt
// man den Kopf durch den Spalt, das kann weit gehen. Freihand haengt er am ausgestreckten
// Arm - da ist nur ein Nachfassen um Handbreite drin, mehr gibt die Haltung nicht her.
if (_inDepth != 0) then {
    // Freihand gibt es nur nach vorne und wieder zurueck bis zum Ausgangspunkt. Weiter
    // heranziehen hiesse, den Kopf in den Stab und in die eigene Hand zu schieben - dabei
    // steckt die Kamera dann im Modell.
    private _minDepth = [GVAR(depthDefault), DEPTH_MIN] select _isDoor;
    private _maxDepth = [GVAR(depthDefault) + GVAR(freeExtend), GVAR(maxDepth)] select _isDoor;
    GVAR(depth) = ((GVAR(depth) + _inDepth * RATE_DEPTH * _delta) max _minDepth) min _maxDepth;
};
// Rauszoomen nur bis zum Ausgangspunkt zurueck. Darueber hinaus wird das Bild so weit, dass
// ein Ziel in wenigen Metern aussieht wie am Horizont - dieselbe Ueberlegung wie beim
// Ausfahren, wo es auch nur nach vorne und wieder zurueck geht.
if (_inFov != 0) then {
    GVAR(fov) = ((GVAR(fov) + _inFov * RATE_ZOOM_KEY * _delta) max GVAR(fovNear)) min GVAR(fovFar);
    GVAR(camera) camSetFov GVAR(fov);
    GVAR(camera) camCommit 0;
};

////////////////////////////////////////////////////////////////////////////////
// Freihand: dem Spieler folgen
////////////////////////////////////////////////////////////////////////////////
//
// An der Tuer bleibt der Ansatzpunkt stehen - der Spalt wandert ja nicht. Freihand haelt
// der Spieler das Geraet in der Hand, also muss der Ansatz jeden Frame neu von Auge und
// Blickrichtung kommen. Ohne das bliebe die Kamera beim Losgehen einfach zurueck.
//
// yaw und pitch aus den Tasten sind dabei Ablagen auf diese Blickrichtung, keine absoluten
// Winkel: das Geraet zeigt dorthin, wohin der Spieler zeigt, und die Tasten schwenken den
// Kopf zusaetzlich.

if (!_isDoor) then {
    private _look = _player weaponDirection (currentWeapon _player);
    if (_look isEqualTo [0, 0, 0]) then {
        _look = getCameraViewDirection _player;
    };

    // Grundlage ist das Auge, darauf kommt der Versatz aus den Einstellungen: vorwaerts
    // entlang der Blickrichtung, seitlich entlang der Rechten, hoch entlang der Welt-Z.
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

// An der Tuer ist GVAR(pitch) der Winkel selbst. Freihand ist er die Ablage auf die
// Blickrichtung, die oben jeden Frame neu gemessen wird - sonst wuerde der Kopf beim
// Umsehen stehen bleiben, waehrend das Geraet in der Hand mitgeht.
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
    // Gegen den eigenen Grundwert gerechnet, nicht gegen einen festen: 1.0x heisst
    // damit "so weit, wie du es eingestellt hast", und nicht "so weit wie meine Zahl".
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
