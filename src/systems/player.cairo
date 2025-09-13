use crate::models::{player::Player};

#[starknet::interface]
pub trait IPlayer<TContractState> {
    fn new(ref self: TContractState, faction: felt252, session_id: felt252);
    fn deal_damage(
        ref self: TContractState,
        target: Array<u256>,
        target_types: Array<felt252>,
        with_items: Array<u256>,
        session_id: felt252,
    );
    fn batch_deal_damage(
        ref self: TContractState,
        batch_targets: Array<Array<u256>>,
        batch_target_types: Array<Array<felt252>>,
        batch_with_items: Array<Array<u256>>,
        session_id: felt252,
    );
    fn get_player(self: @TContractState, player_id: u256, session_id: felt252) -> Player;
    fn register_guild(ref self: TContractState, session_id: felt252);
    fn transfer_objects(
        ref self: TContractState,
        object_ids: Array<u256>,
        to: starknet::ContractAddress,
        session_id: felt252,
    );
    fn refresh(ref self: TContractState, player_id: u256, session_id: felt252);
}

#[dojo::contract]
pub mod PlayerActions {
    use core::num::traits::Zero;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use crate::models::player::{
        Player, PlayerTrait, DamageDealt, PlayerDamaged, FactionStats, PlayerInitialized,
        CombatSessionStarted, BatchDamageProcessed, CombatSessionEnded, DamageAccumulator,
    };
    use crate::models::gear::{Gear, GearLevelStats, ItemRarity, GearType};
    use crate::models::armour::{Armour, ArmourTrait};
    use crate::erc1155::erc1155::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use super::IPlayer;
    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;
    // Import session model for validation
    use crate::models::session::SessionKey;
    // Import session validation helpers
    use crate::helpers::session_validation::{
        validate_combat_session, consume_combat_session_transactions,
    };
    use crate::helpers::gear::parse_id;

    // Faction types as felt252 constants
    const CHAOS_MERCENARIES: felt252 = 'CHAOS_MERCENARIES';
    const SUPREME_LAW: felt252 = 'SUPREME_LAW';
    const REBEL_TECHNOMANCERS: felt252 = 'REBEL_TECHNOMANCERS';

    // Target types as felt252 constants
    const TARGET_LIVING: felt252 = 'LIVING';
    const TARGET_OBJECT: felt252 = 'OBJECT';

    // Armor type constants (high 128 bits)
    const ARMOR_HELMET: u128 = 0x2000;
    const ARMOR_CHESTPLATE: u128 = 0x2001;
    const ARMOR_LEGGINGS: u128 = 0x2002;
    const ARMOR_BOOTS: u128 = 0x2003;
    const ARMOR_GLOVES: u128 = 0x2004;
    const ARMOR_SHIELD: u128 = 0x2005;

    // const GEAR_
    const MIN_THRESHOLD: u32 = 80;

