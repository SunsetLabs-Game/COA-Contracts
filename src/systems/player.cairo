use crate::models::player::Player;

#[starknet::interface]
pub trait IPlayer<TContractState> {
    fn new(ref self: TContractState, faction: felt252);
    fn deal_damage(
        ref self: TContractState,
        attacker_id: u256,
        target: Array<u256>,
        target_types: Array<felt252>,
        with_items: Array<u256>,
    );
    fn get_player(self: @TContractState, player_id: u256) -> Player;
    fn register_guild(ref self: TContractState);
}

#[dojo::contract]
pub mod PlayerActions {
    use starknet::{ContractAddress, get_caller_address};
    use crate::models::player::{Player, PlayerTrait};
    use super::IPlayer;

    // const GEAR_
    const MIN_THRESHOLD: u32 = 80;


    fn dojo_init(
        ref self: ContractState, admin: ContractAddress, default_amount_of_credits: u256,
    ) { // write admin
    // write default amount of credits.

    }

    #[abi(embed_v0)]
    impl PlayerActionsImpl of IPlayer<ContractState> {
        fn new(ref self: ContractState, faction: felt252) { // create the player
        // and call mint
        // maybe in the future, you implement a `mint_default()`
        // spawn player at some random location.
        }

        fn deal_damage(
            ref self: ContractState,
            attacker_id : u256 ,
            target: Array<u256>,
            target_types: Array<felt252>,
            with_items: Array<u256>,
        ) {

            let attacker = self.get_player(attacker_id);
            let attacker_xp: u32 = attacker.xp;

            for i in 0..target.len() {
                let target_id = target.at(i);
                let target_player = self.get_player(*target_id);
                let target_xp: u32 = target_player.xp;

                let xp_diff = if attacker_xp >= target_xp {
                    attacker_xp - target_xp
                } else {
                    target_xp - attacker_xp
                };

                let mut multiplier = (xp_diff / MIN_THRESHOLD) + 1;
                if multiplier < 1 {
                    multiplier = 1;
                }

                //  For now base damage is hardcoded,It dynamicly depandenton  iteam/ weapon type
                let base_damage: u32 = 10;

                let actual_damage = if attacker_xp >= target_xp {
                    base_damage * multiplier
                } else {
                    base_damage / multiplier
                };

                self.receive_damage(*target_id, actual_damage.into());
            }
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
        }

        fn get_player(self: @ContractState, player_id: u256) -> Player {
            Default::default()
        }
        fn register_guild(ref self: ContractState) {}
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn receive_damage(ref self: ContractState, player_id: u256, damage: u256) {}
    }
}
