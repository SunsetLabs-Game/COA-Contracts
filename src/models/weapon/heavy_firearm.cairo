#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct HeavyFirearm {
    #[key]
    pub asset_id: u256,
    pub damage: u64,
    pub area_of_effect: u64,
    pub fire_rate: u64,
    pub ammo_capacity: u32,
    pub mobility_penalty: u8,
}

#[generate_trait]
pub impl HeavyFirearmImpl of HeavyFirearmTrait {
    fn init(
        ref self: HeavyFirearm,
        asset_id: u256,
        damage: u64,
        area_of_effect: u64,
        fire_rate: u64,
        ammo_capacity: u32,
        mobility_penalty: u8,
    ) {
        self.asset_id = asset_id;
        self.damage = damage;
        self.area_of_effect = area_of_effect;
        self.fire_rate = fire_rate;
        self.ammo_capacity = ammo_capacity;
        self.mobility_penalty = mobility_penalty;
    }

    fn get_mobility_penalty(self: @HeavyFirearm) -> u8 {
        *self.mobility_penalty
    }
}
