use core::num::traits::Zero;
use dojo::world::WorldStorage;
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use starknet::ContractAddress;
use crate::erc1155::erc1155::{IERC1155MintableDispatcher, IERC1155MintableDispatcherTrait};
use crate::helpers::base::ContractAddressDefault;
use crate::types::base::CREDITS;
use crate::types::player::{PlayerRank, PlayerRankTrait};

const DEFAULT_HP: u128 = 500;
const DEFAULT_MAX_EQUIPPABLE_SLOT: u32 = 10;

#[dojo::model]
#[derive(Drop, Clone, Serde, Debug, Default)]
pub struct Player {
    #[key]
    pub id: ContractAddress,
    pub hp: u128,
    pub max_hp: u128,
    pub equipped: Array<u256>, // equipped from Player Inventory
    pub max_equip_slot: u32,
    pub rank: PlayerRank,
    pub level: u256, // this level is broken down from exps, usuable for boosters
    pub faction: felt252,
    pub next_rank_in: u64,
    pub left_hand: Array<u256>,
    pub right_hand: Array<u256>,
    pub left_leg: Array<u256>,
    pub right_leg: Array<u256>,
    pub upper_torso: Array<u256>,
    pub lower_torso: Array<u256>,
    pub back: u256, // hangables, but it's usually just an item, leave it one for now.
    pub waist: Array<u256> // max len for this field should be 8. (for now).
}

#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    fn init(ref self: Player, faction: felt252) {
        self.check();
        // does nothing if the player exists
        if self.max_hp == 0 {
            self.hp = DEFAULT_HP;
            self.max_hp = DEFAULT_HP;
            self.max_equip_slot = DEFAULT_MAX_EQUIPPABLE_SLOT;
            self.rank = Default::default();
            self.next_rank_in = self.rank.compute_max_val(); // change this
        }
    }

    #[inline(always)]
    fn get_credits(ref self: Player, erc1155_address: ContractAddress) -> u256 {
        self.check();
        erc1155(erc1155_address).balance_of(self.id, CREDITS)
    }

    #[inline(always)]
    fn mint_credits(ref self: Player, amount: u256, erc1155_address: ContractAddress) {
        self.check();
        assert(amount > 0, 'INVALID AMOUNT');
        self.mint(CREDITS, erc1155_address, amount);
    }

    #[inline(always)]
    fn mint(ref self: Player, id: u256, erc1155_address: ContractAddress, amount: u256) {
        // to mint anything fungible
        // verify its id, and verify if it even exists
        // if fungible, use amount, else, ignore the amount.
        erc1155mint(erc1155_address).mint(self.id, id, amount, array![].span());
    }

    #[inline(always)]
    fn mint_batch(ref self: Player) {}

    #[inline(always)]
    fn purchase(
        ref self: Player, item_id: u256,
    ) { // use the item trait and add this to their inventory, using the erc1155
    // use the inventory trait `add to inventory` for this feat
    // the systems must check if this item exists before calling this function
    }

    fn is_available(self: @Player, item_id: u256) {}

    fn use_item(
        ref self: Player, ref world: WorldStorage, id: u256,
    ) { // once used, it should be burned.
    // Say an asset that increases hp or xp.
    // All these should be done in the Inventory trait.
    // the item trait called by this function should take in the ref of this player
    // replace item_id with the original item to use it's trait
    // the world manipulations would be optimized here.
    // And i bet you can only use this item only if it is equipped.
    // Health should be fungible
    }

    fn add_xp(ref self: Player, value: u256) -> bool {
        // can be refactored to take in a task id with it's available xp to be earned or computed
        // for now it just takes in the raw value.
        // use the bool value to emit an event that a player has leveled up
        // or emit the event right from here.
        // and some combat skills mighht be locked until enough xp is gained.
        false
    }

    fn get_xp(self: @Player) -> u256 {
        // returns the player's xp.
        0
    }

    fn get_multiplier(self: @Player) -> u16 {
        // for the attack, the Rank level can serve as a multiplier.
        0
    }

    fn is_equippable(self: @Player, item_id: u256) -> bool {
        false
    }

    fn is_equipped(self: @Player, type_id: u128) -> u256 {
        0
    }

    #[inline(always)]
    fn check(self: @Player) {
        assert(self.id.is_non_zero(), Errors::ZERO_PLAYER);
    }
    // fn equip(ref self: Player, ref Item) {
//     assert()
// }
}

fn erc1155(contract_address: ContractAddress) -> IERC1155Dispatcher {
    IERC1155Dispatcher { contract_address }
}

fn erc1155mint(contract_address: ContractAddress) -> IERC1155MintableDispatcher {
    IERC1155MintableDispatcher { contract_address }
}

pub mod Errors {
    pub const ZERO_PLAYER: felt252 = 'ZERO PLAYER';
}
