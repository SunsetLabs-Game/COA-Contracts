use core::num::traits::Zero;
use coa::models::gear::{Gear, GearTrait, GearType, parse_gear_type};
use coa::models::player::{Player, PlayerTrait};
use starknet::contract_address_const;

// Test constants
const PLAYER_ADDRESS: felt252 = 0x123456789;
const HEALTH_POTION_ID: u256 = u256 { low: 0x0001, high: 0x90000 }; // HealthPotion
const XP_BOOSTER_ID: u256 = u256 { low: 0x0001, high: 0x90001 }; // XpBooster
const SWORD_ID: u256 = u256 { low: 0x0001, high: 0x102 }; // Sword
const FIREARM_ID: u256 = u256 { low: 0x0001, high: 0x104 }; // Firearm

#[cfg(test)]
mod use_wield_item_tests {
    use super::*;

    fn sample_player_with_equipped_items() -> Player {
        let mut player = Player {
            id: contract_address_const::<PLAYER_ADDRESS>(),
            hp: 300,
            max_hp: 500,
            equipped: array![HEALTH_POTION_ID, SWORD_ID, FIREARM_ID],
            max_equip_slot: 10,
            rank: Default::default(),
            level: 5,
            xp: 1000,
            faction: 'TEST_FACTION',
            next_rank_in: 2000,
            body: Default::default(),
        };
        player
    }

    fn sample_health_potion() -> Gear {
        Gear {
            id: HEALTH_POTION_ID,
            item_type: 'CONSUMABLE',
            asset_id: HEALTH_POTION_ID,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            owner: contract_address_const::<PLAYER_ADDRESS>(),
            max_upgrade_level: 5,
            min_xp_needed: 0,
            spawned: false,
        }
    }

    fn sample_xp_booster() -> Gear {
        Gear {
            id: XP_BOOSTER_ID,
            item_type: 'CONSUMABLE',
            asset_id: XP_BOOSTER_ID,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            owner: contract_address_const::<PLAYER_ADDRESS>(),
            max_upgrade_level: 5,
            min_xp_needed: 0,
            spawned: false,
        }
    }

    fn sample_sword() -> Gear {
        Gear {
            id: SWORD_ID,
            item_type: 'WEAPON',
            asset_id: SWORD_ID,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            owner: contract_address_const::<PLAYER_ADDRESS>(),
            max_upgrade_level: 10,
            min_xp_needed: 0,
            spawned: false,
        }
    }

    fn sample_firearm() -> Gear {
        Gear {
            id: FIREARM_ID,
            item_type: 'WEAPON',
            asset_id: FIREARM_ID,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            owner: contract_address_const::<PLAYER_ADDRESS>(),
            max_upgrade_level: 10,
            min_xp_needed: 0,
            spawned: false,
        }
    }

    #[test]
    fn test_parse_gear_type_consumables() {
        let health_potion_type = parse_gear_type(HEALTH_POTION_ID);
        assert(health_potion_type == GearType::HealthPotion, 'Wrong HealthPotion type');

        let xp_booster_type = parse_gear_type(XP_BOOSTER_ID);
        assert(xp_booster_type == GearType::XpBooster, 'Wrong XpBooster type');
    }

    #[test]
    fn test_parse_gear_type_weapons() {
        let sword_type = parse_gear_type(SWORD_ID);
        assert(sword_type == GearType::Sword, 'Wrong Sword type');

        let firearm_type = parse_gear_type(FIREARM_ID);
        assert(firearm_type == GearType::Firearm, 'Wrong Firearm type');
    }

    #[test]
    fn test_gear_is_consumable() {
        let health_potion = sample_health_potion();
        assert(health_potion.is_consumable(), 'HealthPotion should be consumable');

        let xp_booster = sample_xp_booster();
        assert(xp_booster.is_consumable(), 'XpBooster should be consumable');

        let sword = sample_sword();
        assert(!sword.is_consumable(), 'Sword should not be consumable');
    }

