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
    fn complete_tournament(ref self: TContractState, tournament_id: u256);
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
    use coa::helpers::gear::{parse_id, random_geartype, get_max_upgrade_level, get_min_xp_needed};
    use coa::models::player::{Player, PlayerTrait};
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

        // Initialize global config
        let config = Config {
            id: 0,
            admin,
            next_tournament_id: 1,
            next_guild_id: 1,
            erc1155_address: erc1155,
            credit_token_id: 0,
            default_guild_max_members: 50,
        };
        world.write_model(@config);
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
            let gear_len = gear_details.len();

            let mut i = 0;
            loop {
                if i >= gear_len {
                    break;
                }

                let details = *gear_details.at(i);

                assert(details.validate(), 'Invalid gear details');

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
            assert(max_participants >= 2_u32, 'max_participants must be >= 2');
            // Optional: enforce an upper bound to limit gas/state growth
            assert(max_participants <= 1024_u32, 'max_participants too large');
            // If zero-fee tournaments are disallowed, uncomment:
            // assert(entry_fee > 0, 'entry_fee must be > 0');

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
            world.write_model(@player);
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
                get_block_timestamp() >= tournament.registration_end, 'Registration still open',
            );
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

        fn complete_tournament(ref self: ContractState, tournament_id: u256) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            let mut tournament: Tournament = world.read_model(tournament_id);
            assert(tournament.creator == caller, 'Only creator can complete tournament');
            assert(tournament.status == TournamentStatus::InProgress, 'Tournament not in progress');

            tournament.status = TournamentStatus::Completed;

            world.write_model(@tournament);
        }

        fn distribute_tournament_rewards(
            ref self: ContractState, tournament_id: u256, winners: Array<starknet::ContractAddress>,
        ) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(COA_CONTRACTS);
            let mut tournament: Tournament = world.read_model(tournament_id);

            assert(tournament.creator == caller, 'Only creator can distribute rewards');
            assert(tournament.status == TournamentStatus::Completed, 'Tournament not completed');
            assert(winners.len() > 0, 'No winners provided');
            assert(tournament.prize_pool > 0, 'Rewards already distributed or pool empty');

            // Convert winners length to u256 and calculate prize distribution
            let winners_len: usize = winners.len();
            let winners_count: u256 = self.usize_to_u256(winners_len);
            let prize_per_winner = tournament.prize_pool / winners_count;
            let remainder = tournament.prize_pool % winners_count;

            let mut i = 0;
            while i < winners.len() {
                let winner = *winners.at(i);
                // Winner must be a registered participant
                let wp: Participant = world.read_model((tournament_id, winner));
                assert(wp.is_registered, 'Winner not registered in this tournament');
                let mut player: Player = world.read_model(winner);
                let mut payout = prize_per_winner;
                // Give remainder to first winner to avoid silent loss
                if i == 0 { 
                    payout += remainder; 
                }
                player.mint_credits(payout, contract.erc1155);
                world.write_model(@player);
                i += 1;
            };

            // One-way finalization by emptying the pool
            tournament.prize_pool = 0;
            world.write_model(@tournament);
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

        // Helper function to convert usize to u256
        fn usize_to_u256(x: usize) -> u256 {
            u256 { high: 0, low: x.into() }
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

        // Generate tournament ID
        fn generate_tournament_id(ref self: ContractState) -> u256 {
            let mut world = self.world_default();
            let mut config: Config = world.read_model(0);
            let id = config.next_tournament_id;
            config.next_tournament_id += 1;
            world.write_model(@config);
            id
        }
    }
}
