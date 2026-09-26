#include "..\script_component.hpp"
/*
 * Author: Miss Heda
 * Silences one CBA key handler for the length of a peek - see fnc_lockInput.
 *
 * CBA keeps each handler's parameters as [key, modifiers, code, allowHold, holdDelay] in a
 * namespace, and reads them afresh on every key event. Swapping the code for GVAR(muteCode)
 * leaves the handler registered exactly where it was: CBA still does all its own press and
 * release bookkeeping for it, it just has nothing to run. The original goes into
 * GVAR(muted), and fnc_releaseInput puts it back - but only where the code is still ours, so
 * a handler CBA replaced or re-registered in the meantime is left as CBA left it.
 *
 * Arguments:
 * 0: CBA handler namespace <LOCATION/OBJECT>
 * 1: Handler id <STRING>
 * 2: Key the handler is filed under <NUMBER>
 * 3: Is a release handler <BOOL> (default: false)
 *
 * Return Value:
 * None
 *
 * Example:
 * [cba_events_keyHandlersDown, "tfar$swstereoboth_down_0", 200] call opw_mirror_fnc_muteKeybind
 *
 * Public: No
 */

params ["_namespace", "_id", "_key", ["_isUp", false]];

private _params = _namespace getVariable _id;
if (isNil "_params" || {!(_params isEqualType [])} || {count _params < 3}) exitWith {};

private _code = _params select 2;
if (_code isEqualTo GVAR(muteCode)) exitWith {};

GVAR(muted) pushBack [_namespace, _id, _code, _key, _isUp];
_params set [2, GVAR(muteCode)];
