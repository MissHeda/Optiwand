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

// When the carried monitor comes along - split by mode, because the two feel different: at
// a door you stand still and look, while freehand you hold the device out in front of you
// and want the view clear.
//
// Off by default: the screen on the device is the whole point of the thing. Through the ACE
// interaction the monitor comes up regardless - nobody is aiming there, so the eye never
// gets close enough to read the small screen.
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

[
    QGVAR(guiMode), "LIST",
    [LSTRING(Setting_GuiMode), LSTRING(Setting_GuiMode_Description)],
    CATEGORY_MIRROR,
    [
        [0, 1, 2, 3],
        [LSTRING(GuiMode_Never), LSTRING(GuiMode_Door), LSTRING(GuiMode_Free), LSTRING(GuiMode_Always)],
        0
    ],
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

[
    QGVAR(feedScale), "SLIDER",
    [LSTRING(Setting_FeedScale), LSTRING(Setting_FeedScale_Description)],
    CATEGORY_MIRROR,
    [0.12, 0.7, 0.24, 2],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(feedPosition), "LIST",
    [LSTRING(Setting_FeedPosition), LSTRING(Setting_FeedPosition_Description)],
    CATEGORY_MIRROR,
    [
        [0, 1, 2, 3, 4, 5, 6, 7, 8],
        [
            LSTRING(Anchor_TopLeft),    LSTRING(Anchor_TopCentre),    LSTRING(Anchor_TopRight),
            LSTRING(Anchor_MiddleLeft), LSTRING(Anchor_Centre),       LSTRING(Anchor_MiddleRight),
            LSTRING(Anchor_BottomLeft), LSTRING(Anchor_BottomCentre), LSTRING(Anchor_BottomRight)
        ],
        7
    ],
    0
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
