#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct LegArmor {
    #[key]
    pub asset_id: u256,
    pub defense: u64,
    pub durability: u64,
    pub max_durability: u64,
    pub speed_modifier: i8,
}

#[generate_trait]
pub impl LegArmorImpl of LegArmorTrait {
    fn init(ref self: LegArmor, asset_id: u256, defense: u64, durability: u64, speed_modifier: i8) {
        self.asset_id = asset_id;
        self.defense = defense;
        self.durability = durability;
        self.max_durability = durability;
        self.speed_modifier = speed_modifier;
    }

    fn apply_damage(ref self: LegArmor, damage: u64) -> u64 {
        let absorbed = core::cmp::min(damage, self.defense);
        if absorbed > 0 && self.durability > 0 {
            self.durability -= 1;
        }
        damage - absorbed
    }

    fn is_broken(self: @LegArmor) -> bool {
        *self.durability == 0
    }
}