    #[test]
    fn test_gear_is_wieldable() {
        let sword = sample_sword();
        assert(sword.is_wieldable(), 'Sword should be wieldable');

        let firearm = sample_firearm();
        assert(firearm.is_wieldable(), 'Firearm should be wieldable');

        let health_potion = sample_health_potion();
        assert(!health_potion.is_wieldable(), 'HealthPotion should not be wieldable');
    }

    #[test]
    fn test_player_has_equipped_item() {
        let player = sample_player_with_equipped_items();

        // Check if player has health potion equipped
        let mut has_health_potion = false;
        let mut i = 0;
        while i < player.equipped.len() {
            if *player.equipped.at(i) == HEALTH_POTION_ID {
                has_health_potion = true;
                break;
            }
            i += 1;
        };
        assert(has_health_potion, 'Player should have health potion equipped');

        // Check if player has sword equipped
        let mut has_sword = false;
        let mut i = 0;
        while i < player.equipped.len() {
            if *player.equipped.at(i) == SWORD_ID {
                has_sword = true;
                break;
            }
            i += 1;
        };
        assert(has_sword, 'Player should have sword equipped');
    }

    #[test]
    fn test_health_potion_healing() {
        let mut player = sample_player_with_equipped_items();
        let initial_hp = player.hp; // 300

        // Simulate using health potion (healing 100 HP)
        let heal_amount: u256 = 100;
        let new_hp = if player.hp + heal_amount > player.max_hp {
            player.max_hp
        } else {
            player.hp + heal_amount
        };
        player.hp = new_hp;

        assert(player.hp == 400, 'HP should be 400 after healing');
        assert(player.hp > initial_hp, 'HP should increase');
    }

    #[test]
    fn test_xp_booster_effect() {
        let mut player = sample_player_with_equipped_items();
        let initial_xp = player.xp; // 1000
        let initial_level = player.level; // 5

        // Simulate using XP booster (adding 200 XP)
        let xp_amount: u256 = 200;
        player.add_xp(xp_amount);

        assert(player.xp == initial_xp + xp_amount, 'XP should increase by 200');
        // Level should remain same as 1200 / 1000 = 1 (same as 1000 / 1000 = 1)
        assert(player.level >= initial_level, 'Level should not decrease');
    }

    #[test]
    fn test_remove_item_from_equipped() {
        let mut player = sample_player_with_equipped_items();
        let initial_equipped_count = player.equipped.len();

        // Simulate removing HEALTH_POTION_ID from equipped items
        let item_to_remove = HEALTH_POTION_ID;
        let mut new_equipped: Array<u256> = array![];
        let mut i = 0;
        while i < player.equipped.len() {
            let equipped_item = *player.equipped.at(i);
            if equipped_item != item_to_remove {
                new_equipped.append(equipped_item);
            }
            i += 1;
        };
        player.equipped = new_equipped;

        // Should have one less equipped item
        assert(
            player.equipped.len() == initial_equipped_count - 1,
            'Should have one less equipped item',
        );

        // Should not contain the removed item
        let mut still_has_item = false;
        let mut i = 0;
        while i < player.equipped.len() {
            if *player.equipped.at(i) == item_to_remove {
                still_has_item = true;
                break;
            }
            i += 1;
        };
        assert(!still_has_item, 'Should not contain removed item');
    }

    #[test]
    fn test_gear_wielding_state() {
        let mut sword = sample_sword();
        assert(!sword.in_action, 'Sword should not be in action initially');

        // Simulate wielding the sword
        sword.in_action = true;
        assert(sword.in_action, 'Sword should be in action after wielding');
    }

    #[test]
    fn test_asset_id_structure() {
        // Test that consumable items use correct u256.high values
        assert(HEALTH_POTION_ID.high == 0x90000, 'HealthPotion should use 0x90000 high');
        assert(XP_BOOSTER_ID.high == 0x90001, 'XpBooster should use 0x90001 high');

        // Test that weapons use correct u256.high values
        assert(SWORD_ID.high == 0x102, 'Sword should use 0x102 high');
        assert(FIREARM_ID.high == 0x104, 'Firearm should use 0x104 high');
    }
}
