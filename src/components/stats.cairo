//********************************************************************
//                          IMPORTS                                 ||
//********************************************************************
use core::option::OptionTrait;
use core::fmt::{Display, Formatter, Error};

//********************************************************************
//                        STATUS STRUCTURES                         ||
//********************************************************************

// `Stats` structure represents the core attributes.
// It contains the following stats: attack, defense, speed, and strength.
#[derive(Copy,Drop,Serde,Introspect)]
pub struct Stats {
    attack:u16,
    defense:u16,
    speed:u16,
    strength:u16,
}

//********************************************************************
//                          STATS TRAIT                             ||
//********************************************************************

// `StatsTrait` defines the required behavior for types that can have stats.
pub trait StatsTrait<T>{
    // returns the stats associated with type `T`.
    fn stats(self:T) -> Stats;
    // returns a unique index for the type `T`.
    fn index(self:T) -> u8;
}

//********************************************************************
//                     DISPLAY IMPLEMENTATION                        ||
//********************************************************************

// Implements `Display` for the `Stats` struct, allowing it to be formatted as a string.
// This is useful for debugging.
impl DisplayImplT of Display<Stats> {
    fn fmt(self: @Stats, ref f: Formatter) -> Result<(), Error> {
        let str: ByteArray = format!(
            "attack: {},\tdefense: {},\tspeed: {},\tstrength: {}",
            self.attack,         // Attack stat.
            self.defense,        // Defense stat.
            self.speed,          // Speed stat.
            self.strength        // Strength stat.
        );
        f.buffer.append(@str);   // Append formatted stats string to formatter.
        Result::Ok(())           // Return successful result.
    }
}

//********************************************************************
//                ADDITION IMPLEMENTATION FOR STATS                 ||
//********************************************************************

// Implements `Add` trait for `Stats` struct, allowing addition of two `Stats`.
impl StatsAdd of Add<Stats> {
    fn add(lhs: Stats, rhs: Stats) -> Stats {
        return Stats {
            attack: lhs.attack + rhs.attack,       // Add attack values.
            defense: lhs.defense + rhs.defense,    // Add defense values.
            speed: lhs.speed + rhs.speed,          // Add speed values.
            strength: lhs.strength + rhs.strength, // Add strength values.
        };
        };
    }
}

//********************************************************************
//               MULTIPLICATION IMPLEMENTATION FOR STATS            ||
//********************************************************************

// Implements the `Mul` trait for the `Stats` struct, allowing multiplication of two `Stats`.
impl StatsMul of Mul<Stats> {
    fn mul(lhs: Stats, rhs: Stats) -> Stats {
        return Stats {
            attack: lhs.attack * rhs.attack,         // Multiply attack values.
            defense: lhs.defense * rhs.defense,      // Multiply defense values.
            speed: lhs.speed * rhs.speed,            // Multiply speed values.
            strength: lhs.strength * rhs.strength,   // Multiply strength values.
        };
    }
}

//********************************************************************
//              DIVISION IMPLEMENTATION FOR STATS                   ||
//********************************************************************

// Implements the `Div` trait for the `Stats` struct, allowing division of one `Stats` object by another.
impl StatsDiv of Div<Stats> {
    fn div(lhs: Stats, rhs: Stats) -> Stats {
        return Stats {
            attack: lhs.attack / rhs.attack,         // Divide attack values.
            defense: lhs.defense / rhs.defense,      // Divide defense values.
            speed: lhs.speed / rhs.speed,            // Divide speed values.
            strength: lhs.strength / rhs.strength,   // Divide strength values
        };
    }
}

