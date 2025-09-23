/// interface
/// init an admin account, or list of admin accounts, dojo_init
///
/// Spawn tournamemnts and side quests here, if necessary.

use coa::models::gear::{Gear, GearDetails};

#[starknet::interface]
pub trait ICore<TContractState> {
    fn spawn_items(ref self: TContractState, gear_details: Array<GearDetails>);
    // move to market only items that have been spawned.
    // if caller is admin, check spawned items and relocate
    // if caller is player,
    fn move_to_market(ref self: TContractState, item_ids: Array<u256>);
    fn add_to_market(ref self: TContractState, item_ids: Array<u256>);
    // can be credits, materials, anything
    fn purchase_item(ref self: TContractState, item_id: u256, quantity: u256);
    fn create_tournament(ref self: TContractState);
    fn join_tournament(ref self: TContractState);
    fn purchase_credits(ref self: TContractState);
    fn random_gear_generator(ref self: TContractState) -> Gear;
    fn pick_items(ref self: TContractState, item_ids: Array<u256>) -> Array<u256>;
    fn pause_contract(ref self: TContractState, reason: felt252);
    fn unpause_contract(ref self: TContractState);
}

#[dojo::contract]
pub mod CoreActions {
    use super::super::super::erc1155::erc1155::IERC1155MintableDispatcherTrait;
    use starknet::{ContractAddress, get_caller_address, contract_address_const};
    use dojo::model::ModelStorage;
    use crate::models::core::{Contract, Operator, GearSpawned, ItemPicked};
    use crate::models::gear::*;

    use crate::systems::gear::GearActions::GearActionsImpl;
    use core::array::ArrayTrait;
    use crate::erc1155::erc1155::IERC1155MintableDispatcher;
    use crate::erc1155::erc1155::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use dojo::event::{EventStorage};
    use coa::systems::gear::*;
    use dojo::world::WorldStorage;
    use coa::helpers::gear::{parse_id, random_geartype, get_max_upgrade_level, get_min_xp_needed};
    use coa::models::player::{Player, PlayerTrait};
    use core::traits::Into;
    use core::num::traits::Zero;

    const GEAR: felt252 = 'GEAR';
    const COA_CONTRACTS: felt252 = 'COA_CONTRACTS';

    fn dojo_init(
        ref self: ContractState,
        admin: ContractAddress,
        erc1155: ContractAddress,
        payment_token: ContractAddress,
        escrow_address: ContractAddress,
        registration_fee: u256,
        warehouse: ContractAddress,
    ) {
        let mut world = self.world(@"coa_contracts");

        // Security validation for initialization
        assert(!admin.is_zero(), 'INVALID_ADMIN_ADDRESS');
        assert(!erc1155.is_zero(), 'INVALID_ERC1155_ADDRESS');
        assert(!warehouse.is_zero(), 'INVALID_WAREHOUSE_ADDRESS');

        // Initialize admin
        let operator = Operator { id: admin, is_operator: true };
        world.write_model(@operator);

        // Initialize contract configuration
        let contract = Contract {
            id: COA_CONTRACTS,
            admin,
            erc1155,
            payment_token,
            escrow_address,
            registration_fee,
            paused: false,
            warehouse,
        };
        world.write_model(@contract);

        // Initialize security configuration
        let security_config = coa::models::security::SecurityConfig {
            id: coa::helpers::security::SECURITY_CONFIG_ID,
            max_sessions_per_hour: 5,
            max_spawns_per_hour: 10,
            max_transactions_per_session: 1000,
            session_renewal_threshold: 300, // 5 minutes
            emergency_pause_enabled: true,
        };
        world.write_model(@security_config);
    }

