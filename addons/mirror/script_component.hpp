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

////////////////////////////////////////////////////////////////////////////////
// Render target / overlay
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

// Three controls, and that is the whole overlay - see gui.hpp. There is no idd: this is a
// title layer, not a dialog, and giving it one is part of what let the mouse escape.
#define IDC_FEED        9140102
#define IDC_READOUT     9140108
#define IDC_HINTS       9140110

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
// There is no fault mode. Having no room to work is a state, not a way of deploying - see
// fnc_setFault.

// Freehand: the head sits on the end of the shaft. Base drops below the eye, roughly where
// the wand is actually held, and the reach is fixed - no pushing it further out from there.
#define FREE_BASE_DROP      0.22
// How far out the head sits in freehand mode, before anything in the way shortens it.
//
// Base reach in freehand mode. An outstretched arm from hand height is roughly 0.2 m, plus
// the length of the attachment; much beyond that and the head floats in mid air rather
// than sitting on the device.
//
// The fine offset lives in the settings (freeOffset*), so it can be dialled in while
// playing.
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
// A render target does not behave like the main view, and the usable range sits an order of
// magnitude lower than the main view's. Measured in game: at 0.82 a target a few metres
// away reads as roughly twenty metres off.
//
// Hence 0.22 as the starting point, with the limits set wide around it so the setting has
// room in both directions.
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

// How long the aimed-view check is held off after the ACE interaction raises the device
// itself. Long enough for the engine to have switched, short enough that a deploy which
// genuinely never gets there still ends promptly.
#define VIEW_GRACE          0.6

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
