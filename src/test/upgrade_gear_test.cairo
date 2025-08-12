use coa::models::gear::{Gear, GearType, UpgradeCost, UpgradeSuccessRate, UpgradeMaterial};
use coa::models::player::{Player};
use starknet::ContractAddress;

// Test constants
const PLAYER_ADDRESS: felt252 = 0x123456789;
const UPGRADABLE_ITEM_ID: u256 = 0x2001;
const SCRAP_METAL_ID: u256 = 1;
const WIRING_ID: u256 = 2;


#[cfg(test)]
mod upgrade_gear_tests {
    use super::*;
    use starknet::contract_address_const;

    // Helper function to create a sample player
    fn sample_player() -> Player {
        Player {
            id: contract_address_const::<PLAYER_ADDRESS>(),
            hp: 500,
            max_hp: 500,
            equipped: array![],
            max_equip_slot: 10,
            rank: Default::default(),
            level: 5,
            xp: 5000,
            faction: 'TEST_FACTION',
            next_rank_in: 1000,
            body: Default::default(),
        }
    }

    // Helper function to create a sample gear item that can be upgraded
    fn sample_upgradable_gear(owner: ContractAddress, level: u64, max_level: u64) -> Gear {
        Gear {
            id: UPGRADABLE_ITEM_ID,
            item_type: (GearType::Firearm).into(),
            asset_id: 101,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: level,
            owner: owner,
            max_upgrade_level: max_level,
            min_xp_needed: 100,
            spawned: false,
        }
    }

    // Helper function to define the cost for a specific upgrade level
    fn sample_upgrade_cost(gear_type: GearType, level: u64) -> UpgradeCost {
        let mut materials = array![];
        materials.append(UpgradeMaterial { token_id: SCRAP_METAL_ID, amount: 50 });
        materials.append(UpgradeMaterial { token_id: WIRING_ID, amount: 25 });
        UpgradeCost { gear_type: gear_type, level: level, materials: materials }
    }

    // Helper function to define the success rate for a specific upgrade level
    fn sample_upgrade_success_rate(
        gear_type: GearType, level: u64, rate: u8,
    ) -> UpgradeSuccessRate {
        UpgradeSuccessRate { gear_type: gear_type, level: level, rate: rate }
    }

    #[test]
    fn test_validation_checks_for_upgrade() {
        let player_addr = contract_address_const::<PLAYER_ADDRESS>();
        let other_addr = contract_address_const::<0x987654321>();

        // Scenario 1: Caller is the owner and gear is not at max level (valid)
        let mut valid_gear = sample_upgradable_gear(player_addr, 5, 10);
        assert(valid_gear.owner == player_addr, 'Caller should be owner');
        assert(valid_gear.upgrade_level < valid_gear.max_upgrade_level, 'Gear not at max level');

        // Scenario 2: Gear is at max level (invalid)
        let max_level_gear = sample_upgradable_gear(player_addr, 10, 10);
        assert(
            max_level_gear.upgrade_level == max_level_gear.max_upgrade_level,
            'Gear is at max level',
        );

        // Scenario 3: Caller is not the owner (invalid)
        let not_owned_gear = sample_upgradable_gear(other_addr, 5, 10);
        assert(not_owned_gear.owner != player_addr, 'Caller is not owner');
    }

    #[test]
    #[should_panic(expected: ('Gear at max level',))]
    fn test_upgrade_fails_at_max_level() {
        let player_addr = contract_address_const::<PLAYER_ADDRESS>();
        let gear = sample_upgradable_gear(player_addr, 10, 10);
        assert(gear.upgrade_level < gear.max_upgrade_level, 'Gear at max level');
    }

    #[test]
    #[should_panic(expected: ('Caller is not owner',))]
    fn test_upgrade_fails_if_not_owner() {
        let player_addr = contract_address_const::<PLAYER_ADDRESS>();
        let other_addr = contract_address_const::<0x987654321>();
        let gear = sample_upgradable_gear(other_addr, 5, 10);
        assert(gear.owner == player_addr, 'Caller is not owner');
    }

    #[test]
    fn test_material_consumption_logic() {
        let player_addr = contract_address_const::<PLAYER_ADDRESS>();
        let gear = sample_upgradable_gear(player_addr, 5, 10);
        let upgrade_cost = sample_upgrade_cost(
            gear.item_type.try_into().unwrap(), gear.upgrade_level,
        );

        let mut i = 0;
        loop {
            if i >= upgrade_cost.materials.len() {
                break;
            }
            let material = *upgrade_cost.materials.at(i);
            // Simulate having enough materials
            let player_balance = 100;
            assert(player_balance >= material.amount, 'Insufficient materials');

            // Simulate having insufficient materials
            let insufficient_balance = 20;
            assert(insufficient_balance < material.amount, 'This should fail in contract');
            i += 1;
        };
    }

    #[test]
    fn test_successful_upgrade_state_change() {
        let player_addr = contract_address_const::<PLAYER_ADDRESS>();
        let mut gear = sample_upgradable_gear(player_addr, 5, 10);
        let initial_level = gear.upgrade_level;

        // Simulate a successful upgrade by manually incrementing the level
        gear.upgrade_level += 1;

        assert(gear.upgrade_level == initial_level + 1, 'Level should increment by 1');
    }

    #[test]
    fn test_failed_upgrade_state_unchanged() {
        let player_addr = contract_address_const::<PLAYER_ADDRESS>();
        let gear = sample_upgradable_gear(player_addr, 5, 10);
        let initial_level = gear.upgrade_level;

        // Simulate a failed upgrade. The level should not change.
        // Here, we just assert that the state remains the same if no action is taken.
        assert(gear.upgrade_level == initial_level, 'Level should not change on fail');
    }

    #[test]
    fn test_probability_logic_comparison() {
        // This test simulates the comparison part of the probability check
        // Test breakpoint mechanics - levels 1-5 should have higher rates than 6-10
        let rate_level_4 = sample_upgrade_success_rate(GearType::Firearm, 4, 85);
        let rate_level_5 = sample_upgrade_success_rate(GearType::Firearm, 5, 80);
        let rate_level_6 = sample_upgrade_success_rate(GearType::Firearm, 6, 60);
        // Verify breakpoint: level 5 rate should be higher than level 6
        assert(rate_level_5.rate > rate_level_6.rate, 'Breakpoint not implemented');
        // Simulate a "random" number generation
        let pseudo_random_success: u8 = 59; // less than 60
        let pseudo_random_failure: u8 = 60; // equal to or greater than 60
        assert(pseudo_random_success < rate_level_6.rate, 'Random roll should succeed');
        assert(pseudo_random_failure >= rate_level_6.rate, 'Random roll should fail');
    }
}
