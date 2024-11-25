#[cfg(test)]
mod tests {
    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo_starter::systems::mercenary::MercenaryWorldTrait;
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
    use dojo_starter::{
        components::{
            mercenary::{Mercenary, m_Mercenary }, weapon::{Weapon}, stats::{Stats, StatsTrait}
        }
    };
    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "dojo_starter", resources: [
                TestResource::Model(m_Mercenary::TEST_CLASS_HASH.try_into().unwrap()),
            ].span()
        };

        ndef
    }

    #[test]
    fn test_inflict_damage_using_sword() {
        // Initialize test environment
        let caller = starknet::contract_address_const::<0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2>();//test address
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        // Mint a mercenary
        let mintedMercenary = MercenaryWorldTrait::mint_mercenary(ref world, caller);

        // Attack the mercenary
        MercenaryWorldTrait::inflict_damage(
            ref world, mintedMercenary, Weapon::Sword
        );

        //Get the updated mercenary 
        let updatedMercenary =MercenaryWorldTrait::get_mercenary( ref world, mintedMercenary.id, mintedMercenary.owner);

        // Check if the mercenary stats are updated
        assert_eq!(
            mintedMercenary.stats.defense - Weapon::Sword.stats().attack,
            updatedMercenary.stats.defense,
            "Defense should be reduced by the attack value"
        );

        // Check if the mercenary owner and id are the same
        assert_eq!(
            mintedMercenary.owner,
            updatedMercenary.owner,
            "The owner should be the same"
        );

        assert_eq!(
            mintedMercenary.id,
            updatedMercenary.id,
            "The id should be the same"
        );

    }

    #[test]
    fn test_inflict_damage_using_katana() {
        // Initialize test environment
        let caller = starknet::contract_address_const::<0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2>();//test address
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        // Mint a mercenary
        let mintedMercenary = MercenaryWorldTrait::mint_mercenary(ref world, caller);

        // Attack the mercenary
        MercenaryWorldTrait::inflict_damage(
            ref world, mintedMercenary, Weapon::Katana
        );

        //Get the updated mercenary 
        let updatedMercenary =MercenaryWorldTrait::get_mercenary( ref world, mintedMercenary.id, mintedMercenary.owner);

        // Check if the mercenary stats are updated
        assert_eq!(
            mintedMercenary.stats.defense - Weapon::Katana.stats().attack,
            updatedMercenary.stats.defense,
            "Defense should be reduced by the attack value"
        );

        // Check if the mercenary owner and id are the same
        assert_eq!(
            mintedMercenary.owner,
            updatedMercenary.owner,
            "The owner should be the same"
        );

        assert_eq!(
            mintedMercenary.id,
            updatedMercenary.id,
            "The id should be the same"
        );
    }

    #[test]
    fn test_inflict_damage_negative_defense() {
        // Initialize test environment
        let caller = starknet::contract_address_const::<0x07dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2>();//test address
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        // Mint a mercenary
        let mintedMercenary = MercenaryWorldTrait::mint_mercenary(ref world, caller);

        //it will attack the mercenary 50 times using sword, more than the defense value
        let mut loop_count = 50;

        // Get the updated mercenary
        let mut updatedMercenary = mintedMercenary;
        
        //checking if the mercenary is getting damage and can not have negative defense
        while loop_count!= 0 {
            // Attack the mercenary
            MercenaryWorldTrait::inflict_damage(
                ref world, updatedMercenary, Weapon::Sword
            );

            //Get the updated mercenary 
            updatedMercenary =MercenaryWorldTrait::get_mercenary( ref world, mintedMercenary.id, mintedMercenary.owner);

            //decrement the loop count
            loop_count -= 1;
        };
        

        // Check if the mercenary stats are updated
        assert_eq!(
            updatedMercenary.stats.defense,
            0,
            "Defense should be 0"
        );

        // Check if the mercenary owner and id are the same
        assert_eq!(
            mintedMercenary.owner,
            updatedMercenary.owner,
            "The owner should be the same"
        );

        assert_eq!(
            mintedMercenary.id,
            updatedMercenary.id,
            "The id should be the same"
        );
    }
}
