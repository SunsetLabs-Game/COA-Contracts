// This might be renamed to asset in the future
// For now we are sticking to gear, as some assets are not considered as gear
// These are all gears that are non-fungible

use crate::helpers::base::ContractAddressDefault;
use core::num::traits::Zero;
use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use crate::erc1155::erc1155::{IERC1155MintableDispatcher, IERC1155MintableDispatcherTrait};
use starknet::ContractAddress;
use dojo::world::WorldStorage;

#[dojo::model]
#[derive(Drop, Copy, Default, Serde)]
pub struct Gear {
    #[key]
    pub id: u256,
    pub item_type: felt252,
    pub asset_id: u256,
    // pub variation: // take in an instrospect enum, whether ammo, or companion, etc
    // I don't know if it's variation or not, but the type of that item.
    pub variation_ref: u256,
    pub total_count: u64, // for fungible.
    pub in_action: bool, // this translates to if this gear is ready to be used... just like a gun in hand, rather than a docked gun. This field would be used in important checks in the future.
    pub upgrade_level: u64,
    pub max_upgrade_level: u64,
    pub min_xp_needed: u256,
    pub spawned: bool,
}


#[derive(Drop, Copy, Serde, PartialEq, Default)]
pub enum GearType {
    #[default]
    None,
    // General Weapon category prefix: 0x1
    Weapon, // 0x1
    // WeaponSubTypes -- 0x1xx
    BluntWeapon, // 0x101 - (e.g., Maces, hammers, clubs, axes)
    Sword, // 0x102 - (e.g., Katanas, greatswords, longswords, shortswords, daggers, knives)
    Bow, // 0x103 - (e.g., Compound bows, crossbows, longbows, shortbows)
    Firearm, // 0x104 - (e.g., Pistols, rifles, shotguns, SMGs (submachine guns))
    Polearm, // 0x105 - (e.g., Spears, lances, halberds, pikes, glaives)
    HeavyFirearms, // 0x106 (e.g., LMGs, Rocket Launchers, Grenade Launchers)
    Explosives, // 0x107 (e.g., Grenades, C4, Mines, Explosive Arrows)
    // ArmorTypes -- 0x2xxx
    Helmet, // 0x2000
    ChestArmor, // 0x2001
    LegArmor, // 0x2002
    Boots, // 0x2003
    Gloves, // 0x2004
    Shield, // 0x2005
    // VehicleTypes -- 0x3xxxx
    Vehicle, // 0x30000
    // Pets/Drones -- 0x8xxxxx
    Pet, // 0x800000
    Drone // 0x800001
}

#[derive(Drop, Copy, Serde, Default)]
pub struct GearProperties {
    asset_id: u256,
    // asset: Gear,
}

pub impl GearTypeU128 of Into<GearType, u128> {
    fn into(self: GearType) -> u128 {
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
            GearType::None => 0x0,
        }
    }
}



// for now, all items would implement this trait
// move this trait and it's impl to `helpers/gear.cairo`

#[generate_trait]
pub impl GearImpl of GearTrait {
    fn output(self: @Gear, upgraded_level: u64) -> u256 {
        // TODO: calculation for output based on upgraded level
        1000000
    }
}
// pub trait GearTrait {
//     fn with_id(id: u256) -> Gear;
//     fn is_upgradeable(ref self: Gear) -> bool;
//     fn forge(
//         items: Array<u256>,
//     ) -> u256; // can only be implemented on specific ids. Might invoke the worldstorage if
//     necessary.
//     fn is_fungible(id: u256);
//     fn output(self: @Gear, value: u256);
// }


