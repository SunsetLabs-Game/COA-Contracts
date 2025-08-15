#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct BluntWeapon {
    #[key]
    pub asset_id: u256,
    pub damage: u64,
    pub speed: u64,
    pub stun_chance: u8,
    pub durability: u64,
    pub max_durability: u64,
}

#[generate_trait]
pub impl BluntWeaponImpl of BluntWeaponTrait {
    fn init(
        ref self: BluntWeapon,
        asset_id: u256,
        damage: u64,
        speed: u64,
        stun_chance: u8,
        durability: u64,
    ) {
        self.asset_id = asset_id;
        self.damage = damage;
        self.speed = speed;
        self.stun_chance = stun_chance;
        self.durability = durability;
        self.max_durability = durability;
    }

    fn calculate_dps(self: @BluntWeapon) -> u64 {
        // Using u128 intermediates to avoid overflow.
        let product: u128 = (*self.damage).into() * (*self.speed).into();
        let dps128: u128 = product / 100_u128;
        // Saturate to u64::MAX if downcast overflows.
        match dps128.try_into() {
            Option::Some(v) => v,
            Option::None => 18446744073709551615_u64 // u64::MAX
        }
    }

    fn apply_wear(ref self: BluntWeapon, amount: u64) {
        if self.durability >= amount {
            self.durability -= amount;
        } else {
            self.durability = 0;
        }
    }

    fn repair(ref self: BluntWeapon, amount: u64) {
        let room = if self.max_durability > self.durability {
            self.max_durability - self.durability
        } else {
            0
        };
        let inc = if amount > room {
            room
        } else {
            amount
        };
        self.durability += inc;
    }

    fn is_broken(self: @BluntWeapon) -> bool {
        *self.durability == 0
    }
}
