use crate::models::position::{Position, PositionHistory, MovementType};

#[starknet::interface]
pub trait IPosition<TContractState> {
    fn move_player(
        ref self: TContractState,
        player_id: felt252,
        movement_type: MovementType,
        new_x: u32,
        new_y: u32,
        new_z: u32,
    );

    fn get_player_position(self: @TContractState, player_id: felt252) -> Position;

    fn get_players_in_area(
        self: @TContractState, center_x: u32, center_y: u32, center_z: u32, radius: u32,
    ) -> Array<Position>;

    fn validate_movement(
        self: @TContractState,
        player_id: felt252,
        from: Position,
        to: Position,
        movement_type: MovementType,
    ) -> bool;

    fn check_collision(self: @TContractState, x: u32, y: u32, z: u32) -> bool;

    fn calculate_movement_distance(self: @TContractState, from: Position, to: Position) -> u32;

    fn add_position_history(
        ref self: TContractState,
        player_id: felt252,
        position: Position,
        timestamp: u64,
        movement_type: MovementType,
    );

    fn get_position_history(
        self: @TContractState, player_id: felt252, limit: u32,
    ) -> Array<PositionHistory>;

    fn cleanup_old_history(ref self: TContractState, player_id: felt252, keep_last: u32);
}

#[dojo::contract]
pub mod PositionActions {
    use starknet::get_block_timestamp;
    use crate::models::position::{Position, PositionHistory, MovementType, PlayerMoved};
    use super::IPosition;
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;
    use core::array::ArrayTrait;

    // Movement constraints
    const MAX_MOVEMENT_DISTANCE: u32 = 100;
    const WORLD_MIN_X: u32 = 0;
    const WORLD_MAX_X: u32 = 10000;
    const WORLD_MIN_Y: u32 = 0;
    const WORLD_MAX_Y: u32 = 10000;
    const WORLD_MIN_Z: u32 = 0;
    const WORLD_MAX_Z: u32 = 1000;

    // History management
    const MAX_HISTORY_ENTRIES: u32 = 1000;
    const HISTORY_CLEANUP_THRESHOLD: u32 = 1200;

    #[abi(embed_v0)]
    impl PositionActionsImpl of IPosition<ContractState> {
        fn move_player(
            ref self: ContractState,
            player_id: felt252,
            movement_type: MovementType,
            new_x: u32,
            new_y: u32,
            new_z: u32,
        ) {
            let mut world = self.world_default();

            // Read current position (default if none)
            let mut current: Position = world.read_model(player_id);

            let from_x = current.x;
            let from_y = current.y;
            let from_z = current.z;

            let from = current;
            let to = Position {
                player_id, x: new_x, y: new_y, z: new_z, last_updated: from.last_updated,
            };

            // Centralized validation (see validate_movement)
            assert(self.validate_movement(player_id, from, to, movement_type), 'INVALID_MOVE');

            // Write new position
            let ts = get_block_timestamp();
            let updated = Position { player_id, x: new_x, y: new_y, z: new_z, last_updated: ts };
            world.write_model(@updated);

            // Record history and emit event
            self.add_position_history(player_id, updated, ts, movement_type);
            let moved = PlayerMoved {
                player_id,
                from_x,
                from_y,
                from_z,
                to_x: new_x,
                to_y: new_y,
                to_z: new_z,
                movement_type,
                timestamp: ts,
            };
            world.emit_event(@moved);
        }

        fn get_player_position(self: @ContractState, player_id: felt252) -> Position {
            let world = self.world_default();
            let pos: Position = world.read_model(player_id);
            assert(pos.last_updated != 0, 'PLAYER_NOT_FOUND');
            pos
        }

        fn get_players_in_area(
            self: @ContractState, center_x: u32, center_y: u32, center_z: u32, radius: u32,
        ) -> Array<Position> {
            // Placeholder: requires indexing
            let result: Array<Position> = array![];
            result
        }

