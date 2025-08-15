use starknet::ContractAddress;
use crate::helpers::base::ContractAddressDefault;
use core::num::traits::Zero;
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use crate::erc1155::erc1155::{IERC1155MintableDispatcher, IERC1155MintableDispatcherTrait};
use crate::types::player::{PlayerRank, PlayerRankTrait};
use crate::types::base::{CREDITS};
use dojo::world::{WorldStorage};
use crate::helpers::body::BodyTrait;
use crate::models::gear::GearType;
use crate::helpers::gear::{parse_id};

const DEFAULT_HP: u256 = 500;
pub const DEFAULT_MAX_EQUIPPABLE_SLOT: u32 = 10;
const WAIST_MAX_SLOTS: u32 = 8;


#[derive(Drop, Clone, Serde, Debug, Default, Introspect)]
pub struct Body {
    pub head: u256, // For Helmet
    pub hands: Array<u256>, // For Gloves
    pub left_hand: Array<u256>,
    pub right_hand: Array<u256>,
    pub left_leg: Array<u256>,
    pub right_leg: Array<u256>,
    pub upper_torso: Array<u256>,
    pub lower_torso: Array<u256>,
    pub back: u256, // hangables, but it's usually just an item, leave it one for now.
    pub waist: Array<u256>, // Max 8 slots for now.
    pub feet: Array<u256>, // For Boots
    // Non-body-worn gear
    pub off_body: Array<u256>, // For drones/pets/AI companions — max 1 item
    pub vehicle: u256,
}

