//********************************************************************
//                          IMPORTS                                 ||
//********************************************************************
use dojo_starter::components::stats::{Stats,StatsTrait};

//********************************************************************
//                             ENUM STRUCTURES                      ||
//********************************************************************
// Number of different armor types.
const ARMOUR_COUNT:u8= 1;

///
///'Armour'enum for different armour types.
///
#[derive(Copy, Drop, Serde, Introspect)]
enum Armour {
    Shield
}

//********************************************************************
//                   TRAIT IMPLEMENTATIONS                          ||
//********************************************************************

///
/// The implementation of the `StatsTrait` for the `Armour` enum defines two methods:  
/// 1. `stats`: Calculates and returns the specific statistics for an armour type (`Armour`) using a `match` pattern.  
/// 2. `index`: Returns a unique index (`u8`) to identify the armour type, also using a `match` pattern.  
/// This implementation currently supports only the `Shield` armour type.
/// 
impl ArmourImpl of StatsTrait<Armour> {
 fn stats(self:Armour) -> Stats {
    match self {
        Armour::Shield => Stats {attack:0, defense:6, speed:0, strength:6}
    }
 }
 
fn index(self:Armour) -> u8 {
    match self {
        Armour::Shield => 0
        }
    }
}

//********************************************************************
//                 CONVERSION IMPLEMENTATIONS                       ||
//********************************************************************

///
/// Implements the `Into<u8, Armour>` trait to enable conversion from a `u8` value to an `Armour`.  
/// Provides a `match`-based implementation to map valid indices to corresponding armour types.  
/// Panics for invalid indices.
/// 
impl U8IntoArmour of Into<u8, Armour>{
    fn into(self:u8) -> Armour {
        match self {
            0 => Armour::Shield,
            _ => panic!("wrong armour index")
        }
    }
}

///
/// Implements the `Into<Armour, ByteArray>` trait to convert an `Armour` into its string representation.  
/// Returns  corresponding textual representation for each armour type.  
/// Currently supports only the `Shield` type.
/// 
impl ArmourIntoByteArray of Into<Armour,ByteArray> {
    fn into(self:Armour) -> ByteArray{
        match self {
            Armour::Shield => "Shield"
        }
    }
}
