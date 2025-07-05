#[dojo::contract]
pub mod GearActions {
    use crate::interfaces::gear::IGear;
    use starknet::{ContractAddress, get_caller_address};
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use crate::models::player::Player;
    use dojo::world::{WorldStorage, IWorldDispatcher, IWorldDispatcherTrait};
    use crate::models::gear::{Gear, GearTrait, GearProperties, GearType};
    use crate::helpers::base::generate_id;

    fn dojo_init(ref self: ContractState, admin: ContractAddress) {}

    #[abi(embed_v0)]
    pub impl GearActionsImpl of IGear<ContractState> {
        fn upgrade_gear(
            ref self: ContractState, item_id: u256,
        ) { // check if the available upgrade materials `id` is present in the caller's address
        // TODO: Security
        // for now, you must check if if the item_id with id is available in the game.
        // This would be done accordingly, so the item struct must have the id of the material
        // or the ids of the list of materials that can upgrade it, and the quantity needed per
        // level and the max level attained.
        }

        fn equip(ref self: ContractState, item_id: Array<u256>) {}

        fn equip_on(ref self: ContractState, item_id: u256, target: u256) {}


        // unequips an item and equips another item at that slot.
        fn exchange(ref self: ContractState, in_item_id: u256, out_item_id: u256) {}

        fn refresh(ref self: ContractState) {
            // Get caller address
            let caller = get_caller_address();
            
            // Get ERC1155 contract address
            let erc1155_address = self._get_erc1155_address();
            
            // Get the world storage
            let world = self.world_default();
            
            // Get player data from world storage
            let mut player = get!(world, caller, Player);
            
            // Update player's equipped items based on current ownership
            // This is a simplified implementation - in a real-world scenario,
            // you would need to check each equipped item to verify ownership
            
            // Check equipped items
            let mut i = 0;
            let mut updated_equipped = array![];
            
            while i < player.equipped.len() {
                let item_id = *player.equipped.at(i);
                let erc1155_dispatcher = IERC1155Dispatcher { contract_address: erc1155_address };
                
                // Check if player still owns this item
                let balance = erc1155_dispatcher.balance_of(caller, item_id);
                
                // If player still owns the item, keep it in the equipped array
                if balance > 0 {
                    updated_equipped.append(item_id);
                }
                
                i += 1;
            };
            
            // Update player's equipped items
            player.equipped = updated_equipped;
            
            // Save updated player data
            set!(world, (player));
        }

        fn get_item_details(ref self: ContractState, item_id: u256) -> Gear {
            // might not return a gear
            Default::default()
        }
        // Some Item Details struct.
        fn total_held_of(ref self: ContractState, gear_type: GearType) -> u256 {
            0
        }
        // use the caller and read the model of both the caller, and the target
        // the target only refers to one target type for now
        // This target type is raidable.
        fn raid(ref self: ContractState, target: u256) {}

        fn unequip(ref self: ContractState, item_id: Array<u256>) {}

        fn get_configuration(ref self: ContractState, item_id: u256) -> Option<GearProperties> {
            Option::None
        }

        // This configure should take in an enum that lists all Gear Types with their structs
        // This function would be blocked at the moment, we shall use the default configuration
        // of the gameplay and how items interact with each other.
        // e.g. guns auto-reload once the time has run out
        // and TODO: Add a delay for auto reload.
        // for a base gun, we default the auto reload to exactly 6 seconds...
        //
        fn configure(ref self: ContractState) { // params to be completed
        }

        fn auction(ref self: ContractState, item_ids: Array<u256>) {}
        fn dismantle(ref self: ContractState, item_ids: Array<u256>) {}
        fn transfer(ref self: ContractState, to: ContractAddress, item_ids: Array<u256>, amounts: Array<u256>) {
            // Validate inputs
            assert(item_ids.len() == amounts.len(), 'Arrays length mismatch');
            assert(item_ids.len() > 0, 'Empty arrays not allowed');
            
            // Get caller address
            let caller = get_caller_address();
            
            // Get ERC1155 contract address
            let erc1155_address = self._get_erc1155_address();
            
            // Convert arrays to spans
            let item_ids_span = item_ids.span();
            let amounts_span = amounts.span();
            
            // Transfer items using safeTransferFrom
            let erc1155_dispatcher = IERC1155Dispatcher { contract_address: erc1155_address };
            
            // Use batch transfer if multiple items
            if item_ids.len() > 1 {
                erc1155_dispatcher.safe_batch_transfer_from(
                    caller, to, item_ids_span, amounts_span, array![].span()
                );
            } else {
                // Single item transfer
                erc1155_dispatcher.safe_transfer_from(
                    caller, to, *item_ids.at(0), *amounts.at(0), array![].span()
                );
            }
        }
        fn grant(ref self: ContractState, asset: GearType) {}

        // These functions might be reserved for players within a specific faction

        // this function forges and creates a new item id based
        fn forge(
            ref self: ContractState, item_ids: Array<u256>,
        ) { // should create a new asset. Perhaps deduct credits from the player.
        // 0
        }

        fn awaken(ref self: ContractState, exchange: Array<u256>) {}

        fn can_be_awakened(self: @ContractState, item_ids: Array<u256>) -> Span<bool> {
            array![].span()
        }
    }

    #[generate_trait]
    pub impl GearInternalImpl of GearInternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"coa")
        }

        fn _assert_admin(self: @ContractState) { // assert the admin here.
        }

        fn _retrieve(
            ref self: ContractState, item_id: u256,
        ) { // this function should probably return an enum
        // or use an external function in the helper trait that returns an enum
        }
        
        // Helper function to get the ERC1155 contract address
        fn _get_erc1155_address(self: @ContractState) -> ContractAddress {
        // In a real implementation, this would be stored in a config or contract storage
        // For now, we'll return a placeholder address
        // This should be replaced with the actual ERC1155 contract address
        starknet::contract_address_const::<0x1>() // Placeholder
        }
        
    }
}
