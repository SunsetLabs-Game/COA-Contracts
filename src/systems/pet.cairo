use starknet::ContractAddress;

#[starknet::interface]
pub trait IPetSystem<TContractState> {
    fn equip_pet(ref self: TContractState, player_id: ContractAddress, pet_id: u256);
    fn unequip_pet(ref self: TContractState, player_id: ContractAddress);
    fn pet_action(
        ref self: TContractState, player_id: ContractAddress, action: felt252, target: u256,
    );
    fn evolve_pet(ref self: TContractState, player_id: ContractAddress);
    fn heal_player(ref self: TContractState, player_id: ContractAddress);
}

#[dojo::contract]
pub mod PetSystem {
    use super::IPetSystem;
    use crate::models::player::Player;
    use crate::models::gear::GearType;
    use starknet::ContractAddress;
    use dojo::model::ModelStorage;


    #[abi(embed_v0)]
    impl PetSystemImpl of IPetSystem<ContractState> {
        fn equip_pet(ref self: ContractState, player_id: ContractAddress, pet_id: u256) {
            let mut world = self.world(@"coa");
            let mut player: Player = world.read_model(player_id);
            assert(player.body.off_body.len() == 0, 'ALREADY_HAS_PET');
            let gear_type = crate::helpers::gear::parse_id(pet_id);
            assert(gear_type == GearType::Pet, 'NOT_A_PET');

            // Validate pet exists and player owns it
            let _pet_stats: crate::models::pet_stats::PetStats = world.read_model(pet_id);
            // TODO: Add ownership validation logic

            player.body.off_body.append(pet_id);
            world.write_model(@player);
        }

        fn unequip_pet(ref self: ContractState, player_id: ContractAddress) {
            let mut world = self.world(@"coa");
            let mut player: Player = world.read_model(player_id);
            assert(player.body.off_body.len() > 0, 'NO_PET_EQUIPPED');
            let _ = player.body.off_body.pop_front();
            world.write_model(@player);
        }

        fn pet_action(
            ref self: ContractState, player_id: ContractAddress, action: felt252, target: u256,
        ) {
            let mut world = self.world(@"coa");
            let player: Player = world.read_model(player_id);

            // Check if player has a pet equipped
            assert(player.body.off_body.len() > 0, 'NO_PET_EQUIPPED');

            let pet_id = *player.body.off_body.at(0);
            let mut pet_stats: crate::models::pet_stats::PetStats = world.read_model(pet_id);

            // Perform action based on action type using trait functions
            if action == 'ATTACK' {
                // Ensure enough energy before attacking
                assert(pet_stats.energy >= 20, 'INSUFFICIENT_ENERGY');
                let damage = crate::traits::pet_trait::attack(@pet_stats, target);
                if damage > 0 {
                    pet_stats.energy = pet_stats.energy - 20;
                    pet_stats.experience = pet_stats.experience + 5;
                    // TODO: Apply damage to target
                }
            } else if action == 'HEAL' {
                // Ensure enough energy before healing
                assert(pet_stats.energy >= 15, 'INSUFFICIENT_ENERGY');
                let heal_amount = crate::traits::pet_trait::heal(@pet_stats);
                if heal_amount > 0 {
                    pet_stats.energy = pet_stats.energy - 15;
                    pet_stats.experience = pet_stats.experience + 3;
                    // Note: Actual healing is done in heal_player function
                }
            } else if action == 'TRAVEL' {
                // Ensure enough energy before traveling
                assert(pet_stats.energy >= 10, 'INSUFFICIENT_ENERGY');
                // Safely convert the u256 target into a felt252 destination
                let destination: felt252 = match target.try_into() {
                    Option::Some(dest) => dest,
                    Option::None => {
                        return; // Invalid destination, skip action
                    },
                };
                if crate::traits::pet_trait::travel(@pet_stats, destination) {
                    pet_stats.energy = pet_stats.energy - 10;
                    pet_stats.experience = pet_stats.experience + 2;
                }
            }

            world.write_model(@pet_stats);
        }

        fn evolve_pet(ref self: ContractState, player_id: ContractAddress) {
            let mut world = self.world(@"coa");
            let player: Player = world.read_model(player_id);

            // Check if player has a pet equipped
            assert(player.body.off_body.len() > 0, 'NO_PET_EQUIPPED');

            let pet_id = *player.body.off_body.at(0);
            let pet_stats: crate::models::pet_stats::PetStats = world.read_model(pet_id);

            // Check if pet can evolve using trait function
            assert(crate::traits::pet_trait::can_evolve(@pet_stats), 'CANNOT_EVOLVE');

            // Evolve the pet using trait function
            let evolved_pet = crate::traits::pet_trait::evolve(@pet_stats);
            world.write_model(@evolved_pet);
        }

        fn heal_player(ref self: ContractState, player_id: ContractAddress) {
            let mut world = self.world(@"coa");
            let mut player: Player = world.read_model(player_id);

            // Check if player has a pet equipped
            assert(player.body.off_body.len() > 0, 'NO_PET_EQUIPPED');

            let pet_id = *player.body.off_body.at(0);
            let mut pet_stats: crate::models::pet_stats::PetStats = world.read_model(pet_id);

            // Check if pet has enough energy
            assert(pet_stats.energy >= 15, 'INSUFFICIENT_ENERGY');

            // Calculate heal amount using trait function
            let heal_amount = crate::traits::pet_trait::heal(@pet_stats);

            if heal_amount > 0 {
                // Heal the player
                if player.hp + heal_amount.into() > player.max_hp {
                    player.hp = player.max_hp;
                } else {
                    player.hp = player.hp + heal_amount.into();
                }

                // Reduce pet energy and gain experience
                pet_stats.energy = pet_stats.energy - 15;
                pet_stats.experience = pet_stats.experience + 3;

                // Update both models
                world.write_model(@player);
                world.write_model(@pet_stats);
            }
        }
    }
}
