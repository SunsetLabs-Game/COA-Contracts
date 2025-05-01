#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
    use dojo_starter::models::player::{Player, PlayerTrait, m_Player};
    use dojo_starter::systems::resurrection::ResurrectionWorldTrait;
    use starknet::class_hash::ClassHash;

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "dojo_starter", 
            resources: [
                TestResource::Model(m_Player::TEST_CLASS_HASH.try_into().unwrap()),
            ].span()
        };
        ndef
    }

    #[test]
    fn test_valid_resurrection() {
        // Initialize test environment
        let player_address = starknet::contract_address_const::<0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2>();
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        // Create a player with max_hp of 100
        let mut player = PlayerTrait::new(player_address, 100);
        
        // Kill the player
        player.take_damage(100);
        assert(player.hp == 0, 'Player should be dead');
        assert(!player.is_alive, 'Player should not be alive');

        // Write the dead player to the world
        world.write_model(@player);

        // Resurrect the player
        ResurrectionWorldTrait::resurrect_player(ref world, player_address);

        // Get the resurrected player
        let resurrected_player = ResurrectionWorldTrait::get_player(ref world, player_address);

        // Verify resurrection was successful
        assert(resurrected_player.hp == 100, 'HP should be restored');
        assert(resurrected_player.is_alive, 'Player should be alive');
    }

    #[test]
    #[should_panic(expected: ('Player is not dead',))]
    fn test_invalid_resurrection() {
        // Initialize test environment
        let player_address = starknet::contract_address_const::<0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2>();
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        // Create a player with max_hp of 100
        let player = PlayerTrait::new(player_address, 100);
        
        // Write the alive player to the world
        world.write_model(@player);

        // Attempt resurrection (should panic)
        ResurrectionWorldTrait::resurrect_player(ref world, player_address);
    }
} 