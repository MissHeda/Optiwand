[
    QGVAR(useDeviceScreen), "CHECKBOX",
    [LSTRING(Setting_DeviceScreen), LSTRING(Setting_DeviceScreen_Description)],
    LLSTRING(SettingCategory),
    [true],
    1
] call CBA_fnc_addSetting;

// Picture only after the left mouse button has been held. Uses the transmit readout the
// device already brings - the same bar the spectrum side shows while transmitting.
[
    QGVAR(requireAcquire), "CHECKBOX",
    [LSTRING(Setting_RequireAcquire), LSTRING(Setting_RequireAcquire_Description)],
    LLSTRING(SettingCategory),
    [true],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(acquireTime), "SLIDER",
    [LSTRING(Setting_AcquireTime), LSTRING(Setting_AcquireTime_Description)],
    LLSTRING(SettingCategory),
    [0.2, 8, 1.8, 1],
    1
] call CBA_fnc_addSetting;

// ---------------------------------------------------------------------------------------
// Where the device sits in the view.
//
// The Spectrum Device's display is two real models hung in front of the camera, projected
// with the player's own field of view - so a wider one drops it down the screen and shrinks
// it. The correction pulls it closer by exactly the factor the view widened, which holds
// both its place and its size. It is a no-op at the stock field of view.
//
// Local, not a mission setting: this follows the field of view in a player's own profile,
// which nobody else has any business overriding.
// ---------------------------------------------------------------------------------------
[
    QGVAR(fitDeviceScreen), "CHECKBOX",
    [LSTRING(Setting_FitDeviceScreen), LSTRING(Setting_FitDeviceScreen_Description)],
    LLSTRING(SettingCategory),
    [true],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(screenNudge), "SLIDER",
    [LSTRING(Setting_ScreenNudge), LSTRING(Setting_ScreenNudge_Description)],
    LLSTRING(SettingCategory),
    [-0.15, 0.15, 0, 3],
    0
] call CBA_fnc_addSetting;
