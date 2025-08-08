use starknet::ContractAddress;

// Simple session key model - basic version to test compilation
#[dojo::model]
#[derive(Drop, Copy, Serde, Debug, PartialEq)]
pub struct SessionKey {
    #[key]
    pub session_id: felt252, // Unique session identifier
    #[key]
    pub player_address: ContractAddress,
    pub session_key_address: ContractAddress, // The session key contract address
    pub created_at: u64,
    pub expires_at: u64,
    pub last_used: u64,
    pub status: u8, // 0=Active, 1=Expired, 2=Revoked (simple integer instead of enum)
    pub max_transactions: u32,
    pub used_transactions: u32,
    pub is_valid: bool,
    // Simple boolean for session validation
}

// Simple events for session management
#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct SessionKeyCreated {
    #[key]
    pub session_id: felt252,
    pub player_address: ContractAddress,
    pub session_key_address: ContractAddress,
    pub expires_at: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct SessionKeyRevoked {
    #[key]
    pub session_id: felt252,
    pub player_address: ContractAddress,
    pub revoked_by: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct SessionKeyUsed {
    #[key]
    pub session_id: felt252,
    pub player_address: ContractAddress,
    pub action_type: felt252,
    pub success: bool,
}

// New events for enhanced tracking and analytics
#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct SessionOperationTracked {
    #[key]
    pub session_id: felt252,
    pub player_address: ContractAddress,
    pub system_name: felt252, // 'PLAYER', 'GEAR', 'TOURNAMENT'
    pub operation_name: felt252, // 'equip', 'upgrade', 'register', etc.
    pub timestamp: u64,
    pub transaction_count: u32,
    pub remaining_transactions: u32,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct SessionAutoRenewed {
    #[key]
    pub session_id: felt252,
    pub player_address: ContractAddress,
    pub old_expires_at: u64,
    pub new_expires_at: u64,
    pub old_transaction_count: u32,
    pub new_transaction_count: u32,

    pub renewal_reason: felt252,
    // 'TIME_THRESHOLD', 'TRANSACTION_LIMIT'

}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct SessionAnalytics {
    #[key]
    pub session_id: felt252,
    pub player_address: ContractAddress,
    pub total_operations: u32,
    pub player_operations: u32,
    pub gear_operations: u32,
    pub tournament_operations: u32,
    pub session_duration: u64,
    pub average_operation_interval: u64,
    pub most_used_system: felt252,
    pub most_used_operation: felt252,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct SessionPerformanceMetrics {
    #[key]
    pub session_id: felt252,
    pub player_address: ContractAddress,
    pub operations_per_minute: u32,
    pub peak_activity_time: u64,
    pub idle_periods: u32,
    pub session_efficiency_score: u32, // 0-100
    pub auto_renewal_count: u32,

    pub total_session_value: u256,
    // Estimated value of operations

}
