#[cfg(test)]
mod tests {
    use coa::models::gear::{
        Gear, GearType, GearDetailsComplete, GearStatsCalculated, UpgradeInfo, OwnershipStatus,
        GearFilters, OwnershipFilter, PaginationParams, SortParams, SortField, PaginatedGearResult,
        CombinedEquipmentEffects, GearTrait,
    };
    use coa::models::session::SessionKey;
    use coa::helpers::gear::{calculate_level_multiplier, apply_upgrade_multiplier};
    use coa::helpers::gear::parse_id;
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use core::num::traits::Zero;

    fn create_test_gear(id: u256, gear_type: GearType, level: u64, owner: ContractAddress) -> Gear {
        Gear {
            id,
            item_type: gear_type.into(),
            asset_id: id,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: level,
            owner,
            max_upgrade_level: 10,
            min_xp_needed: 100,
            spawned: owner.is_zero(),
        }
    }

    fn create_test_session(player: ContractAddress) -> SessionKey {
        let current_time = get_block_timestamp();
        SessionKey {
            session_id: 'test_session',
            player_address: player,
            session_key_address: contract_address_const::<0x123>(),
            created_at: current_time,
            expires_at: current_time + 3600, // 1 hour
            last_used: current_time,
            status: 0, // Active
            max_transactions: 100,
            used_transactions: 0,
            is_valid: true,
        }
    }

    #[test]
    fn test_calculate_level_multiplier() {
        assert(calculate_level_multiplier(0) == 100, 'Level 0 should be 100%');
        assert(calculate_level_multiplier(1) == 110, 'Level 1 should be 110%');
        assert(calculate_level_multiplier(5) == 150, 'Level 5 should be 150%');
        assert(calculate_level_multiplier(10) == 200, 'Level 10 should be 200%');
    }

    #[test]
    fn test_apply_upgrade_multiplier() {
        let base_damage = 100;

        assert(apply_upgrade_multiplier(base_damage, 0) == 100, 'Level 0: no change');
        assert(apply_upgrade_multiplier(base_damage, 1) == 110, 'Level 1: +10%');
        assert(apply_upgrade_multiplier(base_damage, 5) == 150, 'Level 5: +50%');
        assert(apply_upgrade_multiplier(base_damage, 10) == 200, 'Level 10: +100%');

        // Test with different base values
        assert(apply_upgrade_multiplier(50, 2) == 60, 'Base 50, Level 2: 60');
        assert(apply_upgrade_multiplier(200, 3) == 260, 'Base 200, Level 3: 260');
    }

    #[test]
    fn test_gear_type_conversions() {
        // Test all gear type conversions
        let weapon_felt: felt252 = GearType::Weapon.into();
        let sword_felt: felt252 = GearType::Sword.into();
        let helmet_felt: felt252 = GearType::Helmet.into();
        let vehicle_felt: felt252 = GearType::Vehicle.into();
        let pet_felt: felt252 = GearType::Pet.into();

        assert(weapon_felt == 0x1, 'Weapon should be 0x1');
        assert(sword_felt == 0x102, 'Sword should be 0x102');
        assert(helmet_felt == 0x2000, 'Helmet should be 0x2000');
        assert(vehicle_felt == 0x30000, 'Vehicle should be 0x30000');
        assert(pet_felt == 0x800000, 'Pet should be 0x800000');

        // Test reverse conversion
        let weapon_back: Option<GearType> = weapon_felt.try_into();
        let sword_back: Option<GearType> = sword_felt.try_into();

        match weapon_back {
            Option::Some(t) => assert(t == GearType::Weapon, 'Should convert back to Weapon'),
            Option::None => assert!(false, "Weapon conversion should succeed"),
        }

        match sword_back {
            Option::Some(t) => assert(t == GearType::Sword, 'Should convert back to Sword'),
            Option::None => assert(false, 'Sword conversion should succeed'),
        }
    }

