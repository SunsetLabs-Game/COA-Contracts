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
    pub owner: ContractAddress, // owner field to track who owns the item 
    pub max_upgrade_level: u64,
    pub min_xp_needed: u256,
    pub spawned: bool,
}


#[derive(Drop, Copy, Serde, PartialEq, Default, Introspect)]
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
    Drone, // 0x800001
    // Consumables -- 0x9xxxx
    HealthPotion, // 0x90000 - restores HP
    XpBooster, // 0x90001 - increases XP
    EnergyDrink, // 0x90002 - temporary stat boost
    RepairKit, // 0x90003 - repairs equipment durability
    Stimpack, // 0x90004 - temporary damage boost
    ArmorRepair, // 0x90005 - repairs armor
    WeaponOil // 0x90006 - temporary weapon enhancement
}

#[derive(Drop, Copy, Serde, Default)]
pub struct GearProperties {
    asset_id: u256,
    // asset: Gear,
}

// for now, all items would implement this trait
// move this trait and it's impl to `helpers/gear.cairo`

#[generate_trait]
pub impl GearImpl of GearTrait {
    fn output(self: @Gear, upgraded_level: u64) -> u256 {
        // TODO: calculation for output based on upgraded level
        1000000
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
    // ownership checking function
    fn is_owned(self: @Gear) -> bool {
        !self.owner.is_zero()
    }
    // function to check if available for pickup
    fn is_available_for_pickup(self: @Gear) -> bool {
        *self.spawned && self.owner.is_zero()
    }

    // Transfer ownership
    fn transfer_to(ref self: Gear, new_owner: ContractAddress) {
        self.owner = new_owner;
        self.spawned = false;
    }

    // Check if item is consumable
    fn is_consumable(self: @Gear) -> bool {
        let type_id = *self.asset_id.high;
        type_id == 0x90000_u128
            || type_id == 0x90001_u128
            || type_id == 0x90002_u128
            || type_id == 0x90003_u128
            || type_id == 0x90004_u128
            || type_id == 0x90005_u128
            || type_id == 0x90006_u128
    }

    // Check if item can be wielded (non-consumable equipment)
    fn is_wieldable(self: @Gear) -> bool {
        let type_id = *self.asset_id.high;
        type_id == 0x1_u128
            || type_id == 0x101_u128
            || type_id == 0x102_u128
            || type_id == 0x103_u128
            || type_id == 0x104_u128
            || type_id == 0x105_u128
            || type_id == 0x106_u128
            || type_id == 0x107_u128
    }
}

