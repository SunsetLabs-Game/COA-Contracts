#[cfg(test)]
mod tests {
    // -----  IMPORTS ----- //

    use crate::models::player::Body;
    use crate::helpers::body::BodyTrait;
    use crate::helpers::gear::{parse_id, get_high};
    use crate::models::gear::GearType;


    // Test item constants as u256 structs
    const LEG_ARMOR_ID: u256 = u256 { low: 1, high: 0x2002 };
    const BOOTS_ID: u256 = u256 { low: 1, high: 0x2003 };
    const GLOVES_ID: u256 = u256 { low: 1, high: 0x2004 };
    const VEHICLE_ID: u256 = u256 { low: 1, high: 0x30000 };
    const FIREARM_ID: u256 = u256 { low: 1, high: 0x104 };
    const PET_ID: u256 = u256 { low: 1, high: 0x800000 };
    const HELMET_ID: u256 = u256 { low: 1, high: 0x2000 };
    const CHEST_ARMOR_ID: u256 = u256 { low: 1, high: 0x2001 };
    const SWORD_ID: u256 = u256 { low: 1, high: 0x102 };
    const EXPLOSIVES_ID: u256 = u256 { low: 1, high: 0x107 };
    const EMPTY_ID: u256 = u256 { low: 0, high: 0 };

    // -----  HELPER FUNCTIONS ----- //

    // Helper to create test body with all items equipped
    fn setup_body_with_items() -> Body {
        Body {
            head: HELMET_ID,
            hands: array![GLOVES_ID],
            left_hand: array![],
            right_hand: array![],
            left_leg: array![],
            right_leg: array![],
            upper_torso: array![CHEST_ARMOR_ID],
            lower_torso: array![LEG_ARMOR_ID],
            back: SWORD_ID,
            waist: array![FIREARM_ID],
            feet: array![BOOTS_ID],
            off_body: array![PET_ID],
            vehicle: VEHICLE_ID,
        }
    }

    // Helper to create test body
    fn setup_body() -> Body {
        Body {
            head: HELMET_ID,
            hands: array![],
            left_hand: array![],
            right_hand: array![],
            left_leg: array![],
            right_leg: array![],
            upper_torso: array![CHEST_ARMOR_ID],
            lower_torso: array![],
            back: SWORD_ID,
            waist: array![],
            feet: array![],
            off_body: array![],
            vehicle: EMPTY_ID,
        }
    }

    // Helper to create empty body
    fn setup_empty_body() -> Body {
        Body {
            head: EMPTY_ID,
            hands: array![],
            left_hand: array![],
            right_hand: array![],
            left_leg: array![],
            right_leg: array![],
            upper_torso: array![],
            lower_torso: array![],
            back: EMPTY_ID,
            waist: array![],
            feet: array![],
            off_body: array![],
            vehicle: EMPTY_ID,
        }
    }

    // Helper to check if array contains exact item
    fn array_contains(array: Array<u256>, item_id: u256) -> bool {
        let mut found = false;
        let mut i = 0;

        while i < array.len() {
            if *array.at(i) == item_id {
                found = true;
                break;
            }
            i += 1;
        };
        found
    }


    // -----  UNIT TESTS ----- //

    #[test]
    fn test_unequip_helmet_state_change() {
        let mut body = setup_body();

        // Pre-state validation
        assert!(body.head == HELMET_ID, "Head should have helmet initially");
        assert!(parse_id(body.head) == GearType::Helmet, "Head item should be helmet");

        // Action
        let result = body.unequip(HELMET_ID);

        // Post-state validation
        assert!(result == HELMET_ID, "Should return helmet ID");
        assert!(body.head == EMPTY_ID, "Head slot should be empty after unequip");
        assert!(parse_id(body.head) == GearType::None, "Empty slot should have no gear type");

        // Test unequipping non-existent item
        let result2 = body.unequip(HELMET_ID);
        assert!(result2 == EMPTY_ID, "Should return 0 for non-equipped item");
    }

    #[test]
    fn test_unequip_validation() {
        let mut body = setup_body();

        // Validate can_equip before unequip
        assert!(!body.can_equip(HELMET_ID), "Should not equip helmet when slot occupied");

        body.unequip(HELMET_ID);

        // Validate can_equip after unequip
        assert!(body.can_equip(HELMET_ID), "Should be able to equip helmet after unequip");
    }

