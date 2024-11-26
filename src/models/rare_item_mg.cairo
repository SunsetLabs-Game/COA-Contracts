use core::starknet::{ContractAddress, get_caller_address};
use starknet::storage::{
    StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait, Map,
};

use core::debug::PrintTrait;
use core::array::ArrayTrait;

const MAX_RARE_Items_CAPACITY: usize = 10;

#[derive(Serde, Copy, Drop)]
#[dojo::model]
pub struct rare_items{
    #[key]              
    pub player : ContractAddress,
    pub items: Array<rareItem>,  
    pub max_capacity: usize, 
  
}

#[derive(Serde, Copy, Drop)]
pub struct rareItem {
    pub item_id: u32,
    pub item_source: RareItemSource,
}

#[derive(Serde, Copy, Drop)]
pub enum RareItemSource {
    Mission,
    Enemy,
}

#[generate_trait]
impl rareItemImpl of rareItemTrait {
    fn new(item_id: u32,item_source : RareItemSource) -> rareItem {
        rareItem {
            item_id,
            item_source,
        }
    }

   
}

#[generate_trait]
impl rare_itemsImpl of rare_itemsTrait {

    // New rare_items
    fn new(player : ContractAddress) -> rare_items {
        rare_items { 
            player,
            items: ArrayTrait::new(),
            max_capacity: MAX_RARE_Items_CAPACITY,
           
        }
    }

    fn has_available_item(self: rare_items, item_id: u32) -> bool {
      
      
        let mut found = false;
        // Check if the item already exists
        for i in 0..self.items.len() {
            if self.items[i].item_id == @item_id {
                found =  true; 
                break;
            }
        };
        return found ;
    }

    // New item
    fn add_rare_item(ref self: rare_items, rareItem: rareItem) -> bool {
        // validate space
        if self.items.len() >= self.max_capacity {
            return false;
        }

        // Add item
        self.items.append(rareItem);
        true
    }

}