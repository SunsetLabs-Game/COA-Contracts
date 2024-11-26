#[cfg(test)]
mod tests {
    use core::starknet::{ContractAddress, get_caller_address};
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};

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
        
        // Data for the rare item
        let item_id: u32 = 12345;
        let source = RareItemSource::Mission;

        // First registration of the rare item
        let rare_item = rareItem_managmentTrait::register_rare_item(ref world, player, item_id, source);
        
        // Verify the registered rare item
        assert_eq!(rare_item.player, player, "Player address mismatch");
        assert_eq!(rare_item.has_available_item(item_id),true, "Registered item not found in inventory");

        // Try to register the same rare item again, handle with `Result`
        // let result = rareItem_managmentTrait::register_rare_item(ref world, player, item_id, source);
        // assert!(result.is_err(), "Duplicate item registration did not return an error");

        // if let Err(err) = result {
        //     assert_eq!(err, "Player already has this item", "Unexpected error message");
        // }

        // Register another item
        let new_item_id: u32 = 67890;
        let new_rare_item = rareItem_managmentTrait::register_rare_item(ref world, player, new_item_id, source);
        assert!(new_rare_item.has_available_item(new_item_id), "Newly added item not found in inventory");
    }

    #[test]
    fn test_create_rare_item_inventory() {
        let player = starknet::contract_address_const::<0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2>();
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let rare_item = rareItem_managmentTrait::create_rare_item_inventory(ref world, player);

        assert_eq!(rare_item.player, player, "Player mismatch");
        assert_eq!(rare_item.items.len(), 0, "Item length mismatch");
        assert_eq!(rare_item.max_capacity, 10, "Capacity mismatch");
    }
}
