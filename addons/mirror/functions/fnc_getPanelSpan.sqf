#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Measures a door leaf by walking rays through it sideways and downwards until they stop
 * hitting it. selectionPosition on a door gives a point somewhere on the leaf, not reliably
 * its middle, which is why the interaction used to sit off by the handle. This gives the real
 * centre and half width instead, and the height of the bottom edge.
 *
 * Result is cached per building type, in model space, so it only ever runs once per door
 * of a given house type. Model space also means it does not matter which side you measured from.
 *
 * Arguments:
 * 0: House <OBJECT>
 * 1: Door selection name <STRING>
 * 2: Hit position ASL <ARRAY>
 * 3: Horizontal unit vector through the door <ARRAY>
 *
 * Return Value:
 * 0: Middle of the bottom edge of the door, ASL <ARRAY>
 * 1: Half width of the door <NUMBER>
 * Empty array if the sample line never hit the door.
 *
 * Example:
 * [_house, "door_1", _hitASL, _through] call opw_mirror_fnc_getPanelSpan
 *
 * Public: No
 */

params ["_house", "_panel", "_hitASL", "_through"];

if (isNil QGVAR(panelSpanCache)) then {GVAR(panelSpanCache) = createHashMap};

private _cacheKey = format ["%1$%2", typeOf _house, _panel];
private _cached = GVAR(panelSpanCache) get _cacheKey;

if (!isNil "_cached") exitWith {
    _cached params ["_bottomModel", "_halfWidth"];
    [_house modelToWorldWorld _bottomModel, _halfWidth]
};

private _right = vectorNormalized (_through vectorCrossProduct [0, 0, 1]);
private _reach = _through vectorMultiply PANEL_PROBE_REACH;

// Is the door still there if we shift the probe by this much?
private _fnc_isPanel = {
    params ["_point"];
    private _hits = [_house, "GEOM"] intersect [ASLToAGL (_point vectorDiff _reach), ASLToAGL (_point vectorAdd _reach)];
    (_hits findIf {toLowerANSI (_x select 0) isEqualTo _panel}) != -1
};

// Sanity: the probe has to find the door where we are actually aiming
if !([_hitASL] call _fnc_isPanel) exitWith {
    TRACE_2("panel sampling found nothing at the aim point",typeOf _house,_panel);
    []
};

// Walk out to both edges
private _edgeRight = 0;
while {_edgeRight < PANEL_MAX && {[_hitASL vectorAdd (_right vectorMultiply (_edgeRight + PANEL_STEP))] call _fnc_isPanel}} do {
    _edgeRight = _edgeRight + PANEL_STEP;
};

private _edgeLeft = 0;
while {_edgeLeft < PANEL_MAX && {[_hitASL vectorAdd (_right vectorMultiply (-(_edgeLeft + PANEL_STEP)))] call _fnc_isPanel}} do {
    _edgeLeft = _edgeLeft + PANEL_STEP;
};

private _halfWidth = (_edgeRight + _edgeLeft) / 2;
private _centreASL = _hitASL vectorAdd (_right vectorMultiply ((_edgeRight - _edgeLeft) / 2));

// Walk down to the bottom edge of the leaf - that is where the slit is
private _drop = 0;
while {_drop < PANEL_MAX * 2 && {[_centreASL vectorAdd [0, 0, -(_drop + PANEL_STEP)]] call _fnc_isPanel}} do {
    _drop = _drop + PANEL_STEP;
};

private _bottomASL = _centreASL vectorAdd [0, 0, -_drop];

TRACE_4("panel measured",typeOf _house,_panel,_halfWidth,_drop);

GVAR(panelSpanCache) set [_cacheKey, [_house worldToModel (ASLToAGL _bottomASL), _halfWidth]];

[_bottomASL, _halfWidth]