    fn dojo_init(
        ref self: ContractState, admin: ContractAddress, default_amount_of_credits: u256,
    ) { // write admin
    // write default amount of credits.

    }

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IPlayer<ContractState> {
        fn new(
            ref self: ContractState, faction: felt252, session_id: felt252,
        ) { // create the player
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut player: Player = world.read_model(caller);

            if player.max_hp == 0 {
                return;
            }
            player.init(faction);
            world.write_model(@player);
            let event = PlayerInitialized { player_id: caller, faction };
            world.emit_event(@event);
        }

        fn deal_damage(
            ref self: ContractState,
            target: Array<u256>,
            target_types: Array<felt252>,
            with_items: Array<u256>,
            session_id: felt252,
        ) { // check if the player and the items exists..
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
            // assert that the items are something that can deal damage
            // from no. 2, not just assert, handle appropriately, but do not panic
            // factor in the faction type and add additional damage
            // factor in the weapon type and xp // rank trait.
            // and factor in the item type, if the item has been upgraded
            // check if the item has been equipped
            // to find out the item's output when upgraded, call the item.output(val), where val is
            // the upgraded level.

            // if with_items.len() is zero, then it's a normal melee attack.

            // factor in the target's damage factor... might later turn out not to be damaged
            // this means that each target or item should have a damage factor, and might cause
            // credits to be repaired

            // for the target, the above is if the target_type is an object.
            // if the target type is a living organism, check all the eqippable traits
            // this means that the PlayerTrait should have a recieve_damage,

            // or recieve damage should probably be an internal trait for now.

            let mut world = self.world_default();
            let caller = get_caller_address();
            // get the player
            let player: Player = world.read_model(caller);

            // Validate input arrays have same length
            assert(target.len() == target_types.len(), 'Target arrays length mismatch');

            let mut target_index = 0;

            // Calculate faction bonuses
            let faction_stats = self.get_faction_stats(player.faction);

            loop {
                if target_index >= target.len() {
                    break;
                }

                let target_id = *target.at(target_index);
                let target_type = *target_types.at(target_index);

                // Calculate base damage
                let mut total_damage = 0;

                if with_items.len() == 0 {
                    // Normal melee attack
                    total_damage = self.calculate_melee_damage(player.clone(), faction_stats);
                } else {
                    // Weapon-based attack
                    total_damage = self
                        .calculate_weapon_damage(player.clone(), with_items.span(), faction_stats);
                }

                // Apply the damage
                self.damage_target(target_id, target_type, total_damage);
                let event = DamageDealt {
                    attacker: caller, target: target_id, damage: total_damage, target_type,
                };
                world.emit_event(@event);
                target_index += 1;
            };
        }

        fn batch_deal_damage(
            ref self: ContractState,
            batch_targets: Array<Array<u256>>,
            batch_target_types: Array<Array<felt252>>,
            batch_with_items: Array<Array<u256>>,
            session_id: felt252,
        ) {
            // Get current time and caller
            let current_time = get_block_timestamp();
            let caller = get_caller_address();
            let mut world = self.world_default();

            // Calculate total expected actions for session validation
            let total_actions = batch_targets.len();
            assert(total_actions > 0, 'NO_ACTIONS_PROVIDED');
            assert(batch_targets.len() == batch_target_types.len(), 'BATCH_LENGTH_MISMATCH');
            assert(batch_targets.len() == batch_with_items.len(), 'ITEMS_LENGTH_MISMATCH');

            // Read session from storage
            let session: SessionKey = world.read_model((session_id, caller));

            // Validate combat session once for entire batch
            let (is_valid, updated_session) = validate_combat_session(
                session, caller, total_actions, current_time,
            );
            assert(is_valid, 'INVALID_COMBAT_SESSION');

            // Emit combat session started event
            let combat_started_event = CombatSessionStarted {
                session_id,
                player_address: caller,
                expected_actions: total_actions,
                session_expires_at: updated_session.expires_at,
            };
            world.emit_event(@combat_started_event);

            // Get player and calculate faction stats once
            let player: Player = world.read_model(caller);
            let faction_stats = self.get_faction_stats(player.faction);

            let mut total_damage_dealt = 0;
            let mut actions_executed = 0;
            let mut batch_index = 0;
            let mut total_targets_count = 0;
            let processing_started_at = get_block_timestamp();

            // Process each batch of damage actions
            loop {
                if batch_index >= batch_targets.len() {
                    break;
                }

                let targets = batch_targets.at(batch_index);
                let target_types = batch_target_types.at(batch_index);
                let with_items = batch_with_items.at(batch_index);

                // Validate arrays within each batch
                assert(targets.len() == target_types.len(), 'TARGET_ARRAYS_MISMATCH');

                let mut target_index = 0;
                let mut batch_damage = 0;

                // Process all targets in this batch
                loop {
                    if target_index >= targets.len() {
                        break;
                    }

                    let target_id = *targets.at(target_index);
                    let target_type = *target_types.at(target_index);

                    // Calculate damage for this target
                    let damage = if with_items.len() == 0 {
                        self.calculate_melee_damage(player.clone(), faction_stats)
                    } else {
                        self
                            .calculate_weapon_damage(
                                player.clone(), with_items.span(), faction_stats,
                            )
                    };

                    // Apply damage to target
                    self.damage_target(target_id, target_type, damage);

                    // Emit individual damage event
                    let damage_event = DamageDealt {
                        attacker: caller, target: target_id, damage, target_type,
                    };
                    world.emit_event(@damage_event);

                    batch_damage += damage;
                    target_index += 1;
                };

                total_damage_dealt += batch_damage;
                actions_executed += 1;
                batch_index += 1;
                total_targets_count += targets.len();
            };

            let processing_ended_at = get_block_timestamp();

            // Emit batch damage processed event
            let batch_processed_event = BatchDamageProcessed {
                session_id,
                attacker: caller,
                total_targets: total_targets_count,
                total_damage: total_damage_dealt,
                actions_processed: actions_executed,
            };
            world.emit_event(@batch_processed_event);

            // Update session with consumed transactions
            let final_session = consume_combat_session_transactions(
                updated_session, actions_executed, current_time,
            );
            world.write_model(@final_session);

            // Calculate gas savings (estimated 60% for 10+ actions)
            let gas_saved_percentage = if actions_executed >= 10 {
                60
            } else if actions_executed >= 5 {
                40
            } else {
                20
            };

            // Emit combat session ended event
            let combat_ended_event = CombatSessionEnded {
                session_id,
                player_address: caller,
                total_actions_executed: actions_executed,
                total_damage_dealt,
                session_duration: processing_ended_at - processing_started_at,
                gas_saved_percentage,
            };
            world.emit_event(@combat_ended_event);
        }

        fn get_player(self: @ContractState, player_id: u256, session_id: felt252) -> Player {
            // Validate session before proceeding (read-only validation)
            assert(session_id != 0, 'INVALID_SESSION');

            // Get the caller's address
            let caller = get_caller_address();

            // Read session from storage for validation
            let world = self.world_default();
            let session: SessionKey = world.read_model((session_id, caller));

            // Validate session exists and belongs to caller
            assert(session.session_id != 0, 'SESSION_NOT_FOUND');
            assert(session.player_address == caller, 'UNAUTHORIZED_SESSION');
            assert(session.is_valid, 'SESSION_INVALID');
            assert(session.status == 0, 'SESSION_NOT_ACTIVE');

            // Validate session has not expired
            let current_time = get_block_timestamp();
            assert(current_time < session.expires_at, 'SESSION_EXPIRED');

            // Note: For read operations, we don't increment transaction count
            // to avoid storage writes in read-only functions

            Default::default()
        }

        fn register_guild(ref self: ContractState, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
            // TODO: Implement guild registration logic
        }

        fn transfer_objects(
            ref self: ContractState,
            object_ids: Array<u256>,
            to: ContractAddress,
            session_id: felt252,
        ) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            // Get the caller's address (current owner of the objects)
            let caller = get_caller_address();

            // Get the ERC1155 contract address from the system
            let erc1155_address = self.get_erc1155_address();

            // Transfer each object to the destination address
            let mut i = 0;
            let len = object_ids.len();
            while i < len {
                let object_id = *object_ids.at(i);
                // Transfer the object (with amount 1 for NFTs)
                let erc1155_dispatcher = erc1155(erc1155_address);
                erc1155_dispatcher.safe_transfer_from(caller, to, object_id, 1, array![].span());
                i += 1;
            }
        }

