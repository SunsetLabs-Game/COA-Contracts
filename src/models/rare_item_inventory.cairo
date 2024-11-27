use core::starknet::{ContractAddress, get_caller_address};
use dojo_starter::{
    components::{world::World, utils::{uuid, RandomTrait},},
    models::rare_item_mg::{
        rareItem, RareItemSource,   rareItemImpl,
        rareItemTrait,
    },
};
const MAX_RARE_Items_CAPACITY: usize = 10;

use starknet::storage::{
    StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait, Map,
    StoragePathEntry,
};
use dojo::model::{ModelStorage, ModelValueStorage};




#[derive(Drop, Serde, Clone)]
#[dojo::model]
pub struct rare_items {
    #[key]
    pub player: ContractAddress,
    pub items: Array<rareItem>,
    
}


#[generate_trait]
impl rare_itemsImpl of rare_itemsTrait {
    // New rare_items
    fn new(player: ContractAddress) -> rare_items {
        rare_items { player, items: ArrayTrait::new(), }    }

    
    fn add_or_check_item(ref  self: rare_items, rareItem: rareItem) -> bool {
        // Check if the item already exists
        let mut added = true  ;
        for i in 0 ..self.items.len() {
            if self.items[i].item_id == @rareItem.item_id {
                added =  false; // Item already exists
                break;
            }
        };
        // Add item if not found
        if added {
        self.items.append(rareItem);
           };
        added
    }
}

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

    fn register_rare_item(
        ref self: World,
        player: ContractAddress,
        item_id: u32,
        source: RareItemSource,
    ) -> rare_items {
        
        // Retrieve inventory
        let mut rare_item: rare_items = self.read_model((player));
        let new_item = rareItemTrait::new(item_id, source);
      
        if ! rare_item.add_or_check_item(new_item) {
            panic!("Player already has this item");
        }
   
        self.write_model(@rare_item);
        rare_item
    }
  
    
}


#[cfg(test)]
mod tests {
    use super::{
        rare_items, rare_itemsImpl, rareItem, rareItemImpl, rareItemTrait, RareItemSource,rareItem_managmentTrait,
        MAX_RARE_Items_CAPACITY,m_rare_items,
    };
    use core::starknet::{ContractAddress, get_caller_address};
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
    use dojo_starter::{
        components::{world::World, utils::{uuid, RandomTrait}}, };
    use core::debug::PrintTrait;

    #[test]
    fn test_new_rare_items() {
        let player = starknet::contract_address_const::<
            0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2
        >();
        let mut inventory = rare_itemsImpl::new(player);
        let source = RareItemSource::Mission;
        let item = rareItemImpl::new(12 , source);
        assert(inventory.player == player, 'Invalid player address');
        assert(inventory.add_or_check_item(item), 'add rare item failed');
        assert(inventory.items.len() == 1, 'items len() empty');
        let item  = inventory.items[0];
        assert_eq!(item.item_id , @12 , "item id mismatch");
        // assert!(item.item_source == @source , "source not match " );
    }

    
    #[test]
    fn test_new_rareItem() {
        let source = RareItemSource::Mission;
        let id: u32 = 19;
        let item = rareItemImpl::new(id, source);
        assert(item.item_id == id, ' mismatch item Id');
        //   assert(item.item_source == source, ' mismatch item source');
    }



    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model(m_rare_items::TEST_CLASS_HASH.try_into().unwrap()),
            ].span(),
        };
        ndef
    }

    #[test]
    fn test_rare_item_registration() {
        let player = starknet::contract_address_const::<0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2>();
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        
        // rareItem_managmentTrait::create_rare_item_inventory(ref world, player);

          // Data for the new item
        let item_id  = 12;
        let source = RareItemSource::Mission;

        // Register the item
          let mut rare_item = rareItem_managmentTrait::register_rare_item(ref world, player, item_id, source);
          let item = rareItemTrait::new(item_id , source);
        // Assertions
        assert_eq!(rare_item.player, player, "Player mismatch");     
        assert_eq!(rare_item.items.len(), 1, "Item was not added");
        assert_eq!(rare_item.add_or_check_item(item),false, "dublicat item added into inventory");
    }

    #[test]
    fn test_create_rare_item_inventory() {
        let player = starknet::contract_address_const::<0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2>();
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let rare_item = rareItem_managmentTrait::create_rare_item_inventory(ref world, player);

        assert_eq!(rare_item.player, player, "Player mismatch");
        assert_eq!(rare_item.items.len(), 0, "Item length mismatch");
    
    }

    #[test]
fn test_add_or_check_item() {
    // Step 1: Create a new player inventory
    let player = starknet::contract_address_const::<
        0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2
    >();
    let mut inventory = rare_itemsImpl::new(player);

    // Step 2: Create a new rare item
    let item1 = rareItemImpl::new(1, RareItemSource::Mission);
    let item2 = rareItemImpl::new(2, RareItemSource::Enemy);

    // Step 3: Add the first item and check the result
    assert_eq!(inventory.add_or_check_item(item1), true, "Item 1 should be added successfully");
    assert_eq!(inventory.items.len()  , 1, "Inventory should contain one item");

    // Step 4: Try to add the same item again
    assert_eq!(inventory.add_or_check_item(item1),false, "Item 1 should not be added again");
    assert_eq!(inventory.items.len() , 1, "Inventory size should remain unchanged");

    // Step 5: Add a different item and check the result
    assert_eq!(inventory.add_or_check_item(item2) , true , "Item 2 should be added successfully");
    assert_eq!(inventory.items.len() , 2, "Inventory should now contain two items");

    // Step 6: Verify item properties
    let first_item = inventory.items[0];
    assert_eq!(first_item.item_id , @1, "First item ID mismatch");
    let second_item = inventory.items[1];
    assert_eq!(second_item.item_id , @2, "Second item ID mismatch");
}

}