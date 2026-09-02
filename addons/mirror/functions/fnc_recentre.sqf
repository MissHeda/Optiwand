#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Resets swivel, reach and zoom to their starting positions.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Handled <BOOL>
 *
 * Example:
 * call opw_mirror_fnc_recentre
 *
 * Public: No
 */

if (!GVAR(active)) exitWith {false};

GVAR(yaw) = 0;
// Works in both modes: at a door basePitch is the resting angle, freehand it is zero and
// GVAR(pitch) is therefore the offset on the look direction.
GVAR(pitch) = GVAR(basePitch);
GVAR(depth) = GVAR(depthDefault);
GVAR(slide) = 0;
GVAR(fov) = GVAR(fovStart);

if (!isNull GVAR(camera)) then {
    GVAR(camera) camSetFov GVAR(fov);
    GVAR(camera) camCommit 0;
};

// Let the collision sweep re-evaluate from wherever the head ends up
GVAR(lastCamPosASL) = [];

true