        fn refresh(ref self: ContractState, player_id: u256, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            // Get the player's address
            let player = self.get_player(player_id, session_id);
            let player_address = player.id;

            // Get the ERC1155 contract address
            let erc1155_address = self.get_erc1155_address();

            // Get the list of game object IDs that we need to check
            let game_object_ids = self.get_game_object_ids();

            // Create an ERC1155 dispatcher to interact with the contract
            let erc1155_dispatcher = erc1155(erc1155_address);

            // Check each game object to see if the player has it
            let mut i = 0;
            let len = game_object_ids.len();

            while i < len {
                let object_id = *game_object_ids.at(i);

                // Get the player's balance of this object from the ERC1155 contract
                let balance = erc1155_dispatcher.balance_of(player_address, object_id);

                // If the player has this object in their wallet but not in the game state,
                // update the game state to reflect this
                if balance > 0 {
                    // Check if the object is already registered in the player's inventory
                    let is_registered = self.is_object_registered(player_id, object_id);

                    if !is_registered {
                        // Register the object in the player's inventory
                        self.register_object(player_id, object_id, balance);
                    } else {
                        // Update the object quantity if it has changed
                        self.update_object_quantity(player_id, object_id, balance);
                    }
                }
                i += 1;
            };
            // Emit an event indicating the refresh was completed
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"coa")
        }

        fn validate_session_for_action(ref self: ContractState, session_id: felt252) {
            // Basic validation - session_id must not be zero
            assert(session_id != 0, 'INVALID_SESSION');

            // Get the caller's address
            let caller = get_caller_address();

            // Read session from storage
            let mut world = self.world_default();
            let mut session: SessionKey = world.read_model((session_id, caller));

            // Validate session exists
            assert(session.session_id != 0, 'SESSION_NOT_FOUND');

            // Validate session belongs to the caller
            assert(session.player_address == caller, 'UNAUTHORIZED_SESSION');

            // Validate session is active
            assert(session.is_valid, 'SESSION_INVALID');
            assert(session.status == 0, 'SESSION_NOT_ACTIVE');

            // Validate session has not expired
            let current_time = get_block_timestamp();
            assert(current_time < session.expires_at, 'SESSION_EXPIRED');

            // Validate session has transactions left
            assert(session.used_transactions < session.max_transactions, 'NO_TRANSACTIONS_LEFT');

            // Check if session needs auto-renewal (less than 5 minutes remaining)
            let time_remaining = if current_time >= session.expires_at {
                0
            } else {
                session.expires_at - current_time
            };

            // Auto-renew if less than 5 minutes remaining (300 seconds)
            if time_remaining < 300 {
                // Auto-renew session for 1 hour with 100 transactions
                let mut updated_session = session;
                updated_session.expires_at = current_time + 3600; // 1 hour
                updated_session.last_used = current_time;
                updated_session.max_transactions = 100;
                updated_session.used_transactions = 0; // Reset transaction count

                // Write updated session back to storage
                world.write_model(@updated_session);

                // Update session reference for validation
                session = updated_session;
            }

            // Increment transaction count for this action
            session.used_transactions += 1;
            session.last_used = current_time;

            // Write updated session back to storage
            world.write_model(@session);
        }

        fn get_faction_stats(self: @ContractState, faction: felt252) -> FactionStats {
            if faction == CHAOS_MERCENARIES {
                FactionStats {
                    damage_multiplier: 120, // +20% damage
                    defense_multiplier: 100,
                    speed_multiplier: 100,
                }
            } else if faction == SUPREME_LAW {
                FactionStats {
                    damage_multiplier: 100,
                    defense_multiplier: 125, // +25% defense
                    speed_multiplier: 100,
                }
            } else if faction == REBEL_TECHNOMANCERS {
                FactionStats {
                    damage_multiplier: 100,
                    defense_multiplier: 100,
                    speed_multiplier: 115 // +15% speed (simplified for now)
                }
            } else {
                // Default/no faction
                FactionStats {
                    damage_multiplier: 100, defense_multiplier: 100, speed_multiplier: 100,
                }
            }
        }

        fn calculate_melee_damage(
            self: @ContractState, player: Player, faction_stats: FactionStats,
        ) -> u256 {
            let default_gear = Gear { // Create a default gear for melee
                id: 0,
                item_type: GearType::Weapon.into(),
                asset_id: 0,
                variation_ref: 0,
                total_count: 1,
                in_action: true,
                upgrade_level: 0,
                owner: player.id,
                max_upgrade_level: 1,
                min_xp_needed: 0,
                spawned: true,
            };
            self.calculate_balanced_damage(player, default_gear, faction_stats)
        }

        fn calculate_weapon_damage(
            self: @ContractState, player: Player, items: Span<u256>, faction_stats: FactionStats,
        ) -> u256 {
            let world = self.world_default();
            let mut total_damage = 0;
            let mut item_index = 0;

            loop {
                if item_index >= items.len() {
                    break;
                }

                let item_id = *items.at(item_index);
                let item: Gear = world.read_model(item_id);

                if !self.can_deal_damage(item.clone()) || !player.is_available(item.id) {
                    item_index += 1;
                    continue;
                }

                let weapon_damage = self.calculate_gear_damage(item);
                total_damage += weapon_damage;
                item_index += 1;
            };

            let faction_damage = (total_damage * faction_stats.damage_multiplier) / 100;
            let rank_multiplier = 100 + (player.rank.into() * 5);
            let final_damage = (faction_damage * rank_multiplier) / 100;
            final_damage
        }

        fn can_deal_damage(self: @ContractState, item: Gear) -> bool {
            // Custom Logic here
            true
        }

        fn get_item_base_damage(self: @ContractState, item_type: felt252) -> u256 {
            // TODO: add proper logic for damage calculation when item types are defined.
            20
        }

        fn get_weapon_type_damage_multiplier(self: @ContractState, item_type: felt252) -> u256 {
            // TODO: add proper logic for weapon damage percentage
            110 // 10% added damage
        }

        fn damage_target(
            ref self: ContractState, target_id: u256, target_type: felt252, damage: u256,
        ) {
            if target_type == TARGET_LIVING {
                self.receive_damage(target_id, damage);
            } else { // TODO: Implement the damage trait to object after game objects are defined.
            }
        }

        fn receive_damage(ref self: ContractState, player_id: u256, damage: u256) {
            let mut world = self.world_default();
            let mut player = world.read_model(player_id);

            let mut remaining_damage = damage;

            let armor_types = array![
                ARMOR_HELMET,
                ARMOR_CHESTPLATE,
                ARMOR_LEGGINGS,
                ARMOR_BOOTS,
                ARMOR_GLOVES,
                ARMOR_SHIELD,
            ];

            let mut armor_index = 0;
            loop {
                if armor_index >= armor_types.len() || remaining_damage == 0 {
                    break;
                }

                let armor_type = *armor_types.at(armor_index);
                let equipped_item_id = (player.clone()).is_equipped(armor_type);

                if equipped_item_id.is_non_zero() {
                    let gear: Gear = world.read_model(equipped_item_id);

                    let mut armor: Armour = world.read_model(gear.asset_id);

                    remaining_damage = armor.apply_damage(remaining_damage);

                    world.write_model(@armor);
                }

                armor_index += 1;
            };

            //-->> Apply remaining damage to player health!!!!!!
            if remaining_damage > 0 {
                if remaining_damage >= player.hp {
                    player.hp = 0;
                } else {
                    player.hp -= remaining_damage;
                }

                world.write_model(@player);
                let _damage_received = damage - remaining_damage;
                let damage_reduction = damage - remaining_damage;
                let event = PlayerDamaged {
                    player_id,
                    damage_received: damage,
                    damage_reduction,
                    actual_damage: remaining_damage,
                    remaining_hp: player.hp,
                    is_alive: player.hp > 0,
                };
                world.emit_event(@event);
            }
        }

        // Optimized batch receive damage for accumulated damage processing
        fn receive_accumulated_damage(
            ref self: ContractState, player_id: u256, total_damage: u256,
        ) {
            let mut world = self.world_default();
            let mut player = world.read_model(player_id);

            // Cache armor item IDs to reduce lookups
            let armor_types = array![
                ARMOR_HELMET,
                ARMOR_CHESTPLATE,
                ARMOR_LEGGINGS,
                ARMOR_BOOTS,
                ARMOR_GLOVES,
                ARMOR_SHIELD,
            ];

            let mut equipped_armor_ids: Array<u256> = array![];
            let mut armor_index = 0;

            // Cache all equipped armor item IDs
            loop {
                if armor_index >= armor_types.len() {
                    break;
                }

                let armor_type = *armor_types.at(armor_index);
                let equipped_item_id = (player.clone()).is_equipped(armor_type);

                if equipped_item_id.is_non_zero() {
                    equipped_armor_ids.append(equipped_item_id);
                }

                armor_index += 1;
            };

            // Apply damage through all armor pieces
            let mut remaining_damage = total_damage;
            let mut armor_cache_index = 0;

            loop {
                if armor_cache_index >= equipped_armor_ids.len() || remaining_damage == 0 {
                    break;
                }

                let equipped_item_id = *equipped_armor_ids.at(armor_cache_index);
                let gear: Gear = world.read_model(equipped_item_id);
                let mut armor: Armour = world.read_model(gear.asset_id);

                remaining_damage = armor.apply_damage(remaining_damage);

                // Write updated armor back to storage
                world.write_model(@armor);
                armor_cache_index += 1;
            };

            // Apply remaining damage to player health
            if remaining_damage > 0 {
                if remaining_damage >= player.hp {
                    player.hp = 0;
                } else {
                    player.hp -= remaining_damage;
                }

                world.write_model(@player);
                let damage_reduction = total_damage - remaining_damage;
                let event = PlayerDamaged {
                    player_id,
                    damage_received: total_damage,
                    damage_reduction,
                    actual_damage: remaining_damage,
                    remaining_hp: player.hp,
                    is_alive: player.hp > 0,
                };
                world.emit_event(@event);
            }
        }

        fn get_erc1155_address(self: @ContractState) -> ContractAddress {
            // In a real implementation, this would be stored in the contract state
            // For now, we return a placeholder address
            // This should be replaced with the actual ERC1155 contract address
            starknet::contract_address_const::<0x0>()
        }

        fn get_game_object_ids(self: @ContractState) -> Array<u256> {
            // In a real implementation, this would return a list of all game object IDs
            // that can be owned by players
            // For now, we return an empty array
            array![]
        }

        fn is_object_registered(self: @ContractState, player_id: u256, object_id: u256) -> bool {
            // In a real implementation, this would check if the object is already registered
            // in the player's inventory in the game state
            // For now, we return false
            false
        }

        fn register_object(
            ref self: ContractState, player_id: u256, object_id: u256, quantity: u256,
        ) {
            // In a real implementation, this would register the object in the player's inventory
            // in the game state
            // For now, this is just a placeholder

            // Get the player model - using placeholder session_id for now
            let mut _player = self.get_player(player_id, 0);
            // Depending on the object type, we would add it to the appropriate inventory slot
        // This is a simplified implementation

            // For example, if it's an equippable item, we might add it to the player's equipped
        // array player.equipped.append(object_id);

            // Then we would update the player model in the world state
        // set_player(player_id, player);
        }

        fn update_object_quantity(
            ref self: ContractState, player_id: u256, object_id: u256, quantity: u256,
        ) { // In a real implementation, this would update the quantity of the object
        // in the player's inventory in the game state
        // For now, this is just a placeholder
        }

        // Damage accumulator functions for combo system
        fn create_damage_accumulator(
            self: @ContractState, target_id: u256, initial_damage: u256, current_time: u64,
        ) -> DamageAccumulator {
            DamageAccumulator {
                target_id,
                accumulated_damage: initial_damage,
                hit_count: 1,
                combo_multiplier: 100, // Start with 1.0x multiplier
                last_hit_time: current_time,
                is_active: true,
            }
        }

        fn update_damage_accumulator(
            self: @ContractState,
            mut accumulator: DamageAccumulator,
            new_damage: u256,
            current_time: u64,
        ) -> DamageAccumulator {
            // Check if combo chain is still active (within 3 seconds of last hit)
            let time_diff = current_time - accumulator.last_hit_time;
            if time_diff > 3 {
                // Reset combo if too much time has passed
                accumulator.hit_count = 1;
                accumulator.combo_multiplier = 100;
                accumulator.accumulated_damage = new_damage;
            } else {
                // Continue combo chain
                accumulator.hit_count += 1;

                // Increase combo multiplier (5% per additional hit, max 200%)
                let multiplier_increase: u256 = ((accumulator.hit_count - 1) * 5).into();
                accumulator.combo_multiplier = 100 + multiplier_increase;
                if accumulator.combo_multiplier > 200 {
                    accumulator.combo_multiplier = 200; // Cap at 2.0x
                }

                // Apply combo multiplier to new damage and add to accumulator
                let boosted_damage = (new_damage * accumulator.combo_multiplier) / 100;
                accumulator.accumulated_damage += boosted_damage;
            }

            accumulator.last_hit_time = current_time;
            accumulator
        }

        fn finalize_damage_accumulator(
            ref self: ContractState, accumulator: DamageAccumulator,
        ) -> u256 {
            // Apply accumulated damage to target
            if accumulator.is_active && accumulator.accumulated_damage > 0 {
                self
                    .receive_accumulated_damage(
                        accumulator.target_id, accumulator.accumulated_damage,
                    );

                // Emit combo event if significant combo was achieved
                if accumulator.hit_count >= 3 { // Could emit a ComboAchieved event here if defined
                }
            }

            accumulator.accumulated_damage
        }

        fn calculate_balanced_damage(
            self: @ContractState, player: Player, gear: Gear, faction_stats: FactionStats,
        ) -> u256 {
            let level_damage = calculate_level_damage(player.level);
            let gear_damage = self.calculate_gear_damage(gear);
            let faction_damage = (level_damage + gear_damage)
                * faction_stats.damage_multiplier
                / 100;
            let balanced_damage = apply_diminishing_returns(faction_damage, player.level);
            balanced_damage
        }

        fn calculate_gear_damage(self: @ContractState, gear: Gear) -> u256 {
            let rarity = self.get_item_rarity(gear.asset_id);
            let base_damage = get_base_damage_for_type(parse_id(gear.asset_id));

            let rarity_multiplier = match rarity {
                ItemRarity::Common => 100,
                ItemRarity::Uncommon => 120,
                ItemRarity::Rare => 150,
                ItemRarity::Epic => 200,
                ItemRarity::Legendary => 300,
            };

            let upgrade_multiplier = 100 + (gear.upgrade_level * 10);
            (base_damage * rarity_multiplier * upgrade_multiplier.into()) / 10000
        }

        fn get_item_rarity(self: @ContractState, asset_id: u256) -> ItemRarity {
            let world = self.world_default();
            let gear_stats: GearLevelStats = world.read_model((asset_id, 0));
            if gear_stats.damage >= 100 {
                ItemRarity::Legendary
            } else if gear_stats.damage >= 75 {
                ItemRarity::Epic
            } else if gear_stats.damage >= 50 {
                ItemRarity::Rare
            } else if gear_stats.damage >= 25 {
                ItemRarity::Uncommon
            } else {
                ItemRarity::Common
            }
        }
    }

    fn erc1155(contract_address: ContractAddress) -> IERC1155Dispatcher {
        IERC1155Dispatcher { contract_address }
    }

    fn get_base_damage_for_type(item_type: GearType) -> u256 {
        match item_type {
            GearType::None => 10,
            GearType::Weapon => 20,
            GearType::BluntWeapon => 22,
            GearType::Sword => 25,
            GearType::Bow => 15,
            GearType::Firearm => 30,
            GearType::Polearm => 22,
            GearType::HeavyFirearms => 40,
            GearType::Explosives => 50,
            GearType::Helmet => 0,
            GearType::ChestArmor => 0,
            GearType::LegArmor => 0,
            GearType::Boots => 0,
            GearType::Gloves => 0,
            GearType::Shield => 0,
            GearType::Vehicle => 0,
            GearType::Pet => 0,
            GearType::Drone => 0,
        }
    }

    fn calculate_level_damage(level: u256) -> u256 {
        if level <= 10 {
            level * 5
        } else if level <= 50 {
            50 + (level - 10) * 3
        } else {
            170 + (level - 50) * 1
        }
    }

    fn apply_diminishing_returns(damage: u256, level: u256) -> u256 {
        let multiplier = if level > 100 {
            80 // 20% reduction for very high levels
        } else if level > 50 {
            90 // 10% reduction for mid-high levels
        } else {
            100 // No reduction for lower levels
        };
        (damage * multiplier) / 100
    }

    fn calculate_xp_requirement(current_level: u256) -> u256 {
        if current_level <= 10 {
            current_level * 1000
        } else if current_level <= 50 {
            10000 + (current_level - 10) * 2000
        } else {
            90000 + (current_level - 50) * 5000
        }
    }

    fn calculate_level_from_xp(xp: u256) -> u256 {
        if xp <= 10000 {
            xp / 1000
        } else if xp <= 90000 {
            10 + (xp - 10000) / 2000
        } else {
            50 + (xp - 90000) / 5000
        }
    }
}
