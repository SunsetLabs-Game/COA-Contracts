use starknet::ContractAddress;

#[starknet::interface]
trait IMercenaryActions<TContractState> {
    fn mint(ref self: TContractState, owner: ContractAddress) -> u128;
    fn attack(ref self: TContractState, targetID: u128, targetOwner: ContractAddress);
    //    fn read_and_write(ref self: TContractState, owner: ContractAddress) -> u128;
    //    fn only_read(self: @TContractState, owner: ContractAddress) -> u128;
}

#[dojo::contract]
mod mercenary_actions {
    use super::IMercenaryActions;
    use starknet::ContractAddress;
    use dojo_starter::systems::mercenary::MercenaryWorldTrait;
    use dojo_starter::{
        components::{
            mercenary::{Mercenary},
            world::World, 
            utils::{uuid, RandomTrait}, 
            weapon::{Weapon},
            stats::{Stats, StatsTrait}
        }
    };
    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::event::EventStorage;

    #[abi(embed_v0)]
    impl MercenaryActionsImpl of IMercenaryActions<ContractState> {
        fn mint(ref self: ContractState, owner: ContractAddress) -> u128 {
            let mut world = self.world(@"dojo_starter");
            let mercenary = MercenaryWorldTrait::mint_mercenary(ref world, owner);
            mercenary.id
        }

        fn attack(ref self: ContractState, targetID: u128, targetOwner: ContractAddress) {
            let mut world = self.world(@"dojo_starter");
            let mut target_mercenary: Mercenary = MercenaryWorldTrait::get_mercenary(
                ref world, targetID, targetOwner
            );
            
            let weapon = Weapon::Sword;
            MercenaryWorldTrait::inflict_damage(ref world, target_mercenary, weapon);
            
        }
    }
}
