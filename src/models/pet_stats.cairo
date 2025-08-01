#[dojo::model]
#[derive(Drop, Copy, Default, Serde)]
pub struct PetStats {
    #[key]
    pub asset_id: u256,
    pub loyalty: u64,
    pub intelligence: u64,
    pub agility: u64,
    pub special_ability: felt252,
    pub energy: u64,
    // Evolución y estado de combate
    pub evolution_stage: u8, // 0 = base, 1 = evolved, etc.
    pub in_combat: bool,
    pub max_energy: u64,
    pub experience: u64,
    pub next_evolution_at: u64,
}
