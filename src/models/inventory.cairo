use core::traits::TryInto;
use core::traits::Into;
use core::debug::PrintTrait;
use core::array::ArrayTrait;
use core::Zeroable;
use dojo_starter::models::item::{Item, ItemImpl, ItemTrait};

const MAX_INVENTORY_CAPACITY: usize = 10;

mod errors {
    const INVENTORY_FULL: felt252 = 'Inventory is full';
    const ITEM_NOT_FOUND: felt252 = 'Item not found in inventory';
    const INVALID_ITEM: felt252 = 'Invalid item data';
}

#[derive(Drop, Serde, Clone)]
#[dojo::model]
pub struct Inventory {
    #[key]              
    pub id: u32,
    pub items: Array<Item>,  
    pub max_capacity: usize, 
    pub is_set: bool  
}

#[generate_trait]
impl InventoryImpl of InventoryTrait {

    // New inventory
    fn new(id: u32) -> Inventory {
        Inventory { 
            id,
            items: ArrayTrait::new(),
            max_capacity: MAX_INVENTORY_CAPACITY,
            is_set: true
        }
    }

    // New item
    fn add_item(ref self: Inventory, item: Item) -> bool {
        // validate space
        if self.items.len() >= self.max_capacity {
            return false;
        }

        // Add item
        self.items.append(item);
        true
    }

    // Is full
    fn is_full(self: @Inventory) -> bool {
        self.items.len() >= *self.max_capacity
    }

    // Current capacity
    fn available_space(self: @Inventory) -> usize {
        *self.max_capacity - self.items.len()
    }

    // Remove item
    fn remove_item(ref self: Inventory, item_id: u32) -> bool {
        let mut found = false;
        let mut new_items = ArrayTrait::new();
        let mut i = 0;
        
        loop {
            if i >= self.items.len() {
                break;
            }
    
            let current_item = self.items.at(i); 
    
            if current_item.id != @item_id || found {
                new_items.append(current_item.clone());  
            } else {
                found = true;  
            }
    
            i += 1;
        };
    
        if found {
            self.items = new_items;
        }
    
        found
    }

}

#[generate_trait]
impl InventoryAssert of AssertTrait {
    #[inline(always)]
    fn assert_exists(self: Inventory) {
        assert(self.is_non_zero(), errors::INVALID_ITEM);
    }

    #[inline(always)]
    fn assert_not_full(self: @Inventory) {
        assert(!InventoryImpl::is_full(self), errors::INVENTORY_FULL);
    }
}

impl ZeroableInventory of Zeroable<Inventory> {
    fn zero() -> Inventory {
        Inventory { 
            id: 0, 
            items: ArrayTrait::new(),
            max_capacity: 0,
            is_set: false
        }
    }

    fn is_zero(self: Inventory) -> bool {
        !self.is_set
    }

    fn is_non_zero(self: Inventory) -> bool {
        self.is_set
    }
}

#[cfg(test)]
mod tests {
    use super::{Inventory, InventoryImpl, Item, ItemImpl, 
        MAX_INVENTORY_CAPACITY
    };

    use core::debug::PrintTrait;

    #[test]
    fn test_new_inventory() {
        let inventory = InventoryImpl::new(1);
        assert(inventory.id == 1, 'Invalid inventory id');
        assert(inventory.is_set == true, 'Should be set');
        assert(inventory.max_capacity == 10, 'Invalid max capacity');
        assert(inventory.items.len() == 0, 'Should start empty');
    }

    #[test]
    fn test_add_item() {
        let mut inventory = InventoryImpl::new(1);
        let item = ItemImpl::new(1, "sword", "a basic sword", 100);
        
        assert(inventory.add_item(item), 'Should add item');
        assert(inventory.items.len() == 1, 'Should have one item');
    }

    #[test]
    fn test_inventory_full() {
        let mut inventory = InventoryImpl::new(1);

        let test_item = ItemImpl::new(1, "sword", "a basic sword", 100);

        let mut i = 0;
        loop {
            if i >= MAX_INVENTORY_CAPACITY {
                break;
            }
            
            let item_to_add = test_item.clone();
            assert(inventory.add_item(item_to_add), 'Should add item');
            i += 1;
        };

        let final_item = test_item.clone();
    
        assert(!inventory.add_item(final_item), 'Should not add when full');
        assert(inventory.is_full(), 'Should be full');
    }

    #[test]
    fn test_remove_item() {
        let mut inventory = InventoryImpl::new(1);
        let item = ItemImpl::new(1, "sword", "a basic sword", 100);
        
        inventory.add_item(item);
        assert(inventory.remove_item(1), 'Should remove item');
        assert(inventory.items.len() == 0, 'Should be empty after remove');
    }

    #[test]
    fn test_available_space() {
        let mut inventory = InventoryImpl::new(1);
        let item = ItemImpl::new(1, "sword", "a basic sword", 100);
        
        assert(inventory.available_space() == MAX_INVENTORY_CAPACITY, 'Should be empty');
        inventory.add_item(item);
        assert(inventory.available_space() == MAX_INVENTORY_CAPACITY - 1, 'Should have one less space');
    }

}