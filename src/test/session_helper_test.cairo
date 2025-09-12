#[cfg(test)]
mod tests {
    use super::*;
    use starknet::contract_address_const;
    use starknet::ContractAddress;
    use coa::models::session::SessionKey;
    use coa::helpers::session_validation::{
        calculate_session_time_remaining_with_time, is_session_expired_with_time,
        has_transactions_left, validate_session_parameters_with_time, get_session_status_with_time,
        MIN_SESSION_DURATION, MAX_SESSION_DURATION, AUTO_RENEWAL_THRESHOLD,
    };

    fn sample_player() -> ContractAddress {
        contract_address_const::<0x123>()
    }

    fn create_valid_session() -> SessionKey {
        SessionKey {
            session_id: 123,
            player_address: sample_player(),
            session_key_address: sample_player(),
            created_at: 1000,
            expires_at: 2000,
            last_used: 1000,
            status: 0,
            max_transactions: 100,
            used_transactions: 50,
            is_valid: true,
        }
    }

    fn create_expired_session() -> SessionKey {
        SessionKey {
            session_id: 124,
            player_address: sample_player(),
            session_key_address: sample_player(),
            created_at: 1000,
            expires_at: 1500, // Expired
            last_used: 1000,
            status: 0,
            max_transactions: 100,
            used_transactions: 50,
            is_valid: true,
        }
    }

    fn create_revoked_session() -> SessionKey {
        SessionKey {
            session_id: 125,
            player_address: sample_player(),
            session_key_address: sample_player(),
            created_at: 1000,
            expires_at: 2000,
            last_used: 1000,
            status: 0,
            max_transactions: 100,
            used_transactions: 50,
            is_valid: false // Revoked
        }
    }

    #[test]
    fn test_calculate_session_time_remaining() {
        let session = create_valid_session();
        let current_time = 1400; // Between created_at (1000) and expires_at (2000)
        let time_remaining = calculate_session_time_remaining_with_time(session, current_time);

        // Should have time remaining (expires_at: 2000, current_time: 1400)
        assert(time_remaining == 600, '600 seconds remaining');
    }

    #[test]
    fn test_is_session_expired() {
        let valid_session = create_valid_session();
        let expired_session = create_expired_session();

        // Use custom time for testing
        let current_time = 1400; // Between created_at (1000) and expires_at (2000)
        assert(!is_session_expired_with_time(valid_session, current_time), 'Valid not expired');

        // For expired session, use time after expires_at (1500)
        let expired_time = 1600; // After expires_at (1500)
        assert(is_session_expired_with_time(expired_session, expired_time), 'Expired session');
    }

    #[test]
    fn test_has_transactions_left() {
        let session_with_transactions = create_valid_session(); // 50 used, 100 max
        let session_no_transactions = SessionKey {
            session_id: 126,
            player_address: sample_player(),
            session_key_address: sample_player(),
            created_at: 1000,
            expires_at: 2000,
            last_used: 1000,
            status: 0,
            max_transactions: 100,
            used_transactions: 100, // No transactions left
            is_valid: true,
        };

        assert(has_transactions_left(session_with_transactions), 'Has transactions');
        assert(!has_transactions_left(session_no_transactions), 'No transactions');
    }

    #[test]
    fn test_validate_session_parameters() {
        let valid_session = create_valid_session();
        let expired_session = create_expired_session();
        let revoked_session = create_revoked_session();

        // Use custom time for testing
        let current_time = 1400; // Between created_at (1000) and expires_at (2000)
        assert(
            validate_session_parameters_with_time(valid_session, sample_player(), current_time),
            'Valid pass',
        );

        // For expired session, use time after expires_at (1500)
        let expired_time = 1600; // After expires_at (1500)
        assert(
            !validate_session_parameters_with_time(expired_session, sample_player(), expired_time),
            'Expired fail',
        );
        assert(
            !validate_session_parameters_with_time(revoked_session, sample_player(), current_time),
            'Revoked fail',
        );
    }

    #[test]
    fn test_get_session_status() {
        let valid_session = create_valid_session();
        let expired_session = create_expired_session();
        let revoked_session = create_revoked_session();

        // Use custom time for testing
        let current_time = 1400; // Between created_at (1000) and expires_at (2000)
        assert(get_session_status_with_time(valid_session, current_time) == 0, 'Status 0');

        // For expired session, use time after expires_at (1500)
        let expired_time = 1600; // After expires_at (1500)
        assert(get_session_status_with_time(expired_session, expired_time) == 4, 'Status 4');
        assert(get_session_status_with_time(revoked_session, current_time) == 2, 'Status 2');
    }

    #[test]
    fn test_constants() {
        assert(MIN_SESSION_DURATION == 3600, 'MIN_DURATION');
        assert(MAX_SESSION_DURATION == 86400, 'MAX_DURATION');
        assert(AUTO_RENEWAL_THRESHOLD == 300, 'RENEWAL_THRESHOLD');
    }
}
