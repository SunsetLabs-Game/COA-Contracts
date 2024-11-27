#[cfg(test)]
mod tests {
    use core::starknet::{ContractAddress, get_caller_address};
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
    const MAX_RARE_Items_CAPACITY: usize = 10;
    use dojo_starter::{
        components::{world::World, utils::{uuid, RandomTrait}},
        systems::rare_item_mg::{rareItem_managmentTrait, rareItem_managmentImpl},
        models::rare_item_mg::{
            rareItem, RareItemSource, rare_items, m_rare_items, rare_itemsTrait, rare_itemsImpl,
            rareItemImpl, rareItemTrait,
        },
    };

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
        
        let rare = rareItem_managmentTrait::create_rare_item_inventory(ref world, player);

        assert_eq!(rare.player, player, "Player mismatch");
        assert_eq!(rare.items.len(), 0, "Item length mismatch");
      
        
        // Data for the new item
        let item_id  = 12;
        let source = RareItemSource::Mission;

        // Register the item
                let rare_item = rareItem_managmentTrait::register_rare_item(ref world, player, item_id, source);

        // Assertions
        assert_eq!(rare_item.player, player, "Player mismatch");
     
        assert_eq!(rare_item.items.len(), 1, "Item was not added");
        assert!(rare_item.has_available_item(item_id), "New item not found in inventory");
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

    
    // #[test]
    // fn test_register_multiple_unique_items() {
    //     let player = starknet::contract_address_const::<
    //         0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2,
    //     >();
    //     let ndef = namespace_def();
    //     let mut world = spawn_test_world([ndef].span());

        // Register multiple items
    //    let mut i = 3;
    //         let source = RareItemSource::Mission;
    //         // rareItem_managmentTrait::register_rare_item(ref world, player, i , source);
    //         // i = 2;
    //         // rareItem_managmentTrait::register_rare_item(ref world, player, i , source);
    //         // i = 3;
    //         let rare_item = rareItem_managmentTrait::register_rare_item(ref world, player, i , source);

    //         // Assertions
    //         assert_eq!(rare_item.player, player, "Player mismatch for item ");
           
    //         // let rare_item = rareItem_managmentTrait::register_rare_item(ref world, player, i , source);
    //         assert_eq!(rare_item.items.len(), i,"array size not match" );
    //         assert!(rare_item.has_available_item(i), "Item  not found in inventory");
    //     }
    }
