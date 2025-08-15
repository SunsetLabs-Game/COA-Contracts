#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Boots {
    #[key]
    pub asset_id: u256,
    pub defense: u64,
    pub speed_bonus: u8,
    pub jump_height_bonus: u8,
    pub durability: u64,
    pub max_durability: u64,
}

#[generate_trait]
pub impl BootsImpl of BootsTrait {
    fn init(
        ref self: Boots,
        asset_id: u256,
        defense: u64,
        speed_bonus: u8,
        jump_height_bonus: u8,
        durability: u64,
    ) {
        self.asset_id = asset_id;
        self.defense = defense;
        self.speed_bonus = speed_bonus;
        self.jump_height_bonus = jump_height_bonus;
        self.durability = durability;
        self.max_durability = durability;
    }

    fn apply_wear(ref self: Boots, amount: u64) {
        if self.durability >= amount {
            self.durability -= amount;
        } else {
            self.durability = 0;
        }
    }

    fn is_broken(self: @Boots) -> bool {
        *self.durability == 0
    }
}
