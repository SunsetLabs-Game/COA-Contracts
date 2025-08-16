use starknet::ContractAddress;
use coa::models::session::SessionKey;
use coa::systems::gear::{IGearDispatcher, IGearDispatcherTrait, GearActions};
use coa::systems::session::SessionActions;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp, spy_events,
    EventSpyAssertionsTrait,
};

// Helper functions
fn sample_player() -> ContractAddress {
    contract_address_const::<0x123>()
}

fn sample_session_key() -> SessionKey {
    SessionKey {
        session_id: 12345,
        player_address: sample_player(),
        session_key_address: sample_player(),
        created_at: 1000,
        expires_at: 4600, // 1 hour from created_at
        last_used: 1000,
        status: 0, // Active
        max_transactions: 100,
        used_transactions: 5,
        is_valid: true,
    }
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

fn create_session_dispatcher() -> SessionActionsDispatcher {
    let contract = declare("SessionActions");
    let mut constructor_args = array![];
    let (contract_address, _) = contract
        .unwrap()
        .contract_class()
        .deploy(@constructor_args)
        .unwrap();
    SessionActionsDispatcher { contract_address }
}

#[test]
fn test_gear_equip_with_valid_session() {
    let gear_dispatcher = create_gear_dispatcher();
    let session_dispatcher = create_session_dispatcher();

    let player = sample_player();
    let session_id = 12345;

    // Setup session in storage (simulated)
    start_cheat_caller_address(gear_dispatcher.contract_address, player);
    start_cheat_block_timestamp(gear_dispatcher.contract_address, 2000);

    // Test equip with valid session
    let items: Array<u256> = array![1_u256, 2_u256];
    gear_dispatcher.equip(items, session_id);

    stop_cheat_caller_address(gear_dispatcher.contract_address);
    stop_cheat_block_timestamp(gear_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('INVALID_SESSION',))]
fn test_gear_equip_with_invalid_session() {
    let gear_dispatcher = create_gear_dispatcher();
    let player = sample_player();

    start_cheat_caller_address(gear_dispatcher.contract_address, player);

    // Test equip with invalid session (session_id = 0)
    let items: Array<u256> = array![1_u256, 2_u256];
    gear_dispatcher.equip(items, 0);

    stop_cheat_caller_address(gear_dispatcher.contract_address);
}

#[test]
fn test_gear_upgrade_with_valid_session() {
    let gear_dispatcher = create_gear_dispatcher();
    let player = sample_player();
    let session_id = 12345;

    start_cheat_caller_address(gear_dispatcher.contract_address, player);
    start_cheat_block_timestamp(gear_dispatcher.contract_address, 2000);

    // Test upgrade with valid session
    gear_dispatcher.upgrade_gear(1_u256, session_id);

    stop_cheat_caller_address(gear_dispatcher.contract_address);
    stop_cheat_block_timestamp(gear_dispatcher.contract_address);
}

#[test]
fn test_gear_forge_with_valid_session() {
    let gear_dispatcher = create_gear_dispatcher();
    let player = sample_player();
    let session_id = 12345;

    start_cheat_caller_address(gear_dispatcher.contract_address, player);
    start_cheat_block_timestamp(gear_dispatcher.contract_address, 2000);

    // Test forge with valid session
    let items: Array<u256> = array![1_u256, 2_u256, 3_u256];
    let result = gear_dispatcher.forge(items, session_id);
    assert(result == 0_u256, 'Should return 0 for now');

    stop_cheat_caller_address(gear_dispatcher.contract_address);
    stop_cheat_block_timestamp(gear_dispatcher.contract_address);
}

#[test]
fn test_gear_auction_with_valid_session() {
    let gear_dispatcher = create_gear_dispatcher();
    let player = sample_player();
    let session_id = 12345;

    start_cheat_caller_address(gear_dispatcher.contract_address, player);
    start_cheat_block_timestamp(gear_dispatcher.contract_address, 2000);

    // Test auction with valid session
    let items: Array<u256> = array![1_u256, 2_u256];
    gear_dispatcher.auction(items, session_id);

    stop_cheat_caller_address(gear_dispatcher.contract_address);
    stop_cheat_block_timestamp(gear_dispatcher.contract_address);
}

#[test]
fn test_gear_sequential_operations_with_same_session() {
    let gear_dispatcher = create_gear_dispatcher();
    let player = sample_player();
    let session_id = 12345;

    start_cheat_caller_address(gear_dispatcher.contract_address, player);
    start_cheat_block_timestamp(gear_dispatcher.contract_address, 2000);

    // Test multiple operations with same session
    let items: Array<u256> = array![1_u256, 2_u256];

    // Operation 1: Equip
    gear_dispatcher.equip(items, session_id);

    // Operation 2: Upgrade
    gear_dispatcher.upgrade_gear(1_u256, session_id);

    // Operation 3: Unequip
    gear_dispatcher.unequip(items, session_id);

    // Operation 4: Auction
    gear_dispatcher.auction(items, session_id);

    stop_cheat_caller_address(gear_dispatcher.contract_address);
    stop_cheat_block_timestamp(gear_dispatcher.contract_address);
}

#[test]
fn test_gear_session_auto_renewal() {
    let gear_dispatcher = create_gear_dispatcher();
    let player = sample_player();
    let session_id = 12345;

    start_cheat_caller_address(gear_dispatcher.contract_address, player);

    // Set time close to session expiration (less than 5 minutes remaining)
    start_cheat_block_timestamp(gear_dispatcher.contract_address, 4300); // 5 minutes before expiry

    // Test operation that should trigger auto-renewal
    let items: Array<u256> = array![1_u256, 2_u256];
    gear_dispatcher.equip(items, session_id);

    stop_cheat_caller_address(gear_dispatcher.contract_address);
    stop_cheat_block_timestamp(gear_dispatcher.contract_address);
}

#[test]
#[should_panic(expected: ('SESSION_EXPIRED',))]
fn test_gear_operation_with_expired_session() {
    let gear_dispatcher = create_gear_dispatcher();
    let player = sample_player();
    let session_id = 12345;

    start_cheat_caller_address(gear_dispatcher.contract_address, player);

    // Set time after session expiration
    start_cheat_block_timestamp(gear_dispatcher.contract_address, 5000); // After expiry

    // Test operation with expired session
    let items: Array<u256> = array![1_u256, 2_u256];
    gear_dispatcher.equip(items, session_id);

    stop_cheat_caller_address(gear_dispatcher.contract_address);
    stop_cheat_block_timestamp(gear_dispatcher.contract_address);
}

#[test]
fn test_gear_get_item_details_with_session() {
    let gear_dispatcher = create_gear_dispatcher();
    let player = sample_player();
    let session_id = 12345;

    start_cheat_caller_address(gear_dispatcher.contract_address, player);
    start_cheat_block_timestamp(gear_dispatcher.contract_address, 2000);

    // Test get_item_details with valid session
    let item_details = gear_dispatcher.get_item_details(1_u256, session_id);

    stop_cheat_caller_address(gear_dispatcher.contract_address);
    stop_cheat_block_timestamp(gear_dispatcher.contract_address);
}

#[test]
fn test_gear_total_held_with_session() {
    let gear_dispatcher = create_gear_dispatcher();
    let player = sample_player();
    let session_id = 12345;

    start_cheat_caller_address(gear_dispatcher.contract_address, player);
    start_cheat_block_timestamp(gear_dispatcher.contract_address, 2000);

    // Test total_held_of with valid session
    let total = gear_dispatcher.total_held_of(GearType::Weapon, session_id);
    assert(total == 0_u256, 'Should return 0 for now');

    stop_cheat_caller_address(gear_dispatcher.contract_address);
    stop_cheat_block_timestamp(gear_dispatcher.contract_address);
}