#[dojo::model]
#[derive(Drop, Clone, Serde, Debug, Default)]
pub struct Player {
    #[key]
    pub id: ContractAddress,
    pub hp: u256,
    pub max_hp: u256,
    pub equipped: Array<u256>, // equipped from Player Inventory
    pub max_equip_slot: u32,
    pub rank: PlayerRank,
    pub level: u256, // this level is broken down from exps, usuable for boosters
    pub xp: u256,
    pub faction: felt252,
    pub next_rank_in: u64,
    pub body: Body,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct DamageDealt {
    #[key]
    pub attacker: ContractAddress,
    #[key]
    pub target: u256,
    pub damage: u256,
    pub target_type: felt252,
}

#[derive(Drop, Copy, Serde)]
#[dojo::event]
pub struct PlayerDamaged {
    #[key]
    pub player_id: u256,
    pub damage_received: u256,
    pub damage_reduction: u256,
    pub actual_damage: u256,
    pub remaining_hp: u256,
    pub is_alive: bool,
}

#[derive(Copy, Drop, Serde)]
pub struct FactionStats {
    pub damage_multiplier: u256,
    pub defense_multiplier: u256,
    pub speed_multiplier: u256,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct PlayerInitialized {
    #[key]
    pub player_id: ContractAddress,
    pub faction: felt252,
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
            self.body = Default::default();
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

    fn is_available(self: @Player, item_id: u256) -> bool {
        true
    }

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

    // fn add_xp(ref self: Player, value: u256) -> bool {
    //     // can be refactored to take in a task id with it's available xp to be earned or computed
    //     // for now it just takes in the raw value.
    //     // use the bool value to emit an event that a player has leveled up
    //     // or emit the event right from here.
    //     // and some combat skills mighht be locked until enough xp is gained.
    //     false
    // }

    // fn get_xp(self: @Player) -> u256 {
    //     // returns the player's xp.
    //     0
    // }

    fn has_free_inventory_slot(self: @Player) -> bool {
        self.equipped.len() < *self.max_equip_slot
    }

    // Update get_xp function implementation
    fn get_xp(self: @Player) -> u256 {
        *self.xp
    }

    // Update the existing add_xp function to actually modify XP
    fn add_xp(ref self: Player, value: u256) -> bool {
        let old_level = self.level;
        self.xp += value;

        let new_level = self.xp / 1000;
        if new_level > old_level {
            self.level = new_level;
            true // Player leveled up
        } else {
            false
        }
    }

    fn has_vehicle_equipped(self: @Player) -> bool {
        let vehicle_in_off_body = self.body.off_body.len() > 0
            && {
                let mut has_vehicle = false;
                let mut i = 0;
                while i < self.body.off_body.len() {
                    if parse_id(*self.body.off_body.at(i)) == GearType::Vehicle {
                        has_vehicle = true;
                        break;
                    }
                    i += 1;
                };
                has_vehicle
            };
        vehicle_in_off_body || parse_id(*self.body.back) == GearType::Vehicle
    }

    fn get_multiplier(self: @Player) -> u16 {
        // for the attack, the Rank level can serve as a multiplier.
        0
    }

    fn is_equippable(self: @Player, item_id: u256) -> bool {
        self.body.can_equip(item_id)
    }

    fn equip(ref self: Player, item_id: u256) {
        // check if the player has enough slots to equip this item
        assert(self.equipped.len() < self.max_equip_slot, Errors::INSUFFICIENT_SLOTS);
        self.body.equip_item(item_id);

        // add the item to the equipped list
        self.equipped.append(item_id);
    }

    fn is_equipped(self: Player, type_id: u128) -> u256 {
        // let equipped = self.equipped; // use this array to check if the item is equipped
        self.body.get_equipped_item(type_id)
    }

    fn receive_damage(ref self: Player, damage: u256) -> bool {
        // Calculate damage reduction based on equipped armor
        let damage_reduction = self.calculate_damage_reduction();
        let actual_damage = if damage > damage_reduction {
            damage - damage_reduction
        } else {
            0
        };

        // Reduce HP
        if actual_damage > 0 {
            if actual_damage >= self.hp {
                // Player dies
                self.hp = 0;
                false
            } else {
                self.hp -= actual_damage;
                true
            }
        } else {
            // No damage taken
            true
        }
    }
    fn calculate_damage_reduction(self: @Player) -> u256 {
        // Calculate damage reduction based on equipped armor
        let mut total_reduction: u256 = 0;

        // Check upper and lower torso for armor
        if !self.body.upper_torso.is_empty() {
            total_reduction += 10; // Example fixed reduction for chest armor
        }
        if !self.body.lower_torso.is_empty() {
            total_reduction += 5; // Example fixed reduction for leg armor
        }
        if *self.body.head != 0 {
            total_reduction += 3; // Helmet reduction
        }

        total_reduction
    }

    #[inline(always)]
    fn check(self: @Player) {
        assert(self.id.is_non_zero(), Errors::ZERO_PLAYER);
    }
    // fn equip(ref self: Player, ref Item) {
//     assert()
// }
}


#[generate_trait]
pub impl BodyImpl of BodyTrait {
    fn can_equip(self: @Body, item_id: u256) -> bool {
        let gear_type = parse_id(item_id);

        match gear_type {
            GearType::Helmet => *self.head == 0_u256,
            // An armour cannot be equipped if one has been equipped already
            GearType::ChestArmor => !contains_gear_type(
                self.upper_torso.clone(), GearType::ChestArmor,
            ),
            GearType::LegArmor => !contains_gear_type(self.lower_torso.clone(), GearType::LegArmor),
            GearType::Boots => !contains_gear_type(self.feet.clone(), GearType::Boots),
            GearType::Gloves => !contains_gear_type(self.hands.clone(), GearType::Gloves),
            GearType::Shield => *self.back == 0_u256,
            // The back can hold Backpack, Quiver, Cape, etc.
            GearType::Pet | GearType::Drone => self.off_body.len() < MAX_OFF_BODY_SLOTS,
            GearType::BluntWeapon | GearType::Sword | GearType::Bow |
            GearType::Polearm => {
                let melee_count = count_gear_in_array(self.waist.clone(), GearType::BluntWeapon)
                    + count_gear_in_array(self.waist.clone(), GearType::Sword)
                    + count_gear_in_array(self.waist.clone(), GearType::Bow)
                    + count_gear_in_array(self.waist.clone(), GearType::Polearm);

                let back_slot_empty = *self.back == 0_u256;

                (melee_count < MAX_MELEE_WEAPON_SLOTS && self.waist.len() < WAIST_MAX_SLOTS)
                    || back_slot_empty
            },
            GearType::HeavyFirearms => { *self.back == 0_u256 },
            GearType::Firearm => {
                {
                    if self.waist.len() >= WAIST_MAX_SLOTS {
                        return false;
                    }
                    let pistol_count = count_gear_in_array(self.waist.clone(), GearType::Firearm);
                    pistol_count < MAX_FIREARM_SLOTS
                }
            },
            GearType::Explosives => {
                if self.waist.len() >= WAIST_MAX_SLOTS {
                    return false;
                }
                let explosives_count = count_gear_in_array(
                    self.waist.clone(), GearType::Explosives,
                );
                explosives_count < MAX_EXPLOSIVES_SLOTS
            },
            GearType::Weapon => *self.back == 0_u256,
            GearType::Vehicle => true, // yet to implement vehicle logic
            // Consumables can be equipped in waist slots
            GearType::HealthPotion | GearType::XpBooster | GearType::EnergyDrink |
            GearType::RepairKit | GearType::Stimpack | GearType::ArmorRepair |
            GearType::WeaponOil => self.waist.len() < WAIST_MAX_SLOTS,
            GearType::None => false,
        }
    }

