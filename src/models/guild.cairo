use starknet::ContractAddress;
use core::num::traits::zero::Zero;
use crate::helpers::base::ContractAddressDefault;

// --- ENUMS ---

#[derive(Drop, Copy, Serde, Debug, Default, PartialEq, Introspect)]
pub enum GuildRole {
    #[default]
    Member,
    Officer,
    Leader,
}

// --- MODELS ---

#[dojo::model]
#[derive(Drop, Copy, Serde, Debug, Default, PartialEq)]
pub struct Guild {
    #[key]
    pub id: u256,
    pub name: felt252,
    pub leader: ContractAddress,
    pub level: u32,
    pub experience: u256,
    pub member_count: u32,
    pub max_members: u32,
    pub created_at: u64,
    pub description: felt252,
}

#[dojo::model]
#[derive(Drop, Copy, Serde, Debug, PartialEq, Default)]
pub struct GuildMember {
    #[key]
    pub guild_id: u256,
    #[key]
    pub player_id: ContractAddress,
    pub role: GuildRole,
    pub joined_at: u64,
    pub contribution: u256,
}

#[dojo::model]
#[derive(Drop, Copy, Serde, Debug, PartialEq, Default)]
pub struct PlayerGuildMembership {
    #[key]
    pub player_id: ContractAddress,
    pub guild_id: u256,
}

#[dojo::model]
#[derive(Drop, Copy, Serde, Debug, PartialEq, Default)]
pub struct GuildInvite {
    #[key]
    pub guild_id: u256,
    #[key]
    pub player_id: ContractAddress,
    pub invited_by: ContractAddress,
    pub created_at: u64,
    pub expires_at: u64,
    pub is_accepted: bool,
}

// --- EVENTS ---

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GuildCreated {
    #[key]
    pub guild_id: u256,
    pub leader: ContractAddress,
    pub name: felt252,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GuildJoined {
    #[key]
    pub guild_id: u256,
    pub player_id: ContractAddress,
    pub role: GuildRole,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GuildLeft {
    #[key]
    pub guild_id: u256,
    pub player_id: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GuildInviteSent {
    #[key]
    pub guild_id: u256,
    pub player_id: ContractAddress,
    pub invited_by: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GuildInviteAccepted {
    #[key]
    pub guild_id: u256,
    pub player_id: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct GuildLevelUp {
    #[key]
    pub guild_id: u256,
    pub new_level: u32,
}

// --- HELPERS & ERRORS ---

pub mod Errors {
    pub const GUILD_NOT_FOUND: felt252 = 'Guild not found';
    pub const PLAYER_ALREADY_IN_GUILD: felt252 = 'Player already in guild';
    pub const PLAYER_NOT_IN_GUILD: felt252 = 'Player not in guild';
    pub const NOT_GUILD_LEADER: felt252 = 'Not the guild leader';
    pub const NOT_GUILD_OFFICER: felt252 = 'Not a guild officer';
    pub const GUILD_FULL: felt252 = 'Guild is full';
    pub const INVALID_GUILD_NAME: felt252 = 'Invalid guild name';
    pub const INSUFFICIENT_PERMISSIONS: felt252 = 'Insufficient permissions';
    pub const INVITE_NOT_FOUND: felt252 = 'Invite not found';
    pub const INVITE_EXPIRED: felt252 = 'Invite expired';
    pub const ALREADY_INVITED: felt252 = 'Player already invited';
}
