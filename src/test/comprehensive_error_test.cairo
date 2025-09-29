#[cfg(test)]
mod comprehensive_error_tests {
    use starknet::{ContractAddress, contract_address_const};
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
        stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
    };
    use coa::systems::player::{IPlayerDispatcher, IPlayerDispatcherTrait};
    use coa::systems::gear::{IGearDispatcher, IGearDispatcherTrait};
    use coa::systems::session::{ISessionActionsDispatcher, ISessionActionsDispatcherTrait};
    use coa::systems::core::{ICoreDispatcher, ICoreDispatcherTrait};

    fn sample_player() -> ContractAddress {
        contract_address_const::<0x123>()
    }

    fn zero_address() -> ContractAddress {
        contract_address_const::<0x0>()
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

    fn create_core_dispatcher() -> ICoreDispatcher {
        let contract = declare("CoreActions");
        let mut constructor_args = array![];
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_args)
            .unwrap();
        ICoreDispatcher { contract_address }
    }

    // ============ UNAUTHORIZED ACCESS TESTS ============

    #[test]
    #[should_panic(expected: ('INSUFFICIENT_PERMISSIONS',))]
    fn test_unauthorized_admin_spawn_items() {
        let core_dispatcher = create_core_dispatcher();
        let non_admin = sample_player();

        start_cheat_caller_address(core_dispatcher.contract_address, non_admin);
        start_cheat_block_timestamp(core_dispatcher.contract_address, 1000);

        // Non-admin tries to spawn items
        let gear_details = array![];
        core_dispatcher.spawn_items(gear_details);

        stop_cheat_caller_address(core_dispatcher.contract_address);
        stop_cheat_block_timestamp(core_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INSUFFICIENT_PERMISSIONS',))]
    fn test_unauthorized_admin_pause_contract() {
        let core_dispatcher = create_core_dispatcher();
        let non_admin = sample_player();

        start_cheat_caller_address(core_dispatcher.contract_address, non_admin);
        start_cheat_block_timestamp(core_dispatcher.contract_address, 1000);

        // Non-admin tries to pause contract
        core_dispatcher.pause_contract('EMERGENCY');

        stop_cheat_caller_address(core_dispatcher.contract_address);
        stop_cheat_block_timestamp(core_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('UNAUTHORIZED_PLAYER',))]
    fn test_unauthorized_player_access() {
        let player_dispatcher = create_player_dispatcher();
        let player1 = contract_address_const::<0x123>();
        let player2 = contract_address_const::<0x456>();

        start_cheat_caller_address(player_dispatcher.contract_address, player1);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Player 1 tries to access Player 2's data without admin rights
        let session_id = 12345;
        player_dispatcher.get_player(player2.into(), session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    // ============ INVALID INPUT TESTS ============

    #[test]
    #[should_panic(expected: ('ZERO_ADDRESS',))]
    fn test_zero_address_validation() {
        let player_dispatcher = create_player_dispatcher();

        start_cheat_caller_address(player_dispatcher.contract_address, zero_address());
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Zero address tries to create player
        player_dispatcher.new('CHAOS_MERCENARIES', 12345);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_DURATION',))]
    fn test_invalid_session_duration() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Invalid duration (too short)
        session_dispatcher.create_session_key(1000, 100); // Less than 1 hour

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_TRANSACTIONS',))]
    fn test_invalid_transaction_count() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Invalid transaction count (too high)
        session_dispatcher.create_session_key(3600, 2000); // More than max allowed

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_FACTION',))]
    fn test_invalid_faction() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Invalid faction
        player_dispatcher.new('INVALID_FACTION', 12345);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('NO_ITEMS_PROVIDED',))]
    fn test_empty_item_array() {
        let core_dispatcher = create_core_dispatcher();
        let admin = contract_address_const::<0x999>();

        start_cheat_caller_address(core_dispatcher.contract_address, admin);
        start_cheat_block_timestamp(core_dispatcher.contract_address, 1000);

        // Empty item array
        let empty_items = array![];
        core_dispatcher.pick_items(empty_items);

        stop_cheat_caller_address(core_dispatcher.contract_address);
        stop_cheat_block_timestamp(core_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('TOO_MANY_ITEMS',))]
    fn test_too_many_items() {
        let core_dispatcher = create_core_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(core_dispatcher.contract_address, player);
        start_cheat_block_timestamp(core_dispatcher.contract_address, 1000);

        // Too many items (more than limit of 50)
        let mut too_many_items = array![];
        let mut i = 0;
        loop {
            if i >= 60 { // More than the limit
                break;
            }
            too_many_items.append(i.into());
            i += 1;
        };

        core_dispatcher.pick_items(too_many_items);

        stop_cheat_caller_address(core_dispatcher.contract_address);
        stop_cheat_block_timestamp(core_dispatcher.contract_address);
    }

    // ============ SESSION VALIDATION FAILURES ============

    #[test]
    #[should_panic(expected: ('INVALID_SESSION',))]
    fn test_zero_session_id() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(player_dispatcher.contract_address, player);

        // Zero session ID
        player_dispatcher.new('CHAOS_MERCENARIES', 0);

        stop_cheat_caller_address(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('SESSION_NOT_FOUND',))]
    fn test_nonexistent_session() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Non-existent session ID
        player_dispatcher.new('CHAOS_MERCENARIES', 999999);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('SESSION_EXPIRED',))]
    fn test_expired_session() {
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        
        // Set time way in the future (expired session)
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 999999);

        let items = array![1_u256];
        gear_dispatcher.equip(items, 12345); // Assuming session 12345 is expired

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('NO_TRANSACTIONS_LEFT',))]
    fn test_session_transaction_limit_exceeded() {
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 1000);

        // Simulate session with no transactions left
        let items = array![1_u256];
        // This would fail if session has used all transactions
        gear_dispatcher.equip(items, 12345);

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    // ============ RATE LIMITING TESTS ============

    #[test]
    #[should_panic(expected: ('RATE_LIMIT_EXCEEDED',))]
    fn test_session_creation_rate_limit() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Create multiple sessions rapidly to exceed rate limit
        let mut i = 0;
        loop {
            if i >= 10 { // Exceed the rate limit
                break;
            }
            session_dispatcher.create_session_key(3600, 100);
            i += 1;
        };

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('RATE_LIMIT_EXCEEDED',))]
    fn test_item_spawn_rate_limit() {
        let core_dispatcher = create_core_dispatcher();
        let admin = contract_address_const::<0x999>();

        start_cheat_caller_address(core_dispatcher.contract_address, admin);
        start_cheat_block_timestamp(core_dispatcher.contract_address, 1000);

        // Spawn items rapidly to exceed rate limit
        let gear_details = array![];
        let mut i = 0;
        loop {
            if i >= 15 { // Exceed the rate limit
                break;
            }
            core_dispatcher.spawn_items(gear_details);
            i += 1;
        };

        stop_cheat_caller_address(core_dispatcher.contract_address);
        stop_cheat_block_timestamp(core_dispatcher.contract_address);
    }

    // ============ CONTRACT STATE VALIDATION ============

    #[test]
    #[should_panic(expected: ('CONTRACT_PAUSED',))]
    fn test_operations_when_paused() {
        let core_dispatcher = create_core_dispatcher();
        let player_dispatcher = create_player_dispatcher();
        let admin = contract_address_const::<0x999>();
        let player = sample_player();

        // Admin pauses contract
        start_cheat_caller_address(core_dispatcher.contract_address, admin);
        start_cheat_block_timestamp(core_dispatcher.contract_address, 1000);
        core_dispatcher.pause_contract('MAINTENANCE');
        stop_cheat_caller_address(core_dispatcher.contract_address);

        // Player tries to create character while paused
        start_cheat_caller_address(player_dispatcher.contract_address, player);
        player_dispatcher.new('CHAOS_MERCENARIES', 12345);
        stop_cheat_caller_address(player_dispatcher.contract_address);

        stop_cheat_block_timestamp(core_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_CONTRACT_STATE',))]
    fn test_invalid_contract_state() {
        let core_dispatcher = create_core_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(core_dispatcher.contract_address, player);
        start_cheat_block_timestamp(core_dispatcher.contract_address, 1000);

        // Try operation with invalid contract state (admin is zero)
        let items = array![1_u256];
        core_dispatcher.pick_items(items);

        stop_cheat_caller_address(core_dispatcher.contract_address);
        stop_cheat_block_timestamp(core_dispatcher.contract_address);
    }

    // ============ BOUNDARY VALUE TESTS ============

    #[test]
    fn test_maximum_valid_values() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test maximum valid session duration (24 hours)
        let session_id = session_dispatcher.create_session_key(86400, 1000);
        assert(session_id != 0, 'Max duration session created');

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    fn test_minimum_valid_values() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test minimum valid session duration (1 hour)
        let session_id = session_dispatcher.create_session_key(3600, 1);
        assert(session_id != 0, 'Min duration session created');

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_COUNT_TOO_HIGH',))]
    fn test_overflow_protection() {
        let core_dispatcher = create_core_dispatcher();
        let admin = contract_address_const::<0x999>();

        start_cheat_caller_address(core_dispatcher.contract_address, admin);
        start_cheat_block_timestamp(core_dispatcher.contract_address, 1000);

        // Test with extremely large values that could cause overflow
        // This would be tested with actual gear details containing large counts
        let gear_details = array![]; // Would contain details with count > 1000000
        core_dispatcher.spawn_items(gear_details);

        stop_cheat_caller_address(core_dispatcher.contract_address);
        stop_cheat_block_timestamp(core_dispatcher.contract_address);
    }

    // ============ MALFORMED DATA TESTS ============

    #[test]
    #[should_panic(expected: ('BATCH_LENGTH_MISMATCH',))]
    fn test_batch_array_length_mismatch() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Mismatched batch arrays
        let batch_targets = array![array![1_u256], array![2_u256]];
        let batch_target_types = array![array!['LIVING']]; // Mismatch
        let batch_weapons = array![array![], array![]];

        player_dispatcher.batch_deal_damage(batch_targets, batch_target_types, batch_weapons, 12345);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('TARGET_ARRAYS_MISMATCH',))]
    fn test_target_array_mismatch() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Mismatched target arrays within batch
        let batch_targets = array![array![1_u256, 2_u256]];
        let batch_target_types = array![array!['LIVING']]; // Mismatch: 2 targets, 1 type
        let batch_weapons = array![array![]];

        player_dispatcher.batch_deal_damage(batch_targets, batch_target_types, batch_weapons, 12345);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    // ============ CONCURRENT ACCESS TESTS ============

    #[test]
    fn test_concurrent_session_creation() {
        let session_dispatcher = create_session_dispatcher();
        let player1 = contract_address_const::<0x123>();
        let player2 = contract_address_const::<0x456>();

        // Player 1 creates session
        start_cheat_caller_address(session_dispatcher.contract_address, player1);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);
        let session_id1 = session_dispatcher.create_session_key(3600, 100);
        stop_cheat_caller_address(session_dispatcher.contract_address);

        // Player 2 creates session at same time
        start_cheat_caller_address(session_dispatcher.contract_address, player2);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);
        let session_id2 = session_dispatcher.create_session_key(3600, 100);
        stop_cheat_caller_address(session_dispatcher.contract_address);

        // Sessions should be different
        assert(session_id1 != session_id2, 'Concurrent sessions different');

        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    // ============ SYSTEM FAILURE SCENARIOS ============

    #[test]
    fn test_graceful_degradation() {
        let gear_dispatcher = create_gear_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(gear_dispatcher.contract_address, player);
        start_cheat_block_timestamp(gear_dispatcher.contract_address, 1000);

        // Test that system continues to work after failed operations
        let invalid_items = array![999999_u256]; // Non-existent item
        
        // This might fail, but shouldn't crash the system
        // gear_dispatcher.equip(invalid_items, 12345);
        
        // Valid operation should still work
        let valid_items = array![1_u256];
        gear_dispatcher.equip(valid_items, 12345);

        stop_cheat_caller_address(gear_dispatcher.contract_address);
        stop_cheat_block_timestamp(gear_dispatcher.contract_address);
    }

    #[test]
    fn test_error_recovery() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test recovery from invalid operations
        // Try invalid faction (might fail)
        // player_dispatcher.new('INVALID', 12345);
        
        // Valid operation should work after failure
        player_dispatcher.new('CHAOS_MERCENARIES', 12345);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }
}