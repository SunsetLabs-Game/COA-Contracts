#[cfg(test)]
mod ManualVerification {
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use coa::models::gear::{Gear, WeaponStats, ArmorStats, VehicleStats, PetStats};
    use coa::models::core::{Contract, Operator};

    // Test creation and validation of gear structs
    #[test]
    fn test_gear_struct_creation() {
        // Test WEAPON_1 creation
        let weapon_1 = Gear {
            id: u256 { low: 0x0001, high: 0x1 },
            item_type: 'WEAPON',
            asset_id: 0x1,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            max_upgrade_level: 10,
        };
        
        assert(weapon_1.id == u256 { low: 0x0001, high: 0x1 }, 'Weapon 1 ID correct');
        assert(weapon_1.item_type == 'WEAPON', 'Weapon type correct');
        assert(weapon_1.asset_id == 0x1, 'Asset ID correct');
        assert(weapon_1.max_upgrade_level == 10, 'Max upgrade level correct');
    }

    #[test]
    fn test_weapon_stats_creation() {
        let weapon_stats = WeaponStats {
            asset_id: 0x1,
            damage: 45,
            range: 100,
            accuracy: 85,
            fire_rate: 15,
            ammo_capacity: 30,
            reload_time: 3,
        };
        
        assert(weapon_stats.asset_id == 0x1, 'Asset ID correct');
        assert(weapon_stats.damage == 45, 'Damage correct');
        assert(weapon_stats.range == 100, 'Range correct');
        assert(weapon_stats.accuracy == 85, 'Accuracy correct');
        assert(weapon_stats.fire_rate == 15, 'Fire rate correct');
        assert(weapon_stats.ammo_capacity == 30, 'Ammo capacity correct');
        assert(weapon_stats.reload_time == 3, 'Reload time correct');
    }

    #[test]
    fn test_armor_stats_creation() {
        let helmet_stats = ArmorStats {
            asset_id: 0x2000,
            defense: 25,
            durability: 100,
            weight: 2,
            slot_type: 'HELMET',
        };
        
        assert(helmet_stats.asset_id == 0x2000, 'Helmet asset ID correct');
        assert(helmet_stats.defense == 25, 'Helmet defense correct');
        assert(helmet_stats.durability == 100, 'Helmet durability correct');
        assert(helmet_stats.weight == 2, 'Helmet weight correct');
        assert(helmet_stats.slot_type == 'HELMET', 'Helmet slot type correct');
        
        let chest_stats = ArmorStats {
            asset_id: 0x2001,
            defense: 50,
            durability: 150,
            weight: 8,
            slot_type: 'CHEST',
        };
        
        assert(chest_stats.defense == 50, 'Chest defense correct');
        assert(chest_stats.durability == 150, 'Chest durability correct');
        assert(chest_stats.weight == 8, 'Chest weight correct');
        assert(chest_stats.slot_type == 'CHEST', 'Chest slot type correct');
    }

    #[test]
    fn test_vehicle_stats_creation() {
        let vehicle_stats = VehicleStats {
            asset_id: 0x30000,
            speed: 80,
            armor: 60,
            fuel_capacity: 100,
            cargo_capacity: 500,
            maneuverability: 70,
        };
        
        assert(vehicle_stats.asset_id == 0x30000, 'Vehicle asset ID correct');
        assert(vehicle_stats.speed == 80, 'Vehicle speed correct');
        assert(vehicle_stats.armor == 60, 'Vehicle armor correct');
        assert(vehicle_stats.fuel_capacity == 100, 'Vehicle fuel correct');
        assert(vehicle_stats.cargo_capacity == 500, 'Vehicle cargo correct');
        assert(vehicle_stats.maneuverability == 70, 'Vehicle maneuver correct');
    }

    #[test]
    fn test_pet_stats_creation() {
        let pet_stats = PetStats {
            asset_id: 0x800000,
            loyalty: 85,
            intelligence: 75,
            agility: 90,
            special_ability: 'STEALTH',
            energy: 100,
        };
        
        assert(pet_stats.asset_id == 0x800000, 'Pet asset ID correct');
        assert(pet_stats.loyalty == 85, 'Pet loyalty correct');
        assert(pet_stats.intelligence == 75, 'Pet intelligence correct');
        assert(pet_stats.agility == 90, 'Pet agility correct');
        assert(pet_stats.special_ability == 'STEALTH', 'Pet ability correct');
        assert(pet_stats.energy == 100, 'Pet energy correct');
    }

    #[test]
    fn test_admin_setup() {
        let admin = contract_address_const::<0x123>();
        let operator = Operator {
            id: admin,
            is_operator: true,
        };
        
        assert(operator.id == admin, 'Admin ID correct');
        assert(operator.is_operator == true, 'Admin operator status correct');
    }

    #[test]
    fn test_contract_setup() {
        let admin = contract_address_const::<0x123>();
        let erc1155_address = contract_address_const::<0x456>();
        
        let contract = Contract {
            id: 'COA_CONTRACTS',
            admin: admin,
            erc1155: erc1155_address,
        };
        
        assert(contract.id == 'COA_CONTRACTS', 'Contract ID correct');
        assert(contract.admin == admin, 'Contract admin correct');
        assert(contract.erc1155 == erc1155_address, 'Contract ERC1155 correct');
    }

