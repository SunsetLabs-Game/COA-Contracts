pub mod systems {
    pub mod player;
    pub mod core;
    pub mod gear;
    pub mod armour;
    pub mod pet;
}

pub mod erc1155 {
    pub mod erc1155;
}

pub mod models {
    pub mod player;
    pub mod core;
    pub mod gear;
    pub mod armour;
    pub mod market;
    pub mod weapon_stats;
    pub mod armor_stats;
    pub mod vehicle_stats;
    pub mod pet_stats;
}

pub mod interfaces {
    pub mod gear;
}

pub mod helpers {
    pub mod base;
    pub mod gear;
}

pub mod types {
    pub mod base;
    pub mod player;
}

pub mod market {
    pub mod marketplace;
    pub mod interface;
}

pub mod tests {}

pub mod traits {
    pub mod pet_trait;
}

// Store system - Sistema de tiendas con arquitectura ECS
pub mod store;
