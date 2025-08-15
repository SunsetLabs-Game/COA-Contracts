#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Bow {
    #[key]
    pub asset_id: u256,
    pub damage: u64,
    pub range: u64,
    pub draw_speed: u64,
    pub accuracy: u8,
}

#[generate_trait]
pub impl BowImpl of BowTrait {
    fn init(ref self: Bow, asset_id: u256, damage: u64, range: u64, draw_speed: u64, accuracy: u8) {
        self.asset_id = asset_id;
        self.damage = damage;
        self.range = range;
        self.draw_speed = draw_speed;
        self.accuracy = accuracy;
    }

    fn get_effective_range_damage(self: @Bow, distance: u64) -> u64 {
        let range = *self.range;
        if range == 0 {
            return 0;
        }
        if distance > range {
            return 0;
        }
        // Linear damage falloff with u128 intermediates:
        // damage - ((damage * distance / range) / 2)
        let dmg128: u128 = (*self.damage).into();
        let scaled = (dmg128 * distance.into()) / range.into();
        let falloff = scaled / 2_u128;
        (dmg128 - falloff).try_into().unwrap()
    }
}
