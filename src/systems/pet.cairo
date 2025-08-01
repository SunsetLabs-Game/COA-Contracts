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
    use crate::models::pet_stats::PetStats;

    // Internal helper functions following companion trait logic
    fn calculate_attack_damage(pet_stats: @PetStats, target: u256) -> u64 {
        // Check if pet has enough energy and is not in combat
        if *pet_stats.energy < 20 || *pet_stats.in_combat {
            return 0;
        }

        // Calculate damage based on agility and intelligence
        let base_damage = (*pet_stats.agility + *pet_stats.intelligence) / 2;

        // Apply loyalty bonus (higher loyalty = more damage)
        let loyalty_bonus = *pet_stats.loyalty / 10;

        // Evolution stage multiplier
        let evolution_multiplier = (*pet_stats.evolution_stage + 1).into();

        base_damage + loyalty_bonus * evolution_multiplier
    }

    fn calculate_heal_amount(pet_stats: @PetStats) -> u64 {
        // Check if pet has enough energy
        if *pet_stats.energy < 15 {
            return 0;
        }

        // Calculate healing based on intelligence and loyalty
        let base_heal = (*pet_stats.intelligence + *pet_stats.loyalty) / 3;

        // Evolution stage affects healing power
        let evolution_multiplier = (*pet_stats.evolution_stage + 1).into();

        base_heal * evolution_multiplier
    }

    fn can_travel(pet_stats: @PetStats, destination: felt252) -> bool {
        // Check if pet has enough energy for travel
        if *pet_stats.energy < 10 {
            return false;
        }

        // High agility pets can travel better
        (*pet_stats.agility) > 50
    }

    fn can_pet_evolve(pet_stats: @PetStats) -> bool {
        // Can evolve if has enough experience and not at max evolution stage
        *pet_stats.experience >= *pet_stats.next_evolution_at && *pet_stats.evolution_stage < 3
    }

    fn evolve_pet_stats(pet_stats: @PetStats) -> PetStats {
        // Create evolved version of the pet
        PetStats {
            asset_id: *pet_stats.asset_id,
            loyalty: *pet_stats.loyalty + 10,
            intelligence: *pet_stats.intelligence + 15,
            agility: *pet_stats.agility + 12,
            special_ability: *pet_stats.special_ability,
            energy: *pet_stats.max_energy, // Full energy after evolution
            evolution_stage: *pet_stats.evolution_stage + 1,
            in_combat: false,
            max_energy: *pet_stats.max_energy + 20,
            experience: 0, // Reset experience after evolution
            next_evolution_at: *pet_stats.next_evolution_at + 100 // Next evolution requires more XP
        }
    }

    #[abi(embed_v0)]
    impl PetSystemImpl of IPetSystem<ContractState> {
        fn equip_pet(ref self: ContractState, player_id: ContractAddress, pet_id: u256) {
            let mut world = self.world(@"coa");
            let mut player: Player = world.read_model(player_id);
            assert(player.body.off_body.len() == 0, 'ALREADY_HAS_PET');
            let gear_type = crate::helpers::gear::parse_id(pet_id);
            assert(gear_type == GearType::Pet, 'NOT_A_PET');
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

            // Perform action based on action type
            if action == 'ATTACK' {
                let damage = calculate_attack_damage(@pet_stats, target);
                if damage > 0 {
                    pet_stats.energy = pet_stats.energy - 20;
                    pet_stats.experience = pet_stats.experience + 5;
                    // TODO: Apply damage to target
                }
            } else if action == 'HEAL' {
                let heal_amount = calculate_heal_amount(@pet_stats);
                if heal_amount > 0 {
                    pet_stats.energy = pet_stats.energy - 15;
                    pet_stats.experience = pet_stats.experience + 3;
                    // Note: Actual healing is done in heal_player function
                }
            } else if action == 'TRAVEL' {
                if can_travel(@pet_stats, target.try_into().unwrap()) {
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

            // Check if pet can evolve using helper function
            assert(can_pet_evolve(@pet_stats), 'CANNOT_EVOLVE');

            // Evolve the pet using helper function
            let evolved_pet = evolve_pet_stats(@pet_stats);
            world.write_model(@evolved_pet);
        }

        fn heal_player(ref self: ContractState, player_id: ContractAddress) {
            let mut world = self.world(@"coa");
            let mut player: Player = world.read_model(player_id);

            // Check if player has a pet equipped
            assert(player.body.off_body.len() > 0, 'NO_PET_EQUIPPED');

            let pet_id = *player.body.off_body.at(0);
            let mut pet_stats: crate::models::pet_stats::PetStats = world.read_model(pet_id);

            // Calculate heal amount using helper function
            let heal_amount = calculate_heal_amount(@pet_stats);

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
