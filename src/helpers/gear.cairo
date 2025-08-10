use crate::models::gear::GearType;

// Helper function to get the high 128 bits from a u256
fn get_high(val: u256) -> u128 {
    val.high
}

pub fn parse_id(id: u256) -> GearType {
    let category = get_high(id);

    // Match the high bits to determine the gear type
    if category == 0x1 {
        GearType::Weapon
    } else if category == 0x101 {
        GearType::BluntWeapon
    } else if category == 0x102 {
        GearType::Sword
    } else if category == 0x103 {
        GearType::Bow
    } else if category == 0x104 {
        GearType::Firearm
    } else if category == 0x105 {
        GearType::Polearm
    } else if category == 0x106 {
        GearType::HeavyFirearms
    } else if category == 0x107 {
        GearType::Explosives
    } else if category == 0x2000 {
        GearType::Helmet
    } else if category == 0x2001 {
        GearType::ChestArmor
    } else if category == 0x2002 {
        GearType::LegArmor
    } else if category == 0x2003 {
        GearType::Boots
    } else if category == 0x2004 {
        GearType::Gloves
    } else if category == 0x2005 {
        GearType::Shield
    } else if category == 0x30000 {
        GearType::Vehicle
    } else if category == 0x800000 {
        GearType::Pet
    } else if category == 0x800001 {
        GearType::Drone
    } else if category == 0x90000 {
        GearType::HealthPotion
    } else if category == 0x90001 {
        GearType::XpBooster
    } else if category == 0x90002 {
        GearType::EnergyDrink
    } else if category == 0x90003 {
        GearType::RepairKit
    } else if category == 0x90004 {
        GearType::Stimpack
    } else if category == 0x90005 {
        GearType::ArmorRepair
    } else if category == 0x90006 {
        GearType::WeaponOil
    } else {
        GearType::None // Fungible tokens or invalid
    }
}

pub fn count_gear_in_array(array: Array<u256>, gear_type: GearType) -> u32 {
    let mut count = 0;
    let mut i = 0;
    while i < array.len() {
        if parse_id(*array.at(i)) == gear_type {
            count += 1;
        }
        i += 1;
    };
    count
}


pub fn contains_gear_type(array: Array<u256>, gear_type: GearType) -> bool {
    let mut found = false;
    let mut i = 0;

    while i < array.len() {
        if parse_id(*array.at(i)) == gear_type {
            found = true;
            // break early if found
            i = array.len(); // force exit loop
        } else {
            i += 1;
        }
    };

    found
}

