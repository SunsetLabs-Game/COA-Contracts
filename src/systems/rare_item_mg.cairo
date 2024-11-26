use core::starknet::{ContractAddress, get_caller_address};
use dojo_starter::{
    components::{world::World, utils::{uuid, RandomTrait},},
    models::rare_item_mg::{
        rareItem, RareItemSource, rare_items, rare_itemsTrait, rare_itemsImpl, rareItemImpl,
        rareItemTrait,
    },
};


use starknet::storage::{
    StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait, Map,
    StoragePathEntry,
};
use dojo::model::{ModelStorage, ModelValueStorage};

#[generate_trait]
impl rareItem_managmentImpl of rareItem_managmentTrait {
    //  create new rare_item inventory
    fn create_rare_item_inventory(ref self: World , player : ContractAddress) -> rare_items {
       

        let rare_item: rare_items = self.read_model((player));
        {
            if rare_item.items.len() > 0 {
                panic!("Player already registered");
            }
        }
        let inventory: rare_items = rare_itemsTrait::new(player);
        inventory
    }

    // register new rare item  in rare item inventory
    fn register_rare_item(ref self: World,player:ContractAddress ,  item_id: u32, source: RareItemSource,) -> rare_items {
      
        // Create a new rare item
        let new_item = rareItemTrait::new(item_id, source);

        let rare_item: rare_items = self.read_model((player));
        
            if rare_item.items.len() > 0 {
                if rare_item.has_available_item(item_id) {
                    panic!("Player already has this item ");
                }
            }
        

        let mut Rare_item: rare_items = self.read_model((player));

        if  Rare_item.add_rare_item(new_item) {
            panic!("Player item array is full");
        }
        self.write_model(@Rare_item);
        Rare_item
    }
}

