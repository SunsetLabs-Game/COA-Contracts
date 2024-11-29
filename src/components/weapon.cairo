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

///
/// Defines 'Weapon' Enum with available weapon types: Sword and Katana.
/// 
#[derive(Copy, Drop, Serde, Introspect)]
enum Weapon {
    Sword,
    Katana
}

//********************************************************************
//                    WEAPON STATS IMPLEMENTATION                   ||
//********************************************************************

///
/// Implements the `StatsTrait` for the `Weapon` enum to define stats for each weapon.
/// 1. `stats`: Returns the stats (attack, defense, speed, strength) for a specific weapon (`Sword` or `Katana`).
/// 2. `index`: Returns the unique index (`u8`) for each weapon (`Sword` -> 0, `Katana` -> 1).
/// 
impl WeaponImpl of StatsTrait<Weapon>{
    fn stats(self: Weapon) ->Stats {
        match self {
            Weapon::Sword  => Stats { attack:4, defense:0, speed:3, strength:6},
            Weapon::Katana => Stats {attack:3, defense :0, speed :7, strength :2}
        }
    }
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

///
/// Implements the conversion from `u8` to `Weapon` using the `Into` trait.
/// 1.`into`: Converts an index (`u8`) to the corresponding weapon type (`Sword` for index 0, `Katana` for index 1).
///  If the index is invalid, it panics with an error message.
/// 
impl U8IntoWeapon of Into<u8, Weapon> {
    fn into(self: u8) -> Weapon{
        match self {
            0 => Weapon::Sword,               
            1 => Weapon::Katana,               
            _ => panic!("wrong weapon index")  
        }
    }
}

///
/// Implements conversion from `Weapon` to `ByteArray` for text representation.
/// 1. `into`: Converts a `Weapon` (`Sword` or `Katana`) to its corresponding string representation.
/// 
impl WeaponIntoByteArray of Into<Weapon,ByteArray> {
    fn into(self:Weapon) ->ByteArray {
        match self {
            Weapon::Sword => "Sword",      
            Weapon::Katana => "Katana"     
        }
    }
}