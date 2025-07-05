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
}

#[dojo::contract]
pub mod PlayerActions {
    use starknet::{ContractAddress, get_caller_address};
    use crate::models::player::{Player, PlayerTrait};
    use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use super::IPlayer;

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
        
        // Refresh player's equipped items based on current NFT ownership
        // This should be called periodically to ensure game state matches blockchain state
        fn refresh(ref self: ContractState) {
            // Get caller address
            let caller = get_caller_address();
            
            // Get the ERC1155 contract address
            // In a real implementation, this would be stored in a config or contract storage
            let erc1155_address = starknet::contract_address_const::<0x1>(); // Placeholder
            
            // Get player data
            let mut player = get!(self.world_default(), caller, Player);
            
            // Create ERC1155 dispatcher
            let erc1155_dispatcher = IERC1155Dispatcher { contract_address: erc1155_address };
            
            // Check and update all equipped items
            // 1. Main equipped items
            let mut updated_equipped = array![];
            let mut i = 0;
            while i < player.equipped.len() {
                let item_id = *player.equipped.at(i);
                let balance = erc1155_dispatcher.balance_of(caller, item_id);
                if balance > 0 {
                    updated_equipped.append(item_id);
                }
                i += 1;
            };
            player.equipped = updated_equipped;
            
            // 2. Left hand items
            let mut updated_left_hand = array![];
            i = 0;
            while i < player.left_hand.len() {
                let item_id = *player.left_hand.at(i);
                let balance = erc1155_dispatcher.balance_of(caller, item_id);
                if balance > 0 {
                    updated_left_hand.append(item_id);
                }
                i += 1;
            };
            player.left_hand = updated_left_hand;
            
            // 3. Right hand items
            let mut updated_right_hand = array![];
            i = 0;
            while i < player.right_hand.len() {
                let item_id = *player.right_hand.at(i);
                let balance = erc1155_dispatcher.balance_of(caller, item_id);
                if balance > 0 {
                    updated_right_hand.append(item_id);
                }
                i += 1;
            };
            player.right_hand = updated_right_hand;
            
            // 4. Left leg items
            let mut updated_left_leg = array![];
            i = 0;
            while i < player.left_leg.len() {
                let item_id = *player.left_leg.at(i);
                let balance = erc1155_dispatcher.balance_of(caller, item_id);
                if balance > 0 {
                    updated_left_leg.append(item_id);
                }
                i += 1;
            };
            player.left_leg = updated_left_leg;
            
            // 5. Right leg items
            let mut updated_right_leg = array![];
            i = 0;
            while i < player.right_leg.len() {
                let item_id = *player.right_leg.at(i);
                let balance = erc1155_dispatcher.balance_of(caller, item_id);
                if balance > 0 {
                    updated_right_leg.append(item_id);
                }
                i += 1;
            };
            player.right_leg = updated_right_leg;
            
            // 6. Upper torso items
            let mut updated_upper_torso = array![];
            i = 0;
            while i < player.upper_torso.len() {
                let item_id = *player.upper_torso.at(i);
                let balance = erc1155_dispatcher.balance_of(caller, item_id);
                if balance > 0 {
                    updated_upper_torso.append(item_id);
                }
                i += 1;
            };
            player.upper_torso = updated_upper_torso;
            
            // 7. Lower torso items
            let mut updated_lower_torso = array![];
            i = 0;
            while i < player.lower_torso.len() {
                let item_id = *player.lower_torso.at(i);
                let balance = erc1155_dispatcher.balance_of(caller, item_id);
                if balance > 0 {
                    updated_lower_torso.append(item_id);
                }
                i += 1;
            };
            player.lower_torso = updated_lower_torso;
            
            // 8. Waist items
            let mut updated_waist = array![];
            i = 0;
            while i < player.waist.len() {
                let item_id = *player.waist.at(i);
                let balance = erc1155_dispatcher.balance_of(caller, item_id);
                if balance > 0 {
                    updated_waist.append(item_id);
                }
                i += 1;
            };
            player.waist = updated_waist;
            
            // 9. Back item (single item)
            if player.back != 0 {
                let balance = erc1155_dispatcher.balance_of(caller, player.back);
                if balance == 0 {
                    player.back = 0; // Reset if player no longer owns the item
                }
            }
            
            // Save updated player data
            set!(self.world_default(), (player));
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {}

}
