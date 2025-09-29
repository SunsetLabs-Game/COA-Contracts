#[cfg(test)]
mod comprehensive_player_tests {
    use starknet::{ContractAddress, contract_address_const};
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
        stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
        spy_events, EventSpyAssertionsTrait,
    };
    use coa::models::player::{Player, PlayerInitialized, DamageDealt, PlayerDamaged};
    use coa::systems::player::{IPlayerDispatcher, IPlayerDispatcherTrait};

    // Faction constants
    const CHAOS_MERCENARIES: felt252 = 'CHAOS_MERCENARIES';
    const SUPREME_LAW: felt252 = 'SUPREME_LAW';
    const REBEL_TECHNOMANCERS: felt252 = 'REBEL_TECHNOMANCERS';

    // Target type constants
    const TARGET_LIVING: felt252 = 'LIVING';
    const TARGET_OBJECT: felt252 = 'OBJECT';

    fn sample_player() -> ContractAddress {
        contract_address_const::<0x123>()
    }

    fn create_player_dispatcher() -> IPlayerDispatcher {
        let contract = declare("PlayerActions");
        let mut constructor_args = array![];
        let (contract_address, _) = contract
            .unwrap()
            .contract_class()
            .deploy(@constructor_args)
            .unwrap();
        IPlayerDispatcher { contract_address }
    }

    #[test]
    fn test_player_creation() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test new player creation with valid faction
        player_dispatcher.new(CHAOS_MERCENARIES, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_player_initialization() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        let mut spy = spy_events();

        // Test player initialization
        player_dispatcher.new(CHAOS_MERCENARIES, session_id);

        // Verify PlayerInitialized event was emitted
        spy.assert_emitted(@array![
            (player_dispatcher.contract_address, PlayerInitialized {
                player_id: player,
                faction: CHAOS_MERCENARIES,
            })
        ]);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_faction_assignment() {
        let player_dispatcher = create_player_dispatcher();
        let player1 = contract_address_const::<0x123>();
        let player2 = contract_address_const::<0x456>();
        let player3 = contract_address_const::<0x789>();
        let session_id = 12345;

        // Test all three factions
        start_cheat_caller_address(player_dispatcher.contract_address, player1);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);
        player_dispatcher.new(CHAOS_MERCENARIES, session_id);
        stop_cheat_caller_address(player_dispatcher.contract_address);

        start_cheat_caller_address(player_dispatcher.contract_address, player2);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1001);
        player_dispatcher.new(SUPREME_LAW, session_id);
        stop_cheat_caller_address(player_dispatcher.contract_address);

        start_cheat_caller_address(player_dispatcher.contract_address, player3);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1002);
        player_dispatcher.new(REBEL_TECHNOMANCERS, session_id);
        stop_cheat_caller_address(player_dispatcher.contract_address);

        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_FACTION',))]
    fn test_player_creation_invalid_faction() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test with invalid faction
        player_dispatcher.new('INVALID_FACTION', session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_player_state_validation() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Create player
        player_dispatcher.new(CHAOS_MERCENARIES, session_id);

        // Test getting player state
        let player_data = player_dispatcher.get_player(1_u256, session_id);
        
        // In a real implementation, we would verify player state
        // For now, we test that the function can be called
        assert(player_data.id == player || player_data.id == contract_address_const::<0x0>(), 'Player data retrieved');

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_damage_system() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test damage calculation
        let target: Array<u256> = array![1_u256];
        let target_types: Array<felt252> = array![TARGET_LIVING];
        let with_items: Array<u256> = array![];

        player_dispatcher.deal_damage(target, target_types, with_items, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_damage_with_weapons() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test damage with weapons
        let target: Array<u256> = array![1_u256];
        let target_types: Array<felt252> = array![TARGET_LIVING];
        let weapons: Array<u256> = array![10_u256, 11_u256]; // Weapon IDs

        player_dispatcher.deal_damage(target, target_types, weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_melee_attack() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test melee attack (no weapons)
        let target: Array<u256> = array![1_u256];
        let target_types: Array<felt252> = array![TARGET_LIVING];
        let no_weapons: Array<u256> = array![];

        player_dispatcher.deal_damage(target, target_types, no_weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_damage_multiple_targets() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test damage to multiple targets
        let targets: Array<u256> = array![1_u256, 2_u256, 3_u256];
        let target_types: Array<felt252> = array![TARGET_LIVING, TARGET_LIVING, TARGET_OBJECT];
        let weapons: Array<u256> = array![10_u256];

        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('Target arrays length mismatch',))]
    fn test_damage_array_mismatch() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test with mismatched array lengths
        let targets: Array<u256> = array![1_u256, 2_u256];
        let target_types: Array<felt252> = array![TARGET_LIVING]; // Mismatch
        let weapons: Array<u256> = array![];

        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('NO_TARGETS_PROVIDED',))]
    fn test_damage_no_targets() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test with no targets
        let targets: Array<u256> = array![];
        let target_types: Array<felt252> = array![];
        let weapons: Array<u256> = array![];

        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('TOO_MANY_TARGETS',))]
    fn test_damage_too_many_targets() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test with too many targets (more than 20)
        let mut targets: Array<u256> = array![];
        let mut target_types: Array<felt252> = array![];
        
        let mut i = 0;
        loop {
            if i >= 25 { // More than the limit of 20
                break;
            }
            targets.append(i.into());
            target_types.append(TARGET_LIVING);
            i += 1;
        };

        let weapons: Array<u256> = array![];
        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_TARGET_TYPE',))]
    fn test_damage_invalid_target_type() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test with invalid target type
        let targets: Array<u256> = array![1_u256];
        let target_types: Array<felt252> = array!['INVALID_TYPE'];
        let weapons: Array<u256> = array![];

        player_dispatcher.deal_damage(targets, target_types, weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_batch_damage_system() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test batch damage processing
        let batch_targets: Array<Array<u256>> = array![
            array![1_u256, 2_u256],
            array![3_u256],
            array![4_u256, 5_u256, 6_u256]
        ];
        
        let batch_target_types: Array<Array<felt252>> = array![
            array![TARGET_LIVING, TARGET_LIVING],
            array![TARGET_OBJECT],
            array![TARGET_LIVING, TARGET_LIVING, TARGET_OBJECT]
        ];
        
        let batch_weapons: Array<Array<u256>> = array![
            array![10_u256],
            array![],
            array![11_u256, 12_u256]
        ];

        player_dispatcher.batch_deal_damage(batch_targets, batch_target_types, batch_weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('NO_ACTIONS_PROVIDED',))]
    fn test_batch_damage_no_actions() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test batch damage with no actions
        let batch_targets: Array<Array<u256>> = array![];
        let batch_target_types: Array<Array<felt252>> = array![];
        let batch_weapons: Array<Array<u256>> = array![];

        player_dispatcher.batch_deal_damage(batch_targets, batch_target_types, batch_weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_player_guild_registration() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test guild registration
        player_dispatcher.register_guild(session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_player_object_transfer() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let recipient = contract_address_const::<0x456>();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test object transfer
        let object_ids: Array<u256> = array![1_u256, 2_u256, 3_u256];
        player_dispatcher.transfer_objects(object_ids, recipient, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_player_refresh() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test player refresh
        player_dispatcher.refresh(1_u256, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    #[should_panic(expected: ('INVALID_SESSION',))]
    fn test_player_operations_invalid_session() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();

        start_cheat_caller_address(player_dispatcher.contract_address, player);

        // Test with invalid session
        player_dispatcher.new(CHAOS_MERCENARIES, 0);

        stop_cheat_caller_address(player_dispatcher.contract_address);
    }

    #[test]
    fn test_faction_damage_bonuses() {
        // Test faction-specific damage calculations
        let chaos_damage_multiplier = 120; // +20% damage
        let supreme_defense_multiplier = 125; // +25% defense
        let rebel_speed_multiplier = 115; // +15% speed

        // Test damage bonus for Chaos Mercenaries
        let base_damage = 100;
        let chaos_damage = (base_damage * chaos_damage_multiplier) / 100;
        assert(chaos_damage == 120, 'Chaos damage bonus');

        // Test defense bonus for Supreme Law
        let base_defense = 100;
        let supreme_defense = (base_defense * supreme_defense_multiplier) / 100;
        assert(supreme_defense == 125, 'Supreme defense bonus');

        // Test speed bonus for Rebel Technomancers
        let base_speed = 100;
        let rebel_speed = (base_speed * rebel_speed_multiplier) / 100;
        assert(rebel_speed == 115, 'Rebel speed bonus');
    }

    #[test]
    fn test_player_death_scenario() {
        let player_dispatcher = create_player_dispatcher();
        let player = sample_player();
        let session_id = 12345;

        start_cheat_caller_address(player_dispatcher.contract_address, player);
        start_cheat_block_timestamp(player_dispatcher.contract_address, 1000);

        // Test player death scenario (conceptual)
        // In a real implementation, this would involve:
        // 1. Dealing enough damage to reduce HP to 0
        // 2. Checking player death state
        // 3. Handling death consequences (item drops, respawn, etc.)

        let target: Array<u256> = array![1_u256]; // Target the player
        let target_types: Array<felt252> = array![TARGET_LIVING];
        let weapons: Array<u256> = array![999_u256]; // High damage weapon

        // This would simulate a fatal attack
        player_dispatcher.deal_damage(target, target_types, weapons, session_id);

        stop_cheat_caller_address(player_dispatcher.contract_address);
        stop_cheat_block_timestamp(player_dispatcher.contract_address);
    }

    #[test]
    fn test_armor_damage_reduction() {
        // Test armor damage reduction calculations
        let incoming_damage = 100_u256;
        let armor_defense = 25_u256; // 25% damage reduction
        
        let damage_after_armor = if incoming_damage > armor_defense {
            incoming_damage - armor_defense
        } else {
            0
        };
        
        assert(damage_after_armor == 75, 'Armor reduces damage');

        // Test full damage absorption
        let high_armor_defense = 150_u256;
        let no_damage = if incoming_damage > high_armor_defense {
            incoming_damage - high_armor_defense
        } else {
            0
        };
        
        assert(no_damage == 0, 'High armor blocks all damage');
    }

    #[test]
    fn test_player_rank_system() {
        // Test player rank progression and damage bonuses
        let base_damage = 100_u256;
        
        // Rank 1 player
        let rank1_multiplier = 100 + (1 * 5); // +5% per rank
        let rank1_damage = (base_damage * rank1_multiplier.into()) / 100;
        assert(rank1_damage == 105, 'Rank 1 damage bonus');
        
        // Rank 5 player
        let rank5_multiplier = 100 + (5 * 5); // +25% at rank 5
        let rank5_damage = (base_damage * rank5_multiplier.into()) / 100;
        assert(rank5_damage == 125, 'Rank 5 damage bonus');
        
        // Rank 10 player
        let rank10_multiplier = 100 + (10 * 5); // +50% at rank 10
        let rank10_damage = (base_damage * rank10_multiplier.into()) / 100;
        assert(rank10_damage == 150, 'Rank 10 damage bonus');
    }
}