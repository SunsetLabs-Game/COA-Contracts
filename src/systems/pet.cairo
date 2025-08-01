use starknet::ContractAddress;

#[starknet::interface]
pub trait IPetSystem<TContractState> {
    fn equip_pet(ref self: TContractState, player_id: ContractAddress, pet_id: u256);
    fn unequip_pet(ref self: TContractState, player_id: ContractAddress);
    fn pet_action(ref self: TContractState, player_id: ContractAddress, action: felt252, target: u256);
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

        fn pet_action(ref self: ContractState, player_id: ContractAddress, action: felt252, target: u256) {
            let mut world = self.world(@"coa");
            let player: Player = world.read_model(player_id);
            
            // Check if player has a pet equipped
            assert(player.body.off_body.len() > 0, 'NO_PET_EQUIPPED');
            
            let pet_id = *player.body.off_body.at(0);
            let mut pet_stats: crate::models::pet_stats::PetStats = world.read_model(pet_id);
            
            // Perform action based on action type
            if action == 'ATTACK' {
                // Simple attack calculation
                if pet_stats.energy >= 20 && !pet_stats.in_combat {
                    let damage = (pet_stats.agility + pet_stats.intelligence) / 2;
                    if damage > 0 {
                        pet_stats.energy = pet_stats.energy - 20;
                        pet_stats.experience = pet_stats.experience + 5;
                    }
                }
            } else if action == 'HEAL' {
                // Simple heal calculation
                if pet_stats.energy >= 15 {
                    let heal_amount = (pet_stats.intelligence + pet_stats.loyalty) / 3;
                    if heal_amount > 0 {
                        pet_stats.energy = pet_stats.energy - 15;
                        pet_stats.experience = pet_stats.experience + 3;
                    }
                }
            } else if action == 'TRAVEL' {
                // Simple travel check
                if pet_stats.energy >= 10 && pet_stats.agility > 50 {
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
            
            // Check if pet can evolve
            assert(pet_stats.experience >= pet_stats.next_evolution_at && pet_stats.evolution_stage < 3, 'CANNOT_EVOLVE');
            
            // Create evolved version of the pet
            let evolved_pet = crate::models::pet_stats::PetStats {
                asset_id: pet_stats.asset_id,
                loyalty: pet_stats.loyalty + 10,
                intelligence: pet_stats.intelligence + 15,
                agility: pet_stats.agility + 12,
                special_ability: pet_stats.special_ability,
                energy: pet_stats.max_energy, // Full energy after evolution
                evolution_stage: pet_stats.evolution_stage + 1,
                in_combat: false,
                max_energy: pet_stats.max_energy + 20,
                experience: 0, // Reset experience after evolution
                next_evolution_at: pet_stats.next_evolution_at + 100, // Next evolution requires more XP
            };
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
            if pet_stats.energy >= 15 {
                // Calculate heal amount based on pet stats
                let heal_amount = (pet_stats.intelligence + pet_stats.loyalty) / 3;
                
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
} 