    #[abi(embed_v0)]
    pub impl CoreActionsImpl of super::ICore<ContractState> {
        //@ryzen-xp, @truthixify
        fn spawn_items(ref self: ContractState, gear_details: Array<GearDetails>) {
            let mut world = self.world_default();

            // Comprehensive security validation
            coa::helpers::security::validate_admin_access(
                world, coa::helpers::security::GAME_ADMIN,
            );
            coa::helpers::security::validate_contract_not_paused(world);

            let caller = get_caller_address();

            // Rate limiting check
            assert(
                coa::helpers::security::check_rate_limit(
                    world, caller, coa::helpers::security::SPAWN_ITEMS_OP,
                ),
                'RATE_LIMIT_EXCEEDED',
            );

            let contract: Contract = world.read_model(COA_CONTRACTS);

            let erc1155_dispatcher = IERC1155MintableDispatcher {
                contract_address: contract.erc1155,
            };

            let mut items = array![];
            let gear_len = gear_details.len();

            let mut i = 0;
            loop {
                if i >= gear_len {
                    break;
                }

                let details = *gear_details.at(i);

                // Input validation and sanitization
                assert(details.validate(), 'Invalid gear details');
                assert(details.total_count > 0, 'INVALID_TOTAL_COUNT');
                assert(details.total_count <= 1000000, 'COUNT_TOO_HIGH');
                assert(details.max_upgrade_level <= 100, 'UPGRADE_LEVEL_TOO_HIGH');

                // Generate ID once and reuse
                let item_id = self.generate_incremental_ids(details.gear_type.into());
                let item_type: felt252 = details.gear_type.into();

                // Create gear struct with computed values
                let mut gear = Gear {
                    id: item_id,
                    item_type,
                    asset_id: item_id,
                    variation_ref: details.variation_ref,
                    total_count: details.total_count,
                    in_action: false,
                    upgrade_level: 0,
                    owner: contract_address_const::<0>(),
                    max_upgrade_level: details.max_upgrade_level,
                    min_xp_needed: details.min_xp_needed,
                    spawned: true,
                };

                world.write_model(@gear);
                items.append(item_id);

                erc1155_dispatcher
                    .mint(contract.warehouse, item_id, details.total_count.into(), array![].span());

                i += 1;
            };

            world.emit_event(@GearSpawned { admin: caller, items });
        }

        // move to market only items that have been spawned.
        // if caller is admin, check spawned items and relocate
        // if caller is player,
        fn move_to_market(ref self: ContractState, item_ids: Array<u256>) {}
        fn add_to_market(ref self: ContractState, item_ids: Array<u256>) {}
        // can be credits, materials, anything
        fn purchase_item(ref self: ContractState, item_id: u256, quantity: u256) {}
        fn create_tournament(ref self: ContractState) {}
        fn join_tournament(ref self: ContractState) {}
        fn purchase_credits(ref self: ContractState) {}

        // Emergency functions for admin
        fn pause_contract(ref self: ContractState, reason: felt252) {
            let mut world = self.world_default();
            coa::helpers::security::validate_admin_access(
                world, coa::helpers::security::SUPER_ADMIN,
            );

            let mut contract: Contract = world.read_model(COA_CONTRACTS);
            contract.paused = true;
            world.write_model(@contract);

            coa::helpers::security::log_security_event(
                world, 'CONTRACT_PAUSED', get_caller_address(), reason,
            );
        }

        fn unpause_contract(ref self: ContractState) {
            let mut world = self.world_default();
            coa::helpers::security::validate_admin_access(
                world, coa::helpers::security::SUPER_ADMIN,
            );

            let mut contract: Contract = world.read_model(COA_CONTRACTS);
            contract.paused = false;
            world.write_model(@contract);

            coa::helpers::security::log_security_event(
                world, 'CONTRACT_UNPAUSED', get_caller_address(), 0,
            );
        }

