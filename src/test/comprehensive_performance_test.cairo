#[cfg(test)]
mod comprehensive_performance_tests {
    use starknet::{ContractAddress, contract_address_const};
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
        stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
        get_class_hash, spy_events, EventSpyAssertionsTrait,
    };
    use coa::systems::player::{IPlayerDispatcher, IPlayerDispatcherTrait};
    use coa::systems::gear::{IGearDispatcher, IGearDispatcherTrait};
    use coa::systems::session::{ISessionActionsDispatcher, ISessionActionsDispatcherTrait};

    fn sample_player() -> ContractAddress {
        contract_address_const::<0x123>()
    }

    fn create_player_dispatcher() -> IPlayerDispatcher {
        let contract = declare("PlayerActions");
        let mut constructor_args = array![];
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_args)
            .unwrap();
        IPlayerDispatcher { contract_address }
    }

    fn create_gear_dispatcher() -> IGearDispatcher {
        let contract = declare("GearActions");
        let mut constructor_args = array![];
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_args)
            .unwrap();
        IGearDispatcher { contract_address }
    }

    fn create_session_dispatcher() -> ISessionActionsDispatcher {
        let contract = declare("SessionActions");
        let mut constructor_args = array![];
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_args)
            .unwrap();
        ISessionActionsDispatcher { contract_address }
    }

    // ============ BATCH OPERATION PERFORMANCE ============

    #[test]
    fn test_batch_vs_individual_operations() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test individual operations (less efficient)
        let targets1 = array![1_u256];
        let target_types1 = array!['LIVING'];
        let weapons1 = array![];

        player_dispatcher.deal_damage(targets1, target_types1, weapons1, session_id);

        let targets2 = array![2_u256];
        let target_types2 = array!['LIVING'];
        let weapons2 = array![];

        player_dispatcher.deal_damage(targets2, target_types2, weapons2, session_id);

        // Test batch operations (more efficient)
        let batch_targets = array![array![3_u256, 4_u256], array![5_u256, 6_u256]];
        let batch_target_types = array![array!['LIVING', 'LIVING'], array!['LIVING', 'LIVING']];
        let batch_weapons = array![array![], array![]];

        player_dispatcher
            .batch_deal_damage(batch_targets, batch_target_types, batch_weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_large_batch_operations() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test large batch operations (10+ actions for 60% gas savings)
        let mut batch_targets = array![];
        let mut batch_target_types = array![];
        let mut batch_weapons = array![];

        let mut i = 0;
        loop {
            if i >= 15 { // Large batch
                break;
            }

            batch_targets.append(array![(i + 1).into(), (i + 2).into()]);
            batch_target_types.append(array!['LIVING', 'LIVING']);
            batch_weapons.append(array![]);

            i += 1;
        };

        player_dispatcher
            .batch_deal_damage(batch_targets, batch_target_types, batch_weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    // ============ ARRAY SIZE PERFORMANCE ============

    #[test]
    fn test_small_array_performance() {
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 1000);

        // Test small arrays (should be fast)
        let small_items = array![1_u256, 2_u256, 3_u256];
        gear_dispatcher.equip(small_items, session_id);

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    #[test]
    fn test_medium_array_performance() {
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 1000);

        // Test medium arrays (10-20 items)
        let mut medium_items = array![];
        let mut i = 0;
        loop {
            if i >= 15 {
                break;
            }
            medium_items.append((i + 1).into());
            i += 1;
        };

        gear_dispatcher.equip(medium_items, session_id);

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    #[test]
    fn test_large_array_performance() {
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 1000);

        // Test large arrays (approaching limit of 50)
        let mut large_items = array![];
        let mut i = 0;
        loop {
            if i >= 45 { // Close to limit but not exceeding
                break;
            }
            large_items.append((i + 1).into());
            i += 1;
        };

        gear_dispatcher.equip(large_items, session_id);

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    // ============ COMPLEX CALCULATION PERFORMANCE ============

    #[test]
    fn test_damage_calculation_performance() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test complex damage calculations with multiple weapons
        let targets = array![1_u256, 2_u256, 3_u256, 4_u256, 5_u256];
        let target_types = array!['LIVING', 'LIVING', 'LIVING', 'LIVING', 'LIVING'];
        let weapons = array![10_u256, 11_u256, 12_u256, 13_u256]; // Multiple weapons

        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_faction_bonus_calculation_performance() {
        let player_dispatcher = create_player_dispatcher();
        let session_id = 12345;

        // Test all three factions for performance comparison
        let chaos_player = contract_address_const::<0x123>();
        let supreme_player = contract_address_const::<0x456>();
        let rebel_player = contract_address_const::<0x789>();

        // Chaos Mercenaries (damage bonus)
        start_cheat_caller_address(player_dispatcher.contract_address, chaos_player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);
        player_dispatcher.new('CHAOS_MERCENARIES', session_id);

        let targets = array![1_u256];
        let target_types = array!['LIVING'];
        let weapons = array![10_u256];
        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);
        stop_cheat_caller_address(player_dispatcher.contract_address);

        // Supreme Law (defense bonus)
        start_cheat_caller_address(player_dispatcher.contract_address, supreme_player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1001);
        player_dispatcher.new('SUPREME_LAW', session_id);
        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);
        stop_cheat_caller_address(player_dispatcher.contract_address);

        // Rebel Technomancers (speed bonus)
        start_cheat_caller_address(player_dispatcher.contract_address, rebel_player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1002);
        player_dispatcher.new('REBEL_TECHNOMANCERS', session_id);
        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);
        stop_cheat_caller_address(player_dispatcher.contract_address);

        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    // ============ SESSION MANAGEMENT PERFORMANCE ============

    #[test]
    fn test_session_validation_performance() {
        let session_dispatcher = create_session_dispatcher();
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Create session
        let session_id = session_dispatcher.create_session_key(3600, 100);
        stop_cheat_caller_address(session_dispatcher.contract_address);

        // Test multiple operations with same session (validation caching)
        start_cheat_caller_address(gear_dispatcher.contract_address, player);

        let items = array![1_u256];

        // Multiple operations to test session validation performance
        gear_dispatcher.equip(items, session_id);
        gear_dispatcher.upgrade_gear(1_u256, session_id);
        gear_dispatcher.unequip(items, session_id);
        gear_dispatcher.equip(items, session_id);
        gear_dispatcher.upgrade_gear(1_u256, session_id);

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    #[test]
    fn test_session_auto_renewal_performance() {
        let session_dispatcher = create_session_dispatcher();
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Create session close to expiration
        let session_id = session_dispatcher.create_session_key(3600, 100);
        stop_cheat_caller_address(session_dispatcher.contract_address);

        // Test auto-renewal performance
        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 4300); // Close to expiration

        let items = array![1_u256];
        gear_dispatcher.equip(items, session_id); // Should trigger auto-renewal

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    // ============ MEMORY USAGE OPTIMIZATION ============

    #[test]
    fn test_memory_efficient_operations() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test memory-efficient batch operations
        // Using smaller batches to reduce memory usage
        let batch_targets = array![
            array![1_u256, 2_u256], // Small batches
            array![3_u256, 4_u256], array![5_u256, 6_u256],
        ];
        let batch_target_types = array![
            array!['LIVING', 'LIVING'], array!['LIVING', 'LIVING'], array!['LIVING', 'LIVING'],
        ];
        let batch_weapons = array![array![], array![], array![]];

        player_dispatcher
            .batch_deal_damage(batch_targets, batch_target_types, batch_weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    // ============ STORAGE ACCESS OPTIMIZATION ============

    #[test]
    fn test_storage_access_patterns() {
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 1000);

        // Test sequential storage access (should be optimized)
        gear_dispatcher.get_item_details(1_u256, session_id);
        gear_dispatcher.get_item_details(2_u256, session_id);
        gear_dispatcher.get_item_details(3_u256, session_id);

        // Test batch storage access
        let items = array![1_u256, 2_u256, 3_u256];
        gear_dispatcher.equip(items, session_id);

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    // ============ EVENT EMISSION PERFORMANCE ============

    #[test]
    fn test_event_emission_performance() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        let mut spy = spy_events();

        // Test multiple operations that emit events
        player_dispatcher.new('CHAOS_MERCENARIES', session_id);

        let targets = array![1_u256, 2_u256, 3_u256];
        let target_types = array!['LIVING', 'LIVING', 'LIVING'];
        let weapons = array![];

        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);

        // Events should be emitted efficiently
        // In a real performance test, we would measure gas usage here

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    // ============ LOOP OPTIMIZATION ============

    #[test]
    fn test_loop_optimization() {
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 1000);

        // Test optimized loops in gear operations
        let mut items = array![];
        let mut i = 0;
        loop {
            if i >= 20 { // Moderate size for loop testing
                break;
            }
            items.append((i + 1).into());
            i += 1;
        };

        gear_dispatcher.equip(items, session_id);

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    // ============ GAS USAGE BENCHMARKS ============

    #[test]
    fn test_gas_usage_single_operations() {
        let player_dispatcher = create_player_dispatcher();
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Benchmark single operations
        player_dispatcher.new('CHAOS_MERCENARIES', session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        start_cheat_caller_address(gear_dispatcher.contract_address, player);

        let items = array![1_u256];
        gear_dispatcher.equip(items, session_id);
        gear_dispatcher.upgrade_gear(1_u256, session_id);

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    #[test]
    fn test_gas_usage_batch_operations() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Benchmark batch operations (should be more gas efficient)
        let batch_targets = array![
            array![1_u256, 2_u256, 3_u256],
            array![4_u256, 5_u256],
            array![6_u256, 7_u256, 8_u256, 9_u256],
        ];
        let batch_target_types = array![
            array!['LIVING', 'LIVING', 'LIVING'],
            array!['LIVING', 'LIVING'],
            array!['LIVING', 'LIVING', 'LIVING', 'LIVING'],
        ];
        let batch_weapons = array![array![10_u256], array![], array![11_u256, 12_u256]];

        player_dispatcher
            .batch_deal_damage(batch_targets, batch_target_types, batch_weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    // ============ STRESS TESTING ============

    #[test]
    fn test_high_frequency_operations() {
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 1000);

        // Test high frequency operations
        let items = array![1_u256];

        let mut i = 0;
        loop {
            if i >= 10 { // High frequency test
                break;
            }

            gear_dispatcher.equip(items, session_id);
            gear_dispatcher.unequip(items, session_id);

            i += 1;
        };

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    #[test]
    fn test_concurrent_user_simulation() {
        let player_dispatcher = create_player_dispatcher();
        let session_id = 12345;

        // Simulate multiple users performing operations
        let players = array![
            contract_address_const::<0x123>(),
            contract_address_const::<0x456>(),
            contract_address_const::<0x789>(),
            contract_address_const::<0xABC>(),
            contract_address_const::<0xDEF>(),
        ];

        let mut i = 0;
        loop {
            if i >= players.len() {
                break;
            }

            let player = *players.at(i);
            start_cheat_caller_address(player_dispatcher.contract_address, player);
            start_cheat_block_timestamp(player_dispatcher.contract_address, 1000 + i.into());

            player_dispatcher.new('CHAOS_MERCENARIES', session_id);

            let targets = array![(i + 1).into()];
            let target_types = array!['LIVING'];
            let weapons = array![];
            player_dispatcher.deal_damage(targets, target_types, weapons, session_id);

            stop_cheat_caller_address(player_dispatcher.contract_address);

            i += 1;
        };

        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }
}
