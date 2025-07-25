/// interface
/// init an admin account, or list of admin accounts, dojo_init
///
/// Spawn tournamemnts and side quests here, if necessary.
#[starknet::interface]
pub trait ICore<TContractState> {
    fn spawn_items(ref self: TContractState, item_types: Array<u256>);
    // move to market only items that have been spawned.
    // if caller is admin, check spawned items and relocate
    // if caller is player,
    fn move_to_market(ref self: TContractState, item_ids: Array<u256>);
    fn add_to_market(ref self: TContractState, item_ids: Array<u256>);
    // can be credits, materials, anything
    fn purchase_item(ref self: TContractState, item_id: u256, quantity: u256);
    fn create_tournament(ref self: TContractState);
    fn join_tournament(ref self: TContractState);
    fn purchase_credits(ref self: TContractState);
}

#[dojo::contract]
pub mod CoreActions {
    use super::super::super::erc1155::erc1155::IERC1155MintableDispatcherTrait;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::model::ModelStorage;
    use crate::models::core::{Contract, Operator, GearCounter};
    use crate::models::gear::{Gear, GearTypeU128, GearSpawned};
    use crate::helpers::gear::parse_id;
    use core::array::ArrayTrait;
    use crate::erc1155::erc1155::IERC1155MintableDispatcher;

    const GEAR: felt252 = 'GEAR';
    const COA_CONTRACTS: felt252 = 'COA_CONTRACTS';
    const GEAR_COUNTER: felt252 = 'GEAR_COUNTER';

    fn dojo_init(ref self: ContractState, admin: ContractAddress, erc1155: ContractAddress) {
        let mut world = self.world(@"coa_contracts");

        // Initialize admin
        let operator = Operator { id: admin, is_operator: true };
        world.write_model(@operator);

        // Initialize contract configuration
        let contract = Contract { id: COA_CONTRACTS, admin, erc1155 };
        world.write_model(@contract);
    }

    #[abi(embed_v0)]
    pub impl CoreActionsImpl of super::ICore<ContractState> {
        fn spawn_items(ref self: ContractState, item_types: Array<u256>) {
            let caller = get_caller_address();
            let mut world = self.world(@"coa_contracts");
            let contract: Contract = world.read_model(COA_CONTRACTS);
            assert(caller == contract.admin, 'Only admin can spawn items');

            let erc1155_dispatcher = IERC1155MintableDispatcher {
                contract_address: contract.erc1155,
            };
            let length_of_item_types = item_types.len();
            for item_type in 0..length_of_item_types {
                let item_type = *item_types.at(item_type);
                let mut gear: Gear = world.read_model(item_type);
                assert(!gear.spawned, 'Gear already spawned');
                let item_id = gear.id;
                let mut gear_counter: GearCounter = world.read_model(GEAR_COUNTER);
                let counter = gear_counter.counter;
                gear_counter.counter = counter + 1;
                world.write_model(@gear_counter);

                let mint_id = u256 { high: item_id.high, low: counter + 1 };
                erc1155_dispatcher.mint(contract.warehouse, mint_id, 1, array![].span());
                gear.item_type = item_id.high.into();
                gear.spawned = true;
                world.write_model(@gear);
            };
            let event = GearSpawned { admin: caller, item_types: item_types };
            world.emit_event(event);
        }
        // move to market only items that have been spawned.
        // if caller is admin, check spawned items and relocate
        // if caller is player,
        fn move_to_market(ref self: ContractState, item_ids: Array<u256>) {}
        fn add_to_market(ref self: ContractState, item_ids: Array<u256>) {}
        // can be credits, materials, anything
        fn purchase_item(ref self: ContractState, item_id: u256, quantity: u256) {}
        fn create_tournament(ref self: ContractState) {}
        fn join_tournament(ref self: ContractState) {}
        fn purchase_credits(ref self: ContractState) {}
    }
}
