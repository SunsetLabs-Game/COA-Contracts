#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Sword {
    #[key]
    pub asset_id: u256,
    pub damage: u64,
    pub speed: u64,
    pub sharpness: u64, // Affects armor penetration
    pub durability: u64,
    pub max_durability: u64,
}

#[generate_trait]
pub impl SwordImpl of SwordTrait {
    fn init(
        ref self: Sword, asset_id: u256, damage: u64, speed: u64, sharpness: u64, durability: u64,
    ) {
        self.asset_id = asset_id;
        self.damage = damage;
        self.speed = speed;
        self.sharpness = sharpness;
        self.durability = durability;
        self.max_durability = durability;
    }

    fn get_armor_penetration_bonus(self: @Sword) -> u64 {
        *self.sharpness / 10
    }

    fn apply_wear(ref self: Sword, amount: u64) {
        if self.durability >= amount {
            self.durability -= amount;
        } else {
            self.durability = 0;
        }
    }

    fn is_broken(self: @Sword) -> bool {
        *self.durability == 0
    }
}
