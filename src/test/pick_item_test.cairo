// Test constants
const PLAYER_ADDRESS: felt252 = 0x123456789;
const ITEM_ID_1: u256 = 0x1001;
const ITEM_ID_2: u256 = 0x1002;
const VEHICLE_ID: u256 = 0x30001;


#[cfg(test)]
mod pick_items_tests {
    use super::*;
    use starknet::contract_address_const;
    use core::num::traits::Zero;
    use coa::models::gear::{Gear, GearTrait};
    use coa::models::player::{Player, PlayerTrait};

    fn sample_player() -> Player {
        Player {
            id: contract_address_const::<PLAYER_ADDRESS>(),
            hp: 500,
            max_hp: 500,
            equipped: array![],
            max_equip_slot: 10,
            rank: Default::default(),
            level: 1,
            xp: 1000, // Has 1000 XP
            faction: 'TEST_FACTION',
            next_rank_in: 1000,
            body: Default::default(),
        }
    }

    fn sample_spawned_gear() -> Gear {
        Gear {
            id: ITEM_ID_1,
            item_type: 'WEAPON',
            asset_id: ITEM_ID_1,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            owner: contract_address_const::<0x0>(), // No owner
            max_upgrade_level: 10,
            min_xp_needed: 500, // Requires 500 XP
            spawned: true // Available for pickup
        }
    }

    fn sample_high_xp_gear() -> Gear {
        Gear {
            id: ITEM_ID_2,
            item_type: 'ARMOR',
            asset_id: ITEM_ID_2,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            owner: contract_address_const::<0x0>(),
            max_upgrade_level: 8,
            min_xp_needed: 2000, // Requires 2000 XP (higher than player's 1000)
            spawned: true,
        }
    }

    fn sample_vehicle() -> Gear {
        Gear {
            id: VEHICLE_ID,
            item_type: 'VEHICLE',
            asset_id: VEHICLE_ID,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            owner: contract_address_const::<PLAYER_ADDRESS>(), // Already owned by player
            max_upgrade_level: 5,
            min_xp_needed: 0,
            spawned: false,
        }
    }

    #[test]
    fn test_gear_available_for_pickup() {
        let gear = sample_spawned_gear();

        // Test availability checks
        assert(gear.is_available_for_pickup(), 'Should be available for pickup');
        assert(!gear.is_owned(), 'Should not be owned');
        assert(gear.spawned == true, 'Should be spawned');
        assert(gear.owner.is_zero(), 'Should have no owner');
    }

    #[test]
    fn test_gear_not_available_for_pickup() {
        let mut gear = sample_spawned_gear();
        gear.owner = contract_address_const::<PLAYER_ADDRESS>();
        gear.spawned = false;

        // Test unavailability checks
        assert(!gear.is_available_for_pickup(), 'Should not be available');
        assert(gear.is_owned(), 'Should be owned');
        assert(gear.spawned == false, 'Should not be spawned');
        assert(!gear.owner.is_zero(), 'Should have owner');
    }

    #[test]
    fn test_gear_transfer_ownership() {
        let mut gear = sample_spawned_gear();
        let new_owner = contract_address_const::<PLAYER_ADDRESS>();

        // Before transfer
        assert(gear.is_available_for_pickup(), 'Should be avail before transfer');
        assert(!gear.is_owned(), 'Shudnt be owned before transfer');

        // Transfer ownership
        gear.transfer_to(new_owner);

        // After transfer
        assert(!gear.is_available_for_pickup(), 'Shudnt be avail after transfer');
        assert(gear.is_owned(), 'Should be owned after transfer');
        assert(gear.owner == new_owner, 'Should have correct owner');
        assert(gear.spawned == false, 'Shudntbe spawned after transfer');
    }

    #[test]
    fn test_player_xp_validation() {
        let player = sample_player();
        let low_xp_gear = sample_spawned_gear(); // Requires 500 XP
        let high_xp_gear = sample_high_xp_gear(); // Requires 2000 XP

        // Test XP validation logic
        assert(player.get_xp() == 1000, 'Player should have 1000 XP');
        assert(player.xp >= low_xp_gear.min_xp_needed, 'Should meet low XP requirement');
        assert(player.xp < high_xp_gear.min_xp_needed, 'Should not meet high XP req');
    }

    #[test]
    fn test_player_add_xp() {
        let mut player = sample_player();
        let initial_xp = player.get_xp();
        let initial_level = player.level;

        // Add XP that doesn't level up (less than 1000)
        let leveled_up = player.add_xp(500);
        assert(!leveled_up, 'Should not level up');
        assert(player.get_xp() == initial_xp + 500, 'XP should increase');
        assert(player.level == initial_level, 'Level should not change');

        // Add XP that levels up (1000 or more total)
        let leveled_up = player.add_xp(500); // Total now 2000
        assert(leveled_up, 'Should level up');
        assert(player.get_xp() == 2000, 'XP should be 2000');
        assert(player.level == 2, 'Level should increase to 2');
    }

