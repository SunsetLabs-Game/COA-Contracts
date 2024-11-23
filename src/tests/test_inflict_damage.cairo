#[cfg(test)]
mod tests {
    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo::world::{WorldStorage, IWorldDispatcher, IWorldDispatcherTrait};
    use dojo_starter::systems::mercenary::MercenaryWorldTrait;
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDefTrait};

    use dojo_starter::{
        components::{
            mercenary::{Mercenary},
            weapon::{Weapon},
            stats::{Stats,StatsTrait},
            world::World,
        }
    };
    use starknet::ContractAddress;
   
    // fn namespace_def() -> NamespaceDef {
    //     let ndef = NamespaceDef {
    //         namespace: "dojo_starter", resources: [
    //             TestResource::Model(m_Position::TEST_CLASS_HASH.try_into().unwrap()),
    //             TestResource::Model(m_Moves::TEST_CLASS_HASH.try_into().unwrap()),
    //             TestResource::Event(actions::e_Moved::TEST_CLASS_HASH.try_into().unwrap()),
    //             TestResource::Contract(
    //                 ContractDefTrait::new(actions::TEST_CLASS_HASH, "actions")
    //                     .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span())
    //             )
    //         ].span()
    //     };
 
    //     ndef
    // }

    #[test]
    fn test_inflict_damage() {
        // Initialize test environment
        
        let mut world = world(@"dojo_starter");

        // Mint a mercenary
        let newMercenary= MercenaryWorldTrait::mint_mercenary(ref world, caller);
        
        // Attack the mercenary
        let updatedMercenary = MercenaryWorldTrait::inflict_damage(ref world, newMercenary, Weapon::Sword);

        if Weapon::Sword.stats().attack > newMercenary.stats.defense {
            // Check if the mercenary stats are updated
            assert_eq!(updatedMercenary.stats.defense, 0);
        } else {
            // Check if the mercenary stats are updated
            assert_eq!(updatedMercenary.stats.defense, newMercenary.stats.defense - Weapon::Sword.stats().attack);
        }

    }

}