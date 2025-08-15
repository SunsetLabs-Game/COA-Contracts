use crate::models::player::Body;
use crate::models::gear::GearType;
use crate::helpers::gear::{parse_id, count_gear_in_array, contains_gear_type, get_high};
use crate::models::player::{DEFAULT_MAX_EQUIPPABLE_SLOT, Errors};
use core::num::traits::Zero;


// Helper function to find the index of an item in an array
fn find_item_index(array: @Array<u256>, item_id: u256) -> Option<u32> {
    let mut i = 0;
    let len = array.len();
    let mut result: Option<u32> = Option::None;

    while i < len {
        if *array.at(i) == item_id {
            result = Option::Some(i);
            break;
        }
        i += 1;
    };
    result
}

// Helper function to remove an item at a specific index from an array
fn remove_item_at_index(mut array: Array<u256>, index: u32) -> Array<u256> {
    let mut new_array = array![];
    let mut i = 0;
    while i < array.len() {
        if i != index {
            new_array.append(*array.at(i));
        }
        i += 1;
    };
    new_array
}

// Constants
const WAIST_MAX_SLOTS: u32 = 8;
const MAX_EXPLOSIVES_SLOTS: u32 = 6;
const MAX_MELEE_WEAPON_SLOTS: u32 = 3;
const HAND_MAX_COUNT: u32 = 2;
const MAX_FIREARM_SLOTS: u32 = 2;
const MAX_OFF_BODY_SLOTS: u32 = 1;

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
            GearType::Vehicle => *self.vehicle == 0_u256, // yet to implement vehicle logic
            GearType::None => false,
        }
    }

    fn equip_item(ref self: Body, item_id: u256) {
        assert(!item_id.is_zero(), Errors::INVALID_ITEM_ID);

        // check if the item is equippable
        assert(self.can_equip(item_id), Errors::CANNOT_EQUIP);

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
            GearType::Vehicle => { self.vehicle = item_id; }, // Handle vehicle logic here
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

        let mut result: u256 = 0_u256;
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
            } else if get_high(self.vehicle) == type_id {
                result = self.vehicle;
            }
        }

        result
    }

    /// Unequips an item from the body by item ID.
    /// Returns the item ID if successfully unequipped, 0 if the item was not found.
    /// This method is slot-aware and type-safe, only removing items that are actually equipped.
    fn unequip(ref self: Body, item_id: u256) -> u256 {
        let gear_type = parse_id(item_id);

        match gear_type {
            GearType::Helmet => {
                if self.head == item_id {
                    let unequipped = self.head;
                    self.head = 0_u256;
                    return unequipped;
                }
            },
            GearType::Shield | GearType::HeavyFirearms |
            GearType::Weapon => {
                if self.back == item_id {
                    let unequipped = self.back;
                    self.back = 0_u256;
                    return unequipped;
                }
            },
            GearType::Vehicle => {
                if self.vehicle == item_id {
                    let unequipped = self.vehicle;
                    self.vehicle = 0_u256;
                    return unequipped;
                }
            },
            GearType::BluntWeapon | GearType::Sword | GearType::Bow |
            GearType::Polearm => {
                // Check back slot first
                if self.back == item_id {
                    let unequipped = self.back;
                    self.back = 0_u256;
                    return unequipped;
                }
                // Check waist slot
                if let Option::Some(index) = find_item_index(@self.waist, item_id) {
                    let unequipped = *self.waist.at(index);
                    self.waist = remove_item_at_index(self.waist, index);
                    return unequipped;
                }
            },
            GearType::Firearm |
            GearType::Explosives => {
                if let Option::Some(index) = find_item_index(@self.waist, item_id) {
                    let unequipped = *self.waist.at(index);
                    self.waist = remove_item_at_index(self.waist, index);
                    return unequipped;
                }
            },
            GearType::Gloves => {
                if let Option::Some(index) = find_item_index(@self.hands, item_id) {
                    let unequipped = *self.hands.at(index);
                    self.hands = remove_item_at_index(self.hands, index);
                    return unequipped;
                }
            },
            GearType::Boots => {
                if let Option::Some(index) = find_item_index(@self.feet, item_id) {
                    let unequipped = *self.feet.at(index);
                    self.feet = remove_item_at_index(self.feet, index);
                    return unequipped;
                }
            },
            GearType::ChestArmor => {
                if let Option::Some(index) = find_item_index(@self.upper_torso, item_id) {
                    let unequipped = *self.upper_torso.at(index);
                    self.upper_torso = remove_item_at_index(self.upper_torso, index);
                    return unequipped;
                }
            },
            GearType::LegArmor => {
                if let Option::Some(index) = find_item_index(@self.lower_torso, item_id) {
                    let unequipped = *self.lower_torso.at(index);
                    self.lower_torso = remove_item_at_index(self.lower_torso, index);
                    return unequipped;
                }
            },
            GearType::Pet |
            GearType::Drone => {
                if let Option::Some(index) = find_item_index(@self.off_body, item_id) {
                    let unequipped = *self.off_body.at(index);
                    self.off_body = remove_item_at_index(self.off_body, index);
                    return unequipped;
                }
            },
            _ => {
                // Check other arrays for completeness (left_hand, right_hand, etc.)
                if let Option::Some(index) = find_item_index(@self.left_hand, item_id) {
                    let unequipped = *self.left_hand.at(index);
                    self.left_hand = remove_item_at_index(self.left_hand, index);
                    return unequipped;
                }
                if let Option::Some(index) = find_item_index(@self.right_hand, item_id) {
                    let unequipped = *self.right_hand.at(index);
                    self.right_hand = remove_item_at_index(self.right_hand, index);
                    return unequipped;
                }
                if let Option::Some(index) = find_item_index(@self.left_leg, item_id) {
                    let unequipped = *self.left_leg.at(index);
                    self.left_leg = remove_item_at_index(self.left_leg, index);
                    return unequipped;
                }
                if let Option::Some(index) = find_item_index(@self.right_leg, item_id) {
                    let unequipped = *self.right_leg.at(index);
                    self.right_leg = remove_item_at_index(self.right_leg, index);
                    return unequipped;
                }
            },
        }

        // Item not found in any slot
        0_u256
    }

    // Check if an exact item_id is equipped anywhere on the body
    fn is_item_equipped(self: @Body, item_id: u256) -> bool {
        if *self.head == item_id || *self.back == item_id || *self.vehicle == item_id {
            return true;
        }

        let arrays = array![
            self.hands,
            self.left_hand,
            self.right_hand,
            self.left_leg,
            self.right_leg,
            self.upper_torso,
            self.lower_torso,
            self.waist,
            self.feet,
            self.off_body,
        ];

        let mut i = 0;
        let mut equipped = false;
        while i < arrays.len() {
            let arr = arrays.at(i);
            if find_item_index(*arr, item_id).is_some() {
                equipped = true;
                break;
            }
            i += 1;
        };

        equipped
    }
}
