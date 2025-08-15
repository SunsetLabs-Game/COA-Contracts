#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Shield {
    #[key]
    pub asset_id: u256,
    pub block_chance: u8,
    pub block_amount: u64,
    pub durability: u64,
    pub max_durability: u64,
}

#[generate_trait]
pub impl ShieldImpl of ShieldTrait {
    fn init(
        ref self: Shield, asset_id: u256, block_chance: u8, block_amount: u64, durability: u64,
    ) {
        self.asset_id = asset_id;
        self.block_chance = block_chance;
        self.block_amount = block_amount;
        self.durability = durability;
        self.max_durability = durability;
    }

    fn attempt_block(ref self: Shield, damage: u64) -> u64 {
        if self.durability == 0 {
            return damage;
        }

        let blocked_damage = if damage > self.block_amount {
            self.block_amount
        } else {
            damage
        };
        self.durability -= 1;
        damage - blocked_damage
    }

    fn is_broken(self: @Shield) -> bool {
        *self.durability == 0
    }
}
