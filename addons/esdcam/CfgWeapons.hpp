class CfgWeapons {
    class ItemCore;
    class InventoryMuzzleItem_Base_F;

    // Basis der Vanilla-Antennen. Wer sie erbt, passt ohne weiteres Zutun in den
    // Muendungsslot des Geraets und bringt muzzlePos/muzzleEnd schon mit.
    class muzzle_antenna_base_01_F: ItemCore {
        class ItemInfo;
    };

    class CAM_ITEM_CLASS: muzzle_antenna_base_01_F {
        author = "Miss Heda";
        _generalMacro = CAM_ITEM;
        scope = 2;
        scopeArsenal = 2;
        scopeCurator = 2;
        displayName = CSTRING(Camera_DisplayName);
        descriptionShort = CSTRING(Camera_Description);
        model = CAM_MODEL;
        picture = CAM_PICTURE;

        // Kein Eintrag "class EM { antenna = ... }".
        //
        // Das ist Absicht und der Kern des Ganzen: ohne EM-Block liefert das Geraet keine
        // Frequenzen, also bleibt der Spektrumteil leer und wir haben den Bildschirm frei.
        // Crows Electronic Warfare kommt damit ebenfalls klar - deren getSpectrumDefaultFreq
        // gibt fuer unbekannte Aufsaetze antenna = -1 zurueck, und spectrumTrackingLocal
        // steigt bei -1 aus, statt zu stolpern.
        GVAR(isCamera) = 1;

        class ItemInfo: InventoryMuzzleItem_Base_F {
            mass = 8;
            muzzlePos = "usti hlavne";
            muzzleEnd = "konec hlavne";
            alternativeFire = "";
        };
    };

    // -----------------------------------------------------------------------------------
    // Den Aufsatz am Geraet zulassen.
    //
    // compatibleItems wird mit += ergaenzt statt ersetzt: sonst haetten wir mit dem Einbau
    // der Kamera die drei Vanilla-Antennen aus dem Muendungsslot geworfen.
    // -----------------------------------------------------------------------------------
    class Pistol;
    class Pistol_Base_F: Pistol;

    class hgun_esd_01_base_F: Pistol_Base_F {
        // Ohne ": WeaponSlotsInfo". Die Klasse hat im Vanilla-Geraet keine Elternklasse; sie
        // ihr hier zu geben, waere eine Aenderung an fremder Config ohne Gegenwert - das Log
        // meldet sie als "Updating base class ''->'WeaponSlotsInfo'". Wir wollen nur einen
        // Eintrag in einer Liste ergaenzen, also fassen wir auch nur den an.
        class WeaponSlotsInfo {
            class MuzzleSlot {
                compatibleItems[] += {CAM_ITEM};
            };
        };
    };
};
