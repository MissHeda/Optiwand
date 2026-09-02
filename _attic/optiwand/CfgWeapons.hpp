class CfgWeapons {
    class Pistol;
    class Pistol_Base_F: Pistol {
        class WeaponSlotsInfo;
    };

    // Die einzige Waffe des Mods. Der Schaft steckt im Mesh, also gibt es kein Anbauteil,
    // das angesteckt oder festgehalten werden muesste.
    class opw_Optiwand: Pistol_Base_F {
        author = "Miss Heda";
        scope = 2;
        displayName = CSTRING(Optiwand_DisplayName);
        descriptionShort = CSTRING(Optiwand_Description);
        model = OPTIWAND_MODEL;
        picture = OPTIWAND_PIC;

        cursor = "";
        cursorAim = "";
        recoil = "empty";
        textureType = "default";
        magazines[] = {"FakeMagazine"};
        weaponInfoType = "RscWeaponEmpty";

        inertia = 0.2;
        dexterity = 1.8;

        // Kein Zielzoom. Pistol_Base_F bringt den Zoom der Eisenvisierung mit, und der zieht
        // beim Rechtsklick das Bild so weit heran, dass der Monitor aus dem Sichtfeld
        // laeuft. Dieses Geraet hat keine Visierung - Zielen heisst hier nur, es vors
        // Gesicht zu halten. 0.75 entspricht der normalen Spielansicht, alle drei Werte
        // gleich heisst: kein Zoombereich, nichts zum Durchschalten.
        opticsZoomMin = 0.75;
        opticsZoomMax = 0.75;
        opticsZoomInit = 0.75;

        // The whole point of the custom model: its screen is a plane with its own material and
        // its own UVs, so the camera render target can be mapped straight onto it. That is what
        // the Spectrum Device could never do - its screen is segment geometry, not a surface.
        // "screen" must also appear in sections[] in model.cfg or this does nothing.
        hiddenSelections[] = {"screen"};
        hiddenSelectionsTextures[] = {OPTIWAND_SCREEN};

        class WeaponSlotsInfo: WeaponSlotsInfo {
            holsterScale = 0;
            mass = 14;

            class MuzzleSlot {};
            class CowsSlot {};
            class PointerSlot {};
        };
    };
};
