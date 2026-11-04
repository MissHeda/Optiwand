#define CATEGORY_MIRROR LLSTRING(SettingCategory)

// In order: numbers, then switches. The device addon's settings join on the end of the category.

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

// How much further than its starting position the head can be pushed in freehand mode. The wall
// check still stops it earlier when something is in the way.
[
    QGVAR(freeExtend), "SLIDER",
    [LSTRING(Setting_FreeExtend), LSTRING(Setting_FreeExtend_Description)],
    CATEGORY_MIRROR,
    [0, 1.0, FREE_EXTEND, 2],
    1
] call CBA_fnc_addSetting;

// ---------------------------------------------------------------------------------------
// Fine offset of the freehand camera, relative to the end of the wand.
//
// A setting rather than a constant, because it can only be judged in game: how far the hand
// sits from the device's origin differs a little with the animation. Three axes, because reach
// along the line of sight and offset across it are separate problems.
//
// New names rather than the old freeOffset*: those measured from the eye, and a value stored
// under them would throw the head far off the wand.
// ---------------------------------------------------------------------------------------
[
    QGVAR(tipOffsetForward), "SLIDER",
    [LSTRING(Setting_OffsetForward), LSTRING(Setting_OffsetForward_Description)],
    CATEGORY_MIRROR,
    [-0.5, 0.5, 0, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(tipOffsetRight), "SLIDER",
    [LSTRING(Setting_OffsetRight), LSTRING(Setting_OffsetRight_Description)],
    CATEGORY_MIRROR,
    [-0.5, 0.5, 0, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(tipOffsetUp), "SLIDER",
    [LSTRING(Setting_OffsetUp), LSTRING(Setting_OffsetUp_Description)],
    CATEGORY_MIRROR,
    [-0.5, 0.5, 0, 2],
    0
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

// With no clearance the head cannot extend, and the monitor says so. Anyone who does not want
// the message - because their unit does not expect to see through walls anyway - turns the
// check off and deploys the mirror anywhere.
[
    QGVAR(requireClearance), "CHECKBOX",
    [LSTRING(Setting_RequireClearance), LSTRING(Setting_RequireClearance_Description)],
    CATEGORY_MIRROR,
    [true],
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
