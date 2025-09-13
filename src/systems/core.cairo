/// interface
/// init an admin account, or list of admin accounts, dojo_init
///
/// Spawn tournamemnts and side quests here, if necessary.

use crate::models::gear::{Gear, GearDetails};
use crate::models::tournament::{
    Tournament, TournamentType, TournamentStatus, Participant, TournamentCreated, PlayerRegistered,
    TournamentStarted, TournamentFinished, Config,
};
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
    fn create_tournament(
        ref self: TContractState, tournament_type: felt252, entry_fee: u256, max_participants: u32,
    );
    fn join_tournament(ref self: TContractState, tournament_id: u256);
    fn start_tournament(ref self: TContractState, tournament_id: u256);
    fn distribute_tournament_rewards(
        ref self: TContractState, tournament_id: u256, winners: Array<starknet::ContractAddress>,
    );
    fn purchase_credits(ref self: TContractState);
    fn random_gear_generator(ref self: TContractState) -> Gear;
    fn pick_items(ref self: TContractState, item_ids: Array<u256>) -> Array<u256>;
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
    use crate::systems::gear::*;
    use dojo::world::WorldStorage;
    use crate::helpers::gear::{parse_id, random_geartype, get_max_upgrade_level, get_min_xp_needed};
    use crate::models::player::{Player, PlayerTrait};
    use core::num::traits::Zero;
    use core::traits::Into;
    use starknet::get_block_timestamp;

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
    }

    #[abi(embed_v0)]
    pub impl CoreActionsImpl of super::ICore<ContractState> {
        //@ryzen-xp, @truthixify
        fn spawn_items(ref self: ContractState, gear_details: Array<GearDetails>) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(COA_CONTRACTS);
            assert(caller == contract.admin, 'Only admin can spawn items');

            let erc1155_dispatcher = IERC1155MintableDispatcher {
                contract_address: contract.erc1155,
            };

            let mut items = array![];
            let mut i = 0;

            while i < gear_details.len() {
                let details = *gear_details.at(i);
                assert(details.validate(), 'Invalid gear details');

                let item_id: u256 = self.generate_incremental_ids(details.gear_type.into());
                let item_type: felt252 = details.gear_type.into();

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
                    spawned: false,
                };

                assert(!gear.spawned, 'Gear already spawned');
                gear.spawned = true;
                world.write_model(@gear);

                items.append(gear.id);
                erc1155_dispatcher
                    .mint(contract.warehouse, gear.id, details.total_count.into(), array![].span());
                i += 1;
            };

            let event = GearSpawned { admin: caller, items };
            world.emit_event(@event);
        }

        // move to market only items that have been spawned.
        // if caller is admin, check spawned items and relocate
        // if caller is player,
        fn move_to_market(ref self: ContractState, item_ids: Array<u256>) {}
        fn add_to_market(ref self: ContractState, item_ids: Array<u256>) {}
        // can be credits, materials, anything
        fn purchase_item(ref self: ContractState, item_id: u256, quantity: u256) {}
        fn create_tournament(
            ref self: ContractState,
            tournament_type: felt252,
            entry_fee: u256,
            max_participants: u32,
        ) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(COA_CONTRACTS);

            // Validate admin permissions
            assert(caller == contract.admin, 'Only admin can create tournaments');

            // Create tournament
            let tournament_id = self.generate_tournament_id();
            let tournament = Tournament {
                id: tournament_id,
                creator: caller,
                name: 'Tournament',
                tournament_type: TournamentType::SingleElimination,
                status: TournamentStatus::Open,
                prize_pool: 0,
                entry_fee,
                max_players: max_participants,
                min_players: 2,
                registration_start: get_block_timestamp(),
                registration_end: get_block_timestamp() + 86400, // 24 hours from now
                registered_players: 0,
                total_rounds: 0,
                level_requirement: 0,
            };

            world.write_model(@tournament);
            world
                .emit_event(
                    @TournamentCreated { tournament_id, creator: caller, name: 'Tournament' },
                );
        }

        fn join_tournament(ref self: ContractState, tournament_id: u256) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(COA_CONTRACTS);

            // Get tournament
            let mut tournament: Tournament = world.read_model(tournament_id);

            // Validate tournament is open
            assert(tournament.status == TournamentStatus::Open, 'Tournament not open');
            assert(tournament.registered_players < tournament.max_players, 'Tournament full');
            assert(get_block_timestamp() <= tournament.registration_end, 'Registration closed');

            // Check if player is already registered
            let participant: Participant = world.read_model((tournament_id, caller));
            assert(!participant.is_registered, 'Already registered');

            // Check player has enough credits for entry fee
            let mut player: Player = world.read_model(caller);
            assert(
                player.get_credits(contract.erc1155) >= tournament.entry_fee,
                'Insufficient credits',
            );

            // Deduct entry fee and add to prize pool
            player.deduct_credits(tournament.entry_fee, contract.erc1155);
            tournament.prize_pool += tournament.entry_fee;
            tournament.registered_players += 1;

            // Add player to tournament
            let participant = Participant {
                tournament_id,
                player_id: caller,
                is_registered: true,
                matches_played: 0,
                matches_won: 0,
                is_eliminated: false,
            };

            world.write_model(@tournament);
            world.write_model(@participant);
            world.emit_event(@PlayerRegistered { tournament_id, player_id: caller });
        }
        fn purchase_credits(ref self: ContractState) {}

        fn start_tournament(ref self: ContractState, tournament_id: u256) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            let mut tournament: Tournament = world.read_model(tournament_id);
            assert(tournament.creator == caller, 'Only creator can start tournament');
            assert(tournament.status == TournamentStatus::Open, 'Tournament not open');
            assert(
                tournament.registered_players >= tournament.min_players, 'Not enough participants',
            );

            tournament.status = TournamentStatus::InProgress;

            world.write_model(@tournament);
            world
                .emit_event(
                    @TournamentStarted {
                        tournament_id, initial_matches: tournament.registered_players / 2,
                    },
                );
        }

        fn distribute_tournament_rewards(
            ref self: ContractState, tournament_id: u256, winners: Array<starknet::ContractAddress>,
        ) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(COA_CONTRACTS);
            let tournament: Tournament = world.read_model(tournament_id);

            assert(tournament.creator == caller, 'Only creator can distribute rewards');
            assert(tournament.status == TournamentStatus::Completed, 'Tournament not completed');

            let prize_per_winner = tournament.prize_pool / winners.len();

            let mut i = 0;
            while i < winners.len() {
                let winner = *winners.at(i);
                let mut player: Player = world.read_model(winner);
                player.mint_credits(prize_per_winner, contract.erc1155);
                world.write_model(@player);
                i += 1;
            };

            world.emit_event(@TournamentFinished { tournament_id, winner: *winners.at(0) });
        }

        //@ryzen-xp
        // random gear  item genrator
        fn random_gear_generator(ref self: ContractState) -> Gear {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(COA_CONTRACTS);
            assert(caller == contract.admin, 'Only admin can spawn items');

            let gear_type = random_geartype();
            let item_type: felt252 = gear_type.into();
            let item_id: u256 = self.generate_incremental_ids(gear_type.into());
            let max_upgrade_level: u64 = get_max_upgrade_level(gear_type);
            let min_xp_needed: u256 = get_min_xp_needed(gear_type);

            let gear = Gear {
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
            };

            gear
        }

        //@ryzen-xp
        fn pick_items(ref self: ContractState, item_ids: Array<u256>) -> Array<u256> {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let contract: Contract = world.read_model(COA_CONTRACTS);
            let mut player: Player = world.read_model(caller);

            player.init('default');

            let mut successfully_picked: Array<u256> = array![];

            let mut has_vehicle = player.has_vehicle_equipped();

            let mut i = 0;
            while i < item_ids.len() {
                let item_id = *item_ids.at(i);
                let mut gear: Gear = world.read_model(item_id);

                assert(gear.is_available_for_pickup(), 'Item not available');

                if player.xp < gear.min_xp_needed {
                    i += 1;
                    continue;
                }

                let mut equipped = false;
                let mut mint_item = false;

                if has_vehicle {
                    // if player has vehicle, mint all items directly to inventory !!!!!!!!!!!!
                    mint_item = true;
                } else {
                    if player.is_equippable(item_id) {
                        PlayerTrait::equip(ref player, item_id);
                        equipped = true;
                        mint_item = true;
                    } else if player.has_free_inventory_slot() {
                        mint_item = true;
                    }
                }

                if mint_item {
                    // Transfer the pre-minted item from warehouse to the player

                    let erc1155 = IERC1155Dispatcher { contract_address: contract.erc1155 };
                    erc1155
                        .safe_transfer_from(
                            contract.warehouse, caller, item_id, 1, array![].span(),
                        );

                    gear.transfer_to(caller);
                    world.write_model(@gear);

                    // Add to successfully picked array
                    successfully_picked.append(item_id);

                    world
                        .emit_event(
                            @ItemPicked {
                                player_id: caller,
                                item_id: item_id,
                                equipped: equipped,
                                via_vehicle: has_vehicle,
                            },
                        );
                }

                i += 1;

                // if we just equipped a vehicle, enable hands-free pickup
                if equipped && parse_id(item_id) == GearType::Vehicle {
                    has_vehicle = true;
                }
            };

            // Update Player state
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

            let data = GearCounter { id: item_id.high, counter: gear_counter.counter + 1 };

            world.write_model(@data);

            let id = u256 { high: data.id, low: data.counter };
            id
        }

        // Generate tournament ID
        fn generate_tournament_id(ref self: ContractState) -> u256 {
            let mut world = self.world_default();
            let mut config: Config = world.read_model(1);

            config.next_tournament_id += 1;
            world.write_model(@config);

            config.next_tournament_id
        }
    }
}
