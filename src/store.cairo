use dojo::world::WorldStorage;
use starknet::ContractAddress;

use crate::models::gear::Gear;
use crate::helpers::base::generate_id;

#[starknet::interface]
pub trait IStore<TContractState> {
    fn init_gear(ref self: TContractState);
}

#[generate_trait]
pub impl StoreImpl of StoreTrait {
    fn new(world: WorldStorage) -> Store {
        Store { world: world }
    }

    fn _construct_gear(ref self: Store, asset_id: u256) -> Gear {
        Gear {
            id: generate_id('GEAR', ref self.world),
            item_type: asset_id.high.into(),
            asset_id: asset_id,
            variation_ref: 0,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            max_upgrade_level: 0,
        }
    }


    // [ Initialization methods ]
    fn init_gear(ref self: Store) {
        // Weapon types (0x1xx)
        // General Weapon category prefix: 0x1
        let weapon_id = u256 {high: 0x1, low: 0x1};
        let weapon = self._construct_gear(weapon_id, ref world);
        self.world.write_model(@weapon);

        // Blunt Weapon (0x101) - Maces, hammers, clubs, axes
        let blunt_weapon_id = u256 {high: 0x101, low: 0x1};
        let blunt_weapon = self._construct_gear(blunt_weapon_id, ref world);
        self.world.write_model(@blunt_weapon);

        // Sword (0x102) - Katanas, greatswords, longswords, shortswords, daggers, knives
        let sword_id = u256 {high: 0x102, low: 0x1};
        let sword = self._construct_gear(sword_id, ref world);
        self.world.write_model(@sword);

        // Bow (0x103) - Compound bows, crossbows, longbows, shortbows
        let bow_id = u256 {high: 0x103, low: 0x1};
        let bow = self._construct_gear(bow_id, ref world);
        self.world.write_model(@bow);

        // Firearm (0x104) - Pistols, rifles, shotguns, SMGs
        let firearm_id = u256 {high: 0x104, low: 0x1};
        let firearm = self._construct_gear(firearm_id, ref world);
        self.world.write_model(@firearm);

        // Polearm (0x105) - Spears, lances, halberds, pikes, glaives
        let polearm_id = u256 {high: 0x105, low: 0x1};
        let polearm = self._construct_gear(polearm_id, ref world);
        self.world.write_model(@polearm);

        // Heavy Firearms (0x106) - LMGs, Rocket Launchers, Grenade Launchers
        let heavy_firearm_id = u256 {high: 0x106, low: 0x1};
        let heavy_firearm = self._construct_gear(heavy_firearm_id, ref world);
        self.world.write_model(@heavy_firearm);

        // Explosives (0x107) - Grenades, C4, Mines, Explosive Arrows
        let explosive_id = u256 {high: 0x107, low: 0x1};
        let explosive = self._construct_gear(explosive_id, ref world);
        self.world.write_model(@explosive);

        // Armor types (0x2xxx)
        // Helmet (0x2000)
        let helmet_id = u256 {high: 0x2000, low: 0x1};
        let helmet = self._construct_gear(helmet_id, ref world);
        self.world.write_model(@helmet);

        // Chest Armor (0x2001)
        let chest_armor_id = u256 {high: 0x2001, low: 0x1};
        let chest_armor = self._construct_gear(chest_armor_id, ref world);
        self.world.write_model(@chest_armor);

        // Leg Armor (0x2002)
        let leg_armor_id = u256 {high: 0x2002, low: 0x1};
        let leg_armor = self._construct_gear(leg_armor_id, ref world);
        self.world.write_model(@leg_armor);

        // Boots (0x2003)
        let boots_id = u256 {high: 0x2003, low: 0x1};
        let boots = self._construct_gear(boots_id, ref world);
        self.world.write_model(@boots);

        // Gloves (0x2004)
        let gloves_id = u256 {high: 0x2004, low: 0x1};
        let gloves = self._construct_gear(gloves_id, ref world);
        self.world.write_model(@gloves);

        // Shield (0x2005)
        let shield_id = u256 {high: 0x2005, low: 0x1};
        let shield = self._construct_gear(shield_id, ref world);
        self.world.write_model(@shield);

        // Vehicle types (0x3xxxx)
        // Vehicle (0x30000)
        let vehicle_id = u256 {high: 0x30000, low: 0x1};
        let vehicle = self._construct_gear(vehicle_id, ref world);
        self.world.write_model(@vehicle);

        // Pets/Drones (0x8xxxxx)
        // Pet (0x800000)
        let pet_id = u256 {high: 0x800000, low: 0x1};
        let pet = self._construct_gear(pet_id, ref world);
        self.world.write_model(@pet);

        // Drone (0x800001)
        let drone_id = u256 {high: 0x800001, low: 0x1};
        let drone = self._construct_gear(drone_id, ref world);
        self.world.write_model(@drone);
    }
}
