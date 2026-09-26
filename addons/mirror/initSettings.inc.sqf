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

// Off lets every other mod's keys fire while peeking again - the TFAR stereo keys on
// Ctrl+arrows among them. For the player who wants that trade, not a default.
[
    QGVAR(lockInput), "CHECKBOX",
    [LSTRING(Setting_LockInput), LSTRING(Setting_LockInput_Description)],
    CATEGORY_MIRROR,
    [true],
    0
] call CBA_fnc_addSetting;

// With no clearance the head cannot extend, and the device says so. Anyone who does not
// want the message - because their unit does not expect to see through walls anyway -
// turns the check off and deploys the mirror anywhere.
[
    QGVAR(requireClearance), "CHECKBOX",
    [LSTRING(Setting_RequireClearance), LSTRING(Setting_RequireClearance_Description)],
    CATEGORY_MIRROR,
    [true],
    1
] call CBA_fnc_addSetting;

// Three values that belong together: the two limits and the starting value between them.
//
// The starting value is forced into those limits on deploy, so it can never begin at a
// field of view the zoom keys are unable to reach again.
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

// How much further than its starting position the head can be pushed in freehand mode.
// The arm is already extended, and the posture does not allow much beyond a regrip - anyone
// who wants more turns it up here. The wall check still stops it earlier when something is
// in the way.
[
    QGVAR(freeExtend), "SLIDER",
    [LSTRING(Setting_FreeExtend), LSTRING(Setting_FreeExtend_Description)],
    CATEGORY_MIRROR,
    [0, 1.0, FREE_EXTEND, 2],
    1
] call CBA_fnc_addSetting;

// ---------------------------------------------------------------------------------------
// Fine offset of the freehand camera, relative to the look direction.
//
// A setting rather than a constant, because it can only be judged in game: the camera must
// sit neither inside the device model nor floating beside it. Three axes, because reach
// along the line of sight and offset across it are separate problems.
//
// The defaults moved after testing: forward from 0.20 to 0.35, sideways from 0 to 0.10, up
// from 0 to 0.06. The wand is held in the right hand and reaches out in front, so a camera
// sitting on the eye looks straight down its own shaft - the shaft and the operator's own
// hands were both in the picture. Out, right and up puts the lens past all of it.
//
// A stored value beats a default, so anyone who has already touched these sliders keeps what
// they set. Reset them in Configure Addons to pick the new ones up.
// ---------------------------------------------------------------------------------------
[
    QGVAR(freeOffsetForward), "SLIDER",
    [LSTRING(Setting_OffsetForward), LSTRING(Setting_OffsetForward_Description)],
    CATEGORY_MIRROR,
    [-0.5, 1, 0.35, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(freeOffsetRight), "SLIDER",
    [LSTRING(Setting_OffsetRight), LSTRING(Setting_OffsetRight_Description)],
    CATEGORY_MIRROR,
    [-0.5, 0.5, 0.10, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(freeOffsetUp), "SLIDER",
    [LSTRING(Setting_OffsetUp), LSTRING(Setting_OffsetUp_Description)],
    CATEGORY_MIRROR,
    [-0.5, 0.5, 0.06, 2],
    0
] call CBA_fnc_addSetting;
