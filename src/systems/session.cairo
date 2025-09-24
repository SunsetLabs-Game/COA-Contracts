#[dojo::contract]
pub mod SessionActions {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use coa::models::session::{SessionKey, SessionKeyCreated};
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;

    // Constants for session management
    const DEFAULT_SESSION_DURATION: u64 = 21600; // 6 hours in seconds
    const MAX_SESSION_DURATION: u64 = 86400; // 24 hours in seconds
    const MIN_SESSION_DURATION: u64 = 3600; // 1 hour in seconds
    const MAX_TRANSACTIONS_PER_SESSION: u32 = 1000;
    const MAX_ACTIVE_SESSIONS_PER_PLAYER: u32 = 5; // Maximum active sessions per player

    #[external(v0)]
    fn create_session_key(
        ref self: ContractState, session_duration: u64, max_transactions: u32,
    ) -> felt252 {
        let player = get_caller_address();
        let current_time = get_block_timestamp();
        let mut world = self.world_default();

        // Security validations
        coa::helpers::security::validate_contract_not_paused(world);
        coa::helpers::security::validate_player_access(world, player);

        // Validate session duration
        assert(
            coa::helpers::security::validate_session_duration(session_duration), 'INVALID_DURATION',
        );
        assert(max_transactions > 0, 'INVALID_MAX_TRANSACTIONS');
        assert(max_transactions <= MAX_TRANSACTIONS_PER_SESSION, 'TOO_MANY_TRANSACTIONS');

        // Rate limiting check
        assert(
            coa::helpers::security::check_rate_limit(
                world, player, coa::helpers::security::CREATE_SESSION_OP,
            ),
            'RATE_LIMIT_EXCEEDED',
        );

        // Generate secure session ID
        let session_id = coa::helpers::security::generate_secure_session_id(player);

        // Create session key model
        let session_key = SessionKey {
            session_id,
            player_address: player,
            session_key_address: player, // Using player as session key for now
            created_at: current_time,
            expires_at: current_time + session_duration,
            last_used: current_time,
            status: 0, // Active
            max_transactions,
            used_transactions: 0,
            is_valid: true,
        };

        // Store session in world storage
        let mut world = self.world_default();
        world.write_model(@session_key);

        // Emit creation event
        let event = SessionKeyCreated {
            session_id,
            player_address: player,
            session_key_address: player,
            expires_at: current_time + session_duration,
        };
        world.emit_event(@event);

        session_id
    }

    #[external(v0)]
    fn validate_session(
        self: @ContractState, session_id: felt252, player: ContractAddress,
    ) -> bool {
        // Validate session by reading from storage and checking all properties
        let world = self.world_default();

        // Try to read the session from storage
        let session: SessionKey = world.read_model((session_id, player));

        // Check if session exists (non-zero values indicate it exists)
        if session.session_id == 0 {
            return false;
        }

        // Validate session belongs to the correct player
        if session.player_address != player {
            return false;
        }

        // Check if session is valid
        if !session.is_valid {
            return false;
        }

        // Check session status (0 = Active)
        if session.status != 0 {
            return false;
        }

        // Check if session has expired
        let current_time = get_block_timestamp();
        if current_time >= session.expires_at {
            return false;
        }

        // Check if session has exceeded transaction limit
        if session.used_transactions >= session.max_transactions {
            return false;
        }

        // All validations passed
        true
    }

    #[external(v0)]
    fn check_session_expiry(
        self: @ContractState, session_created_at: u64, session_duration: u64,
    ) -> bool {
        let current_time = get_block_timestamp();
        let expiry_time = session_created_at + session_duration;

        // Return true if session has not expired
        current_time < expiry_time
    }

    #[external(v0)]
    fn check_transaction_limit(
        self: @ContractState, used_transactions: u32, max_transactions: u32,
    ) -> bool {
        // Return true if there are transactions left
        used_transactions < max_transactions
    }

