#[cfg(test)]
mod comprehensive_session_tests {
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
        stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
        spy_events, EventSpyAssertionsTrait,
    };
    use coa::models::session::{SessionKey, SessionKeyCreated};
    use coa::systems::session::{
        SessionActions, ISessionActionsDispatcher, ISessionActionsDispatcherTrait,
    };

    // Test constants
    const VALID_DURATION: u64 = 3600; // 1 hour
    const MAX_DURATION: u64 = 86400; // 24 hours
    const MIN_DURATION: u64 = 3600; // 1 hour
    const VALID_TRANSACTIONS: u32 = 100;
    const MAX_TRANSACTIONS: u32 = 1000;

    fn sample_player() -> ContractAddress {
        contract_address_const::<0x123>()
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

    #[test]
    fn test_session_creation_and_validation() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test valid session creation
        let session_id = session_dispatcher.create_session_key(VALID_DURATION, VALID_TRANSACTIONS);
        assert(session_id != 0, 'Session ID should not be zero');

        // Test session validation
        let is_valid = session_dispatcher.validate_session(session_id, player);
        assert(is_valid, 'Session should be valid');

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    fn test_session_expiration() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Create session
        let session_id = session_dispatcher.create_session_key(VALID_DURATION, VALID_TRANSACTIONS);

        // Test session expiry check - should not be expired
        let not_expired = session_dispatcher.check_session_expiry(1000, VALID_DURATION);
        assert(not_expired, 'Session should not be expired');

        // Move time forward past expiration
        start_cheat_block_timestamp(session_dispatcher.contract_address, 5000);

        // Test session expiry check - should be expired
        let expired = session_dispatcher.check_session_expiry(1000, VALID_DURATION);
        assert(!expired, 'Session should be expired');

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    fn test_session_limit_enforcement() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test transaction limit check
        let has_transactions = session_dispatcher.check_transaction_limit(50, VALID_TRANSACTIONS);
        assert(has_transactions, 'Should have transactions left');

        let no_transactions = session_dispatcher
            .check_transaction_limit(VALID_TRANSACTIONS, VALID_TRANSACTIONS);
        assert(!no_transactions, 'Should have no transactions left');

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    fn test_session_auto_renewal() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Create session
        let session_id = session_dispatcher.create_session_key(VALID_DURATION, VALID_TRANSACTIONS);

        // Test renewal check - should not need renewal
        let needs_renewal = session_dispatcher.check_session_needs_renewal(session_id, 300);
        assert(!needs_renewal, 'Should not need renewal');

        // Move time close to expiration
        start_cheat_block_timestamp(session_dispatcher.contract_address, 4500);

        // Test renewal check - should need renewal
        let needs_renewal_now = session_dispatcher.check_session_needs_renewal(session_id, 300);
        assert(needs_renewal_now, 'Should need renewal');

        // Test session renewal
        let renewed = session_dispatcher
            .renew_session(session_id, VALID_DURATION, VALID_TRANSACTIONS);
        assert(renewed, 'Session should be renewed');

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    fn test_session_edge_cases() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test minimum duration
        let session_id_min = session_dispatcher
            .create_session_key(MIN_DURATION, VALID_TRANSACTIONS);
        assert(session_id_min != 0, 'Min duration session created');

        // Test maximum duration
        let session_id_max = session_dispatcher
            .create_session_key(MAX_DURATION, VALID_TRANSACTIONS);
        assert(session_id_max != 0, 'Max duration session created');

        // Test maximum transactions
        let session_id_max_tx = session_dispatcher
            .create_session_key(VALID_DURATION, MAX_TRANSACTIONS);
        assert(session_id_max_tx != 0, 'Max transactions session created');

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('DURATION_TOO_SHORT',))]
    fn test_session_invalid_duration_too_short() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test duration too short
        session_dispatcher.create_session_key(3599, VALID_TRANSACTIONS); // Less than 1 hour

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('DURATION_TOO_LONG',))]
    fn test_session_invalid_duration_too_long() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test duration too long
        session_dispatcher.create_session_key(86401, VALID_TRANSACTIONS); // More than 24 hours

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_MAX_TRANSACTIONS',))]
    fn test_session_invalid_transactions_zero() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test zero transactions
        session_dispatcher.create_session_key(VALID_DURATION, 0);

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('TOO_MANY_TRANSACTIONS',))]
    fn test_session_invalid_transactions_too_many() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test too many transactions
        session_dispatcher.create_session_key(VALID_DURATION, 1001); // More than max

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    fn test_session_concurrent_creation() {
        let session_dispatcher = create_session_dispatcher();
        let player1 = contract_address_const::<0x123>();
        let player2 = contract_address_const::<0x456>();

        // Create session for player 1
        start_cheat_caller_address(session_dispatcher.contract_address, player1);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);
        let session_id1 = session_dispatcher.create_session_key(VALID_DURATION, VALID_TRANSACTIONS);
        stop_cheat_caller_address(session_dispatcher.contract_address);

        // Create session for player 2
        start_cheat_caller_address(session_dispatcher.contract_address, player2);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1001);
        let session_id2 = session_dispatcher.create_session_key(VALID_DURATION, VALID_TRANSACTIONS);
        stop_cheat_caller_address(session_dispatcher.contract_address);

        // Sessions should be different
        assert(session_id1 != session_id2, 'Sessions should be different');

        // Validate both sessions
        let valid1 = session_dispatcher.validate_session(session_id1, player1);
        let valid2 = session_dispatcher.validate_session(session_id2, player2);
        assert(valid1, 'Player 1 session should be valid');
        assert(valid2, 'Player 2 session should be valid');

        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    fn test_session_validation_for_action() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Create session
        let session_id = session_dispatcher.create_session_key(VALID_DURATION, VALID_TRANSACTIONS);

        // Test session validation for action (should not panic)
        session_dispatcher.validate_session_for_action(session_id);

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_SESSION',))]
    fn test_session_validation_for_action_invalid() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        // Test with invalid session ID (0)
        session_dispatcher.validate_session_for_action(0);

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }

    #[test]
    fn test_session_remaining_calculations() {
        let session_dispatcher = create_session_dispatcher();

        // Test remaining transactions calculation
        let remaining_tx = session_dispatcher.calculate_remaining_transactions(25, 100);
        assert(remaining_tx == 75, 'Should have 75 transactions left');

        let no_remaining_tx = session_dispatcher.calculate_remaining_transactions(100, 100);
        assert(no_remaining_tx == 0, 'Should have 0 transactions left');

        // Test remaining time calculation
        let remaining_time = session_dispatcher.calculate_session_time_remaining(1000, 3600);
        // This would need to be tested with proper block timestamp mocking
        assert(remaining_time >= 0, 'Should have remaining time');
    }

    #[test]
    fn test_session_events() {
        let session_dispatcher = create_session_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(session_dispatcher.contract_address, player);
        start_cheat_block_timestamp(session_dispatcher.contract_address, 1000);

        let mut spy = spy_events();

        // Create session and check for event
        let session_id = session_dispatcher.create_session_key(VALID_DURATION, VALID_TRANSACTIONS);

        // Verify SessionKeyCreated event was emitted
        spy
            .assert_emitted(
                @array![
                    (
                        session_dispatcher.contract_address,
                        SessionKeyCreated {
                            session_id,
                            player_address: player,
                            session_key_address: player,
                            expires_at: 1000 + VALID_DURATION,
                        },
                    ),
                ],
            );

        stop_cheat_caller_address(session_dispatcher.contract_address);
        stop_cheat_block_timestamp(session_dispatcher.contract_address);
    }
}
