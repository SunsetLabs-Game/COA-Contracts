#[cfg(test)]
mod tests {
    use core::starknet::{ContractAddress, get_caller_address};
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};

    use dojo_starter::{
        components::{world::World, utils::{uuid, RandomTrait},},
        systems::rare_item_mg::{rareItem_managmentTrait, rareItem_managmentImpl},
        models::rare_item_mg::{
            rareItem, RareItemSource, rare_items, m_rare_items, rare_itemsTrait, rare_itemsImpl,
            rareItemImpl, rareItemTrait,
        },
    };

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "dojo_starter", resources: [
                TestResource::Model(m_rare_items::TEST_CLASS_HASH.try_into().unwrap()),
            ].span(),
        };

        ndef
    }
    #[test]
    fn test_rare_item_registration() {
        let player = get_caller_address();
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        // Data for the rare item
        let id: u32 = 12345;
        let source = RareItemSource::Mission;
        // Register the rare item
        let rare_item = rareItem_managmentTrait::register_rare_item(ref world, id, source);
        // Verify the registered rare item
        assert_eq!(rare_item.player, player, "player address mismatch");
        let length = rare_item.items.len();
        let rareitem = rare_item.items[length - 1];
        // Check if the item already exists
        //   let mut found_item_id = false ;
        //   let mut  found_source = false ;
        //   for i in 0..rare_item.items.len() {
        //     if rare_item.items[i].item_id == @id {
        //         found_item_id =  true;
        //         if rare_item.items[i].item_source == @source{
        //             found_source = true ;
        //         }
        //         break;
        //     }
        //    };
        assert_eq!(rareitem.item_id, @id, "item_Id not match");
        // assert_eq!(rareitem.item_source, @source, "item source  not match");

        // Try to register the same rare item again (expect a panic)
    // let result = std::panic::catch_unwind(|| {
    //     rareItem_managmentTrait::register_rare_item(ref world, item_id, source);
    // });
    // assert!(result.is_err(), "Duplicate item registration did not panic as expected");
    }

    #[test]
    fn test_create_rare_item_inventory() {
        let player = get_caller_address();
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let rare_item = rareItem_managmentTrait::create_rare_item_inventory(ref world);

        assert_eq!(rare_item.player, player, "player mismatch");
        assert_eq!(rare_item.max_capacity, 10, "capacity mismatch");
    }
}
