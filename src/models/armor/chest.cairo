#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct ChestArmor {
    #[key]
    pub asset_id: u256,
    pub defense: u64,
    pub durability: u64,
    pub max_durability: u64,
    pub weight: u64,
}

#[generate_trait]
pub impl ChestArmorImpl of ChestArmorTrait {
    fn init(ref self: ChestArmor, asset_id: u256, defense: u64, durability: u64, weight: u64) {
        self.asset_id = asset_id;
        self.defense = defense;
        self.durability = durability;
        self.max_durability = durability;
        self.weight = weight;
    }

    fn apply_damage(ref self: ChestArmor, damage: u64) -> u64 {
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

    fn is_broken(self: @ChestArmor) -> bool {
        *self.durability == 0
    }
}
