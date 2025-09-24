use starknet::ContractAddress;
use core::num::traits::Zero;

// Security models for access control and rate limiting
#[dojo::model]
#[derive(Drop, Copy, Serde, Default)]
pub struct RateLimit {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub operation: felt252,
    #[key]
    pub time_window: u64, // Hour-based window
    pub count: u32,
}

#[dojo::model]
#[derive(Drop, Copy, Serde, Default)]
pub struct SecurityConfig {
    #[key]
    pub id: felt252,
    pub max_sessions_per_hour: u32,
    pub max_spawns_per_hour: u32,
    pub max_transactions_per_session: u32,
    pub session_renewal_threshold: u64, // seconds
    pub emergency_pause_enabled: bool,
}

#[dojo::model]
#[derive(Drop, Copy, Serde, Default)]
pub struct AdminRole {
    #[key]
    pub admin: ContractAddress,
    pub role_type: felt252, // 'SUPER_ADMIN', 'GAME_ADMIN', 'MODERATOR'
    pub granted_by: ContractAddress,
    pub granted_at: u64,
    pub is_active: bool,
}

#[dojo::model]
#[derive(Drop, Copy, Serde, Default)]
pub struct PlayerSecurityStatus {
    #[key]
    pub player: ContractAddress,
    pub is_banned: bool,
    pub ban_reason: felt252,
    pub ban_expires_at: u64,
    pub warning_count: u32,
    pub last_violation: u64,
}

// Security Events
#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct SecurityEvent {
    #[key]
    pub event_type: felt252, // 'UNAUTHORIZED_ACCESS', 'RATE_LIMIT_EXCEEDED', etc.
    #[key]
    pub user: ContractAddress,
    pub timestamp: u64,
    pub details: felt252,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct ContractPaused {
    #[key]
    pub paused_by: ContractAddress,
    pub timestamp: u64,
    pub reason: felt252,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct ContractUnpaused {
    #[key]
    pub unpaused_by: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct EmergencyWithdraw {
    #[key]
    pub token: ContractAddress,
    #[key]
    pub withdrawn_by: ContractAddress,
    pub amount: u256,
    pub timestamp: u64,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct RateLimitExceeded {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub operation: felt252,
    pub current_count: u32,
    pub limit: u32,
    pub timestamp: u64,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct AdminRoleGranted {
    #[key]
    pub admin: ContractAddress,
    #[key]
    pub granted_by: ContractAddress,
    pub role_type: felt252,
    pub timestamp: u64,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct AdminRoleRevoked {
    #[key]
    pub admin: ContractAddress,
    #[key]
    pub revoked_by: ContractAddress,
    pub role_type: felt252,
    pub timestamp: u64,
}

pub impl ContractAddressDefault of Default<ContractAddress> {
    #[inline(always)]
    fn default() -> ContractAddress {
        Zero::zero()
    }
}
