#[dojo::contract]
pub mod GearActions {
    use crate::interfaces::gear::IGear;
    use dojo::event::EventStorage;
    use crate::models::gear::GearTrait;
    use crate::helpers::session_validation::{validate_session_for_action_centralized};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use crate::models::player::{Player, PlayerTrait};
    use dojo::world::WorldStorage;
    use dojo::model::ModelStorage;

    use crate::models::gear::{Gear, GearProperties, GearType};
    use crate::models::core::{Operator, Contract};

    use crate::helpers::base::generate_id;
    use crate::helpers::base::ContractAddressDefault;

    // Import session model for validation
    use crate::models::session::SessionKey;

    // Import ERC1155 interface for burning items
    use crate::erc1155::erc1155::{IERC1155MintableDispatcher, IERC1155MintableDispatcherTrait};

    const GEAR: felt252 = 'GEAR';

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct ItemPicked {
        #[key]
        pub player_id: ContractAddress,
        #[key]
        pub item_id: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct ItemUsed {
        #[key]
        pub player_id: ContractAddress,
        #[key]
        pub item_id: u256,
        pub target_id: Option<u256>,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct ItemWielded {
        #[key]
        pub player_id: ContractAddress,
        #[key]
        pub item_id: u256,
        pub wielded: bool,
    }

    #[abi(embed_v0)]
    pub impl GearActionsImpl of IGear<ContractState> {
        fn equip(ref self: ContractState, item_id: Array<u256>, session_id: felt252) {
            // Basic implementation
        }

        fn exchange(ref self: ContractState, in_item_id: u256, out_item_id: u256, session_id: felt252) {
            // Basic implementation
        }

        fn equip_on(ref self: ContractState, item_id: u256, target: u256, session_id: felt252) {
            // Basic implementation
        }

        fn refresh(ref self: ContractState, session_id: felt252) {
            // Basic implementation
        }

        fn get_item_details(ref self: ContractState, item_id: u256, session_id: felt252) -> Gear {
            let world = self.world_default();
            world.read_model(item_id)
        }

        fn total_held_of(ref self: ContractState, gear_type: GearType, session_id: felt252) -> u256 {
            0
        }

        fn raid(ref self: ContractState, target: u256, session_id: felt252) {
            // Basic implementation
        }

        fn unequip(ref self: ContractState, item_id: Array<u256>, session_id: felt252) {
            // Basic implementation
        }

        fn get_configuration(ref self: ContractState, item_id: u256, session_id: felt252) -> Option<GearProperties> {
            Option::None
        }

        fn configure(ref self: ContractState, session_id: felt252) {
            // Basic implementation
        }

        fn auction(ref self: ContractState, item_ids: Array<u256>, session_id: felt252) {
            // Basic implementation
        }

        fn dismantle(ref self: ContractState, item_ids: Array<u256>, session_id: felt252) {
            // Basic implementation
        }

        fn transfer(ref self: ContractState, item_ids: Array<u256>, session_id: felt252) {
            // Basic implementation
        }

        fn grant(ref self: ContractState, asset: GearType) {
            // Basic implementation
        }

        fn forge(ref self: ContractState, item_ids: Array<u256>, session_id: felt252) -> u256 {
            0
        }

        fn awaken(ref self: ContractState, exchange: Array<u256>, session_id: felt252) {
            // Basic implementation
        }

        fn can_be_awakened(ref self: ContractState, item_ids: Array<u256>, session_id: felt252) -> Span<bool> {
            array![].span()
        }

        fn pick_items(ref self: ContractState, item_id: Array<u256>, session_id: felt252) -> Array<u256> {
            array![]
        }

        fn use_item(ref self: ContractState, item_id: u256, target_id: Option<u256>, session_id: felt252) {
            self.validate_session_for_action(session_id);
            let mut world = self.world_default();
            let caller = get_caller_address();
            
            // Read the gear item
            let gear: Gear = world.read_model(item_id);
            
            // Validate ownership
            assert(gear.owner == caller, 'Not item owner');
            
            // Check if item is consumable
            assert(gear.is_consumable(), 'Item not consumable');
            
            // Read player
            let mut player: Player = world.read_model(caller);
            
            // Apply item effects based on type
            let type_id = gear.asset_id.high;
            if type_id == 0x90000_u128 { // Health Potion
                player.hp = if player.hp + 50 > player.max_hp { player.max_hp } else { player.hp + 50 };
            } else if type_id == 0x90001_u128 { // XP Booster
                player.xp += 100;
            } else if type_id == 0x90002_u128 { // Energy Drink
                player.max_hp += 50;
                player.hp += 50;
            }
            
            // Update player
            world.write_model(@player);
            
            // Burn the item - reduce total_count or remove completely
            let contract: Contract = world.read_model('CONTRACT');
            let erc1155_address = contract.erc1155;
            let erc1155_contract = IERC1155MintableDispatcher { contract_address: erc1155_address };
            erc1155_contract.burn(caller, item_id, 1);
            
            // Update player and gear state
            let mut updated_gear = gear;
            updated_gear.total_count -= 1;
            
            if updated_gear.total_count == 0 {
                // Item completely used up, no longer exists
                // Note: Inventory management will be handled separately
                world.write_model(@player);
            } else {
                world.write_model(@updated_gear);
            }
            
            // Emit event
            world.emit_event(@ItemUsed { player_id: caller, item_id, target_id });
        }

        fn wield_item(ref self: ContractState, item_id: u256, session_id: felt252) {
            self.validate_session_for_action(session_id);
            let mut world = self.world_default();
            let caller = get_caller_address();
            
            // Read the gear item
            let gear: Gear = world.read_model(item_id);
            
            // Validate ownership
            assert(gear.owner == caller, 'Not item owner');
            
            // Check if item can be wielded
            assert(gear.is_wieldable(), 'Item not wieldable');
            
            // Read player
            let mut player: Player = world.read_model(caller);
            
            // Check if player has available equipment slot
            assert(player.has_free_inventory_slot(), 'No free inventory slot');
            
            // Note: Equipment logic will be handled through gear management
            
            // Update gear state
            let mut updated_gear = gear;
            updated_gear.in_action = true;
            
            // Write updates
            world.write_model(@player);
            world.write_model(@updated_gear);
            
            // Emit ItemWielded event
            world.emit_event(@ItemWielded { player_id: caller, item_id: item_id, wielded: true });
        }
    }

    #[generate_trait]
    impl GearActionsHelperImpl of GearActionsHelperTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"coa")
        }
        
        fn validate_session_for_action(ref self: ContractState, session_id: felt252) {
            assert(session_id != 0, 'INVALID_SESSION');
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let mut world = self.world_default();
            let mut session: SessionKey = world.read_model((session_id, caller));
            
            let (is_valid, updated_session) = validate_session_for_action_centralized(session, caller, current_time);
            assert(is_valid, 'SESSION_VALIDATION_FAILED');
            
            // Update session with incremented transaction count
            let mut final_session = updated_session;
            final_session.used_transactions += 1;
            final_session.last_used = current_time;
            world.write_model(@final_session);
        }
        
        fn _assert_admin(self: @ContractState) {
            let world = self.world_default();
            let caller = get_caller_address();
            let operator: Operator = world.read_model(caller);
            assert(operator.is_operator == true, 'Not authorized');
        }
    }
}
