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
    // A slot of our own rather than an entry in an existing one. Read out of the vanilla
    // config, the device carries three muzzle slots, one per antenna:
    //
    //   MuzzleSlot   iconPosition {0.30,0.55}  hgun_esd_01_antenna_01_F_ca  {muzzle_antenna_01_f}
    //   MuzzleSlot2  iconPosition {0.40,0.55}  hgun_esd_01_antenna_02_F_ca  {muzzle_antenna_02_f}
    //   MuzzleSlot3  iconPosition {0.10,0.55}  hgun_esd_01_antenna_03_F_ca  {muzzle_antenna_03_f}
    //
    // The reason for three is the picture. iconPicture is a property of the slot, not of the
    // item in it, and it is what Arma draws over the weapon's own inventory picture to show
    // something is fitted. One slot for everything would mean one overlay for everything -
    // so an entry added to MuzzleSlot showed the camera wearing antenna 01's picture.
    // -----------------------------------------------------------------------------------
    class Pistol;
    class Pistol_Base_F: Pistol;

    class hgun_esd_01_base_F: Pistol_Base_F {
        // No ": WeaponSlotsInfo". The class has no parent on the vanilla device; giving it
        // one here would change somebody else's config for no gain - the log reports it as
        // "Updating base class ''->'WeaponSlotsInfo'".
        class WeaponSlotsInfo {
            // Named, not defined. This is how the slot below reaches its parent without
            // touching the vanilla one - writing anything inside it would.
            class MuzzleSlot;

            class MuzzleSlot4: MuzzleSlot {
                // Antenna 03's position, because the camera is the attachment closest to it
                // in size and shape: 57.9 cm against its 55.6, mount head modelled off it.
                iconPosition[] = {0.1, 0.55};
                iconPicture = CAM_SLOT_PICTURE;
                compatibleItems[] = {CAM_ITEM};
            };
        };
    };
};
