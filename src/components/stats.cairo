//********************************************************************
//                          IMPORTS                                 ||
//********************************************************************
use core::option::OptionTrait;
use core::fmt::{Display, Formatter, Error};

//********************************************************************
//                        STATUS STRUCTURES                         ||
//********************************************************************

///
/// The `Stats` structure represents the core attributes of a character or entity.
/// 1. `attack`: The attack value of the entity.  
/// 2. `defense`: The defense value of the entity.  
/// 3. `speed`: The speed value of the entity.  
/// 4. `strength`: The strength value of the entity.
/// 
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

///
/// `StatsTrait` defines the required behavior for types that can have stats.
/// 1. `stats`: Returns the stats associated with type `T`.  
/// 2. `index`: Returns a unique index (`u8`) for the type `T`.
/// 
pub trait StatsTrait<T>{
    fn stats(self:T) -> Stats;
    fn index(self:T) -> u8;
}

//********************************************************************
//                     DISPLAY IMPLEMENTATION                       ||
//********************************************************************

///
/// Implements `Display` for the `Stats` struct, allowing it to be formatted as a string.
/// This is useful for debugging.
/// 1. `fmt`:Formats`Stats` struct into a string displaying its attributes: `attack`, `defense`, `speed`, and `strength`.
/// 
impl DisplayImplT of Display<Stats> {
    fn fmt(self: @Stats, ref f: Formatter) -> Result<(), Error> {
        let str: ByteArray = format!(
            "attack: {},\tdefense: {},\tspeed: {},\tstrength: {}",
            self.attack,         
            self.defense,        
            self.speed,          
            self.strength        
        );
        f.buffer.append(@str);   
        Result::Ok(())          
    }
}

//********************************************************************
//                ADDITION IMPLEMENTATION FOR STATS                 ||
//********************************************************************

///
/// The Implements `Add` trait for `Stats` struct, allowing addition of two `Stats`.
///1.`add`: Sum the corresponding attributes of two `Stats` structs and returns  the result.
/// attributes :`attack`, `defense`, `speed`, `strength`.
///
impl StatsAdd of Add<Stats> {
    fn add(lhs: Stats, rhs: Stats) -> Stats {
        return Stats {
            attack: lhs.attack + rhs.attack,       
            defense: lhs.defense + rhs.defense,    
            speed: lhs.speed + rhs.speed,          
            strength: lhs.strength + rhs.strength, 
        };
    }
}

//********************************************************************
//               MULTIPLICATION IMPLEMENTATION FOR STATS            ||
//********************************************************************

///
/// Implements the `Mul` trait for the `Stats` struct, allowing multiplication of two `Stats`.
/// 1. `mul`: Multiplies the corresponding attributes of two `Stats` structs and returns the result.
///  attributes :`attack`, `defense`, `speed`, `strength`.
///
impl StatsMul of Mul<Stats> {
    fn mul(lhs: Stats, rhs: Stats) -> Stats {
        return Stats {
            attack: lhs.attack * rhs.attack,         
            defense: lhs.defense * rhs.defense,      
            speed: lhs.speed * rhs.speed,            
            strength: lhs.strength * rhs.strength,   
        };
    }
}

//********************************************************************
//              DIVISION IMPLEMENTATION FOR STATS                   ||
//********************************************************************

///
/// Implements the `Div` trait for the `Stats` struct, allowing division of one `Stats` object by another.
/// 1. `div`: Divides the corresponding attributes of two `Stats` structs and returns the result.
/// attributes :`attack`, `defense`, `speed`, `strength`.
/// 
impl StatsDiv of Div<Stats> {
    fn div(lhs: Stats, rhs: Stats) -> Stats {
        return Stats {
            attack: lhs.attack / rhs.attack,         
            defense: lhs.defense / rhs.defense,     
            speed: lhs.speed / rhs.speed,            
            strength: lhs.strength / rhs.strength,   
        };
    }
}

