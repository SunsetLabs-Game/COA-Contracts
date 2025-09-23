use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
use dojo::model::ModelStorage;
use dojo::event::EventStorage;
use dojo::world::WorldStorage;
use coa::models::core::Contract;
use coa::models::security::{
    RateLimit, SecurityConfig, AdminRole, PlayerSecurityStatus, SecurityEvent, RateLimitExceeded,
    ContractPaused, ContractUnpaused,
};
use coa::models::session::SessionKey;
use core::num::traits::Zero;
use core::poseidon::poseidon_hash_span;

// Security constants
pub const SUPER_ADMIN: felt252 = 'SUPER_ADMIN';
pub const GAME_ADMIN: felt252 = 'GAME_ADMIN';
pub const MODERATOR: felt252 = 'MODERATOR';

// Operation types as numbers for rate limiting
pub const CREATE_SESSION_OP: u32 = 1;
pub const SPAWN_ITEMS_OP: u32 = 2;
pub const ADMIN_ACTION_OP: u32 = 3;

pub const SECURITY_CONFIG_ID: felt252 = 'SECURITY_CONFIG';
pub const COA_CONTRACTS: felt252 = 'COA_CONTRACTS';

// Basic admin validation function (simplified)
pub fn validate_admin_access(world: WorldStorage, _required_role: felt252) {
    let caller = get_caller_address();

    // Validate caller is not zero address
    assert(!caller.is_zero(), 'ZERO_ADDRESS');

    // Read contract state
    let contract: Contract = world.read_model(COA_CONTRACTS);

    // Validate contract state
    assert(!contract.admin.is_zero(), 'INVALID_CONTRACT_STATE');
    assert(!contract.paused, 'CONTRACT_PAUSED');

    // Basic admin check (simplified for now)
    assert(caller == contract.admin, 'INSUFFICIENT_PERMISSIONS');
}

// Full admin validation function
pub fn validate_admin_access_full(world: WorldStorage, required_role: felt252) {
    let caller = get_caller_address();

    // Validate caller is not zero address
    assert(!caller.is_zero(), 'ZERO_ADDRESS');

    // Read contract state
    let contract: Contract = world.read_model(COA_CONTRACTS);

    // Validate contract state
    assert(!contract.admin.is_zero(), 'INVALID_CONTRACT_STATE');
    assert(!contract.paused, 'CONTRACT_PAUSED');

    // Check if caller is super admin (contract admin)
    if caller == contract.admin {
        return;
    }

    // Check role-based access
    let admin_role: AdminRole = world.read_model(caller);
    assert(admin_role.is_active, 'INSUFFICIENT_PERMISSIONS');

    // Validate role hierarchy using if-else
    if required_role == SUPER_ADMIN {
        assert(caller == contract.admin, 'SUPER_ADMIN_REQUIRED');
    } else if required_role == GAME_ADMIN {
        assert(
            caller == contract.admin
                || admin_role.role_type == GAME_ADMIN
                || admin_role.role_type == SUPER_ADMIN,
            'GAME_ADMIN_REQUIRED',
        );
    } else if required_role == MODERATOR {
        assert(
            caller == contract.admin
                || admin_role.role_type == SUPER_ADMIN
                || admin_role.role_type == GAME_ADMIN
                || admin_role.role_type == MODERATOR,
            'MODERATOR_REQUIRED',
        );
    } else {
        assert(false, 'INVALID_ROLE');
    }
}

pub fn validate_player_access(world: WorldStorage, player_id: ContractAddress) {
    let caller = get_caller_address();

    // Validate caller is not zero address
    assert(!caller.is_zero(), 'ZERO_ADDRESS');

    // Validate player ID matches caller (unless admin)
    let contract: Contract = world.read_model(COA_CONTRACTS);
    if caller != contract.admin {
        assert(caller == player_id, 'UNAUTHORIZED_PLAYER');
    }

    // Check if player is banned
    let security_status: PlayerSecurityStatus = world.read_model(player_id);
    if security_status.is_banned {
        let current_time = get_block_timestamp();
        if security_status.ban_expires_at > current_time {
            assert(false, 'PLAYER_BANNED');
        }
    }
}