    fn equip_item(ref self: Body, item_id: u256) {
        let gear_type = parse_id(item_id);

        match gear_type {
            GearType::Helmet => self.head = item_id,
            GearType::Gloves => self.hands.append(item_id),
            // equips a pair of shoes, etc
            GearType::Boots => self.feet.append(item_id),
            GearType::Shield => self.back = item_id,
            GearType::BluntWeapon | GearType::Sword | GearType::Bow |
            GearType::Polearm => {
                if self.back == 0_u256 {
                    self.back = item_id;
                } else {
                    self.waist.append(item_id);
                }
            },
            GearType::HeavyFirearms => { self.back = item_id; },
            GearType::Firearm => { self.waist.append(item_id); },
            GearType::Explosives => { self.waist.append(item_id); },
            GearType::Weapon => { self.back = item_id; },
            GearType::Pet | GearType::Drone => { self.off_body.append(item_id); },
            GearType::ChestArmor => self.upper_torso.append(item_id),
            GearType::LegArmor => self.lower_torso.append(item_id),
            GearType::Vehicle => {}, // Handle vehicle logic here
            _ => { // Do nothing
            },
        }
    }

    fn get_equipped_item(self: Body, type_id: u128) -> u256 {
        let equipped_arrays = array![
            self.left_hand,
            self.right_hand,
            self.left_leg,
            self.right_leg,
            self.upper_torso,
            self.lower_torso,
            self.waist,
            self.feet,
            self.hands,
            self.off_body,
        ];

        let mut result: u256 = 0;
        let mut found = false;
        let mut i = 0;
        let arrays_len = equipped_arrays.len();
        while i < arrays_len && !found {
            let arr = equipped_arrays.at(i);
            let mut j = 0;
            let arr_len = arr.len();
            while j < arr_len && !found {
                let item = *arr.at(j);
                if get_high(item) == type_id {
                    result = item;
                    found = true;
                }
                j = j + 1;
            };
            i = i + 1;
        };

        if !found {
            if get_high(self.back) == type_id {
                result = self.back;
            } else if get_high(self.head) == type_id {
                result = self.head;
            }
        }

        result
    }
}


fn erc1155(contract_address: ContractAddress) -> IERC1155Dispatcher {
    IERC1155Dispatcher { contract_address }
}

fn erc1155mint(contract_address: ContractAddress) -> IERC1155MintableDispatcher {
    IERC1155MintableDispatcher { contract_address }
}

pub mod Errors {
    pub const ZERO_PLAYER: felt252 = 'ZERO PLAYER';
    pub const INVALID_ITEM_ID: felt252 = 'INVALID ITEM ID';
    pub const CANNOT_EQUIP: felt252 = 'CANNOT EQUIP';
    pub const INSUFFICIENT_SLOTS: felt252 = 'INSUFFICIENT EQUIP SLOTS';
    pub const OUT_ITEM_NOT_EQUIPPED: felt252 = 'OUT ITEM NOT EQUIPPED';
    pub const OUT_ITEM_NOT_OWNED: felt252 = 'OUT ITEM NOT OWNED';
    pub const IN_ITEM_NOT_OWNED: felt252 = 'IN ITEM NOT OWNED';
    pub const IN_ITEM_ALREADY_EQUIPPED: felt252 = 'IN ITEM ALREADY EQUIPPED';
    pub const VEHICLE_NOT_EQUIPPED: felt252 = 'VEHICLE NOT EQUIPPED';
    pub const ITEM_TOKEN_NOT_OWNED: felt252 = 'PLAYER NOT OWNER OF ITEM TOKEN';
    pub const IN_ITEM_SAME_AS_OUT_ITEM: felt252 = 'IN ITEM SAME AS OUT ITEM';
}

// Helper function to get the high 128 bits from a u256
fn get_high(val: u256) -> u128 {
    val.high
}

fn get_low(val: u256) -> u128 {
    val.low
}
