class CfgVehicles {
    class Pistol_Base_F;

    class OPW_Item_Optiwand: Pistol_Base_F {
        author = "Miss Heda";
        scope = 2;
        scopeCurator = 2;
        displayName = CSTRING(Optiwand_DisplayName);
        editorCategory = "EdCat_Equipment";
        editorSubcategory = "EdSubcat_InventoryItems";
        vehicleClass = "Items";

        class TransportWeapons {
            class opw_Optiwand {
                weapon = WAND_OPTIWAND;
                count = 1;
            };
        };
    };
};
