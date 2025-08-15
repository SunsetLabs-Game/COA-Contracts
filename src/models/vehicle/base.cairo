#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct Vehicle {
    #[key]
    pub asset_id: u256,
    pub health: u64,
    pub max_health: u64,
    pub armor: u64,
    pub speed: u64,
    pub fuel_capacity: u64,
    pub current_fuel: u64,
    pub passenger_capacity: u8,
}

#[generate_trait]
pub impl VehicleImpl of VehicleTrait {
    fn init(
        ref self: Vehicle,
        asset_id: u256,
        health: u64,
        armor: u64,
        speed: u64,
        fuel_capacity: u64,
        passenger_capacity: u8,
    ) {
        self.asset_id = asset_id;
        self.health = health;
        self.max_health = health;
        self.armor = if armor > 100_u64 {
            100_u64
        } else {
            armor
        };
        self.speed = speed;
        self.fuel_capacity = fuel_capacity;
        self.current_fuel = fuel_capacity;
        self.passenger_capacity = passenger_capacity;
    }

    fn apply_damage(ref self: Vehicle, damage: u64) {
        // Cap armor effectiveness to 100% and use u64-typed literals.
        let capped_armor = if self.armor > 100_u64 {
            100_u64
        } else {
            self.armor
        };
        let absorbed_damage = damage * capped_armor / 100_u64;
        // Saturate to zero if absorbed_damage > damage to avoid underflow.
        let net_damage = if absorbed_damage <= damage {
            damage - absorbed_damage
        } else {
            0_u64
        };
        if self.health >= net_damage {
            self.health -= net_damage;
        } else {
            self.health = 0_u64;
        }
    }

    fn consume_fuel(ref self: Vehicle, distance: u64) {
        // 1 unit of fuel per 10 units of distance
        let fuel_consumed = distance / 10;
        if self.current_fuel >= fuel_consumed {
            self.current_fuel -= fuel_consumed;
        } else {
            self.current_fuel = 0;
        }
    }

    fn refuel(ref self: Vehicle, amount: u64) {
        // Add only up to the remaining capacity to prevent overflow.
        let available = if self.fuel_capacity > self.current_fuel {
            self.fuel_capacity - self.current_fuel
        } else {
            0_u64
        };
        let to_add = if amount > available {
            available
        } else {
            amount
        };
        self.current_fuel += to_add;
    }

    fn repair(ref self: Vehicle, amount: u64) {
        // Add only up to the remaining health to prevent overflow.
        let remaining = if self.max_health > self.health {
            self.max_health - self.health
        } else {
            0_u64
        };
        let to_add = if amount > remaining {
            remaining
        } else {
            amount
        };
        self.health += to_add;
    }

    fn is_destroyed(self: @Vehicle) -> bool {
        *self.health == 0
    }

    fn needs_fuel(self: @Vehicle) -> bool {
        *self.current_fuel == 0
    }
}
