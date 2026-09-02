#define COMPONENT mirror
#define COMPONENT_BEAUTIFIED Mirror Mechanics
#include "\z\opw\addons\main\script_mod.hpp"

// #define DEBUG_MODE_FULL
// #define DISABLE_COMPILE_CACHE
// #define ENABLE_PERFORMANCE_COUNTERS

#ifdef DEBUG_ENABLED_MIRROR
    #define DEBUG_MODE_FULL
#endif

#ifdef DEBUG_SETTINGS_MIRROR
    #define DEBUG_SETTINGS DEBUG_SETTINGS_MIRROR
#endif

#include "\z\opw\addons\main\script_macros.hpp"

////////////////////////////////////////////////////////////////////////////////
// Weapon / assets
////////////////////////////////////////////////////////////////////////////////

// This addon holds no weapon of its own. Which weapons count as a mirror wand is decided
// at runtime through GVAR(wandClasses), and each device addon registers itself there.
// Keeping the mechanics free of any weapon class is what lets the same code drive the
// Spectrum Device today and anything else later.

#define ICON_MIRROR     "\A3\ui_f\data\IGUI\Cfg\simpleTasks\types\scout_ca.paa"

// Screen mask drawn on top of the feed: opaque surround, rounded transparent centre.
// This is what gives the picture rounded corners and a vignette instead of a hard rectangle.
#define TEXTURE_SCREENMASK "\z\ace\addons\viewports\data\optic_window_ca.paa"

// Optional: one image of a device with a fully transparent screen cutout. Leave "" and the
// housing is built from procedural colours instead. If you set it, DEVICE_CUT_* say where the
// cutout sits inside that image as fractions of the image, and the feed is fitted into it -
// the image is then scaled so the cutout lands exactly on the feed.
//   e.g. a 1024x640 image whose cutout runs from px 96..928 across and 72..520 down gives
//   L 0.094  T 0.113  R 0.906  B 0.813
#define TEXTURE_DEVICE  ""
#define DEVICE_CUT_L    0.07
#define DEVICE_CUT_T    0.12
#define DEVICE_CUT_R    0.93
#define DEVICE_CUT_B    0.80

////////////////////////////////////////////////////////////////////////////////
// Render target / dialog
////////////////////////////////////////////////////////////////////////////////

#define RTT_NAME        QGVAR(rtt)

// Edge length of the render target. 512 was visibly ragged on a screen-wide monitor, 1024
// clearly better, 2048 the last step that still buys anything.
//
// Why so much at all: the buffer is square, but the image inside it has the aspect ratio of
// the player's screen. So it gets squeezed into the square once and stretched back out on
// the monitor - two conversions, and sharpness is lost in each. A buffer in the right
// aspect ratio would be cheaper, but Arma decides the render target's format itself; the
// numbers here only control the size.
//
// This only runs while the mirror is out, so it costs nothing during normal play.
//
// Must match FEED_TEXTURE in the device addon. If you need frame rate, set both back to
// 1024.
#define RTT_SIZE        2048
#define IDD_MIRROR      91401

#define IDC_CURSORKILL  9140090
#define IDC_DEVICE      9140099
#define IDC_BODY        9140100
#define IDC_BEZEL       9140101
#define IDC_FEED        9140102
#define IDC_SCREENMASK  9140103
#define IDC_TOPBAR      9140105
#define IDC_TITLE       9140106
#define IDC_READOUT     9140108
#define IDC_BOTBAR      9140109
#define IDC_HINTS       9140110
#define IDC_BRAND       9140111
#define IDC_FAULT       9140115
#define IDC_IRTINT      9140116
#define IDC_SCREW_TL    9140120
#define IDC_SCREW_TR    9140121
#define IDC_SCREW_BL    9140122
#define IDC_SCREW_BR    9140123

////////////////////////////////////////////////////////////////////////////////
// Door detection
////////////////////////////////////////////////////////////////////////////////

// How far in front of the camera we look for a door (same idea as ACE's door reach)
#define DOOR_REACH_DISTANCE (((AGLToASL positionCameraToWorld [0, 0, 0]) vectorDistance (ACE_player modelToWorldWorld (ACE_player selectionPosition "Head"))) + 2)

// How far around the player a door is looked for, and at what height.
// The search deliberately does not depend on where you are looking: standing next to a
// door should be enough to be offered the mirror, without having to aim at it first. A fan
// of DOOR_SEARCH_RAYS rays is cast all the way round.
#define DOOR_SEARCH_RADIUS  3.2
#define DOOR_SEARCH_HEIGHT  0.9
#define DOOR_SEARCH_RAYS    12

// Interact-menu action point sits this far above the bottom edge of the door
#define ACTION_HEIGHT       0.06
// Interaction radius of the action point. Must reach at least as far as the search above,
// or the fan finds a door that the ACE menu then refuses to show.
#define ACTION_DISTANCE     3.6