        fn validate_movement(
            self: @ContractState,
            player_id: felt252,
            from: Position,
            to: Position,
            movement_type: MovementType,
        ) -> bool {
            if !(to.x >= WORLD_MIN_X && to.x <= WORLD_MAX_X) {
                return false;
            }
            if !(to.y >= WORLD_MIN_Y && to.y <= WORLD_MAX_Y) {
                return false;
            }
            if !(to.z >= WORLD_MIN_Z && to.z <= WORLD_MAX_Z) {
                return false;
            }
            // Allow first spawn anywhere.
            if from.last_updated != 0 {
                // Allow special movement types to bypass distance limits.
                match movement_type {
                    MovementType::Teleport | MovementType::Respawn | MovementType::Forced => {},
                    _ => {
                        let distance: u32 = self.calculate_movement_distance(from, to);
                        if distance > MAX_MOVEMENT_DISTANCE {
                            return false;
                        }
                    },
                }
            }
            if self.check_collision(to.x, to.y, to.z) {
                return false;
            }
            true
        }

        fn check_collision(self: @ContractState, x: u32, y: u32, z: u32) -> bool {
            // No obstacles model yet
            false
        }

        fn calculate_movement_distance(self: @ContractState, from: Position, to: Position) -> u32 {
            let dx = if to.x >= from.x {
                to.x - from.x
            } else {
                from.x - to.x
            };
            let dy = if to.y >= from.y {
                to.y - from.y
            } else {
                from.y - to.y
            };
            let dz = if to.z >= from.z {
                to.z - from.z
            } else {
                from.z - to.z
            };
            dx + dy + dz
        }

        fn add_position_history(
            ref self: ContractState,
            player_id: felt252,
            position: Position,
            timestamp: u64,
            movement_type: MovementType,
        ) {
            let mut world = self.world_default();
            // Use timestamp as the base and increment to avoid collisions within the same second.
            let ts: u64 = timestamp;
            let mut seq: u64 = ts;
            loop {
                let existing: PositionHistory = world.read_model((player_id, seq));
                if existing.timestamp == 0_u64 {
                    break;
                }
                seq += 1_u64;
            };
            let history = PositionHistory {
                player_id,
                sequence: seq,
                subsequence: 0,
                x: position.x,
                y: position.y,
                z: position.z,
                timestamp,
                movement_type,
            };
            world.write_model(@history);
        }

        fn get_position_history(
            self: @ContractState, player_id: felt252, limit: u32,
        ) -> Array<PositionHistory> {
            let world = self.world_default();
            let now = get_block_timestamp();
            let mut seq: u64 = now;
            let mut collected: u32 = 0;
            let mut result: Array<PositionHistory> = array![];
            loop {
                if collected >= limit {
                    break;
                }
                // Bound search window to 1h worth of seconds to limit gas
                if seq <= now && (now - seq) > 3600_u64 {
                    break;
                }
                let entry: PositionHistory = world.read_model((player_id, seq));
                if entry.timestamp != 0 {
                    result.append(entry);
                    collected += 1;
                }
                if seq == 0 {
                    break;
                }
                seq -= 1_u64;
            };
            result
        }

        fn cleanup_old_history(ref self: ContractState, player_id: felt252, keep_last: u32) {
            let mut world = self.world_default();
            let now = get_block_timestamp();
            let mut seq: u64 = now;
            let mut kept: u32 = 0;
            let mut scanned: u32 = 0;
            loop {
                if scanned >= HISTORY_CLEANUP_THRESHOLD {
                    break;
                }
                let entry: PositionHistory = world.read_model((player_id, seq));
                if entry.timestamp != 0 {
                    if kept < keep_last {
                        kept += 1;
                    }
                }
                scanned += 1;
                if seq == 0 {
                    break;
                }
                seq -= 1_u64;
            };
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"coa")
        }
    }
}
