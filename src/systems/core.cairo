/// interface
/// init an admin account, or list of admin accounts, dojo_init
///
/// Spawn tournamemnts and side quests here, if necessary.
#[starknet::interface]
pub trait ICore<TContractState> {
    fn spawn_items(ref self: TContractState, item_ids: Array<u256>);
    // move to market only items that have been spawned.
    // if caller is admin, check spawned items and relocate
    // if caller is player,
    fn move_to_market(ref self: TContractState, item_ids: Array<u256>);
    fn add_to_market(ref self: TContractState, item_ids: Array<u256>);
    // can be credits, materials, anything
    fn purchase_item(ref self: TContractState, item_id: u256, quantity: u256);
    fn create_tournament(ref self: TContractState);
    fn join_tournament(ref self: TContractState);
    fn purchase_credits(ref self: TContractState);
}

#[dojo::contract]
pub mod CoreActions {
    use dojo::model::ModelStorage;
    use dojo::world::WorldStorage;
    use starknet::{ContractAddress, get_caller_address};
    use crate::helpers::base::generate_id;
    use crate::models::core::{Contract, Operator};
    use crate::models::gear::Gear;

    const GEAR: felt252 = 'GEAR';

    fn dojo_init(ref self: ContractState, admin: ContractAddress, erc1155: ContractAddress) {
        let mut world = self.world_default();

        // Initialize admin
        let operator = Operator { id: admin, is_operator: true };
        world.write_model(@operator);

        // Initialize contract configuration
        let contract = Contract { id: 'COA_CONTRACTS', admin, erc1155 };
        world.write_model(@contract);

        // Initialize base gear assets with their stats
        self._initialize_gear_assets(ref world);
    }

    #[abi(embed_v0)]
    pub impl CoreActionsImpl of super::ICore<ContractState> {
        fn spawn_items(ref self: ContractState, item_ids: Array<u256>) {}
        // move to market only items that have been spawned.
        // if caller is admin, check spawned items and relocate
        // if caller is player,
        fn move_to_market(ref self: ContractState, item_ids: Array<u256>) {}
        fn add_to_market(ref self: ContractState, item_ids: Array<u256>) {}
        // can be credits, materials, anything
        fn purchase_item(ref self: ContractState, item_id: u256, quantity: u256) {}
        fn create_tournament(ref self: ContractState) {}
        fn join_tournament(ref self: ContractState) {}
        fn purchase_credits(ref self: ContractState) {}
    }

