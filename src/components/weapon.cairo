//********************************************************************
//                          IMPORTS                                 ||
//********************************************************************
use dojo_starter::components::stats::{Stats,StatsTrait};

//********************************************************************
//                          CONSTANTS                               ||
//********************************************************************
const WEAPON_COUNT:u8= 2;

//********************************************************************
//                          WEAPON ENUM                              ||
//********************************************************************

// Defines 'Weapon' Enum with available weapon types: Sword and Katana.
#[derive(Copy, Drop, Serde, Introspect)]
enum Weapon {
    Sword,
    Katana
}

//********************************************************************
//                    WEAPON STATS IMPLEMENTATION                   ||
//********************************************************************

// Implements the `StatsTrait` for the `Weapon` enum to define stats for each weapon.
impl WeaponImpl of StatsTrait<Weapon>{
     // Returns the stats for a specific weapon.
    fn stats(self: Weapon) ->Stats {
        match self {
            Weapon::Sword  => Stats { attack:4, defense:0, speed:3, strength:6},
            Weapon::Katana => Stats {attack:3, defense :0, speed :7, strength :2}
        }
    }
    // Returns the index for the weapon.
    fn index(self:Weapon) -> u8 {
        match self {
            Weapon::Sword => 0,
            Weapon::Katana => 1,
        }
    }
}

//********************************************************************
//                      WEAPON CONVERSION IMPLEMENTATION            ||
//********************************************************************

// Implements the conversion from `u8` to `Weapon` using the `Into` trait.
impl U8IntoWeapon of Into<u8, Weapon> {
     // Converts an index `u8` to corresponding weapon type.
    fn into(self: u8) -> Weapon{
        match self {
            0 => Weapon::Sword,                // Convert index 0 to Sword.
            1 => Weapon::Katana,               // Convert index 1 to Katana.
            _ => panic!("wrong weapon index")  // Panic for invalid index.
        }
    }
}

//Implements conversion from `Weapon` to `ByteArray` for text representation.
impl WeaponIntoByteArray of Into<Weapon,ByteArray> {
    fn into(self:Weapon) ->ByteArray {
        match self {
            Weapon::Sword => "Sword",      // Convert Sword to string.
            Weapon::Katana => "Katana"     // Convert Katana to string.
        }
    }
}