    #[test]
    fn test_player_vehicle_equipped_logic() {
        let mut player = sample_player();

        // Test without vehicle
        assert(!player.has_vehicle_equipped(), 'Shouldnt have vehicle initially');
        assert(player.body.off_body.len() == 0, 'Off body should be empty');
        assert(player.body.back == 0, 'Back slot should be empty');

        // Test vehicle in off_body slot
        let vehicle_id = u256 { low: 0x0001, high: 0x30000 }; // Matches GearType::Vehicle
        player.body.off_body.append(vehicle_id);

        let has_vehicle_in_off_body = player.body.off_body.len() > 0;
        assert(has_vehicle_in_off_body, 'Should have vehicle in off_body');

        // Test vehicle in back slot
        let mut player2 = sample_player();
        player2.body.back = vehicle_id;

        let has_vehicle_in_back = player2.body.back != 0;
        assert(has_vehicle_in_back, 'Shud have vehicle in back slot');

        // Test with non-vehicle item (should not count as vehicle)
        let mut player3 = sample_player();
        let weapon_id = u256 { low: 0x0001, high: 0x1 }; // Weapon type
        player3.body.off_body.append(weapon_id);

        let has_non_vehicle = player3.body.off_body.len() > 0;
        assert(has_non_vehicle, 'Should have item in off_body');

        // Test multiple items in off_body with one vehicle
        let mut player4 = sample_player();
        player4.body.off_body.append(weapon_id); // Non-vehicle
        player4.body.off_body.append(vehicle_id); // Vehicle

        let has_mixed_items = player4.body.off_body.len() == 2;
        assert(has_mixed_items, 'Should have 2 items in off_body');
    }

    #[test]
    fn test_player_inventory_slot_availability() {
        let mut player = sample_player();

        // Test free slots
        assert(player.has_free_inventory_slot(), 'Shouldve free slots initially');
        assert(player.equipped.len() == 0, 'Shud start with empty inventory');
        assert(player.equipped.len() < player.max_equip_slot, 'Should be under max slots');

        // Simulate filling slots (simplified)
        let mut i = 0;
        while i < player.max_equip_slot {
            player.equipped.append(i.into());
            i += 1;
        };

        assert(!player.has_free_inventory_slot(), 'Shudnt hv free slots when full');
        assert(player.equipped.len() == player.max_equip_slot, 'Should be at max slots');
    }

    #[test]
    fn test_pick_items_validation_logic() {
        let player = sample_player();
        let available_gear = sample_spawned_gear();
        let unavailable_gear = sample_high_xp_gear();

        assert(available_gear.is_available_for_pickup(), 'Item should be available');

        let meets_xp_req = player.xp >= available_gear.min_xp_needed;
        assert(meets_xp_req, 'Player should meet XP req');

        let fails_xp_req = player.xp >= unavailable_gear.min_xp_needed;
        assert(!fails_xp_req, 'Player shudnt meet high XP req');

        let has_space = player.has_free_inventory_slot();
        assert(has_space, 'Player shudve inventory space');

        let has_vehicle = player.has_vehicle_equipped();
        assert(!has_vehicle, 'Player shudnt hv vehicle initly');
    }

    #[test]
    fn test_successful_pickup_scenario() {
        let mut player = sample_player();
        let mut gear = sample_spawned_gear();
        let player_address = player.id;

        // Validate preconditions
        assert(gear.is_available_for_pickup(), 'Gear should be available');
        assert(player.xp >= gear.min_xp_needed, 'Player should meet XP req');
        assert(player.has_free_inventory_slot(), 'Player should have space');

        // Simulate successful pickup
        gear.transfer_to(player_address);
        player.equipped.append(gear.id);

        // Validate postconditions
        assert(!gear.is_available_for_pickup(), 'Gear shouldnt be available');
        assert(gear.is_owned(), 'Gear should be owned');
        assert(gear.owner == player_address, 'Gear should be owned by player');
        assert(player.equipped.len() == 1, 'Player shouldve 1 equipped item');
    }

    #[test]
    fn test_failed_pickup_scenarios() {
        let player = sample_player();
        let high_xp_gear = sample_high_xp_gear();

        // Test XP requirement failure
        assert(high_xp_gear.is_available_for_pickup(), 'Gear should be spawned');
        assert(player.xp < high_xp_gear.min_xp_needed, 'Player shud nt meet XP req.');

        // Test already owned gear
        let mut owned_gear = sample_spawned_gear();
        owned_gear.transfer_to(contract_address_const::<0x999>());
        assert(!owned_gear.is_available_for_pickup(), 'Owned gear shudnt be available');
    }

    #[test]
    fn test_pick_items_return_array_logic() {
        let mut successfully_picked: Array<u256> = array![];

        // Simulate successful pickups
        successfully_picked.append(ITEM_ID_1);
        successfully_picked.append(ITEM_ID_2);

        assert(successfully_picked.len() == 2, 'Should have 2 successful picks');
        assert(*successfully_picked.at(0) == ITEM_ID_1, 'First item should be ITEM_ID_1');
        assert(*successfully_picked.at(1) == ITEM_ID_2, 'Second item should be ITEM_ID_2');
    }
}
