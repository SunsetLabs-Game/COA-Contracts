use crate::models::player::Body;
use crate::models::gear::GearType;
use crate::helpers::gear::{parse_id, count_gear_in_array, contains_gear_type, get_high};


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
            } else if get_high(self.vehicle) == type_id {
                result = self.vehicle;
            }
        }

        result
    }

    fn unequip(ref self: Body, item_id: u256) -> u256 {
        // TODO: Implement unequip logic
        0_u256
    }
}
