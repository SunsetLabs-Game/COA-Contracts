use core::debug::PrintTrait;
use core::traits::TryInto;
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
use starknet::{ContractAddress, contract_address_const};

use dojo_starter::models::equipped_item::{EquippedItem, EquippedItemImpl, Slot, m_EquippedItem};
use dojo_starter::models::item::{Item, ItemImpl, ItemTrait, m_Item};
use dojo_starter::models::inventory::{Inventory, InventoryImpl, InventoryTrait, m_Inventory};
use dojo_starter::systems::equipment::EquipmentWorldTrait;

// Define namespace for standalone tests
fn namespace_def() -> NamespaceDef {
    let ndef = NamespaceDef {
        namespace: "dojo_starter", 
        resources: [
            TestResource::Model(m_EquippedItem::TEST_CLASS_HASH.try_into().unwrap()),
            TestResource::Model(m_Inventory::TEST_CLASS_HASH.try_into().unwrap()),
            TestResource::Model(m_Item::TEST_CLASS_HASH.try_into().unwrap()),
        ].span()
    };
    ndef
}

#[cfg(test)]
mod tests {
    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
    use starknet::{ContractAddress, contract_address_const};
    
    use dojo_starter::models::equipped_item::{EquippedItem, EquippedItemImpl, Slot, m_EquippedItem};
    use dojo_starter::models::inventory::{Inventory, InventoryImpl, InventoryTrait, m_Inventory};
    use dojo_starter::models::item::{Item, ItemImpl, ItemTrait, m_Item};
    use dojo_starter::systems::equipment::EquipmentWorldTrait;
    use super::namespace_def;

    #[test]
    fn test_equip_item() {
        // Initialize test environment
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        
        // Setup test data
        let player_id: u32 = 1;
        let slot = Slot::MainHand;
        let token_id: u256 = 5_u256;
        
        // Equip an item using the world trait
        EquipmentWorldTrait::equip_item(ref world, player_id, slot, token_id);
        
        // Read from world to verify
        let stored_item: EquippedItem = world.read_model((player_id, slot));
        
        // Verify item was equipped correctly
        assert(stored_item.player_id == player_id, 'Wrong player_id');
        assert(stored_item.token_id == token_id, 'Wrong token_id');
        assert(stored_item.is_equipped, 'Should be equipped');
        
        // Equip a new item (replacing the old one)
        let new_token_id: u256 = 10_u256;
        EquipmentWorldTrait::equip_item(ref world, player_id, slot, new_token_id);
        
        // Read the updated item
        let updated_stored_item: EquippedItem = world.read_model((player_id, slot));
        
        // Verify the item was updated
        assert(updated_stored_item.token_id == new_token_id, 'New token not equipped');
        assert(updated_stored_item.is_equipped, 'Should still be equipped');
    }
    
    #[test]
    fn test_unequip_item() {
        // Initialize test environment
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        
        // Setup test data
        let player_id: u32 = 1;
        let slot = Slot::Head;
        let token_id: u256 = 15_u256;
        
        // Equip an item then unequip it
        EquipmentWorldTrait::equip_item(ref world, player_id, slot, token_id);
        
        // Verify item was equipped
        let stored_item: EquippedItem = world.read_model((player_id, slot));
        assert(stored_item.token_id == token_id, 'Wrong token_id');
        assert(stored_item.is_equipped, 'Should be equipped');
        
        // Unequip the item
        EquipmentWorldTrait::unequip_item(ref world, player_id, slot);
        
        // Read the updated item
        let unequipped_item: EquippedItem = world.read_model((player_id, slot));
        
        // Verify the item was unequipped
        assert(!unequipped_item.is_equipped, 'Should be unequipped');
        assert(unequipped_item.token_id == 0_u256, 'Token ID should be reset');
    }
    
    #[test]
    fn test_multiple_slots() {
        // Initialize test environment
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        
        // Setup test data
        let player_id: u32 = 1;
        let sword_token: u256 = 101_u256;
        let helmet_token: u256 = 202_u256;
        let chest_token: u256 = 303_u256;
        
        // Equip items to different slots
        EquipmentWorldTrait::equip_item(ref world, player_id, Slot::MainHand, sword_token);
        EquipmentWorldTrait::equip_item(ref world, player_id, Slot::Head, helmet_token);
        EquipmentWorldTrait::equip_item(ref world, player_id, Slot::Chest, chest_token);
        
        // Read items from world
        let stored_main_hand: EquippedItem = world.read_model((player_id, Slot::MainHand));
        let stored_head: EquippedItem = world.read_model((player_id, Slot::Head));
        let stored_chest: EquippedItem = world.read_model((player_id, Slot::Chest));
        
        // Verify items were equipped correctly
        assert(stored_main_hand.is_equipped, 'Sword should be equipped');
        assert(stored_head.is_equipped, 'Helmet should be equipped');
        assert(stored_chest.is_equipped, 'Chest armor should be equipped');
        
        // Verify correct token ids
        assert(stored_main_hand.token_id == sword_token, 'Wrong sword token');
        assert(stored_head.token_id == helmet_token, 'Wrong helmet token');
        assert(stored_chest.token_id == chest_token, 'Wrong chest token');
        
        // Unequip just the helmet
        EquipmentWorldTrait::unequip_item(ref world, player_id, Slot::Head);
        
        // Read updated helmet
        let unequipped_head: EquippedItem = world.read_model((player_id, Slot::Head));
        let main_hand_still_equipped: EquippedItem = world.read_model((player_id, Slot::MainHand));
        let chest_still_equipped: EquippedItem = world.read_model((player_id, Slot::Chest));
        
        // Verify helmet was unequipped but others remain equipped
        assert(!unequipped_head.is_equipped, 'Helmet should be unequipped');
        assert(main_hand_still_equipped.is_equipped, 'Sword should still be equipped');
        assert(chest_still_equipped.is_equipped, 'Chest still equipped');
        
        // Re-equip a different helmet
        let new_helmet_token: u256 = 505_u256;
        EquipmentWorldTrait::equip_item(ref world, player_id, Slot::Head, new_helmet_token);
        
        // Read updated helmet
        let new_helmet: EquippedItem = world.read_model((player_id, Slot::Head));
        
        // Verify new helmet is equipped
        assert(new_helmet.is_equipped, 'New helmet should be equipped');
        assert(new_helmet.token_id == new_helmet_token, 'Wrong new helmet token');
    }

