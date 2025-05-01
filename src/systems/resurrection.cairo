use starknet::ContractAddress;
use dojo_starter::models::player::{Player, PlayerTrait};
use dojo_starter::components::world::World;
use dojo::model::{ModelStorage, ModelValueStorage};

#[generate_trait]
impl ResurrectionWorldImpl of ResurrectionWorldTrait {
    fn resurrect_player(ref self: World, player_address: ContractAddress) {
        let mut player: Player = self.read_model(player_address);
        player.resurrect();
        self.write_model(@player);
    }

    fn get_player(ref self: World, player_address: ContractAddress) -> Player {
        let player: Player = self.read_model(player_address);
        player
    }
} 