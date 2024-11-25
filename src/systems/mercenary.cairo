use starknet::ContractAddress;
use dojo_starter::{
    components::{
        mercenary::{Mercenary, MercenaryTrait}, 
        world::World, 
        utils::{uuid, RandomTrait},
        weapon::{Weapon}, 
        stats::{Stats, StatsTrait}
    }
};
use dojo::model::{ModelStorage, ModelValueStorage};

#[generate_trait]
impl MercenaryWorldImpl of MercenaryWorldTrait {

    fn mint_mercenary(ref self: World, owner: ContractAddress) -> Mercenary {
        let id:u128 = 234;//uuid(self);
        let mut random = RandomTrait::new();
        let seed = random.next();
        let mercenary = MercenaryTrait::new(owner,id,seed);
        // let mut world = self.world(@"dojo_starter");
        self.write_model(@mercenary);
        mercenary
    }

    fn get_mercenary(ref self: World, id: u128, owner: ContractAddress) -> Mercenary {
        // let mut world = self.world(@"dojo_starter");
        //Mercenary has two keys, id and owner, it must be read with both keys using a tuple
        let mercenary: Mercenary = self.read_model((id, owner));
        assert(mercenary.owner.is_non_zero(), 'mercenary not exists');
        mercenary
    }
    
    fn inflict_damage(ref self: World, target: Mercenary, weapon: Weapon) {
        //Optionally check if the mercenary is already dead
        //assert!(target.stats.defense > 0, "Mercenary is already dead");

        //get the weapon attack
        let mut weaponAttack: u16 = weapon.stats().attack;

        //get a new mercenary with the updated stats
        let mut updated_mercenary:Mercenary = target;

        //validate the mercenary stats to avoid negative values
        if updated_mercenary.stats.defense < weaponAttack {
            updated_mercenary.stats.defense = 0;
        } else {
            updated_mercenary.stats.defense -= weaponAttack;
        }

        // update the mercenary stats in the world
        self.write_model(@updated_mercenary);
    }
}
