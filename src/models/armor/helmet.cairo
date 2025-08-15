#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Helmet {
    #[key]
    pub asset_id: u256,
    pub defense: u64,
    pub durability: u64,
    pub max_durability: u64,
    pub vision_bonus: i8,
}

#[generate_trait]
pub impl HelmetImpl of HelmetTrait {
    fn init(ref self: Helmet, asset_id: u256, defense: u64, durability: u64, vision_bonus: i8) {
        self.asset_id = asset_id;
        self.defense = defense;
        self.durability = durability;
        self.max_durability = durability;
        self.vision_bonus = vision_bonus;
    }

    fn apply_damage(ref self: Helmet, damage: u64) -> u64 {
        let reduction = self.defense;
        let absorbed = if damage > reduction {
            reduction
        } else {
            damage
        };
        if self.durability > 0 {
            self.durability -= 1;
        }
        damage - absorbed
    }

    fn is_broken(self: @Helmet) -> bool {
        *self.durability == 0
    }
}
