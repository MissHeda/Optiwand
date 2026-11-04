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
// If you need frame rate, set it back to 1024.
#define RTT_SIZE        2048

// The whole overlay - see gui.hpp. There is no idd: this is a title layer, not a dialog, and
// giving it one is part of what let the mouse escape.
#define IDC_SCREEN      9140100
#define IDC_FEED        9140102
#define IDC_MONITOR     9140104
#define IDC_READOUT     9140108
#define IDC_HINTS       9140110
// The picture build-up on the monitor's dark screen, which the device addon drives. Must match
// addons\esdcam\script_component.hpp.
#define IDC_ACQ_LABEL   9140112
#define IDC_ACQ_TRACK   9140114
#define IDC_ACQ_FILL    9140116
#define IDC_OSD_TOP     9140118
#define IDC_OSD_BOTTOM  9140120
#define IDC_BACKING     9140122
// The invisible dialog that holds the player still during a locked peek - see fnc_lockDialog.
#define IDD_LOCK        9140198
#define IDC_LOCK_CURSOR 9140124
// How long the dialog waits for mouse buttons still held to come up, in seconds.
#define LOCK_DIALOG_WAIT 2
// How far from the middle the pointer may go during that dialog, as a share of the screen.
#define MOUSE_RANGE 0.25

// The field monitor, a picture rendered by tools/render_monitor.py. Its proportions and where
// the screen lies in it, as fractions of the picture - that tool prints them, and they have
// to agree with it. Its screen is 16:9.
#define MONITOR_TEXTURE     QPATHTOF(data\monitor_ca.paa)
#define MONITOR_ASPECT      0.64844
#define MONITOR_SCREEN_X    0.07031
#define MONITOR_SCREEN_Y    0.08584
#define MONITOR_SCREEN_W    0.85938
#define MONITOR_SCREEN_H    0.74548
// Its size and place on the player's screen, as fractions of that screen: along the bottom
// edge, where a monitor held in the hands would be.
#define MONITOR_WIDTH       0.50
#define MONITOR_MAX_HEIGHT  0.72
#define MONITOR_BOTTOM      0.012
// The dark bands on the monitor's screen, and how far the text sits inside them: structured
// text hangs from the top of its control, so a band of its own lets it be centred by eye.
#define OSD_BAND_HEIGHT     0.034
#define OSD_TEXT_DROP       0.011

////////////////////////////////////////////////////////////////////////////////
// Door detection
////////////////////////////////////////////////////////////////////////////////

// How far in front of the camera we look for a door (same idea as ACE's door reach)
#define DOOR_REACH_DISTANCE (((AGLToASL positionCameraToWorld [0, 0, 0]) vectorDistance (CURRENT_UNIT modelToWorldWorld (CURRENT_UNIT selectionPosition "Head"))) + 2)

// How far around the player a door is looked for, and at what height.
// The search deliberately does not depend on where you are looking: standing next to a
// door should be enough to be offered the mirror, without having to aim at it first. A fan
// of DOOR_SEARCH_RAYS rays is cast all the way round.
#define DOOR_SEARCH_RADIUS  3.2
#define DOOR_SEARCH_HEIGHT  0.9
#define DOOR_SEARCH_RAYS    12
// How far the door may lie behind the surface the line hit first, in metres: its own thickness.
#define DOOR_HIT_TOLERANCE  0.25

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

// Freehand: the head sits on the end of the wand, measured from the hand that holds it. The
// hand follows every stance, lean and bit of sway, which the eye does not.
//
// From the device's origin at the grip to the lens: the muzzle proxy sits 0.098 m ahead of it
// and the attachment is 0.579 m long. The fine offset lives in the settings (tipOffset*), so it
// can be dialled in while playing.
#define TIP_REACH           0.68
// Where the hand cannot be read, the head is placed from the eye, this far below it.
#define FREE_BASE_DROP      0.22

// Refuse to deploy if there is less clear air than this in front of the operator
#define FREE_MIN_CLEAR      0.35

// How far past its starting position the head can be pushed in freehand mode.
// The wall check still applies and stops it earlier when something is
// in the way.
#define FREE_EXTEND         0.5

// How far around the operator loose shafts are hunted down after a detach
#define SHAFT_SWEEP_RANGE   8
// A mirror on a stick does not look backwards
#define FREE_YAW_LIMIT      100
#define FREE_PITCH_MIN      (-75)
#define FREE_PITCH_MAX      75

#define DEPTH_MIN           0.02
// At a door the depth counts from the leaf's face. The head has to start and stay clear past it:
// inside the leaf, the sweep in fnc_update sees the leaf's far side as a wall in the way, and
// throws the head back out in front of the door.
#define DEPTH_DEFAULT       0.30
#define DOOR_DEPTH_MIN      0.20
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
#define PROBE_FIRST         1.4
#define PROBE_DOWN          0.9
// Stop this far short of whatever the head ran into
#define COLLISION_CLEARANCE 0.25

////////////////////////////////////////////////////////////////////////////////
// Session
////////////////////////////////////////////////////////////////////////////////

// How long the aimed-view check is held off after the ACE interaction raises the device
// itself. Long enough for the engine to have switched, short enough that a deploy which
// genuinely never gets there still ends promptly.
#define VIEW_GRACE          0.6

// Engine actions that keep working while the keyboard is locked for a peek - see
// fnc_lockInput. Only the voice and the pause menu: with the lock on, a peek means standing
// still with the device up. Names the engine does not know simply resolve to no keys.
#define PASS_ACTIONS [ \
    "PushToTalk", "PushToTalkAll", "PushToTalkSide", "PushToTalkCommand", \
    "PushToTalkGroup", "PushToTalkVehicle", "PushToTalkDirect", "VoiceOverNet", "Chat", \
    "IngamePause" \
]

// CBA's key dispatch, read out of cba_events (CBA 3.19). keyDownStates/keyUpStates are arrays
// of 270 lists of handler ids, one per key, and are only read here, never written.
// keyHandlersDown/Up are the namespaces holding each id's parameters as
// [key, modifiers, code, allowHold, holdDelay] - the code is what fnc_muteKeybind swaps.
// keyDownActiveList holds the releases armed by presses still held. Named here so a CBA rename
// has exactly one place to be fixed - fnc_lockInput checks and skips if they are gone.
#define CBA_KEY_DOWN            "cba_events_keyDownStates"
#define CBA_KEY_UP              "cba_events_keyUpStates"
#define CBA_KEY_HANDLERS_DOWN   "cba_events_keyHandlersDown"
#define CBA_KEY_HANDLERS_UP     "cba_events_keyHandlersUp"
#define CBA_KEY_DOWN_ACTIVE     "cba_events_keyDownActiveList"
// Where CBA files mouse buttons in those arrays: 0xF0 + button, from its MOUSE_OFFSET.
#define CBA_MOUSE_OFFSET        0xF0

// How long the lock may go on draining after a peek, waiting for keys pressed during it to come
// up. Normally it ends the moment they do; this only matters for a release that went to
// another display and is never coming.
#define DRAIN_TIMEOUT           3

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
