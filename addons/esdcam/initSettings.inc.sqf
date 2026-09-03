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
