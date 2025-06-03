#[cfg(test)]
mod TestCoreSystem {
    use coa::models::core::{Contract, Operator};
    use coa::models::gear::{ArmorStats, Gear, PetStats, VehicleStats, WeaponStats};
    use coa::systems::core::{CoreActions, ICore};
    use dojo::test_utils::{deploy_contract, spawn_test_world};
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use starknet::testing::{set_caller_address, set_contract_address};
    use starknet::{ContractAddress, contract_address_const};

    fn setup() -> (IWorldDispatcher, ICore, ContractAddress, ContractAddress) {
        // Create test addresses
        let admin = contract_address_const::<0x123>();
        let erc1155_address = contract_address_const::<0x456>();

        // Spawn test world with our models
        let mut models = array![
            coa::models::core::operator::TEST_CLASS_HASH,
            coa::models::core::contract::TEST_CLASS_HASH,
            coa::models::gear::gear::TEST_CLASS_HASH,
            coa::models::gear::weapon_stats::TEST_CLASS_HASH,
            coa::models::gear::armor_stats::TEST_CLASS_HASH,
            coa::models::gear::vehicle_stats::TEST_CLASS_HASH,
            coa::models::gear::pet_stats::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world("coa", models.span());

        // Deploy the CoreActions contract
        let core_contract_address = world
            .deploy_contract(
                'salt', coa::systems::core::CoreActions::TEST_CLASS_HASH.try_into().unwrap(),
            );

        // Initialize the world with the contract
        world
            .init_contract(
                selector!("dojo_init"), array![admin.into(), erc1155_address.into()].span(),
            );

        let core_actions = ICore { contract_address: core_contract_address };

        (world, core_actions, admin, erc1155_address)
    }

    #[test]
    fn test_dojo_init_admin_setup() {
        let (world, core_actions, admin, erc1155_address) = setup();

        // Check if admin was properly initialized as operator
        let operator: Operator = world.read_model(admin);
        assert(operator.is_operator == true, 'Admin should be operator');
        assert(operator.id == admin, 'Admin ID should match');
    }

    #[test]
    fn test_dojo_init_contract_setup() {
        let (world, core_actions, admin, erc1155_address) = setup();

        // Check if contract configuration was properly set
        let contract: Contract = world.read_model('COA_CONTRACTS');
        assert(contract.admin == admin, 'Contract admin should match');
        assert(contract.erc1155 == erc1155_address, 'ERC1155 address should match');
        assert(contract.id == 'COA_CONTRACTS', 'Contract ID should match');
    }

    #[test]
    fn test_weapon_gear_initialization() {
        let (world, core_actions, admin, erc1155_address) = setup();

        // Check WEAPON_1 gear initialization
        let weapon_1_id = u256 { low: 0x0001, high: 0x1 };
        let weapon_1: Gear = world.read_model(weapon_1_id);

        assert(weapon_1.id == weapon_1_id, 'Weapon 1 ID should match');
        assert(weapon_1.item_type == 'WEAPON', 'Should be WEAPON type');
        assert(weapon_1.asset_id == 0x1, 'Asset ID should be 0x1');
        assert(weapon_1.variation_ref == 1, 'Variation should be 1');
        assert(weapon_1.total_count == 1, 'Count should be 1');
        assert(weapon_1.in_action == false, 'Should not be in action');
        assert(weapon_1.upgrade_level == 0, 'Should start at level 0');
        assert(weapon_1.max_upgrade_level == 10, 'Max level should be 10');

        // Check WEAPON_2 gear initialization
        let weapon_2_id = u256 { low: 0x0002, high: 0x1 };
        let weapon_2: Gear = world.read_model(weapon_2_id);

        assert(weapon_2.id == weapon_2_id, 'Weapon 2 ID should match');
        assert(weapon_2.variation_ref == 2, 'Variation should be 2');
    }

    #[test]
    fn test_weapon_stats_initialization() {
        let (world, core_actions, admin, erc1155_address) = setup();

        // Check weapon stats
        let weapon_stats: WeaponStats = world.read_model(0x1);

        assert(weapon_stats.asset_id == 0x1, 'Asset ID should match');
        assert(weapon_stats.damage == 45, 'Damage should be 45');
        assert(weapon_stats.range == 100, 'Range should be 100');
        assert(weapon_stats.accuracy == 85, 'Accuracy should be 85');
        assert(weapon_stats.fire_rate == 15, 'Fire rate should be 15');
        assert(weapon_stats.ammo_capacity == 30, 'Ammo capacity should be 30');
        assert(weapon_stats.reload_time == 3, 'Reload time should be 3');
    }

    #[test]
    fn test_armor_gear_initialization() {
        let (world, core_actions, admin, erc1155_address) = setup();

        // Check HELMET gear
        let helmet_id = u256 { low: 0x0001, high: 0x2000 };
        let helmet: Gear = world.read_model(helmet_id);

        assert(helmet.id == helmet_id, 'Helmet ID should match');
        assert(helmet.item_type == 'ARMOR', 'Should be ARMOR type');
        assert(helmet.asset_id == 0x2000, 'Asset ID should be 0x2000');
        assert(helmet.max_upgrade_level == 8, 'Max level should be 8');

        // Check CHEST_ARMOR gear
        let chest_id = u256 { low: 0x0001, high: 0x2001 };
        let chest: Gear = world.read_model(chest_id);

        assert(chest.id == chest_id, 'Chest ID should match');
        assert(chest.asset_id == 0x2001, 'Asset ID should be 0x2001');
    }

    #[test]
    fn test_armor_stats_initialization() {
        let (world, core_actions, admin, erc1155_address) = setup();

        // Check helmet stats
        let helmet_stats: ArmorStats = world.read_model(0x2000);

        assert(helmet_stats.asset_id == 0x2000, 'Asset ID should match');
        assert(helmet_stats.defense == 25, 'Defense should be 25');
        assert(helmet_stats.durability == 100, 'Durability should be 100');
        assert(helmet_stats.weight == 2, 'Weight should be 2');
        assert(helmet_stats.slot_type == 'HELMET', 'Slot type should be HELMET');

        // Check chest armor stats
        let chest_stats: ArmorStats = world.read_model(0x2001);

        assert(chest_stats.defense == 50, 'Chest defense should be 50');
        assert(chest_stats.durability == 150, 'Chest durability should be 150');
        assert(chest_stats.weight == 8, 'Chest weight should be 8');
        assert(chest_stats.slot_type == 'CHEST', 'Slot type should be CHEST');
    }

    #[test]
    fn test_vehicle_gear_initialization() {
        let (world, core_actions, admin, erc1155_address) = setup();

        // Check VEHICLE gear
        let vehicle_id = u256 { low: 0x0001, high: 0x30000 };
        let vehicle: Gear = world.read_model(vehicle_id);

        assert(vehicle.id == vehicle_id, 'Vehicle ID should match');
        assert(vehicle.item_type == 'VEHICLE', 'Should be VEHICLE type');
        assert(vehicle.asset_id == 0x30000, 'Asset ID should be 0x30000');
        assert(vehicle.max_upgrade_level == 5, 'Max level should be 5');

        // Check vehicle stats
        let vehicle_stats: VehicleStats = world.read_model(0x30000);

        assert(vehicle_stats.asset_id == 0x30000, 'Asset ID should match');
        assert(vehicle_stats.speed == 80, 'Speed should be 80');
        assert(vehicle_stats.armor == 60, 'Armor should be 60');
        assert(vehicle_stats.fuel_capacity == 100, 'Fuel capacity should be 100');
        assert(vehicle_stats.cargo_capacity == 500, 'Cargo capacity should be 500');
        assert(vehicle_stats.maneuverability == 70, 'Maneuverability should be 70');
    }

    #[test]
    fn test_pet_gear_initialization() {
        let (world, core_actions, admin, erc1155_address) = setup();

        // Check PET_1 gear
        let pet_id = u256 { low: 0x0001, high: 0x800000 };
        let pet: Gear = world.read_model(pet_id);

        assert(pet.id == pet_id, 'Pet ID should match');
        assert(pet.item_type == 'PET', 'Should be PET type');
        assert(pet.asset_id == 0x800000, 'Asset ID should be 0x800000');
        assert(pet.max_upgrade_level == 15, 'Max level should be 15');

        // Check pet stats
        let pet_stats: PetStats = world.read_model(0x800000);

        assert(pet_stats.asset_id == 0x800000, 'Asset ID should match');
        assert(pet_stats.loyalty == 85, 'Loyalty should be 85');
        assert(pet_stats.intelligence == 75, 'Intelligence should be 75');
        assert(pet_stats.agility == 90, 'Agility should be 90');
        assert(pet_stats.special_ability == 'STEALTH', 'Special ability should be STEALTH');
        assert(pet_stats.energy == 100, 'Energy should be 100');
    }

    #[test]
    fn test_all_erc1155_assets_covered() {
        let (world, core_actions, admin, erc1155_address) = setup();

        // Test that all ERC1155 defined assets have corresponding gear entries

        // Weapons
        let weapon_1: Gear = world.read_model(u256 { low: 0x0001, high: 0x1 });
        let weapon_2: Gear = world.read_model(u256 { low: 0x0002, high: 0x1 });
        assert(weapon_1.id.high == 0x1, 'Weapon 1 should exist');
        assert(weapon_2.id.high == 0x1, 'Weapon 2 should exist');

        // Armor
        let helmet: Gear = world.read_model(u256 { low: 0x0001, high: 0x2000 });
        let chest: Gear = world.read_model(u256 { low: 0x0001, high: 0x2001 });
        let legs: Gear = world.read_model(u256 { low: 0x0001, high: 0x2002 });
        let boots: Gear = world.read_model(u256 { low: 0x0001, high: 0x2003 });
        let gloves: Gear = world.read_model(u256 { low: 0x0001, high: 0x2004 });
        assert(helmet.id.high == 0x2000, 'Helmet should exist');
        assert(chest.id.high == 0x2001, 'Chest should exist');
        assert(legs.id.high == 0x2002, 'Legs should exist');
        assert(boots.id.high == 0x2003, 'Boots should exist');
        assert(gloves.id.high == 0x2004, 'Gloves should exist');

        // Vehicles
        let vehicle_1: Gear = world.read_model(u256 { low: 0x0001, high: 0x30000 });
        let vehicle_2: Gear = world.read_model(u256 { low: 0x0002, high: 0x30000 });
        assert(vehicle_1.id.high == 0x30000, 'Vehicle 1 should exist');
        assert(vehicle_2.id.high == 0x30000, 'Vehicle 2 should exist');

        // Pets
        let pet_1: Gear = world.read_model(u256 { low: 0x0001, high: 0x800000 });
        let pet_2: Gear = world.read_model(u256 { low: 0x0002, high: 0x800000 });
        assert(pet_1.id.high == 0x800000, 'Pet 1 should exist');
        assert(pet_2.id.high == 0x800000, 'Pet 2 should exist');
    }
}
