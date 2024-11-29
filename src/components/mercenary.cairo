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

// Defines`Mercenary` model with unique id #[key], owner #[key], traits #[struct],stats #[struct].
#[derive(Copy,Drop,Serde)]
#[dojo::model]
struct Mercenary {
    #[key]
    id:u128,
    #[key]
    owner:ContractAddress,
    traits:Traits,                  // mercenary's equipped traits (weapon, armour).
    stats:Stats,                    // Combined stats of the mercenary.
}

// Defines `Traits` struct, which encapsulates weapon and armour.
#[derive(Copy,Drop,Serde,Introspect)]
struct Traits {
    weapon:Weapon,
    armour:Armour,
}

//********************************************************************
//                   TRAIT IMPLEMENTATIONS                          ||
//********************************************************************

impl OutcomeIntoByteArray of Into<Traits, ByteArray>{

    //'into()' Converts `Traits` into a text `ByteArray`.
    fn into(self:Traits) -> ByteArray {
        let weapon:ByteArray = self.weapon.into();
        let armour:ByteArray = self.armour.into();

        format!("weapon {}  armour {} ", weapon, armour)
    }
}

// Implements `Display` for `Traits` using the `Into<Traits, ByteArray>` conversion.
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

// Implements `MercenaryTrait` for creating new mercenaries.
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

// Implements `Display` for types that implement `Into` and `Copy`.
impl DisplayImplT<T, +Into<T, ByteArray>, +Copy<T>> of Display<T> {
    fn fmt(self: @T, ref f: Formatter) -> Result<(), Error> {
        let str: ByteArray = (*self).into();
        f.buffer.append(@str);
        Result::Ok(())
    }
}