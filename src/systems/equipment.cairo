use starknet::{ContractAddress};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use core::option::OptionTrait;

use dojo_starter::models::equipped_item::{EquippedItem, EquippedItemImpl, Slot};
use dojo_starter::models::inventory::{Inventory, InventoryImpl};
use dojo_starter::models::item::{Item, ItemImpl};
use dojo_starter::{
    components::{
        world::World
    }
};
use dojo::model::{ModelStorage, ModelValueStorage};

#[derive(Drop, starknet::Event)]
struct ItemEquipped {
    player_id: u32,
    slot: Slot,
    token_id: u256
}

#[derive(Drop, starknet::Event)]
struct ItemUnequipped {
    player_id: u32,
    slot: Slot
}

// Error constants
const ERROR_ITEM_NOT_FOUND: felt252 = 'Item not found in inventory';
const ERROR_NOT_AUTHORIZED: felt252 = 'Not authorized to equip/unequip';

#[generate_trait]
impl EquipmentWorldImpl of EquipmentWorldTrait {
    fn equip_item(
        ref self: World, player_id: u32, slot: Slot, token_id: u256
    ) {
        // Create a new EquippedItem model
        let equipped_item = EquippedItemImpl::new(player_id, slot, token_id);
        
        // Write the model to the world
        self.write_model(@equipped_item);
    }

    fn unequip_item(ref self: World, player_id: u32, slot: Slot) {
        // Get the current equipped item
        let mut equipped_item: EquippedItem = self.read_model((player_id, slot));
        
        // Unequip the item
        equipped_item.unequip();
        
        // Write the updated model to the world
        self.write_model(@equipped_item);
    }
} 