    #[test]
    fn test_gear_trait_functions() {
        let player = contract_address_const::<0x123>();
        let _other_player = contract_address_const::<0x456>();

        // Test owned gear
        let owned_gear = create_test_gear(1, GearType::Sword, 1, player);
        assert(owned_gear.is_owned(), 'Should be owned');
        assert!(
            owned_gear.is_available_for_pickup() == false, "Owned gear should not be available",
        );
        // Test unowned spawned gear
        let mut unowned_gear = create_test_gear(2, GearType::Sword, 1, Zero::zero());
        unowned_gear.spawned = true;
        assert(!unowned_gear.is_owned(), 'Should not be owned');
        assert(unowned_gear.is_available_for_pickup(), 'Should be available for pickup');
        // Test transfer function
        unowned_gear.transfer_to(player);
        assert(unowned_gear.owner == player, 'Owner should be updated');
        assert!(unowned_gear.spawned == false, "Should not be spawned after transfer");
    }

    #[test]
    fn test_gear_type_parsing() {
        let sword_gear = create_test_gear(
            u256 { low: 0x0001, high: 0x102 }, GearType::Sword, 1, Zero::zero(),
        );
        let bow_gear = create_test_gear(
            u256 { low: 0x0001, high: 0x103 }, GearType::Bow, 1, Zero::zero(),
        );

        // Test that parse_id correctly identifies gear types
        let sword_type = parse_id(sword_gear.asset_id);
        let bow_type = parse_id(bow_gear.asset_id);

        assert(sword_type == GearType::Sword, 'Should parse as Sword');
        assert(bow_type == GearType::Bow, 'Should parse as Bow');
        assert!(sword_type != bow_type, "Different types should not be equal");
    }

    #[test]
    fn test_gear_level_validation() {
        let level_5_gear = create_test_gear(1, GearType::Sword, 5, Zero::zero());

        assert(level_5_gear.upgrade_level == 5, 'Level should be 5');
        assert(
            level_5_gear.upgrade_level <= level_5_gear.max_upgrade_level,
            'Level should not exceed max',
        );
        assert(level_5_gear.max_upgrade_level == 10, 'Max level should be 10');

        // Test level bounds
        let level_0_gear = create_test_gear(2, GearType::Bow, 0, Zero::zero());
        assert(level_0_gear.upgrade_level == 0, 'Min level should be 0');

        let max_level_gear = create_test_gear(3, GearType::Firearm, 10, Zero::zero());
        assert(
            max_level_gear.upgrade_level == max_level_gear.max_upgrade_level,
            'Should be at max level',
        );
    }

    #[test]
    fn test_gear_stats_structure() {
        let stats = GearStatsCalculated {
            damage: 100,
            range: 50,
            accuracy: 80,
            fire_rate: 10,
            defense: 60,
            durability: 100,
            weight: 5,
            speed: 0,
            armor: 0,
            fuel_capacity: 0,
            loyalty: 0,
            intelligence: 0,
            agility: 0,
        };

        // Test that stats structure is properly initialized
        assert(stats.damage == 100, 'Damage should be 100');
        assert(stats.defense == 60, 'Defense should be 60');
        assert(stats.weight == 5, 'Weight should be 5');
        assert!(stats.speed == 0, "Speed should be 0 for non-vehicles");
        assert!(stats.loyalty == 0, "Loyalty should be 0 for non-pets");
    }

    #[test]
    fn test_gear_filters_structure() {
        let filters = GearFilters {
            gear_types: Option::Some(array![GearType::Sword, GearType::Bow]),
            min_level: Option::Some(1),
            max_level: Option::Some(5),
            ownership_filter: Option::Some(OwnershipFilter::Owned),
            min_xp_required: Option::Some(0),
            max_xp_required: Option::Some(1000),
            spawned_only: Option::Some(false),
        };

        // Test that filters are properly structured
        match filters.gear_types {
            Option::Some(types) => {
                assert(types.len() == 2, 'Should have 2 gear types');
                assert(*types.at(0) == GearType::Sword, 'First type should be Sword');
                assert(*types.at(1) == GearType::Bow, 'Second type should be Bow');
            },
            Option::None => assert(false, 'Gear types should be Some'),
        }

        match filters.ownership_filter {
            Option::Some(filter) => assert(
                filter == OwnershipFilter::Owned, 'Should filter owned items',
            ),
            Option::None => assert(false, 'Ownership filter should be Some'),
        }

        match filters.spawned_only {
            Option::Some(spawned) => assert(!spawned, 'Should not filter spawned only'),
            Option::None => assert(false, 'Spawned filter should be Some'),
        }
    }

