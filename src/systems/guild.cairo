use starknet::ContractAddress;
use coa::models::guild::{
    Guild, GuildMember, GuildRole, GuildInvite, GuildCreated, GuildJoined, GuildLeft,
    GuildInviteSent, GuildInviteAccepted,
};
use coa::models::tournament::Config;

#[starknet::interface]
pub trait IGuild<TContractState> {
    fn create_guild(ref self: TContractState, guild_name: felt252);
    fn join_guild(ref self: TContractState, guild_id: u256);
    fn leave_guild(ref self: TContractState);
    fn invite_to_guild(ref self: TContractState, player_id: ContractAddress);
    fn accept_guild_invite(ref self: TContractState, guild_id: u256);
}

#[dojo::contract]
pub mod GuildActions {
    use super::IGuild;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use coa::models::guild::{
        Guild, GuildMember, GuildRole, GuildInvite, GuildCreated, GuildJoined, GuildLeft,
        GuildInviteSent, GuildInviteAccepted,
    };
    use coa::models::tournament::Config;
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;
    use dojo::world::WorldStorage;

    #[abi(embed_v0)]
    pub impl GuildActionsImpl of super::IGuild<ContractState> {
        fn create_guild(ref self: ContractState, guild_name: felt252) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            // Check if player is already in a guild
            let existing_guild: GuildMember = world.read_model((0, caller));
            assert(existing_guild.guild_id == 0, 'Player already in guild');

            // Create guild
            let guild_id = self.generate_guild_id();
            let guild = Guild {
                id: guild_id,
                name: guild_name,
                leader: caller,
                level: 1,
                experience: 0,
                member_count: 1,
                max_members: 50,
                created_at: get_block_timestamp(),
                description: 'A new guild',
            };

            // Add player to guild as leader
            let guild_member = GuildMember {
                guild_id,
                player_id: caller,
                role: GuildRole::Leader,
                joined_at: get_block_timestamp(),
                contribution: 0,
            };

            world.write_model(@guild);
            world.write_model(@guild_member);
            world.emit_event(@GuildCreated { guild_id, leader: caller, name: guild_name });
        }

        fn join_guild(ref self: ContractState, guild_id: u256) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            // Check if player is already in a guild
            let existing_guild: GuildMember = world.read_model((0, caller));
            assert(existing_guild.guild_id == 0, 'Player already in guild');

            // Get guild and check if it has space
            let mut guild: Guild = world.read_model(guild_id);
            assert(guild.id != 0, 'Guild not found');
            assert(guild.member_count < guild.max_members, 'Guild full');

            // Add player to guild
            let guild_member = GuildMember {
                guild_id,
                player_id: caller,
                role: GuildRole::Member,
                joined_at: get_block_timestamp(),
                contribution: 0,
            };

            guild.member_count += 1;

            world.write_model(@guild);
            world.write_model(@guild_member);
            world.emit_event(@GuildJoined { guild_id, player_id: caller, role: GuildRole::Member });
        }

        fn leave_guild(ref self: ContractState) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            // Get player's guild membership
            let guild_member: GuildMember = world.read_model((0, caller));
            assert(guild_member.guild_id != 0, 'Player not in guild');

            // Get guild and update member count
            let mut guild: Guild = world.read_model(guild_member.guild_id);
            guild.member_count -= 1;

            // If leader is leaving, disband guild or transfer leadership
            if guild_member.role == GuildRole::Leader {
                // For now, disband the guild
                guild.id = 0; // Mark as disbanded
            }

            // Remove player from guild
            let empty_guild_member = GuildMember {
                guild_id: 0,
                player_id: caller,
                role: GuildRole::Member,
                joined_at: 0,
                contribution: 0,
            };

            world.write_model(@guild);
            world.write_model(@empty_guild_member);
            world.emit_event(@GuildLeft { guild_id: guild_member.guild_id, player_id: caller });
        }

        fn invite_to_guild(ref self: ContractState, player_id: ContractAddress) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            // Get caller's guild membership
            let guild_member: GuildMember = world.read_model((0, caller));
            assert(guild_member.guild_id != 0, 'Player not in guild');
            assert(
                guild_member.role == GuildRole::Leader || guild_member.role == GuildRole::Officer,
                'Insufficient permissions',
            );

            // Check if target player is already in a guild
            let target_guild: GuildMember = world.read_model((0, player_id));
            assert(target_guild.guild_id == 0, 'Player already in guild');

            // Create invite
            let invite = GuildInvite {
                guild_id: guild_member.guild_id,
                player_id,
                invited_by: caller,
                created_at: get_block_timestamp(),
                expires_at: get_block_timestamp() + 86400, // 24 hours
                is_accepted: false,
            };

            world.write_model(@invite);
            world
                .emit_event(
                    @GuildInviteSent {
                        guild_id: guild_member.guild_id, player_id, invited_by: caller,
                    },
                );
        }

        fn accept_guild_invite(ref self: ContractState, guild_id: u256) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            // Get invite
            let mut invite: GuildInvite = world.read_model((guild_id, caller));
            assert(invite.guild_id != 0, 'Invite not found');
            assert(!invite.is_accepted, 'Invite already accepted');
            assert(get_block_timestamp() <= invite.expires_at, 'Invite expired');

            // Check if player is already in a guild
            let existing_guild: GuildMember = world.read_model((0, caller));
            assert(existing_guild.guild_id == 0, 'Player already in guild');

            // Get guild and check if it has space
            let mut guild: Guild = world.read_model(guild_id);
            assert(guild.member_count < guild.max_members, 'Guild full');

            // Add player to guild
            let guild_member = GuildMember {
                guild_id,
                player_id: caller,
                role: GuildRole::Member,
                joined_at: get_block_timestamp(),
                contribution: 0,
            };

            guild.member_count += 1;
            invite.is_accepted = true;

            world.write_model(@guild);
            world.write_model(@guild_member);
            world.write_model(@invite);
            world.emit_event(@GuildJoined { guild_id, player_id: caller, role: GuildRole::Member });
            world.emit_event(@GuildInviteAccepted { guild_id, player_id: caller });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"coa")
        }

        fn generate_guild_id(ref self: ContractState) -> u256 {
            let mut world = self.world_default();
            let mut config: Config = world.read_model(0);

            config.next_guild_id += 1;
            world.write_model(@config);

            config.next_guild_id
        }
    }
}
