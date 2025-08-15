#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Gloves {
    #[key]
    pub asset_id: u256,
    pub defense: u64,
    pub attack_speed_bonus: u8,
    pub reload_speed_bonus: u8,
    pub durability: u64,
    pub max_durability: u64,
}

#[generate_trait]
pub impl GlovesImpl of GlovesTrait {
    fn init(
        ref self: Gloves,
        asset_id: u256,
        defense: u64,
        attack_speed_bonus: u8,
        reload_speed_bonus: u8,
        durability: u64,
    ) {
        self.asset_id = asset_id;
        self.defense = defense;
        self.attack_speed_bonus = attack_speed_bonus;
        self.reload_speed_bonus = reload_speed_bonus;
        self.durability = durability;
        self.max_durability = durability;
    }

    fn apply_wear(ref self: Gloves, amount: u64) {
        if self.durability >= amount {
            self.durability -= amount;
        } else {
            self.durability = 0;
        }
    }

    fn is_broken(self: @Gloves) -> bool {
        *self.durability == 0
    }
}
