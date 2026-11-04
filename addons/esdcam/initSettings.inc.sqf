// In the mirror component's category, so all of the mod's settings are in one place.

[
    QGVAR(acquireTime), "SLIDER",
    [LSTRING(Setting_AcquireTime), LSTRING(Setting_AcquireTime_Description)],
    LELSTRING(mirror,SettingCategory),
    [0.2, 8, 1.8, 1],
    1
] call CBA_fnc_addSetting;

// Picture only after the left mouse button has been held.
[
    QGVAR(requireAcquire), "CHECKBOX",
    [LSTRING(Setting_RequireAcquire), LSTRING(Setting_RequireAcquire_Description)],
    LELSTRING(mirror,SettingCategory),
    [true],
    1
] call CBA_fnc_addSetting;
