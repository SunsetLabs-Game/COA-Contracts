use starknet::ContractAddress;
use coa::models::tournament::{TournamentType};

#[starknet::interface]
pub trait ITournament<TContractState> {
    // --- Admin Functions ---
    fn init(ref self: TContractState, erc1155_address: ContractAddress, credit_token_id: u256);
    fn set_admin(ref self: TContractState, new_admin: ContractAddress);

    // --- Tournament Management ---
    fn create_tournament(
        ref self: TContractState,
        name: felt252,
        tournament_type: TournamentType,
        prize_pool: u256,
        entry_fee: u256,
        max_players: u32,
        min_players: u32,
        registration_start: u64,
        registration_end: u64,
        level_requirement: u256,
    );
    fn cancel_tournament(
        ref self: TContractState, tournament_id: u256, registered_players: Array<ContractAddress>,
    );
    fn start_tournament(
        ref self: TContractState, tournament_id: u256, participants: Array<ContractAddress>,
    );

    // --- Player Actions ---
    fn register(ref self: TContractState, tournament_id: u256, session_id: felt252);
    fn unregister(ref self: TContractState, tournament_id: u256, session_id: felt252);
    fn report_match_result(
        ref self: TContractState,
        tournament_id: u256,
        match_id: u32,
        winner_id: ContractAddress,
        session_id: felt252,
    );
    fn claim_prize(ref self: TContractState, tournament_id: u256, session_id: felt252);
}