////////////////////////////////////////////////////////////////////////////////
// Door measuring
////////////////////////////////////////////////////////////////////////////////

// Sampling resolution when walking along a door to find its edges
#define PANEL_STEP          0.08
// Give up past this - no door leaf is 1.4 m from its own centre
#define PANEL_MAX           1.44
// Half length of the ray pushed through the door while sampling
#define PANEL_PROBE_REACH   0.4
// Used when sampling fails and we fall back to the aim point
#define PANEL_FALLBACK_HALF 0.35

// Selections that say outright they are not a door
#define WINDOW_TOKENS       ["window", "okno", "vitrine", "shutter"]

// A door reaches the floor, a window does not. Anything whose bottom edge sits higher
// than this above the operator's feet is a window and gets handed to freehand instead.
#define DOOR_SILL_MAX       0.45

////////////////////////////////////////////////////////////////////////////////
// Mirror head
////////////////////////////////////////////////////////////////////////////////

#define YAW_LIMIT           95
#define PITCH_MIN           (-35)
#define PITCH_MAX           55
#define PITCH_DEFAULT       8
// Deploy modes
#define MODE_DOOR           0
#define MODE_FREE           1
// Nothing to show, just the device reporting it cannot be worked here
#define MODE_FAULT          2

// Freehand: the head sits on the end of the shaft. Base drops below the eye, roughly where
// the wand is actually held, and the reach is fixed - no pushing it further out from there.
#define FREE_BASE_DROP      0.22
// How far out the head sits in freehand mode, before anything in the way shortens it.
//
// Base reach in freehand mode. Measured rather than guessed: an outstretched arm from hand
// height is roughly 0.2 m, plus the length of the attachment. Earlier values put the head
// half a metre past the tip, where it floated in mid air instead of sitting on the device.
//
// The fine offset lives in the settings (freeOffset*), so it can be tried out in game
// rather than guessed at here.
#define POLE_LENGTH         0.65

// Refuse to deploy if there is less clear air than this in front of the operator
#define FREE_MIN_CLEAR      0.35

// How far the head sits above the shaft axis. Without it the camera looks along its own
// model when swivelling up, and the shaft stands in the middle of the picture. A few
// centimetres above and the device stays below the field of view.
#define FREE_CAM_LIFT       0.08

// How far past its starting position the head can be pushed in freehand mode.
// Deliberately small: the arm is outstretched, and the posture allows little more than a
// handspan of regrip. The wall check still applies and stops it earlier when something is
// in the way.
#define FREE_EXTEND         0.25

// How far around the operator loose shafts are hunted down after a detach
#define SHAFT_SWEEP_RANGE   8
// A mirror on a stick does not look backwards
#define FREE_YAW_LIMIT      100
#define FREE_PITCH_MIN      (-75)
#define FREE_PITCH_MAX      75

#define DEPTH_MIN           0.02
#define DEPTH_DEFAULT       0.14
// camSetFov: a smaller number means more zoomed in.
//
// These numbers were hunted for in the wrong order of magnitude for a long time. Values
// around 0.75 to 1.15 come from assuming a render target behaves like the main view - it
// does not. Measured in game: at 0.82 a target a few metres away looked like it was twenty
// metres off. That is roughly a factor of four, so the base value belongs an order of
// magnitude lower.
//
// 0.22 is the starting point that came out of that. The lower limit sits deliberately far
// below it, so the setting has room in both directions and does not run into an edge that
// was merely guessed at.
#define FOV_MIN             0.05
#define FOV_MAX             1.20
#define FOV_DEFAULT         0.22

// Keep the head clear of the door frame when sliding sideways
#define SLIDE_MARGIN        0.17

#define RATE_YAW            55
#define RATE_PITCH          40
#define RATE_DEPTH          0.25
#define RATE_SLIDE          0.25
#define RATE_ZOOM_KEY       0.35

////////////////////////////////////////////////////////////////////////////////
// Keeping the head out of solid geometry
////////////////////////////////////////////////////////////////////////////////

// Floor is re-probed once the head has moved further than this
#define PROBE_TOLERANCE     0.02
// Probe window around the expected floor height
#define PROBE_UP            0.3
#define PROBE_DOWN          0.9
// Stop this far short of whatever the head ran into
#define COLLISION_CLEARANCE 0.09

////////////////////////////////////////////////////////////////////////////////
// Session
////////////////////////////////////////////////////////////////////////////////

// Auto-retract once the operator steps away from where they deployed
#define ABORT_DISTANCE      1.5
// A door counts as "open" from this animation phase up
#define DOOR_OPEN_PHASE     0.25

// Axis indices for GVAR(axes)
#define AXIS_YAW            0
#define AXIS_PITCH          1
#define AXIS_DEPTH          2
#define AXIS_FOV            3
#define AXIS_SLIDE          4
