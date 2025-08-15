#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Drone {
    #[key]
    pub asset_id: u256,
    pub health: u64,
    pub max_health: u64,
    pub range: u64,
    pub battery_life: u64,
    pub max_battery_life: u64,
    pub surveillance_level: u8,
}

#[generate_trait]
pub impl DroneImpl of DroneTrait {
    fn init(
        ref self: Drone,
        asset_id: u256,
        health: u64,
        range: u64,
        battery_life: u64,
        surveillance_level: u8,
    ) {
        self.asset_id = asset_id;
        self.health = health;
        self.max_health = health;
        self.range = range;
        self.battery_life = battery_life;
        self.max_battery_life = battery_life;
        self.surveillance_level = surveillance_level;
    }

    fn take_damage(ref self: Drone, damage: u64) {
        if self.health >= damage {
            self.health -= damage;
        } else {
            self.health = 0;
        }
    }

    fn consume_battery(ref self: Drone, time_active: u64) {
        if self.battery_life >= time_active {
            self.battery_life -= time_active;
        } else {
            self.battery_life = 0;
        }
    }

    fn recharge(ref self: Drone, amount: u64) {
        // Avoid overflow: compare against remaining capacity first
        let remaining = if self.max_battery_life >= self.battery_life {
            self.max_battery_life - self.battery_life
        } else {
            0
        };
        if amount >= remaining {
            self.battery_life = self.max_battery_life;
        } else {
            self.battery_life += amount;
        }
    }

    fn is_destroyed(self: @Drone) -> bool {
        *self.health == 0
    }

    fn needs_charge(self: @Drone) -> bool {
        *self.battery_life == 0
    }
}