#[dojo::contract]
pub mod TournamentActions {
    use super::ITournament;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};
    use dojo::model::ModelStorage;
    // use dojo::world::WorldStorage;
    use dojo::event::EventStorage;
    use core::num::traits::Zero;
    use core::num::traits::Pow;

    use crate::models::tournament::{
        Tournament, TournamentType, TournamentStatus, Participant, Match, Winner, Config, Errors,
        TournamentCreated, PlayerRegistered, PlayerUnregistered, TournamentStarted,
        TournamentCancelled, MatchCompleted, TournamentFinished, PrizeClaimed,
    };
    use crate::models::player::{Player};
    use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use core::option::OptionTrait;
    use core::array::ArrayTrait;
    // Import session model for validation
    use crate::models::session::SessionKey;


    #[abi(embed_v0)]
    impl TournamentImpl of ITournament<ContractState> {
        fn init(ref self: ContractState, erc1155_address: ContractAddress, credit_token_id: u256) {
            let mut world = self.world_default();
            let config: Config = world.read_model(0);
            assert(config.admin.is_zero(), 'Already initialized');
            let admin = get_caller_address();
            let config = Config {
                id: 0, admin, next_tournament_id: 1, erc1155_address, credit_token_id,
            };
            world.write_model(@config);
        }

        fn set_admin(ref self: ContractState, new_admin: ContractAddress) {
            let mut world = self.world_default();
            let mut config: Config = world.read_model(0);
            assert(get_caller_address() == config.admin, Errors::NOT_ADMIN);
            config.admin = new_admin;
            world.write_model(@config);
        }

        fn create_tournament(
            ref self: ContractState,
            name: felt252,
            tournament_type: TournamentType,
            prize_pool: u256,
            entry_fee: u256,
            max_players: u32,
            min_players: u32,
            registration_start: u64,
            registration_end: u64,
            level_requirement: u256,
        ) {
            let creator = get_caller_address();
            let mut world = self.world_default();
            let mut config: Config = world.read_model(0);
            let tournament_id = config.next_tournament_id;

            assert(registration_start < registration_end, Errors::INVALID_DATES);
            assert(min_players >= 2 && min_players <= max_players, Errors::INVALID_PLAYERS);
            // Ensure registration window hasn't already passed
            let now = get_block_timestamp();
            assert(registration_end > now, Errors::REGISTRATION_END_MUST_BE_IN_FUTURE);
            // Ensure prize pool makes sense relative to potential entry fees
            let min_entry_fees = entry_fee * min_players.into();
            assert(prize_pool >= min_entry_fees, Errors::LOW_PRIZE_POOL);

            let total_rounds = self.calculate_rounds(max_players);

            let tournament = Tournament {
                id: tournament_id,
                creator,
                name,
                tournament_type,
                status: TournamentStatus::Open,
                prize_pool,
                entry_fee,
                max_players,
                min_players,
                registration_start,
                registration_end,
                registered_players: 0,
                total_rounds,
                level_requirement,
            };
            world.write_model(@tournament);
            config.next_tournament_id += 1;
            world.write_model(@config);

            let event = TournamentCreated { tournament_id, creator, name };
            world.emit_event(@event);
        }

        fn cancel_tournament(
            ref self: ContractState,
            tournament_id: u256,
            registered_players: Array<ContractAddress>,
        ) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let mut tournament: Tournament = world.read_model(tournament_id);

            assert(caller == tournament.creator, Errors::NOT_CREATOR);
            assert(tournament.status == TournamentStatus::Open, Errors::ALREADY_STARTED);

            tournament.status = TournamentStatus::Cancelled;
            world.write_model(@tournament);

            if tournament.entry_fee > 0 {
                let config: Config = world.read_model(0);
                let erc1155 = IERC1155Dispatcher { contract_address: config.erc1155_address };
                let contract_address = get_contract_address();

                let mut i = 0;
                loop {
                    if i >= registered_players.len() {
                        break;
                    }
                    let player_id = *registered_players.at(i);
                    let participant_key = (tournament_id, player_id);
                    let participant: Participant = world.read_model(participant_key);

                    if participant.is_registered {
                        erc1155
                            .safe_transfer_from(
                                contract_address,
                                player_id,
                                config.credit_token_id,
                                tournament.entry_fee,
                                array![].span(),
                            );
                        world.erase_model(@participant)
                    }
                    i += 1;
                };
            }
            let event = TournamentCancelled {
                tournament_id, refunds_processed: registered_players.len().try_into().unwrap(),
            };
            world.emit_event(@event);
        }

        fn register(ref self: ContractState, tournament_id: u256, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            let player_id = get_caller_address();
            let mut world = self.world_default();
            let mut tournament: Tournament = world.read_model(tournament_id);
            let player: Player = world.read_model(player_id);

            let now = get_block_timestamp();
            assert(
                now >= tournament.registration_start && now < tournament.registration_end,
                Errors::REG_WINDOW_CLOSED,
            );
            assert(tournament.status == TournamentStatus::Open, Errors::NOT_OPEN);
            assert(tournament.registered_players < tournament.max_players, Errors::TOURNAMENT_FULL);
            assert(player.level >= tournament.level_requirement, Errors::LEVEL_TOO_LOW);

            let participant_key = (tournament_id, player_id);
            let participant: Participant = world.read_model(participant_key);
            assert(!participant.is_registered, Errors::ALREADY_REGISTERED);

            let config: Config = world.read_model(0);
            if tournament.entry_fee > 0 {
                let erc1155 = IERC1155Dispatcher { contract_address: config.erc1155_address };
                erc1155
                    .safe_transfer_from(
                        player_id,
                        get_contract_address(),
                        config.credit_token_id,
                        tournament.entry_fee,
                        array![].span(),
                    );
            }

            let new_participant = Participant {
                tournament_id,
                player_id,
                is_registered: true,
                matches_played: 0,
                matches_won: 0,
                is_eliminated: false,
            };
            world.write_model(@new_participant);

            tournament.registered_players += 1;
            world.write_model(@tournament);

            let event = PlayerRegistered { tournament_id, player_id };
            world.emit_event(@event);
        }

        fn unregister(ref self: ContractState, tournament_id: u256, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            let player_id = get_caller_address();
            let mut world = self.world_default();
            let mut tournament: Tournament = world.read_model(tournament_id);
            let participant_key = (tournament_id, player_id);
            let participant: Participant = world.read_model(participant_key);

            assert(tournament.status == TournamentStatus::Open, Errors::ALREADY_STARTED);
            assert(participant.is_registered, Errors::NOT_REGISTERED);

            if tournament.entry_fee > 0 {
                let config: Config = world.read_model(0);
                let erc1155 = IERC1155Dispatcher { contract_address: config.erc1155_address };
                erc1155
                    .safe_transfer_from(
                        get_contract_address(),
                        player_id,
                        config.credit_token_id,
                        tournament.entry_fee,
                        array![].span(),
                    );
            }

            world.erase_model(@participant);
            tournament.registered_players -= 1;
            world.write_model(@tournament);

            let event = PlayerUnregistered { tournament_id, player_id };
            world.emit_event(@event);
        }

        fn start_tournament(
            ref self: ContractState, tournament_id: u256, participants: Array<ContractAddress>,
        ) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let mut tournament: Tournament = world.read_model(tournament_id);

            assert(caller == tournament.creator, Errors::NOT_CREATOR);
            assert(tournament.status == TournamentStatus::Open, 'Tournament cannot be started');
            assert(
                tournament.registered_players >= tournament.min_players, Errors::NOT_ENOUGH_PLAYERS,
            );
            assert(
                participants.len() == tournament.registered_players.into(),
                'Participant list mismatch',
            );

            // Verify all participants are actually registered
            let mut i = 0;
            loop {
                if i >= participants.len() {
                    break;
                }

                let player_id = *participants.at(i);
                let participant: Participant = world.read_model((tournament_id, player_id));
                assert(participant.is_registered, Errors::UNREGISTERED_PLAYER);

                i += 1;
            };

            tournament.status = TournamentStatus::InProgress;
            world.write_model(@tournament);

            let initial_matches = self.generate_brackets(tournament_id, participants);
            let event = TournamentStarted { tournament_id, initial_matches };
            world.emit_event(@event);
        }

        fn report_match_result(
            ref self: ContractState,
            tournament_id: u256,
            match_id: u32,
            winner_id: ContractAddress,
            session_id: felt252,
        ) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
            let mut world = self.world_default();
            let match_key = (tournament_id, match_id);
            let mut match_: Match = world.read_model(match_key);
            assert(match_.match_id != 0, Errors::MATCH_NOT_FOUND);
            assert(!match_.is_completed, Errors::MATCH_COMPLETED);

            let _loser_id = if winner_id == match_.player1 {
                match_.player2.unwrap()
            } else {
                match_.player1
            };
            assert(
                winner_id == match_.player1 || winner_id == match_.player2.unwrap(),
                Errors::INVALID_WINNER,
            );

            // Handle bye rounds where player2 might be None
            if let Option::Some(player2) = match_.player2 {
                assert(winner_id == match_.player1 || winner_id == player2, Errors::INVALID_WINNER);
                let loser_id = if winner_id == match_.player1 {
                    player2
                } else {
                    match_.player1
                };
                self.update_participant_stats(tournament_id, loser_id, false);
            } else {
                // Bye round - only player1 exists
                assert(winner_id == match_.player1, Errors::INVALID_WINNER);
            }

            match_.winner = winner_id;
            match_.is_completed = true;
            world.write_model(@match_);

            self.update_participant_stats(tournament_id, winner_id, true);
            // self.update_participant_stats(tournament_id, loser_id, false);

            if let Option::Some(next_match_id) = match_.next_match_id {
                self.advance_winner(tournament_id, winner_id, next_match_id);
            } else {
                self.finalize_tournament(tournament_id, winner_id);
            }

            let event = MatchCompleted { tournament_id, match_id, winner_id };
            world.emit_event(@event);
        }

        fn claim_prize(ref self: ContractState, tournament_id: u256, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
            let player_id = get_caller_address();
            let mut world = self.world_default();
            let winner_key = (tournament_id, player_id);
            let mut winner: Winner = world.read_model(winner_key);

            assert(winner.player_id == player_id, Errors::NOT_WINNER);
            assert(!winner.has_claimed, Errors::PRIZE_CLAIMED);
            winner.has_claimed = true;
            world.write_model(@winner);

            let config: Config = world.read_model(0);
            let erc1155 = IERC1155Dispatcher { contract_address: config.erc1155_address };
            erc1155
                .safe_transfer_from(
                    get_contract_address(),
                    player_id,
                    config.credit_token_id,
                    winner.prize_amount,
                    array![].span(),
                );

            let event = PrizeClaimed { tournament_id, player_id, amount: winner.prize_amount };
            world.emit_event(@event);
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
            let current_time = starknet::get_block_timestamp();
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

        fn calculate_rounds(self: @ContractState, num_players: u32) -> u32 {
            if num_players <= 1 {
                return 0;
            }
            let mut p = num_players - 1;
            let mut rounds = 0;
            while p > 0 {
                p = p / 2;
                rounds += 1;
            };
            rounds
        }

        fn generate_brackets(
            ref self: ContractState, tournament_id: u256, participants: Array<ContractAddress>,
        ) -> u32 {
            let mut world = self.world_default();
            let tournament: Tournament = world.read_model(tournament_id);

            let num_players = tournament.registered_players;
            let total_rounds = tournament.total_rounds;
            let next_power_of_two: u32 = 2_u32.pow(total_rounds.into()).try_into().unwrap();
            let byes = next_power_of_two - num_players;
            let first_round_matches = (num_players - byes) / 2;
            let mut p_index = 0_u32;

            let mut current_match_id = 1_u32;
            let mut next_round_start_match_id = first_round_matches + byes + 1;

            // Process players who get a bye
            while p_index < byes {
                let player_id = *participants.at(p_index.into());
                let next_match_id = next_round_start_match_id + (p_index / 2);
                self.advance_winner(tournament_id, player_id, next_match_id);
                p_index += 1;
            };

            // Process players in the first round of matches
            let first_round_players_start_index = p_index;
            while p_index < num_players {
                let player1 = *participants.at(p_index.into());
                let player2 = *participants.at((p_index + 1).into());

                let relative_index = p_index - first_round_players_start_index;
                let next_match_id = next_round_start_match_id + (relative_index / 2);

                let match_to_create = Match {
                    tournament_id,
                    match_id: current_match_id,
                    round: 1,
                    player1,
                    player2: Option::Some(player2),
                    winner: starknet::contract_address_const::<0>(),
                    is_completed: false,
                    next_match_id: Option::Some(next_match_id),
                };
                world.write_model(@match_to_create);
                current_match_id += 1;
                p_index += 2;
            };
            first_round_matches
        }

        fn update_participant_stats(
            ref self: ContractState,
            tournament_id: u256,
            player_id: ContractAddress,
            is_winner: bool,
        ) {
            let mut world = self.world_default();
            let participant_key = (tournament_id, player_id);
            let mut participant: Participant = world.read_model(participant_key);
            participant.matches_played += 1;
            if is_winner {
                participant.matches_won += 1;
            } else {
                participant.is_eliminated = true;
            }
            world.write_model(@participant);
        }

        fn advance_winner(
            ref self: ContractState,
            tournament_id: u256,
            winner_id: ContractAddress,
            next_match_id: u32,
        ) {
            let mut world = self.world_default();
            let tournament: Tournament = world.read_model(tournament_id);
            let match_key = (tournament_id, next_match_id);
            let mut next_match: Match = world.read_model(match_key);

            if next_match.match_id != 0 {
                let round = self.calculate_match_round(tournament.max_players, next_match_id);
                let total_matches = tournament.max_players - 1;
                let final_match_id = total_matches;

                let mut next_next_match_id_opt = Option::None;
                if next_match_id < final_match_id {
                    // Simplified logic for next match calculation
                    let matches_in_current_round = 2_u32.pow(tournament.total_rounds - round);
                    let base_match_id = total_matches - matches_in_current_round + 1;
                    next_next_match_id_opt =
                        Option::Some(base_match_id + ((next_match_id - base_match_id) / 2));
                }

                let new_match = Match {
                    tournament_id,
                    match_id: next_match_id,
                    round,
                    player1: winner_id,
                    player2: Option::None,
                    winner: starknet::contract_address_const::<0>(),
                    is_completed: false,
                    next_match_id: next_next_match_id_opt,
                };
                world.write_model(@new_match);
            } else {
                next_match.player2 = Option::Some(winner_id);
                world.write_model(@next_match);
            }
        }

        fn finalize_tournament(
            ref self: ContractState, tournament_id: u256, winner_id: ContractAddress,
        ) {
            let mut world = self.world_default();
            let mut tournament: Tournament = world.read_model(tournament_id);
            tournament.status = TournamentStatus::Completed;
            world.write_model(@tournament);

            self.distribute_prizes(tournament_id, winner_id);

            let event = TournamentFinished { tournament_id, winner: winner_id };
            world.emit_event(@event);
        }

        fn distribute_prizes(
            ref self: ContractState, tournament_id: u256, winner_id: ContractAddress,
        ) {
            let mut world = self.world_default();
            let tournament: Tournament = world.read_model(tournament_id);

            // MVP: Winner takes all.
            let winner_prize = Winner {
                tournament_id,
                player_id: winner_id,
                placement: 1,
                prize_amount: tournament.prize_pool,
                has_claimed: false,
            };
            world.write_model(@winner_prize);
        }

        fn calculate_match_round(self: @ContractState, max_players: u32, match_id: u32) -> u32 {
            // This is a simplified calculation and may need adjustment for complex brackets.
            let mut m_id = match_id;
            let mut p = max_players;
            let mut round = 1;
            loop {
                if p <= 1 {
                    break;
                }
                let matches_in_round = p / 2;
                if m_id <= matches_in_round {
                    break;
                }
                m_id -= matches_in_round;
                p = (p + 1) / 2;
                round += 1;
            };
            round
        }
    }
}
