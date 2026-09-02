class CfgWeapons {
    class ItemCore;
    class InventoryMuzzleItem_Base_F;

    // Base class of the vanilla antennas. Inheriting from it fits the device's muzzle
    // slot with no further work and brings muzzlePos/muzzleEnd along already.
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

        // No "class EM { antenna = ... }" entry.
        //
        // That omission is deliberate and is the crux of the whole thing: with no EM block
        // the device reports no frequencies, so the spectrum side stays empty and the
        // screen is ours to use. Mods that drive the spectrum read the attachment for its
        // frequency band and fall through when there is none, so they are unaffected.
        GVAR(isCamera) = 1;

        class ItemInfo: InventoryMuzzleItem_Base_F {
            mass = 8;
            muzzlePos = "usti hlavne";
            muzzleEnd = "konec hlavne";
            alternativeFire = "";
        };
    };

    // -----------------------------------------------------------------------------------
    // Allow the attachment on the device.
    //
    // compatibleItems is extended with += rather than replaced: otherwise fitting the
    // camera would have thrown the three vanilla antennas out of the muzzle slot.
    // -----------------------------------------------------------------------------------
    class Pistol;
    class Pistol_Base_F: Pistol;

    class hgun_esd_01_base_F: Pistol_Base_F {
        // No ": WeaponSlotsInfo". The class has no parent on the vanilla device; giving it
        // one here would change somebody else's config for no gain - the log reports it as
        // "Updating base class ''->'WeaponSlotsInfo'". All we want is one more entry in one
        // list, so that is all we touch.
        class WeaponSlotsInfo {
            class MuzzleSlot {
                compatibleItems[] += {CAM_ITEM};
            };
        };
    };
};
