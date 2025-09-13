use crate::models::gear::{GearType, GearDetails, GearDetailsImpl};
use origami_random::dice::DiceTrait;

// Helper function to calculate upgrade multipliers based on level
pub fn calculate_level_multiplier(level: u64) -> u64 {
    // Base multiplier starts at 100% (level 0) and increases by 10% per level
    100 + (level * 10)
}

// Helper function to apply upgrade multipliers to base stats
pub fn apply_upgrade_multiplier(base_stat: u64, level: u64) -> u64 {
    let multiplier: u128 = calculate_level_multiplier(level).into();
    let base: u128 = base_stat.into();
    // Avoid u64 overflow during multiplication
    let scaled: u128 = (base * multiplier) / 100_u128;
    scaled.try_into().unwrap_or(0)
}

// Helper function to get the high 128 bits from a u256
pub fn get_high(val: u256) -> u128 {
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

//@ryzen-xp
pub fn random_geartype() -> GearType {
    let mut dice = DiceTrait::new(17, 'SEED');
    let idx = dice.roll();

    match idx {
        0 => GearType::None,
        1 => GearType::BluntWeapon,
        2 => GearType::Sword,
        3 => GearType::Bow,
        4 => GearType::Firearm,
        5 => GearType::Polearm,
        6 => GearType::HeavyFirearms,
        7 => GearType::Explosives,
        8 => GearType::Helmet,
        9 => GearType::ChestArmor,
        10 => GearType::LegArmor,
        11 => GearType::Boots,
        12 => GearType::Gloves,
        13 => GearType::Shield,
        14 => GearType::Vehicle,
        15 => GearType::Pet,
        16 => GearType::Drone,
        17 => GearType::Weapon,
        _ => GearType::None,
    }
}

//@ryzen-xp
// THis geive us max level of any Gear can be upgraded!!
// NOTE:: max level scales with gear power; not final in-game .
pub fn get_max_upgrade_level(gear_type: GearType) -> u64 {
    match gear_type {
        GearType::Weapon | GearType::BluntWeapon | GearType::Sword | GearType::Bow |
        GearType::Firearm | GearType::Polearm | GearType::HeavyFirearms |
        GearType::Explosives => 10,
        GearType::Helmet | GearType::ChestArmor | GearType::LegArmor | GearType::Boots |
        GearType::Gloves | GearType::Shield => 5,
        GearType::Vehicle => 3,
        GearType::Pet | GearType::Drone => 7,
        _ => 1,
    }
}

//@ryzen-xp
// From here we get min XP need to pick the items.
//NOTE:: XP scales with gear power; not final in-game XP system.
pub fn get_min_xp_needed(gear_type: GearType) -> u256 {
    match gear_type {
        // high damage
        GearType::HeavyFirearms => 50, // Machine guns, miniguns
        GearType::Explosives => 45, // RPGs, grenades
        GearType::Firearm => 40, // Rifles, pistols
        GearType::Bow => 35, // Bows, crossbows
        GearType::Sword => 30, // Katanas, longswords
        GearType::Polearm => 28, // Spears, halberds
        GearType::BluntWeapon => 25, // Hammers, maces
        GearType::Weapon => 20, // Generic melee/light weapons
        // Defensive gear
        GearType::Helmet => 15,
        GearType::ChestArmor => 18,
        GearType::LegArmor => 14,
        GearType::Boots => 12,
        GearType::Gloves => 10,
        GearType::Shield => 16,
        // lower damage gear
        GearType::Vehicle => 22, // Combat vehicles
        GearType::Pet => 12, // Attack/support pets
        GearType::Drone => 18, // Combat drones
        _ => 5,
    }
}

// Helper function to generate random GearDetails
pub fn random_gear_details() -> GearDetails {
    let mut gear_type = random_geartype();

    if gear_type == GearType::None {
        // Fallback to a sane default; alternatively re-roll with a different seed.
        gear_type = GearType::Weapon;
    }

    let min_xp_needed = get_min_xp_needed(gear_type);
    let max_upgrade_level = get_max_upgrade_level(gear_type);

    // Generate random base damage (between 10 and 100 for simplicity)
    let mut dice = DiceTrait::new(90, 'DAMAGE_SEED');
    let base_damage: u64 = (10 + dice.roll()).into();

    GearDetails {
        gear_type, min_xp_needed, base_damage, max_upgrade_level, total_count: 1, variation_ref: 0,
    }
}

// Helper function to validate GearDetails array
pub fn validate_gear_details_array(details: @Array<GearDetails>) -> bool {
    let mut i = 0;
    let mut valid = true;

    while i < details.len() {
        let gear_details = *details.at(i);
        if !gear_details.validate() {
            valid = false;
            break;
        }
        i += 1;
    };

    valid
}

// Helper function to generate multiple GearDetails for batch spawning
pub fn generate_batch_gear_details(amount: u32) -> Array<GearDetails> {
    let mut result = array![];
    let mut i = 0;

    while i < amount {
        result.append(random_gear_details());
        i += 1;
    };

    result
}

// Tests for helper functions
#[cfg(test)]
mod tests {
    use super::{
        GearDetailsImpl, GearType, random_gear_details, validate_gear_details_array,
        generate_batch_gear_details,
    };

    #[test]
    fn test_random_gear_details() {
        let gear = random_gear_details();
        assert(gear.validate(), 'Random gear should be valid');
        assert(gear.gear_type != GearType::None, 'Gear type should not be None');
        assert(gear.base_damage >= 10 && gear.base_damage <= 100, 'Base damage out of range');
        assert(gear.total_count == 1, 'Total count should be 1');
    }

    #[test]
    #[should_panic(expected: 'Gear type cannot be None')]
    fn test_validate_gear_details_array() {
        let mut details = array![
            GearDetailsImpl::new(GearType::Sword, 30, 50, 10, 1, 1),
            GearDetailsImpl::new(GearType::Helmet, 15, 0, 5, 1, 0),
        ];
        assert(validate_gear_details_array(@details), 'Valid array should pass');

        // Add invalid gear details
        details.append(GearDetailsImpl::new(GearType::None, 5, 10, 1, 1, 0));
    }

    #[test]
    fn test_generate_batch_gear_details() {
        let details = generate_batch_gear_details(3);
        assert(details.len() == 3, 'Should generate 3 gear details');
        assert(validate_gear_details_array(@details), 'Batch should be valid');
    }
}
