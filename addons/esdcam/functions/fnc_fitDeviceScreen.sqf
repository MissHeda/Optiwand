#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Holds the device in the same place on screen whatever field of view the player runs.
 *
 * The Spectrum Device's display is not a 2D panel. Read out of ui_f_enoch's config:
 *
 *   class Objects {
 *       class Model:  RscObject { type=82; idc=11; scale=0.7; position[]={0,-0.04,0.2}; }
 *       class Screen: RscObject { type=82; idc=10; scale=0.7; position[]={0,-0.04,0.2}; }
 *   }
 *
 * Two real models, hung at a fixed point in front of the camera and projected with the
 * player's own field of view. So both where the device sits on screen and how large it is
 * depend on that field of view, and the lift in our gui.hpp - which raises it far enough
 * that the screen is not clipped by the bottom edge - was dialled in at one particular one.
 * Widen the view and the device shrinks and drops away.
 *
 * Both come back by moving it along z alone. Screen offset goes as (y/z)/tan, apparent size
 * as (scale/z)/tan, so pulling the object closer by exactly the factor the field of view
 * widened holds both:
 *
 *     z' = z * t0 / t          y unchanged
 *
 * t is the tangent of the half vertical view angle, measured rather than read - Arma offers
 * no command for the profile's fovTop. A point one metre above the axis at ten metres lands
 * 0.05/t below the centre of the screen, and worldToScreen reports exactly that.
 *
 * At the stock field of view t equals t0, the factor is 1 and nothing moves. Nobody on
 * default settings can be made worse off by this.
 *
 * Called every frame, and it has to be. Setting it once was the first attempt: the device
 * visibly jumped to the right place and Arma put it straight back, because the engine
 * re-applies the position from the config on its own. So this runs from a per frame handler
 * for as long as the camera is deployed, and the two setters it does are the cheapest part
 * of that frame.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * Applied <BOOL>
 *
 * Example:
 * call opw_esdcam_fnc_fitDeviceScreen
 *
 * Public: No
 */

if (!GVAR(fitDeviceScreen)) exitWith {false};

private _display = uiNamespace getVariable [SPECTRUM_DISPLAY, displayNull];
if (isNull _display) exitWith {false};

// Measure the view. Both points are dead ahead, so neither can fall off the screen and
// worldToScreen can only come back empty if there is no camera at all.
private _centre = worldToScreen (positionCameraToWorld [0, 0, FOV_PROBE_DISTANCE]);
private _above = worldToScreen (positionCameraToWorld [0, 1, FOV_PROBE_DISTANCE]);
if (_centre isEqualTo [] || {_above isEqualTo []}) exitWith {false};

private _drop = abs ((_centre select 1) - (_above select 1));
if (_drop < 1e-5) exitWith {false};

private _tan = (0.5 / FOV_PROBE_DISTANCE) / _drop;
private _factor = SCREEN_FOV_BASELINE / _tan;

// A sanity band. Anything outside it is not a field of view, it is a measurement that went
// wrong - and shoving the model to a nonsense distance would be worse than leaving it.
_factor = (_factor max 0.35) min 2.5;

{
    _x params ["_idc", "_z"];
    private _ctrl = _display displayCtrl _idc;
    if (isNull _ctrl) exitWith {};
    // The object controls take a 3D position, not a rectangle. x and y stay where the
    // config put them - only the distance changes.
    _ctrl ctrlSetPosition [0, SCREEN_LIFT + GVAR(screenNudge), _z * _factor];
    _ctrl ctrlCommit 0;
} forEach [[IDC_ESD_MODEL, SCREEN_DISTANCE], [IDC_ESD_SCREEN, SCREEN_DISTANCE]];

TRACE_3("device screen fitted",_tan,_factor,GVAR(screenNudge));
true