    #[test]
    fn test_unequip_non_existent_item() {
        let mut body = setup_body();
        let non_existent = u256 { low: 999, high: 0x9999 };

        let result = body.unequip(non_existent);

        assert!(result == EMPTY_ID, "Should return 0 for non-existent item");
        assert!(body.head == HELMET_ID, "Helmet should remain equipped");
    }

    #[test]
    fn test_unequip_chest_armor_state_change() {
        let mut body = setup_body();

        // Pre-state
        assert!(body.upper_torso.len() == 1, "Chest slot should have one item");
        assert!(parse_id(*body.upper_torso.at(0)) == GearType::ChestArmor, "Should be chest armor");

        // Action
        let result = body.unequip(CHEST_ARMOR_ID);

        // Post-state
        assert!(result == CHEST_ARMOR_ID, "Should return chest armor ID");
        assert!(body.upper_torso.is_empty(), "Chest slot should be empty");
    }

    #[test]
    fn test_unequip_leg_armor() {
        let mut body = setup_body_with_items();

        let result = body.unequip(LEG_ARMOR_ID);
        assert(get_high(result) == get_high(LEG_ARMOR_ID), 'Should return leg armor ID');
        assert(body.lower_torso.is_empty(), 'Lower torso should be empty');
    }

    #[test]
    fn test_unequip_boots() {
        let mut body = setup_body_with_items();

        let result = body.unequip(BOOTS_ID);
        assert(result == BOOTS_ID, 'Should return boots ID');
        assert(body.feet.is_empty(), 'Feet should be empty');
    }

    #[test]
    fn test_unequip_gloves() {
        let mut body = setup_body_with_items();

        let result = body.unequip(GLOVES_ID);
        assert(result == GLOVES_ID, 'Should return gloves ID');
        assert(body.hands.is_empty(), 'Hands should be empty');
    }

    #[test]
    fn test_unequip_vehicle() {
        let mut body = setup_body_with_items();

        let result = body.unequip(VEHICLE_ID);
        assert(result == VEHICLE_ID, 'Should return vehicle ID');
        assert(body.vehicle == EMPTY_ID, 'Vehicle slot should be empty');
    }

    #[test]
    fn test_unequip_sword_from_back() {
        let mut body = setup_body_with_items();

        let result = body.unequip(SWORD_ID);
        assert(result == SWORD_ID, 'Should return sword ID');
        assert(body.back == EMPTY_ID, 'Back slot should be empty');
    }

    #[test]
    fn test_unequip_firearm_from_waist() {
        let mut body = setup_body_with_items();

        let result = body.unequip(FIREARM_ID);
        assert(result == FIREARM_ID, 'Should return firearm ID');
        assert(body.waist.is_empty(), 'Waist should be empty');
    }

    #[test]
    fn test_unequip_pet_from_off_body() {
        let mut body = setup_body_with_items();

        let result = body.unequip(PET_ID);
        assert(result == PET_ID, 'Should return pet ID');
        assert(body.off_body.is_empty(), 'Off body should be empty');
    }

    // -----  EDGE CASE TESTS ----- //

    #[test]
    fn test_unequip_wrong_type_item() {
        let mut body = setup_body_with_items();

        // Try to unequip a helmet ID that's not actually equipped
        let wrong_helmet_id = u256 { low: 999, high: 0x2000 };
        let result = body.unequip(wrong_helmet_id);
        assert(result == EMPTY_ID, 'Should return 0 for wrong item');
    }


    #[test]
    fn test_unequip_multiple_items_from_waist() {
        let mut body = Body {
            head: EMPTY_ID,
            hands: array![],
            left_hand: array![],
            right_hand: array![],
            left_leg: array![],
            right_leg: array![],
            upper_torso: array![],
            lower_torso: array![],
            back: EMPTY_ID,
            waist: array![FIREARM_ID, EXPLOSIVES_ID],
            feet: array![],
            off_body: array![],
            vehicle: EMPTY_ID,
        };

        // Unequip first item
        let result1 = body.unequip(FIREARM_ID);
        assert(result1 == FIREARM_ID, 'Should unequip first firearm');
        assert(body.waist.len() == 1, 'Should have 1 item left');
        assert(array_contains(body.clone().waist, EXPLOSIVES_ID), 'Explosives should remain');

        // Unequip second item
        let result2 = body.unequip(EXPLOSIVES_ID);
        assert(result2 == EXPLOSIVES_ID, 'Should unequip explosives');
        assert(body.waist.is_empty(), 'Waist should be empty');
    }