pub fn check_rate_limit(
    mut world: WorldStorage, user: ContractAddress, operation_type: u32,
) -> bool {
    let current_time = get_block_timestamp();
    let time_window = current_time / 3600; // 1 hour windows
    let operation_felt: felt252 = operation_type.into();
    let rate_limit_key = (user, operation_felt, time_window);

    let mut rate_limit: RateLimit = world.read_model(rate_limit_key);
    let security_config: SecurityConfig = world.read_model(SECURITY_CONFIG_ID);

    // Use if-else for operation type checking
    let limit = if operation_type == CREATE_SESSION_OP {
        security_config.max_sessions_per_hour
    } else if operation_type == SPAWN_ITEMS_OP {
        security_config.max_spawns_per_hour
    } else if operation_type == ADMIN_ACTION_OP {
        50 // Default admin action limit
    } else {
        100 // Default limit
    };

    if rate_limit.count >= limit {
        // Emit rate limit exceeded event
        let event = RateLimitExceeded {
            user,
            operation: operation_felt,
            current_count: rate_limit.count,
            limit,
            timestamp: current_time,
        };
        world.emit_event(@event);

        // Log security event
        let security_event = SecurityEvent {
            event_type: 'RATE_LIMIT_EXCEEDED',
            user,
            timestamp: current_time,
            details: operation_felt,
        };
        world.emit_event(@security_event);

        return false;
    }

    rate_limit.count += 1;
    world.write_model(@rate_limit);
    true
}

pub fn sanitize_input(input: felt252) -> felt252 {
    // Basic input sanitization - in a real implementation,
    // you might want to check for malicious patterns
    input
}

pub fn validate_faction(faction: felt252) -> bool {
    faction == 'CHAOS_MERCENARIES' || faction == 'SUPREME_LAW' || faction == 'REBEL_TECHNOMANCERS'
}

pub fn validate_session_duration(duration: u64) -> bool {
    duration >= 3600 && duration <= 86400 // 1 hour to 24 hours
}

pub fn generate_secure_session_id(player: ContractAddress) -> felt252 {
    // Use multiple sources of entropy for security
    let tx_hash: felt252 = starknet::get_tx_info().unbox().transaction_hash;
    let block_timestamp: felt252 = get_block_timestamp().into();
    let player_address: felt252 = player.into();

    // Combine entropy sources
    let mut hash_data = array![tx_hash, block_timestamp, player_address];
    poseidon_hash_span(hash_data.span())
}

pub fn validate_contract_not_paused(world: WorldStorage) {
    let contract: Contract = world.read_model(COA_CONTRACTS);
    assert(!contract.paused, 'CONTRACT_PAUSED');
}

pub fn log_security_event(
    mut world: WorldStorage, event_type: felt252, user: ContractAddress, details: felt252,
) {
    let event = SecurityEvent { event_type, user, timestamp: get_block_timestamp(), details };
    world.emit_event(@event);
}

// Emergency functions
pub fn pause_contract(mut world: WorldStorage, reason: felt252) {
    validate_admin_access(world, SUPER_ADMIN);

    let mut contract: Contract = world.read_model(COA_CONTRACTS);
    contract.paused = true;
    world.write_model(@contract);

    let event = ContractPaused {
        paused_by: get_caller_address(), timestamp: get_block_timestamp(), reason,
    };
    world.emit_event(@event);
}

pub fn unpause_contract(mut world: WorldStorage) {
    validate_admin_access(world, SUPER_ADMIN);

    let mut contract: Contract = world.read_model(COA_CONTRACTS);
    contract.paused = false;
    world.write_model(@contract);

    let event = ContractUnpaused {
        unpaused_by: get_caller_address(), timestamp: get_block_timestamp(),
    };
    world.emit_event(@event);
}

// Session security helpers
pub fn create_secure_session(
    mut world: WorldStorage, session_duration: u64, max_transactions: u32,
) -> felt252 {
    let caller = get_caller_address();
    let current_time = get_block_timestamp();

    // Validate inputs
    assert(validate_session_duration(session_duration), 'INVALID_DURATION');
    assert(max_transactions > 0 && max_transactions <= 1000, 'INVALID_TRANSACTIONS');

    // Check rate limiting
    assert(check_rate_limit(world, caller, CREATE_SESSION_OP), 'RATE_LIMIT_EXCEEDED');

    // Generate secure session ID
    let session_id = generate_secure_session_id(caller);

    // Create session with security measures
    let session_key = SessionKey {
        session_id,
        player_address: caller,
        session_key_address: caller,
        created_at: current_time,
        expires_at: current_time + session_duration,
        last_used: current_time,
        status: 0, // Active
        max_transactions,
        used_transactions: 0,
        is_valid: true,
    };

    world.write_model(@session_key);
    session_id
}

// Input validation helpers
pub fn validate_item_id(item_id: u256) -> bool {
    item_id > 0
}

pub fn validate_quantity(quantity: u256) -> bool {
    quantity > 0 && quantity <= 1000000 // Reasonable upper limit
}

pub fn validate_address_not_zero(address: ContractAddress) -> bool {
    !address.is_zero()
}
