//********************************************************************
//                          IMPORTS                                 ||
//********************************************************************
use dojo_starter::components::stats::{Stats,StatsTrait};

//********************************************************************
//                             ENUM STRUCTURES                      ||
//********************************************************************
// Number of different armor types.
const ARMOUR_COUNT:u8= 1;

// Enum for different armour types.
#[derive(Copy, Drop, Serde, Introspect)]
enum Armour {
    Shield
}

//********************************************************************
//                   TRAIT IMPLEMENTATIONS                          ||
//********************************************************************

// Implements of `StatsTrait<Armour>`trait for `Armour` Enum.
impl ArmourImpl of StatsTrait<Armour> {

// Returns the stats for the given armour type.
 fn stats(self:Armour) -> Stats {
    match self {
        Armour::Shield => Stats {attack:0, defense:6, speed:0, strength:6}
    }
 }
 
// Returns the index of the given armor type.
fn index(self:Armour) -> u8 {
    match self {
        Armour::Shield => 0
        }
    }
}

//********************************************************************
//                 CONVERSION IMPLEMENTATIONS                       ||
//********************************************************************

// Implementation of `Into<u8, Armour>` trait.
impl U8IntoArmour of Into<u8, Armour>{

    // Converts `u8` to `Armour` or panics on invalid index.
    fn into(self:u8) -> Armour {
        match self {
            0 => Armour::Shield,
            _ => panic!("wrong armour index")
        }
    }
}

// Implementation of `Into<Armour, ByteArray>` trait.
impl ArmourIntoByteArray of Into<Armour,ByteArray> {

    // Converts Armour into ByteArray for textual representation.
    fn into(self:Armour) -> ByteArray{
        match self {
            Armour::Shield => "Shield"
        }
    }
}
