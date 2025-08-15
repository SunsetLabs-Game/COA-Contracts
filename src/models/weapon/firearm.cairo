#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Firearm {
    #[key]
    pub asset_id: u256,
    pub damage: u64,
    pub range: u64,
    pub accuracy: u8,
    pub fire_rate: u64,
    pub ammo_capacity: u32,
    pub reload_speed: u64,
}

#[generate_trait]
pub impl FirearmImpl of FirearmTrait {
    fn init(
        ref self: Firearm,
        asset_id: u256,
        damage: u64,
        range: u64,
        accuracy: u8,
        fire_rate: u64,
        ammo_capacity: u32,
        reload_speed: u64,
    ) {
        self.asset_id = asset_id;
        self.damage = damage;
        self.range = range;
        self.accuracy = accuracy;
        self.fire_rate = fire_rate;
        self.ammo_capacity = ammo_capacity;
        self.reload_speed = reload_speed;
    }

    fn calculate_dps(self: @Firearm) -> u64 {
        // Using u128 intermediate to avoid overflow on multiplication.
        let dmg128: u128 = (*self.damage).into();
        let rate128: u128 = (*self.fire_rate).into();
        let dps128 = (dmg128 * rate128) / 60_u128;
        // Safe to cast back given domain constraints;
        dps128.try_into().unwrap()
    }
}