        //@ryzen-xp
        // random gear  item genrator
        fn random_gear_generator(ref self: ContractState) -> Gear {
            let mut world = self.world_default();

            // Security validation
            coa::helpers::security::validate_admin_access(
                world, coa::helpers::security::GAME_ADMIN,
            );
            coa::helpers::security::validate_contract_not_paused(world);

            let gear_type = random_geartype();
            let item_type: felt252 = gear_type.into();
            let item_id = self.generate_incremental_ids(item_type.into());

            let (max_upgrade_level, min_xp_needed) = (
                get_max_upgrade_level(gear_type), get_min_xp_needed(gear_type),
            );

            Gear {
                id: item_id,
                item_type,
                asset_id: item_id,
                variation_ref: 0,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                owner: contract_address_const::<0>(),
                max_upgrade_level,
                min_xp_needed,
                spawned: false,
            }
        }

        //@ryzen-xp
        fn pick_items(ref self: ContractState, item_ids: Array<u256>) -> Array<u256> {
            let mut world = self.world_default();
            let caller = get_caller_address();

            // Security validation
            coa::helpers::security::validate_contract_not_paused(world);
            coa::helpers::security::validate_player_access(world, caller);

            // Validate input
            assert(item_ids.len() > 0, 'NO_ITEMS_PROVIDED');
            assert(item_ids.len() <= 50, 'TOO_MANY_ITEMS'); // Prevent spam

            // Cache contract + dispatcher
            let contract: Contract = world.read_model(COA_CONTRACTS);
            let erc1155 = IERC1155Dispatcher { contract_address: contract.erc1155 };

            let mut player: Player = world.read_model(caller);
            player.init('default');

            let mut successfully_picked = ArrayTrait::<u256>::new();
            let mut gears_to_update = ArrayTrait::<Gear>::new();
            let mut events_to_emit = ArrayTrait::<ItemPicked>::new();
            let mut has_vehicle = player.has_vehicle_equipped();

            let item_count = item_ids.len();
            let mut i = 0;

            loop {
                if i >= item_count {
                    break;
                }

                let item_id = *item_ids.at(i);
                let mut gear: Gear = world.read_model(item_id);

                // Early filter-out
                if gear.is_available_for_pickup() && player.clone().xp >= gear.min_xp_needed {
                    let mut equipped = false;
                    let can_pick = if has_vehicle {
                        true
                    } else if player.is_equippable(item_id) {
                        PlayerTrait::equip(ref player, item_id);
                        equipped = true;
                        true
                    } else {
                        player.has_free_inventory_slot()
                    };

                    if can_pick {
                        // ERC1155 transfer
                        erc1155
                            .safe_transfer_from(
                                contract.warehouse,
                                caller,
                                item_id,
                                1,
                                ArrayTrait::<felt252>::new().span(),
                            );

                        // Defer gear update + event
                        gear.transfer_to(caller);
                        gears_to_update.append(gear);
                        successfully_picked.append(item_id);

                        events_to_emit
                            .append(
                                ItemPicked {
                                    player_id: caller, item_id, equipped, via_vehicle: has_vehicle,
                                },
                            );

                        // If just equipped a vehicle, persist for next items
                        if equipped && parse_id(item_id) == GearType::Vehicle {
                            has_vehicle = true;
                        }
                    }
                }

                i += 1;
            };

            let updates_len = gears_to_update.len();
            let mut j = 0;
            loop {
                if j >= updates_len {
                    break;
                }
                world.write_model(gears_to_update.at(j));
                world.emit_event(events_to_emit.at(j));
                j += 1;
            };

            world.write_model(@player);

            successfully_picked
        }
    }

    #[generate_trait]
    pub impl CoreInternalImpl of CoreInternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"coa")
        }

        //@ryzen-xp
        // Generates an incremental u256 ID based on gear_id.high.
        fn generate_incremental_ids(ref self: ContractState, item_id: u256) -> u256 {
            let mut world = self.world_default();
            let mut gear_counter: GearCounter = world.read_model(item_id.high);

            gear_counter.counter += 1;
            world.write_model(@gear_counter);

            u256 { high: item_id.high, low: gear_counter.counter }
        }
    }
}