    #[test]
    fn test_pagination_params() {
        let pagination = PaginationParams { offset: 0, limit: 50 };

        assert(pagination.offset == 0, 'Offset should be 0');
        assert(pagination.limit == 50, 'Limit should be 50');

        // Test validation logic
        let valid = pagination.limit > 0 && pagination.limit <= 1000;
        assert(valid, 'Valid pagination should pass');

        let invalid_pagination = PaginationParams {
            offset: 0, limit: 0 // Invalid - limit must be > 0
        };
        let invalid = invalid_pagination.limit > 0 && invalid_pagination.limit <= 1000;
        assert(!invalid, 'Invalid pagination should fail');

        // Test max limit
        let max_pagination = PaginationParams { offset: 0, limit: 1000 // Max allowed
        };
        let max_valid = max_pagination.limit > 0 && max_pagination.limit <= 1000;
        assert(max_valid, 'Max pagination should be valid');
    }

    #[test]
    fn test_sort_params() {
        let sort_by_damage = SortParams {
            sort_by: SortField::Damage, ascending: false // Descending for damage (highest first)
        };

        let sort_by_level = SortParams {
            sort_by: SortField::Level, ascending: true // Ascending for level (lowest first)
        };

        assert(sort_by_damage.sort_by == SortField::Damage, 'Should sort by damage');
        assert(!sort_by_damage.ascending, 'Should be descending');
        assert(sort_by_level.sort_by == SortField::Level, 'Should sort by level');
        assert(sort_by_level.ascending, 'Should be ascending');
    }

    #[test]
    fn test_ownership_status_creation() {
        let player = contract_address_const::<0x123>();
        let _gear = create_test_gear(1, GearType::Sword, 5, player);

        let ownership_status = OwnershipStatus {
            is_owned: true,
            owner: player,
            is_spawned: false,
            is_available_for_pickup: false,
            is_equipped: false,
            meets_xp_requirement: true,
        };

        assert(ownership_status.is_owned, 'Should be owned');
        assert(ownership_status.owner == player, 'Owner should match');
        assert(!ownership_status.is_spawned, 'Should not be spawned');
        assert(ownership_status.meets_xp_requirement, 'Should meet XP requirement');
    }

    #[test]
    fn test_upgrade_info_structure() {
        let upgrade_info = UpgradeInfo {
            current_level: 5,
            max_level: 10,
            can_upgrade: true,
            next_level_cost: Option::None,
            success_rate: Option::Some(85),
            next_level_stats: Option::None,
            total_upgrade_cost: Option::None,
        };

        assert(upgrade_info.current_level == 5, 'Current level should be 5');
        assert(upgrade_info.max_level == 10, 'Max level should be 10');
        assert(upgrade_info.can_upgrade, 'Should be able to upgrade');

        match upgrade_info.success_rate {
            Option::Some(rate) => assert(rate == 85, 'Success rate should be 85%'),
            Option::None => assert(false, 'Success rate should be Some'),
        }
    }

