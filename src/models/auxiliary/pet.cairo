#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Pet {
    #[key]
    pub asset_id: u256,
    pub health: u64,
    pub max_health: u64,
    pub attack: u64,
    pub special_ability_id: u32,
}

#[generate_trait]
pub impl PetImpl of PetTrait {
    fn init(ref self: Pet, asset_id: u256, health: u64, attack: u64, special_ability_id: u32) {
        self.asset_id = asset_id;
        self.health = health;
        self.max_health = health;
        self.attack = attack;
        self.special_ability_id = special_ability_id;
    }

    fn take_damage(ref self: Pet, damage: u64) {
        if self.health >= damage {
            self.health -= damage;
        } else {
            self.health = 0;
        }
    }

    fn heal(ref self: Pet, amount: u64) {
        // Avoid overflow by checking the headroom first.
        if amount > self.max_health - self.health {
            self.health = self.max_health;
        } else {
            self.health += amount;
        }
    }

    fn is_incapacitated(self: @Pet) -> bool {
        *self.health == 0
    }
}
