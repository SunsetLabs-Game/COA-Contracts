#[dojo::model]
#[derive(Drop, Copy, Serde, Default)]
pub struct Position {
    #[key]
    pub player_id: felt252,
    pub x: u32,
    pub y: u32,
    pub z: u32,
    pub last_updated: u64,
}

#[dojo::model]
#[derive(Copy, Drop, Serde)]
pub struct PositionHistory {
    #[key]
    pub player_id: felt252,
    #[key]
    pub sequence: u64,
    #[key]
    pub subsequence: u32,
    pub x: u32,
    pub y: u32,
    pub z: u32,
    pub timestamp: u64,
    pub movement_type: MovementType,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum MovementType {
    Walk,
    Run,
    Teleport,
    Respawn,
    Forced,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct PlayerMoved {
    #[key]
    pub player_id: felt252,
    pub from_x: u32,
    pub from_y: u32,
    pub from_z: u32,
    pub to_x: u32,
    pub to_y: u32,
    pub to_z: u32,
    pub movement_type: MovementType,
    pub timestamp: u64,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct PlayersInProximity {
    #[key]
    pub player1: felt252,
    #[key]
    pub player2: felt252,
    pub distance: u32,
}