    #[test]
    fn test_unequip_melee_weapon_from_back_vs_waist() {
        // Test sword in back slot
        let mut body1 = Body {
            head: EMPTY_ID,
            hands: array![],
            left_hand: array![],
            right_hand: array![],
            left_leg: array![],
            right_leg: array![],
            upper_torso: array![],
            lower_torso: array![],
            back: SWORD_ID,
            waist: array![],
            feet: array![],
            off_body: array![],
            vehicle: EMPTY_ID,
        };

        let result1 = body1.unequip(SWORD_ID);
        assert(result1 == SWORD_ID, 'Should unequip sword from back');
        assert(body1.back == EMPTY_ID, 'Back should be empty');

        // Test sword in waist slot
        let mut body2 = Body {
            head: EMPTY_ID,
            hands: array![],
            left_hand: array![],
            right_hand: array![],
            left_leg: array![],
            right_leg: array![],
            upper_torso: array![],
            lower_torso: array![],
            back: EMPTY_ID,
            waist: array![SWORD_ID],
            feet: array![],
            off_body: array![],
            vehicle: EMPTY_ID,
        };

        let result2 = body2.unequip(SWORD_ID);
        assert(result2 == SWORD_ID, 'Should unequip sword from waist');
        assert(body2.waist.is_empty(), 'Waist should be empty');
    }

    #[test]
    fn test_double_unequip_same_item() {
        let mut body = setup_body_with_items();

        // First unequip should succeed
        let result1 = body.unequip(HELMET_ID);
        assert(result1 == HELMET_ID, 'First unequip should succeed');
        assert(body.head == EMPTY_ID, 'Head should be empty');

        // Second unequip should fail
        let result2 = body.unequip(HELMET_ID);
        assert(result2 == EMPTY_ID, 'Second unequip should return 0');
        assert(body.head == EMPTY_ID, 'Head should still be empty');
    }

    #[test]
    fn test_unequip_preserves_other_items() {
        let mut body = setup_body_with_items();

        // Store original state
        let original_chest = body.upper_torso.clone();
        let original_waist = body.waist.clone();
        let original_vehicle = body.vehicle;
        let original_back = body.back;

        // Unequip helmet
        let result = body.unequip(HELMET_ID);
        assert(result == HELMET_ID, 'Should unequip helmet');

        // Check other items are preserved
        assert(body.upper_torso.len() == original_chest.len(), 'Chest armor should be preserved');
        assert!(
            array_contains(body.upper_torso, CHEST_ARMOR_ID),
            "Chest armor item should be preserved",
        );
        assert!(body.waist.len() == original_waist.len(), "Waist items count should be preserved");
        assert!(array_contains(body.waist, FIREARM_ID), "Firearm should be preserved in waist");
        assert(body.vehicle == original_vehicle, 'Vehicle should be preserved');
        assert(body.back == original_back, 'Back item should be preserved');
    }

    #[test]
    fn test_can_re_equip_after_unequip() {
        let mut body = setup_body_with_items();

        // Unequip helmet
        let result = body.unequip(HELMET_ID);
        assert(result == HELMET_ID, 'Should unequip helmet');
        assert(body.head == EMPTY_ID, 'Head should be empty');

        // Should be able to equip again
        assert!(body.can_equip(HELMET_ID), "Should be able to equip helmet again");

        // Re-equip
        body.equip_item(HELMET_ID);
        assert(body.head == HELMET_ID, 'Head should have helmet again');
    }

    #[test]
    fn test_edge_case_empty_arrays() {
        let mut body = setup_empty_body();

        // Try to unequip from empty arrays
        let result1 = body.unequip(GLOVES_ID);
        assert(result1 == EMPTY_ID, 'Should return 0 for empty hands');

        let result2 = body.unequip(FIREARM_ID);
        assert(result2 == EMPTY_ID, 'Should return 0 for empty waist');

        let result3 = body.unequip(PET_ID);
        assert!(result3 == EMPTY_ID, "Should return 0 for empty off_body");
    }

    #[test]
    fn test_unequip_handles_gear_type_parsing() {
        let mut body = setup_empty_body();

        // Test with invalid gear type (should not crash)
        let invalid_item = u256 { low: 1, high: 0x9999 };
        let result = body.unequip(invalid_item);
        assert!(result == EMPTY_ID, "Should return 0 for invalid gear type");
    }
}
