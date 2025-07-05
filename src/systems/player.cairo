use crate::models::player::Player;

#[starknet::interface]
pub trait IPlayer<TContractState> {
    fn new(ref self: TContractState, faction: felt252);
    fn deal_damage(
        ref self: TContractState,
        target: Array<u256>,
        target_types: Array<felt252>,
        with_items: Array<u256>,
    );
    fn get_player(self: @TContractState, player_id: u256) -> Player;
    fn register_guild(ref self: TContractState);
    // Refresh player's inventory to sync with ERC1155 token balances
    fn refresh_inventory(ref self: TContractState);
    // Transfer NFT objects from the game
    fn transfer_objects(ref self: TContractState, item_ids: Array<u256>);
}

#[dojo::contract]
pub mod PlayerActions {
    use starknet::ContractAddress;
    use crate::models::player::{Player, PlayerTrait};
    use super::IPlayer;
    use crate::interfaces::gear::{IGearDispatcher, IGearDispatcherTrait};

    // const GEAR_

    fn dojo_init(
        ref self: ContractState, admin: ContractAddress, default_amount_of_credits: u256,
    ) { // write admin
    // write default amount of credits.

    }

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IPlayer<ContractState> {
        fn new(ref self: ContractState, faction: felt252) { // create the player
        // and call mint
        // maybe in the future, you implement a `mint_default()`
        // spawn player at some random location.
        }

        fn deal_damage(
            ref self: ContractState,
            target: Array<u256>,
            target_types: Array<felt252>,
            with_items: Array<u256>,
        ) { // check if the player and the items exists..
        // assert that the items are something that can deal damage
        // from no. 2, not just assert, handle appropriately, but do not panic
        // factor in the faction type and add additional damage
        // factor in the weapon type and xp // rank trait.
        // and factor in the item type, if the item has been upgraded
        // check if the item has been equipped
        // to find out the item's output when upgraded, call the item.output(val), where val is the
        // upgraded level.

        // if with_items.len() is zero, then it's a normal melee attack.

        // factor in the target's damage factor... might later turn out not to be damaged
        // this means that each target or item should have a damage factor, and might cause credits
        // to be repaired

        // for the target, the above is if the target_type is an object.
        // if the target type is a living organism, check all the eqippable traits
        // this means that the PlayerTrait should have a recieve_damage,

        // or recieve damage should probably be an internal trait for now.
        }

        fn get_player(self: @ContractState, player_id: u256) -> Player {
            Default::default()
        }
        fn register_guild(ref self: ContractState) {}
        
        fn refresh_inventory(ref self: ContractState) {
            // Get the gear system contract address and call refresh
            // This will check all equipped items and unequip any that the player no longer owns
            let contract_address = starknet::contract_address_const::<0x2>();
            let gear_contract = IGearDispatcher { contract_address };
            gear_contract.refresh();
        }
        
        fn transfer_objects(ref self: ContractState, item_ids: Array<u256>) {
            // Get the gear system contract address and call transfer
            // This will unequip the items if necessary and prepare them for transfer
            let contract_address = starknet::contract_address_const::<0x2>();
            let gear_contract = IGearDispatcher { contract_address };
            gear_contract.transfer(item_ids);
            
            // Note: The actual transfer of the ERC1155 token would be handled by the ERC1155 contract
            // This function just ensures that equipped items are unequipped before transfer
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {}

}
