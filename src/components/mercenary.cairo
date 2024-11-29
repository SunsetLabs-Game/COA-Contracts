//********************************************************************
//                           IMPORTS                                ||                        
//********************************************************************
use core::traits::TryInto;
use starknet::ContractAddress;
use core::fmt::{Display, Formatter, Error};

use dojo_starter::components::stats::{Stats,StatsTrait};
use dojo_starter::components::weapon::{Weapon,WEAPON_COUNT};
use dojo_starter::components::armour::{Armour,ARMOUR_COUNT};

//********************************************************************
//                        DATA STRUCTURES                           ||
//********************************************************************

///
/// Defines`Mercenary` model with unique id #[key], owner #[key], traits #[struct],stats #[struct].
/// 1. `id`: A unique identifier for the mercenary.  
/// 2. `owner`: The contract address of the mercenary's owner.  
/// 3. `traits`: A struct encapsulating the mercenary's weapon and armour.  
/// 4. `stats`: A struct that stores the combined stats of the mercenary.
/// 
#[derive(Copy,Drop,Serde)]
#[dojo::model]
struct Mercenary {
    #[key]
    id:u128,
    #[key]
    owner:ContractAddress,
    traits:Traits,
    stats:Stats,                    
}

///
/// Defines `Traits` struct, which encapsulates weapon and armour.
/// 1. `weapon`: The weapon equipped by the mercenary.  
/// 2. `armour`: The armour equipped by the mercenary.
/// 
#[derive(Copy,Drop,Serde,Introspect)]
struct Traits {
    weapon:Weapon,
    armour:Armour,
}

//********************************************************************
//                   TRAIT IMPLEMENTATIONS                          ||
//********************************************************************

///
/// The Implements the `Into<Traits, ByteArray>` trait for `Traits`.  
/// 1.`into`: Converts `Traits` into a textual representation in `ByteArray` format.
/// 
impl OutcomeIntoByteArray of Into<Traits, ByteArray>{
    fn into(self:Traits) -> ByteArray {
        let weapon:ByteArray = self.weapon.into();
        let armour:ByteArray = self.armour.into();

        format!("weapon {}  armour {} ", weapon, armour)
    }
}

///
/// The implementation of the `Display` trait for `Traits` uses its `Into<Traits, ByteArray>`  
/// implementation to format and output the weapon and armour details as a string.
/// 
impl DisplayImplTraits = DisplayImplT<Traits>;

//********************************************************************
//                     HELPER FUNCTIONS                             ||
//********************************************************************

// Combines stats from weapon and armour into a single `Stats` object.
fn calculate_stats(traits:Traits) -> Stats {
let Traits {weapon,armour} = traits;
let (weapon_stats,armour_stats) = (weapon.stats() , armour.stats());
    return (weapon_stats + armour_stats);
}

// Generates random traits (weapon and armour) based on a given seed.
fn generate_traits(seed:u256) -> Traits {
    let armour_count:u256 = ARMOUR_COUNT.into();
    let weapon_count:u256 = WEAPON_COUNT.into();

    let mut seed_m = seed;

    let armour:u8 = (seed_m % armour_count).try_into().unwrap();
    seed_m /=0x100;
    let weapon:u8 = (seed_m % weapon_count).try_into().unwrap();  

    Traits {
        armour: armour.into(), 
        weapon: weapon.into()
    }
}

//********************************************************************
//                     MERCENARY TRAIT                              ||
//********************************************************************

///
///The Implements `MercenaryTrait` for creating new mercenaries.
/// 1. `new`:Creates a new `Mercenary` with the specified `id`, `owner`, generated `traits`, and calculated `stats` from the `seed`.
///  
#[generate_trait]
impl MercenaryImpl of MercenaryTrait {
    fn new(owner:ContractAddress,id:u128,seed:u256)-> Mercenary{
        let traits = generate_traits(seed);
        let stats = calculate_stats(traits);
       return Mercenary{
            id,
            owner,
            traits,
            stats
        };
    }
}

//********************************************************************
//                  DISPLAY IMPLEMENTATION                          ||
//********************************************************************

///
/// The implementation of `Display` for types that implement `Into` and `Copy` allows formatting a type as a string.
/// 1. `fmt`: Formats the type by converting it into a `ByteArray` and appending it to the formatter buffer.
///
impl DisplayImplT<T, +Into<T, ByteArray>, +Copy<T>> of Display<T> {
    fn fmt(self: @T, ref f: Formatter) -> Result<(), Error> {
        let str: ByteArray = (*self).into();
        f.buffer.append(@str);
        Result::Ok(())
    }
}