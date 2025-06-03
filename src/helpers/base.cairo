use core::num::traits::Zero;
use dojo::model::ModelStorage;
use dojo::world::WorldStorage;
use starknet::ContractAddress;

pub impl ContractAddressDefault of Default<ContractAddress> {
    #[inline(always)]
    fn default() -> ContractAddress {
        Zero::zero()
    }
}

#[dojo::model]
#[derive(Drop, Copy, Serde, Default)]
pub struct Id {
    #[key]
    id: felt252,
    nonce: u256,
}

pub fn generate_id(target: felt252, ref world: WorldStorage) -> u256 {
    let mut game_id: Id = world.read_model(target);
    let mut id = game_id.nonce + 1;
    game_id.nonce = id;
    world.write_model(@game_id);
    id
}