    #[generate_trait]
    pub impl CoreInternalImpl of CoreInternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"coa")
        }

        fn _initialize_gear_assets(ref self: ContractState, ref world: WorldStorage) {
            // Weapons - using ERC1155 token IDs as primary keys
            let weapon_1_gear = Gear {
                id: u256 { low: 0x0001, high: 0x1 }, // WEAPON_1 from ERC1155
                item_type: 'WEAPON',
                asset_id: 0x1, // u256.high for weapons
                variation_ref: 1,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 10,
            };
            world.write_model(@weapon_1_gear);

            // Weapon 1 stats
            let weapon_1_stats = crate::models::gear::WeaponStats {
                asset_id: 0x1,
                damage: 45,
                range: 100,
                accuracy: 85,
                fire_rate: 15,
                ammo_capacity: 30,
                reload_time: 3,
            };
            world.write_model(@weapon_1_stats);

            let weapon_2_gear = Gear {
                id: u256 { low: 0x0002, high: 0x1 }, // WEAPON_2 from ERC1155
                item_type: 'WEAPON',
                asset_id: 0x1,
                variation_ref: 2,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 10,
            };
            world.write_model(@weapon_2_gear);

            // Weapon 2 stats
            let weapon_2_stats = crate::models::gear::WeaponStats {
                asset_id: 0x1,
                damage: 60,
                range: 80,
                accuracy: 90,
                fire_rate: 10,
                ammo_capacity: 20,
                reload_time: 4,
            };
            world.write_model(@weapon_2_stats);

            // Armor Types
            let helmet_gear = Gear {
                id: u256 { low: 0x0001, high: 0x2000 }, // HELMET from ERC1155
                item_type: 'ARMOR',
                asset_id: 0x2000, // u256.high for helmet
                variation_ref: 1,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 8,
            };
            world.write_model(@helmet_gear);

            // Helmet stats
            let helmet_stats = crate::models::gear::ArmorStats {
                asset_id: 0x2000, defense: 25, durability: 100, weight: 2, slot_type: 'HELMET',
            };
            world.write_model(@helmet_stats);

            let chest_armor_gear = Gear {
                id: u256 { low: 0x0001, high: 0x2001 }, // CHEST_ARMOR from ERC1155
                item_type: 'ARMOR',
                asset_id: 0x2001, // u256.high for chest armor
                variation_ref: 1,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 8,
            };
            world.write_model(@chest_armor_gear);

            // Chest armor stats
            let chest_armor_stats = crate::models::gear::ArmorStats {
                asset_id: 0x2001, defense: 50, durability: 150, weight: 8, slot_type: 'CHEST',
            };
            world.write_model(@chest_armor_stats);

            let leg_armor_gear = Gear {
                id: u256 { low: 0x0001, high: 0x2002 }, // LEG_ARMOR from ERC1155
                item_type: 'ARMOR',
                asset_id: 0x2002, // u256.high for leg armor
                variation_ref: 1,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 8,
            };
            world.write_model(@leg_armor_gear);

            // Leg armor stats
            let leg_armor_stats = crate::models::gear::ArmorStats {
                asset_id: 0x2002, defense: 35, durability: 120, weight: 6, slot_type: 'LEGS',
            };
            world.write_model(@leg_armor_stats);

            let boots_gear = Gear {
                id: u256 { low: 0x0001, high: 0x2003 }, // BOOTS from ERC1155
                item_type: 'ARMOR',
                asset_id: 0x2003, // u256.high for boots
                variation_ref: 1,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 8,
            };
            world.write_model(@boots_gear);

            // Boots stats
            let boots_stats = crate::models::gear::ArmorStats {
                asset_id: 0x2003, defense: 20, durability: 80, weight: 3, slot_type: 'BOOTS',
            };
            world.write_model(@boots_stats);

            let gloves_gear = Gear {
                id: u256 { low: 0x0001, high: 0x2004 }, // GLOVES from ERC1155
                item_type: 'ARMOR',
                asset_id: 0x2004, // u256.high for gloves
                variation_ref: 1,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 8,
            };
            world.write_model(@gloves_gear);

            // Gloves stats
            let gloves_stats = crate::models::gear::ArmorStats {
                asset_id: 0x2004, defense: 15, durability: 60, weight: 1, slot_type: 'GLOVES',
            };
            world.write_model(@gloves_stats);

            // Vehicles
            let vehicle_gear = Gear {
                id: u256 { low: 0x0001, high: 0x30000 }, // VEHICLE from ERC1155
                item_type: 'VEHICLE',
                asset_id: 0x30000, // u256.high for vehicles
                variation_ref: 1,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 5,
            };
            world.write_model(@vehicle_gear);

            // Vehicle 1 stats
            let vehicle_stats = crate::models::gear::VehicleStats {
                asset_id: 0x30000,
                speed: 80,
                armor: 60,
                fuel_capacity: 100,
                cargo_capacity: 500,
                maneuverability: 70,
            };
            world.write_model(@vehicle_stats);

            let vehicle_2_gear = Gear {
                id: u256 { low: 0x0002, high: 0x30000 }, // VEHICLE_2 from ERC1155
                item_type: 'VEHICLE',
                asset_id: 0x30000,
                variation_ref: 2,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 5,
            };
            world.write_model(@vehicle_2_gear);

            // Vehicle 2 stats (different variation)
            let vehicle_2_stats = crate::models::gear::VehicleStats {
                asset_id: 0x30000,
                speed: 60,
                armor: 90,
                fuel_capacity: 150,
                cargo_capacity: 800,
                maneuverability: 50,
            };
            world.write_model(@vehicle_2_stats);

            // Pets / Drones
            let pet_1_gear = Gear {
                id: u256 { low: 0x0001, high: 0x800000 }, // PET_1 from ERC1155
                item_type: 'PET',
                asset_id: 0x800000, // u256.high for pets
                variation_ref: 1,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 15,
            };
            world.write_model(@pet_1_gear);

            // Pet 1 stats
            let pet_1_stats = crate::models::gear::PetStats {
                asset_id: 0x800000,
                loyalty: 85,
                intelligence: 75,
                agility: 90,
                special_ability: 'STEALTH',
                energy: 100,
            };
            world.write_model(@pet_1_stats);

            let pet_2_gear = Gear {
                id: u256 { low: 0x0002, high: 0x800000 }, // PET_2 from ERC1155
                item_type: 'PET',
                asset_id: 0x800000,
                variation_ref: 2,
                total_count: 1,
                in_action: false,
                upgrade_level: 0,
                max_upgrade_level: 15,
            };
            world.write_model(@pet_2_gear);

            // Pet 2 stats
            let pet_2_stats = crate::models::gear::PetStats {
                asset_id: 0x800000,
                loyalty: 95,
                intelligence: 85,
                agility: 70,
                special_ability: 'COMBAT_SUPPORT',
                energy: 120,
            };
            world.write_model(@pet_2_stats);
        }
    }
}