    // Integration test for gear details retrieval
    #[test]
    fn test_gear_details_complete_structure() {
        let player = contract_address_const::<0x123>();
        let gear = create_test_gear(1, GearType::Sword, 3, player);

        let calculated_stats = GearStatsCalculated {
            damage: 130, // Base 100 + 30% for level 3
            range: 110, // Base 100 + 10% for level 3
            accuracy: 143, // Base 130 + 10% for level 3
            fire_rate: 22, // Base 20 + 10% for level 3
            defense: 0,
            durability: 0,
            weight: 5,
            speed: 0,
            armor: 0,
            fuel_capacity: 0,
            loyalty: 0,
            intelligence: 0,
            agility: 0,
        };

        let ownership_status = OwnershipStatus {
            is_owned: true,
            owner: player,
            is_spawned: false,
            is_available_for_pickup: false,
            is_equipped: false,
            meets_xp_requirement: true,
        };

        let upgrade_info = UpgradeInfo {
            current_level: 3,
            max_level: 10,
            can_upgrade: true,
            next_level_cost: Option::None,
            success_rate: Option::Some(80),
            next_level_stats: Option::None,
            total_upgrade_cost: Option::None,
        };

        let gear_details = GearDetailsComplete {
            gear, calculated_stats, upgrade_info: Option::Some(upgrade_info), ownership_status,
        };

        assert(gear_details.gear.upgrade_level == 3, 'Gear level should be 3');
        assert(gear_details.calculated_stats.damage == 130, 'Damage should be upgraded');
        assert(gear_details.ownership_status.is_owned, 'Should be owned');
        assert(gear_details.ownership_status.owner == player, 'Owner should match');

        match gear_details.upgrade_info {
            Option::Some(info) => {
                assert(info.can_upgrade, 'Should be able to upgrade');
                assert(info.current_level == 3, 'Current level should be 3');
                assert(info.max_level == 10, 'Max level should be 10');
            },
            Option::None => assert(false, 'Upgrade info should be Some'),
        }
    }

    // Test integration with existing gear system
    #[test]
    fn test_integration_with_existing_gear_system() {
        // Test that the new read operations work with existing gear functions
        let player = contract_address_const::<0x123>();
        let _session_id = 'test_session';

        // This would test the actual integration in a real test environment
        // For now, we just verify the data structures are compatible
        let gear = create_test_gear(1, GearType::Sword, 5, player);
        assert(gear.id == 1, 'Gear ID should match');
        assert(gear.upgrade_level == 5, 'Upgrade level should match');
        assert(gear.owner == player, 'Owner should match');

        // Test that gear type conversion works
        let gear_type_felt: felt252 = GearType::Sword.into();
        assert(gear_type_felt == 0x102, 'Sword should convert to 0x102');

        // Test that we can convert back
        let converted_type: Option<GearType> = gear_type_felt.try_into();
        match converted_type {
            Option::Some(t) => assert(t == GearType::Sword, 'Should convert back to Sword'),
            Option::None => assert(false, 'Conversion should succeed'),
        }
    }

    #[test]
    fn test_session_validation_structure() {
        let player = contract_address_const::<0x123>();
        let session = create_test_session(player);

        // Test session structure
        assert(session.session_id == 'test_session', 'Session ID should match');
        assert(session.player_address == player, 'Player should match');
        assert(session.is_valid, 'Session should be valid');
        assert(session.status == 0, 'Status should be active');
        assert(
            session.used_transactions < session.max_transactions, 'Should have transactions left',
        );

        // Test session expiry logic
        let current_time = get_block_timestamp();
        assert(session.expires_at > current_time, 'Session should not be expired');
    }

    #[test]
    fn test_upgrade_material_structure() {
        use coa::models::gear::UpgradeMaterial;

        let material = UpgradeMaterial { token_id: 1, amount: 100 };

        assert(material.token_id == 1, 'Token ID should be 1');
        assert(material.amount == 100, 'Amount should be 100');
    }

    #[test]
    fn test_combined_equipment_effects_structure() {
        let effects = CombinedEquipmentEffects {
            total_damage: 150,
            total_defense: 80,
            total_weight: 25,
            equipped_slots: array![],
            empty_slots: array!['HEAD', 'CHEST'],
            set_bonuses: array![('ARMOR_SET', 20)],
        };

        assert(effects.total_damage == 150, 'Total damage should be 150');
        assert(effects.total_defense == 80, 'Total defense should be 80');
        assert(effects.total_weight == 25, 'Total weight should be 25');
        assert(effects.empty_slots.len() == 2, 'Should have 2 empty slots');
        assert(effects.set_bonuses.len() == 1, 'Should have 1 set bonus');

        let (bonus_type, bonus_value) = *effects.set_bonuses.at(0);
        assert(bonus_type == 'ARMOR_SET', 'Bonus type should be ARMOR_SET');
        assert(bonus_value == 20, 'Bonus value should be 20');
    }

