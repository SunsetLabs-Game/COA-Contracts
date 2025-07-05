#[dojo::contract]
pub mod GearActions {
    use crate::interfaces::gear::IGear;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use crate::models::gear::{Gear, GearTrait, GearProperties, GearType};
    use crate::helpers::base::generate_id;
    use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use crate::models::player::Player;

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

        fn refresh(
            ref self: ContractState,
        ) {
            // Get the caller address (player)
            let caller = get_caller_address();
            let world = self.world_default();
            
            // Get the player model
            let mut player = get!(world, caller, Player);
            
            // This should be stored in a config or passed as a parameter
            // For now, we'll use a helper function to get the ERC1155 dispatcher
            
            // Get all equipped items to check
            let mut items_to_check = array![];
            
            // Add all equipped items to the check list
            let mut i = 0;
            let equipped_len = player.equipped.len();
            while i < equipped_len {
                items_to_check.append(*player.equipped.at(i));
                i += 1;
            }
            
            // Add items from other equipment slots
            self._add_items_to_check(ref items_to_check, player.right_hand);
            self._add_items_to_check(ref items_to_check, player.left_hand);
            self._add_items_to_check(ref items_to_check, player.right_leg);
            self._add_items_to_check(ref items_to_check, player.left_leg);
            self._add_items_to_check(ref items_to_check, player.upper_torso);
            self._add_items_to_check(ref items_to_check, player.lower_torso);
            self._add_items_to_check(ref items_to_check, player.waist);
            
            // Check back item if it's not zero
            if player.back != 0 {
                items_to_check.append(player.back);
            }
            
            // Check each item to see if the player still owns it
            let erc1155 = self._get_erc1155_dispatcher();
            
            // Process each item
            let mut i = 0;
            let items_len = items_to_check.len();
            while i < items_len {
                let item_id = *items_to_check.at(i);
                let balance = erc1155.balance_of(caller, item_id);
                
                // If balance is 0, the item has been transferred away
                if balance == 0 {
                    // Unequip the item
                    self._unequip_item(ref world, ref player, item_id);
                }
                
                i += 1;
            }
            
            // Save the updated player model
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
        fn transfer(ref self: ContractState, item_ids: Array<u256>) {
            // Get the caller address (player) and recipient (to be specified by the caller)
            let caller = get_caller_address();
            let world = self.world_default();
            
            // Get the player model
            let mut player = get!(world, caller, Player);
            
            // For each item, check if it's equipped and unequip it if necessary
            let mut i = 0;
            let items_len = item_ids.len();
            while i < items_len {
                let item_id = *item_ids.at(i);
                
                // Check if the item is equipped
                let is_equipped = self._is_item_equipped(ref player, item_id);
                
                // If equipped, unequip it first
                if is_equipped {
                    self._unequip_item(ref world, ref player, item_id);
                }
                
                i += 1;
            }
            
            // Save the updated player model if any changes were made
            set!(world, (player));
            
            // Note: The actual transfer of the ERC1155 token should be done through a separate call
            // to the ERC1155 contract's safe_transfer_from or safe_batch_transfer_from methods
            // This function just ensures that equipped items are unequipped before transfer
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
        
        // Helper function to create an ERC1155 dispatcher
        fn _get_erc1155_dispatcher(self: @ContractState) -> IERC1155Dispatcher {
            let erc1155_address = self._get_erc1155_address();
            IERC1155Dispatcher { contract_address: erc1155_address }
        }
        
        // Helper function to add items from an array to the check list
        fn _add_items_to_check(self: @ContractState, ref items_to_check: Array<u256>, items: Array<u256>) {
            let mut i = 0;
            let items_len = items.len();
            while i < items_len {
                items_to_check.append(*items.at(i));
                i += 1;
            }
        }
        
        // Helper function to check if an item is equipped
        fn _is_item_equipped(self: @ContractState, ref player: Player, item_id: u256) -> bool {
            // Check in all equipment slots
            
            // Check equipped array
            let mut i = 0;
            let equipped_len = player.equipped.len();
            while i < equipped_len {
                if *player.equipped.at(i) == item_id {
                    return true;
                }
                i += 1;
            }
            
            // Check other equipment slots
            if self._check_array_for_item(player.right_hand, item_id) {
                return true;
            }
            if self._check_array_for_item(player.left_hand, item_id) {
                return true;
            }
            if self._check_array_for_item(player.right_leg, item_id) {
                return true;
            }
            if self._check_array_for_item(player.left_leg, item_id) {
                return true;
            }
            if self._check_array_for_item(player.upper_torso, item_id) {
                return true;
            }
            if self._check_array_for_item(player.lower_torso, item_id) {
                return true;
            }
            if self._check_array_for_item(player.waist, item_id) {
                return true;
            }
            
            // Check back item
            if player.back == item_id {
                return true;
            }
            
            false
        }
        
        // Helper function to check if an item is in an array
        fn _check_array_for_item(self: @ContractState, items: Array<u256>, item_id: u256) -> bool {
            let mut i = 0;
            let items_len = items.len();
            while i < items_len {
                if *items.at(i) == item_id {
                    return true;
                }
                i += 1;
            }
            false
        }
        
        // Helper function to unequip an item
        fn _unequip_item(self: @ContractState, ref world: WorldStorage, ref player: Player, item_id: u256) {
            // Check and remove from equipped array
            let mut new_equipped = array![];
            let mut i = 0;
            let equipped_len = player.equipped.len();
            while i < equipped_len {
                let current_item = *player.equipped.at(i);
                if current_item != item_id {
                    new_equipped.append(current_item);
                }
                i += 1;
            }
            player.equipped = new_equipped;
            
            // Check and remove from other equipment slots
            player.right_hand = self._filter_item_from_array(player.right_hand, item_id);
            player.left_hand = self._filter_item_from_array(player.left_hand, item_id);
            player.right_leg = self._filter_item_from_array(player.right_leg, item_id);
            player.left_leg = self._filter_item_from_array(player.left_leg, item_id);
            player.upper_torso = self._filter_item_from_array(player.upper_torso, item_id);
            player.lower_torso = self._filter_item_from_array(player.lower_torso, item_id);
            player.waist = self._filter_item_from_array(player.waist, item_id);
            
            // Check back item
            if player.back == item_id {
                player.back = 0;
            }
        }
        
        // Helper function to filter an item from an array
        fn _filter_item_from_array(self: @ContractState, items: Array<u256>, item_id: u256) -> Array<u256> {
            let mut new_items = array![];
            let mut i = 0;
            let items_len = items.len();
            while i < items_len {
                let current_item = *items.at(i);
                if current_item != item_id {
                    new_items.append(current_item);
                }
                i += 1;
            }
            new_items
        }
    }
}
