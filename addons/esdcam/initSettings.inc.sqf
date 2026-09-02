[
    QGVAR(useDeviceScreen), "CHECKBOX",
    [LSTRING(Setting_DeviceScreen), LSTRING(Setting_DeviceScreen_Description)],
    LLSTRING(SettingCategory),
    [true],
    1
] call CBA_fnc_addSetting;

// Bild erst nach gehaltener linker Maustaste. Nutzt die Sendeanzeige, die das Geraet ohnehin
// mitbringt - derselbe Balken, den das Spektrum beim Senden zeigt.
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