    #[test]
    fn test_paginated_result_structure() {
        let result = PaginatedGearResult { items: array![], total_count: 100, has_more: true };

        assert(result.items.len() == 0, 'Items array should be empty');
        assert(result.total_count == 100, 'Total count should be 100');
        assert(result.has_more, 'Should have more items');
    }

    #[test]
    fn test_gear_workflow_simulation() {
        // Simulate a complete gear workflow
        let player = contract_address_const::<0x123>();
        let _session = create_test_session(player);

        // Create a sword at level 0
        let mut sword = create_test_gear(1, GearType::Sword, 0, player);
        assert(sword.upgrade_level == 0, 'Should start at level 0');
        assert(sword.is_owned(), 'Should be owned by player');

        // Simulate upgrade to level 3
        sword.upgrade_level = 3;
        assert(sword.upgrade_level == 3, 'Should be upgraded to level 3');

        // Test calculated stats with upgrade multiplier
        let base_damage = 100_u64;
        let upgraded_damage = apply_upgrade_multiplier(base_damage, sword.upgrade_level);
        assert(upgraded_damage == 130, 'Level 3 should give 130 damage');

        // Create gear details structure
        let calculated_stats = GearStatsCalculated {
            damage: upgraded_damage,
            range: apply_upgrade_multiplier(80, sword.upgrade_level),
            accuracy: apply_upgrade_multiplier(90, sword.upgrade_level),
            fire_rate: apply_upgrade_multiplier(15, sword.upgrade_level),
            defense: 0,
            durability: 0,
            weight: 5, // Weight doesn't scale
            speed: 0,
            armor: 0,
            fuel_capacity: 0,
            loyalty: 0,
            intelligence: 0,
            agility: 0,
        };

        let ownership_status = OwnershipStatus {
            is_owned: sword.is_owned(),
            owner: sword.owner,
            is_spawned: sword.spawned,
            is_available_for_pickup: sword.is_available_for_pickup(),
            is_equipped: sword.in_action,
            meets_xp_requirement: true,
        };

        let gear_details = GearDetailsComplete {
            gear: sword, calculated_stats, upgrade_info: Option::None, ownership_status,
        };

        // Verify the complete workflow
        assert(gear_details.gear.upgrade_level == 3, 'Gear should be level 3');
        assert(gear_details.calculated_stats.damage == 130, 'Damage should be upgraded');
        assert(gear_details.calculated_stats.range == 104, 'Range should be upgraded');
        assert(gear_details.ownership_status.is_owned, 'Should be owned');
        assert(!gear_details.ownership_status.is_available_for_pickup, 'Should not be available');
    }

    #[test]
    fn test_equipment_slot_info() {
        let player = contract_address_const::<0x123>();
        let helmet = create_test_gear(1, GearType::Helmet, 2, player);

        let slot_info = coa::models::gear::EquipmentSlotInfo {
            slot_type: 'HEAD', equipped_item: Option::Some(helmet), is_empty: false,
        };

        assert(slot_info.slot_type == 'HEAD', 'Slot type should be HEAD');
        assert(!slot_info.is_empty, 'Slot should not be empty');

        match slot_info.equipped_item {
            Option::Some(gear) => {
                assert(gear.id == 1, 'Equipped item ID should be 1');
                assert(gear.upgrade_level == 2, 'Equipped item should be level 2');
            },
            Option::None => assert(false, 'Should have equipped item'),
        }

        // Test empty slot
        let empty_slot = coa::models::gear::EquipmentSlotInfo {
            slot_type: 'CHEST', equipped_item: Option::None, is_empty: true,
        };

        assert(empty_slot.is_empty, 'Empty slot should be empty');
        assert(empty_slot.slot_type == 'CHEST', 'Slot type should be CHEST');
    }
}
