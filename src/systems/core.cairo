/// interface
/// init an admin account, or list of admin accounts, dojo_init
///
/// Spawn tournamemnts and side quests here, if necessary.
#[starknet::interface]
pub trait ICore<TContractState> {
    fn spawn_items(ref self: TContractState, items: Array<crate::models::gear::GearDetails>);
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

#[starknet::contract]
mod CoreActions {
    use core::traits::TryInto;
    use starknet::{ContractAddress, get_caller_address, contract_address_const};
    use starknet::storage_access::StorageAccess;
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use dojo::model::{Model, ModelTrait};
    use crate::models::core::{Contract, Operator};
    use crate::models::gear::GearDetails;
    use crate::helpers::gear::GearTypeIntoU128;
    use crate::erc1155::erc1155::{IERC1155MintableDispatcher, IERC1155MintableDispatcherTrait};
    use crate::helpers::base::generate_id;

    #[storage]
    struct Storage {
        world: IWorldDispatcher,
    }

    #[constructor]
    fn constructor(ref self: ContractState, world: ContractAddress) {
        self.world.write(IWorldDispatcher { contract_address: world });
    }

    #[external(v0)]
    fn spawn_items(ref self: ContractState, items: Array<GearDetails>) {
        let world = self.world.read();
        let caller = get_caller_address();
        let contract: Contract = world.try_read_id(COA_CONTRACTS.try_into().unwrap()).unwrap();
        assert(caller == contract.admin, 'Caller is not admin');
        
        let erc1155 = contract.erc1155;
        let mut i = 0;
        while i < items.len() {
            let details = *items.at(i);
            // Generate NFT id: high = GearType as u128, low = incremental
            let high = GearTypeIntoU128::into_u128(details.item_type);
            let low = generate_id(GEAR, ref world).low;
            let id = u256 { low, high };
            // Mint to contract address
            let mintable = IERC1155MintableDispatcher { contract_address: erc1155 };
            let contract_address = starknet::contract_address_try_from_felt252(contract.id).unwrap();
            mintable.mint(contract_address, id, 1, array![].span());
            i += 1;
        }
    }

    const GEAR: felt252 = 'GEAR';
    const COA_CONTRACTS: felt252 = 'COA_CONTRACTS';

    fn dojo_init(ref self: ContractState, admin: ContractAddress, erc1155: ContractAddress) {
        let mut world = self.world(@"coa_contracts");

        // Initialize admin
        let operator = Operator { id: admin, is_operator: true };
        world.write_model(@operator);

        // Initialize contract configuration
        let contract = Contract { id: COA_CONTRACTS, admin, erc1155 };
        world.write_model(@contract);
    }

    #[generate_trait]
    impl WorldDefaultImpl of WorldDefaultTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"coa_contracts")
        }
    }

    #[abi(embed_v0)]
    pub impl CoreActionsImpl of super::ICore<ContractState> {
        fn spawn_items(
            ref self: ContractState, items: Array<GearDetails>,
        ) {
            // assert the caller is the admin
            let mut world = self.world_default();
            let caller = starknet::get_caller_address();
            let contract: crate::models::core::Contract = world.read_model(COA_CONTRACTS);
            assert(caller == contract.admin, 'Caller is not admin');
            let erc1155 = contract.erc1155;
            let mut i = 0;
            while i < items.len() {
                let details = *items.at(i);
                // Generate NFT id: high = GearType as u128, low = incremental
                let high = GearTypeIntoU128::into_u128(details.item_type);
                let low = generate_id(GEAR, ref world).low;
                let id = u256 { low, high };
                // Mint to contract address
                let mintable = IERC1155MintableDispatcher { contract_address: erc1155 };
                let contract_address = starknet::contract_address_try_from_felt252(contract.id).unwrap();
                mintable.mint(contract_address, id, 1, array![].span());
                // Optionally: store gear details in world (not shown here)
                i += 1;
            }
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
