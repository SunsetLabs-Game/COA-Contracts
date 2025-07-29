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

#[generate_trait]
pub trait IntoU128<T> {
    fn into_u128(self: T) -> u128;
}

#[generate_trait]
pub trait IntoU256<T> {
    fn into_u256(self: T) -> u256;
}

pub impl GearTypeIntoU128 of IntoU128<GearType> {
    fn into_u128(self: GearType) -> u128 {
        match self {
            GearType::Weapon => 0x1,
            GearType::BluntWeapon => 0x101,
            GearType::Sword => 0x102,
            GearType::Bow => 0x103,
            GearType::Firearm => 0x104,
            GearType::Polearm => 0x105,
            GearType::HeavyFirearms => 0x106,
            GearType::Explosives => 0x107,
            GearType::Helmet => 0x2000,
            GearType::ChestArmor => 0x2001,
            GearType::LegArmor => 0x2002,
            GearType::Boots => 0x2003,
            GearType::Gloves => 0x2004,
            GearType::Shield => 0x2005,
            GearType::Vehicle => 0x30000,
            GearType::Pet => 0x800000,
            GearType::Drone => 0x800001,
            GearType::None => 0,
        }
    }
}

pub impl GearTypeIntoU256 of IntoU256<GearType> {
    fn into_u256(self: GearType) -> u256 {
        u256 { low: 0, high: GearTypeIntoU128::into_u128(self) }
    }
}

