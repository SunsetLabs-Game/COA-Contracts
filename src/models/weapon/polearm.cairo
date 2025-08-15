#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Polearm {
    #[key]
    pub asset_id: u256,
    pub damage: u64,
    pub range: u64,
    pub speed: u64,
    pub can_sweep: bool, // Can hit multiple targets
    pub durability: u64,
    pub max_durability: u64,
}

#[generate_trait]
pub impl PolearmImpl of PolearmTrait {
    fn init(
        ref self: Polearm,
        asset_id: u256,
        damage: u64,
        range: u64,
        speed: u64,
        can_sweep: bool,
        durability: u64,
    ) {
        self.asset_id = asset_id;
        self.damage = damage;
        self.range = range;
        self.speed = speed;
        self.can_sweep = can_sweep;
        self.durability = durability;
        self.max_durability = durability;
    }

    fn apply_wear(ref self: Polearm, amount: u64) {
        if self.durability >= amount {
            self.durability -= amount;
        } else {
            self.durability = 0;
        }
    }

    fn is_broken(self: @Polearm) -> bool {
        *self.durability == 0
    }
}
