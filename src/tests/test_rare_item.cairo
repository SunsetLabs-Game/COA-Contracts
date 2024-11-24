#[cfg(test)]
mod tests {
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use dojo::utils::test::{spawn_test_world, deploy_contract};
    use dojo_starter::{
        systems::{mercenary::{MercenaryWorldTrait, RareItemSource }},
    };

    #[test]
    fn test_rare_item_registration() {
       
        let player = starknet::contract_address_const::<0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2>();

      
        let mut world = spawn_test_world(["dojo_starter"].span(), [].span());

        // Data for the rare item
        let item_id: u128 = 12345;
        let source = RareItemSource::Mission;

        let rare_item = MercenaryWorldTrait::register_rare_item(ref world, player, item_id, source);

        // Verify the registered rare item
        assert_eq!(rare_item.item_id, item_id, "Item ID is incorrect");
        assert_eq!(rare_item.player, player, "Player address is incorrect");
        assert_eq!(rare_item.source, source, "Source of the rare item is incorrect");

        // Try to register the same rare item again
        let duplicate_item_result = std::panic::catch_unwind(|| {
            MercenaryWorldTrait::register_rare_item(ref world, player, item_id, source);
        });


        assert!(duplicate_item_result.is_err(), "Duplicate item registration did not panic as expected");
    }
}
