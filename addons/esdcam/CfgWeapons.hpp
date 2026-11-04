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
    // With braces: HEMTT 1.22 refuses a bare "class A: B;", and an empty body re-states
    // vanilla's own parent without touching anything in it.
    class Pistol_Base_F: Pistol {};

    class hgun_esd_01_base_F: Pistol_Base_F {
        // No ": WeaponSlotsInfo". The class has no parent on the vanilla device; giving it
        // one here would change somebody else's config for no gain - the log reports it as
        // "Updating base class ''->'WeaponSlotsInfo'".
        class WeaponSlotsInfo {
            // Named, not defined. This is how the slot below reaches its parent without
            // touching the vanilla one - writing anything inside it would.
            class MuzzleSlot;

            class MuzzleSlot4: MuzzleSlot {
                // The overlay is centred on this point. It is laid out like antenna 02's, with
                // the cable loop to the right of the mount, so the mount sits at 165 of 256
                // px rather than antenna 03's 247 - and 0.33 is what puts it on the device's
                // muzzle, which antennas 01 and 03 agree is at 0.433 of the picture's width.
                // See "The inventory pictures" in the README.
                iconPosition[] = {0.33, 0.55};
                iconPicture = CAM_SLOT_PICTURE;
                compatibleItems[] = {CAM_ITEM};
            };
        };
    };
};
