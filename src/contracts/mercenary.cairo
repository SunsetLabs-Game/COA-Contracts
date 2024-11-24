use starknet::ContractAddress;

#[starknet::interface]
trait IMercenaryActions<TContractState> {
    fn mint(ref self: TContractState, owner: ContractAddress) -> u128;
//    fn read_and_write(ref self: TContractState, owner: ContractAddress) -> u128;
//    fn only_read(self: @TContractState, owner: ContractAddress) -> u128;
}

#[dojo::contract]
mod mercenary_actions {
    use super::IMercenaryActions;
    use starknet::ContractAddress;
    use dojo_starter::{components::{mercenary::{Mercenary, MercenaryTrait}, world::World, utils::{uuid, RandomTrait}}};
    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::event::EventStorage;

    #[abi(embed_v0)]
    impl MercenaryActionsImpl of IMercenaryActions<ContractState> {
        fn mint(ref self: ContractState, owner: ContractAddress) -> u128 {
            let mut world = self.world(@"dojo_starter");

          
            
            let id: u128 = 12345;

           
            let mut random = RandomTrait::new();
            let random_seed = random.next();


            let mercenary = MercenaryTrait::new(owner, id, random_seed);

            world.write_model(@mercenary);

            id
        }
    }
}