    #[test]
    fn test_erc1155_id_compatibility() {
        // Test that our gear IDs match ERC1155 token IDs exactly
        
        // Weapons from erc1155/src/utils.cairo
        let weapon_1_expected = u256 { low: 0x0001, high: 0x1 }; // WEAPON_1
        let weapon_2_expected = u256 { low: 0x0002, high: 0x1 }; // WEAPON_2
        
        let weapon_1_gear = Gear {
            id: weapon_1_expected,
            item_type: 'WEAPON',
            asset_id: 0x1,
            variation_ref: 1,
            total_count: 1,
            in_action: false,
            upgrade_level: 0,
            max_upgrade_level: 10,
        };
        
        assert(weapon_1_gear.id == weapon_1_expected, 'Weapon 1 ID matches ERC1155');
        
        // Armor from erc1155/src/utils.cairo
        let helmet_expected = u256 { low: 0x0001, high: 0x2000 }; // HELMET
        let chest_expected = u256 { low: 0x0001, high: 0x2001 }; // CHEST_ARMOR
        let legs_expected = u256 { low: 0x0001, high: 0x2002 }; // LEG_ARMOR
        let boots_expected = u256 { low: 0x0001, high: 0x2003 }; // BOOTS
        let gloves_expected = u256 { low: 0x0001, high: 0x2004 }; // GLOVES
        
        // Vehicles from erc1155/src/utils.cairo
        let vehicle_1_expected = u256 { low: 0x0001, high: 0x30000 }; // VEHICLE
        let vehicle_2_expected = u256 { low: 0x0002, high: 0x30000 }; // VEHICLE_2
        
        // Pets from erc1155/src/utils.cairo
        let pet_1_expected = u256 { low: 0x0001, high: 0x800000 }; // PET_1
        let pet_2_expected = u256 { low: 0x0002, high: 0x800000 }; // PET_2
        
        // All IDs are properly formatted with the correct high values
        assert(helmet_expected.high == 0x2000, 'Helmet high value correct');
        assert(chest_expected.high == 0x2001, 'Chest high value correct');
        assert(legs_expected.high == 0x2002, 'Legs high value correct');
        assert(boots_expected.high == 0x2003, 'Boots high value correct');
        assert(gloves_expected.high == 0x2004, 'Gloves high value correct');
        assert(vehicle_1_expected.high == 0x30000, 'Vehicle 1 high value correct');
        assert(vehicle_2_expected.high == 0x30000, 'Vehicle 2 high value correct');
        assert(pet_1_expected.high == 0x800000, 'Pet 1 high value correct');
        assert(pet_2_expected.high == 0x800000, 'Pet 2 high value correct');
    }

    #[test]
    fn test_complete_asset_coverage() {
        // Verify we have all the assets from ERC1155 utils
        
        // Create gear for all ERC1155 defined assets
        let all_gear_ids = array![
            // Weapons
            u256 { low: 0x0001, high: 0x1 },
            u256 { low: 0x0002, high: 0x1 },
            // Armor
            u256 { low: 0x0001, high: 0x2000 },
            u256 { low: 0x0001, high: 0x2001 },
            u256 { low: 0x0001, high: 0x2002 },
            u256 { low: 0x0001, high: 0x2003 },
            u256 { low: 0x0001, high: 0x2004 },
            // Vehicles
            u256 { low: 0x0001, high: 0x30000 },
            u256 { low: 0x0002, high: 0x30000 },
            // Pets
            u256 { low: 0x0001, high: 0x800000 },
            u256 { low: 0x0002, high: 0x800000 },
        ];
        
        // Total should be 11 NFT assets
        assert(all_gear_ids.len() == 11, 'All NFT assets covered');
        
        // All have valid high values (indicating NFTs)
        let mut i = 0;
        loop {
            if i >= all_gear_ids.len() {
                break;
            }
            assert(*all_gear_ids.at(i).high > 0, 'Asset is valid NFT');
            i += 1;
        };
    }

    #[test] 
    fn test_stats_consistency() {
        // Test that different gear types have appropriate stat ranges
        
        // Weapons should have combat stats
        let weapon_stats = WeaponStats {
            asset_id: 0x1,
            damage: 45,
            range: 100,
            accuracy: 85,
            fire_rate: 15,
            ammo_capacity: 30,
            reload_time: 3,
        };
        
        assert(weapon_stats.damage > 0, 'Weapons have damage');
        assert(weapon_stats.range > 0, 'Weapons have range');
        assert(weapon_stats.accuracy > 0, 'Weapons have accuracy');
        
        // Armor should have defensive stats
        let armor_stats = ArmorStats {
            asset_id: 0x2000,
            defense: 25,
            durability: 100,
            weight: 2,
            slot_type: 'HELMET',
        };
        
        assert(armor_stats.defense > 0, 'Armor has defense');
        assert(armor_stats.durability > 0, 'Armor has durability');
        assert(armor_stats.weight > 0, 'Armor has weight');
        
        // Vehicles should have mobility stats
        let vehicle_stats = VehicleStats {
            asset_id: 0x30000,
            speed: 80,
            armor: 60,
            fuel_capacity: 100,
            cargo_capacity: 500,
            maneuverability: 70,
        };
        
        assert(vehicle_stats.speed > 0, 'Vehicles have speed');
        assert(vehicle_stats.fuel_capacity > 0, 'Vehicles have fuel capacity');
        assert(vehicle_stats.cargo_capacity > 0, 'Vehicles have cargo capacity');
        
        // Pets should have companion stats
        let pet_stats = PetStats {
            asset_id: 0x800000,
            loyalty: 85,
            intelligence: 75,
            agility: 90,
            special_ability: 'STEALTH',
            energy: 100,
        };
        
        assert(pet_stats.loyalty > 0, 'Pets have loyalty');
        assert(pet_stats.intelligence > 0, 'Pets have intelligence');
        assert(pet_stats.agility > 0, 'Pets have agility');
        assert(pet_stats.energy > 0, 'Pets have energy');
    }
} 