    #[test]
    fn test_unequip_empty_slot() {
        // Initialize test environment
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        
        // Create a test player with an already unequipped slot
        let player_id = 2;
        let slot = Slot::Head;
        
        // First equip then unequip to create an empty slot
        EquipmentWorldTrait::equip_item(ref world, player_id, slot, 1_u256);
        EquipmentWorldTrait::unequip_item(ref world, player_id, slot);
        
        // Verify slot is empty
        let stored_empty_item: EquippedItem = world.read_model((player_id, slot));
        assert(!stored_empty_item.is_equipped, 'Slot should be empty');
        
        // Try unequipping again (should do nothing)
        EquipmentWorldTrait::unequip_item(ref world, player_id, slot);
        
        // Verify slot is still empty
        let still_empty_item: EquippedItem = world.read_model((player_id, slot));
        assert(!still_empty_item.is_equipped, 'Slot should still be empty');
    }
}

#[test]
fn test_unequip_empty_slot() {
    // Create a test player with an already unequipped slot
    let player_id = 2;
    let slot = Slot::Head;
    
    // Create an unequipped item
    let mut empty_equipped_item = EquippedItemImpl::new(player_id, slot, 0_u256);
    empty_equipped_item.unequip();
    
    // Verify slot is empty
    assert(!empty_equipped_item.is_equipped, 'Slot should be empty');
    
    // Try unequipping again (should do nothing)
    empty_equipped_item.unequip();
    
    // Verify slot is still empty
    assert(!empty_equipped_item.is_equipped, 'Slot should still be empty');
}

#[test]
fn test_unequip_multiple_items() {
    // Setup test environment
    let ndef = namespace_def();
    let mut world = spawn_test_world([ndef].span());
    
    // Create a test player and inventory
    let player_id: u32 = 3;
    let mut inventory = InventoryImpl::new(player_id);
    
    // Create and add multiple items to the inventory with u256 token IDs for equipment
    let sword_id: u256 = 101_u256;
    let helmet_id: u256 = 202_u256;
    let chest_id: u256 = 303_u256;
    
    // Set the inventory in the world
    world.write_model(@inventory);
    
    // Equip items to different slots
    let main_hand_slot = Slot::MainHand;
    let head_slot = Slot::Head;
    let chest_slot = Slot::Chest;
    
    // Equip items using the world trait with u256 token IDs
    EquipmentWorldTrait::equip_item(ref world, player_id, main_hand_slot, sword_id);
    EquipmentWorldTrait::equip_item(ref world, player_id, head_slot, helmet_id); 
    EquipmentWorldTrait::equip_item(ref world, player_id, chest_slot, chest_id);
    
    // Verify all items are equipped
    let sword_check: EquippedItem = world.read_model((player_id, main_hand_slot));
    let helmet_check: EquippedItem = world.read_model((player_id, head_slot));
    let chest_check: EquippedItem = world.read_model((player_id, chest_slot));
    
    assert(sword_check.is_equipped, 'Sword should be equipped');
    assert(helmet_check.is_equipped, 'Helmet should be equipped');
    assert(chest_check.is_equipped, 'Chest armor should be equipped');
    
    // Unequip the helmet
    EquipmentWorldTrait::unequip_item(ref world, player_id, head_slot);
    
    // Verify helmet was unequipped but others remain equipped
    let helmet_unequipped: EquippedItem = world.read_model((player_id, head_slot));
    let sword_still_equipped: EquippedItem = world.read_model((player_id, main_hand_slot));
    let chest_still_equipped: EquippedItem = world.read_model((player_id, chest_slot));
    
    assert(!helmet_unequipped.is_equipped, 'Helmet should be unequipped');
    assert(sword_still_equipped.is_equipped, 'Sword should still be equipped');
    assert(chest_still_equipped.is_equipped, 'Chest still equipped');
    
    // Verify inventory
    let inventory_check: Inventory = world.read_model(player_id);
    assert(inventory_check.max_capacity == 10, 'Default max items is 10');
} 