    // Middleware functions for game actions
    #[external(v0)]
    fn validate_session_for_action(ref self: ContractState, session_id: felt252) {
        // Basic validation - session_id must not be zero
        assert(session_id != 0, 'INVALID_SESSION');

        // Get the caller's address
        let caller = get_caller_address();

        // Read session from storage
        let mut world = self.world_default();
        let mut session: SessionKey = world.read_model((session_id, caller));

        // Validate session exists
        assert(session.session_id != 0, 'SESSION_NOT_FOUND');

        // Validate session belongs to the caller
        assert(session.player_address == caller, 'UNAUTHORIZED_SESSION');

        // Validate session is active
        assert(session.is_valid, 'SESSION_INVALID');
        assert(session.status == 0, 'SESSION_NOT_ACTIVE');

        // Validate session has not expired
        let current_time = get_block_timestamp();
        assert(current_time < session.expires_at, 'SESSION_EXPIRED');

        // Validate session has transactions left
        assert(session.used_transactions < session.max_transactions, 'NO_TRANSACTIONS_LEFT');

        // Check if session needs auto-renewal (less than 5 minutes remaining)
        let time_remaining = if current_time >= session.expires_at {
            0
        } else {
            session.expires_at - current_time
        };

        // Auto-renew if less than 5 minutes remaining (300 seconds)
        if time_remaining < 300 {
            // Auto-renew session for 1 hour with 100 transactions
            let mut updated_session = session;
            updated_session.expires_at = current_time + 3600; // 1 hour
            updated_session.last_used = current_time;
            updated_session.max_transactions = 100;
            updated_session.used_transactions = 0; // Reset transaction count

            // Write updated session back to storage
            world.write_model(@updated_session);

            // Update session reference for validation
            session = updated_session;
        }

        // Increment transaction count for this action
        session.used_transactions += 1;
        session.last_used = current_time;

        // Write updated session back to storage
        world.write_model(@session);
    }


    #[external(v0)]
    fn calculate_remaining_transactions(
        self: @ContractState, used_transactions: u32, max_transactions: u32,
    ) -> u32 {
        if used_transactions >= max_transactions {
            return 0;
        }
        max_transactions - used_transactions
    }

    #[external(v0)]
    fn calculate_session_time_remaining(
        self: @ContractState, session_created_at: u64, session_duration: u64,
    ) -> u64 {
        let current_time = get_block_timestamp();
        let expiry_time = session_created_at + session_duration;

        if current_time >= expiry_time {
            return 0;
        }

        expiry_time - current_time
    }

    #[external(v0)]
    fn renew_session(
        ref self: ContractState, session_id: felt252, new_duration: u64, new_max_transactions: u32,
    ) -> bool {
        let player = get_caller_address();
        let current_time = get_block_timestamp();

        // Validate new session parameters
        assert(new_duration >= MIN_SESSION_DURATION, 'DURATION_TOO_SHORT');
        assert(new_duration <= MAX_SESSION_DURATION, 'DURATION_TOO_LONG');
        assert(new_max_transactions > 0, 'INVALID_MAX_TRANSACTIONS');
        assert(new_max_transactions <= MAX_TRANSACTIONS_PER_SESSION, 'TOO_MANY_TRANSACTIONS');

        // Read existing session
        let mut world = self.world_default();
        let mut session: SessionKey = world.read_model((session_id, player));

        // Validate session exists and belongs to caller
        assert(session.session_id != 0, 'SESSION_NOT_FOUND');
        assert(session.player_address == player, 'UNAUTHORIZED_SESSION');

        // Check if session is still valid (not revoked)
        assert(session.is_valid, 'SESSION_INVALID');
        assert(session.status == 0, 'SESSION_NOT_ACTIVE');

        // Renew the session
        session.expires_at = current_time + new_duration;
        session.last_used = current_time;
        session.max_transactions = new_max_transactions;
        session.used_transactions = 0; // Reset transaction count

        // Write updated session back to storage
        world.write_model(@session);

        // Emit renewal event
        let event = SessionKeyCreated {
            session_id,
            player_address: player,
            session_key_address: player,
            expires_at: current_time + new_duration,
        };
        world.emit_event(@event);

        true
    }

    #[external(v0)]
    fn check_session_needs_renewal(
        self: @ContractState, session_id: felt252, min_time_remaining: u64,
    ) -> bool {
        let player = get_caller_address();
        let current_time = get_block_timestamp();

        // Read existing session
        let world = self.world_default();
        let session: SessionKey = world.read_model((session_id, player));

        // Check if session exists and is valid
        if session.session_id == 0 || !session.is_valid || session.status != 0 {
            return false;
        }

        // Calculate time remaining
        let time_remaining = if current_time >= session.expires_at {
            0
        } else {
            session.expires_at - current_time
        };

        // Return true if renewal is needed
        time_remaining < min_time_remaining
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"coa")
        }
    }
}
