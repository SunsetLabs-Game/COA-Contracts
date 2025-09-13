pub mod systems {
    pub mod player;
    pub mod core;
    pub mod gear;
    pub mod armour;
    pub mod pet;
    pub mod tournament;
    pub mod guild;
    pub mod session;
    pub mod position;
}

pub mod erc1155 {
    pub mod erc1155;
}

pub mod gear {
    pub mod GearActions;
}

pub mod models {
    pub mod player;
    pub mod core;
    pub mod gear;
    pub mod armour;
    pub mod position;
    pub mod marketplace;
    pub mod weapon_stats;
    pub mod armor_stats;
    pub mod vehicle_stats;
    pub mod pet_stats;
    pub mod tournament;
    pub mod guild;
    pub mod session;
    pub mod weapon {
        pub mod blunt;
        pub mod bow;
        pub mod explosives;
        pub mod firearm;
        pub mod heavy_firearm;
        pub mod polearm;
        pub mod sword;
    }
    pub mod armor {
        pub mod boots;
        pub mod chest;
        pub mod gloves;
        pub mod helmet;
        pub mod leg;
        pub mod shield;
    }
    pub mod auxiliary {
        pub mod drone;
        pub mod pet;
    }
    pub mod vehicle {
        pub mod base;
    }
}

pub mod interfaces {
    pub mod gear;
}

pub mod helpers {
    pub mod base;
    pub mod gear;
    pub mod body;
    pub mod session_validation;
}

pub mod types {
    pub mod base;
    pub mod player;
}

pub mod market {
    pub mod marketplace;
    pub mod interface;
}

pub mod test {
    pub mod session_system_test;
    pub mod pick_item_test;
    pub mod player_session_integration_test;
    pub mod session_helper_test;
    pub mod test_exchange_items;
    pub mod test_unequip;
    pub mod upgrade_gear_test;
    pub mod gear_read_test;
    pub mod model_test_player;
}

pub mod traits {
    pub mod pet_trait;
}

// Store system - Sistema de tiendas con arquitectura ECS
pub mod store;
