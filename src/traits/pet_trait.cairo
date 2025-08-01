use crate::models::pet_stats::PetStats;

// Companion helper functions
pub fn attack(pet_stats: @PetStats, target: u256) -> u64 {
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

pub fn heal(pet_stats: @PetStats) -> u64 {
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

pub fn travel(pet_stats: @PetStats, destination: felt252) -> bool {
    // Check if pet has enough energy for travel
    if *pet_stats.energy < 10 {
        return false;
    }

    // High agility pets can travel better
    (*pet_stats.agility) > 50
}

pub fn evolve(pet_stats: @PetStats) -> PetStats {
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

pub fn can_evolve(pet_stats: @PetStats) -> bool {
    // Can evolve if has enough experience and not at max evolution stage
    *pet_stats.experience >= *pet_stats.next_evolution_at && *pet_stats.evolution_stage < 3
}
