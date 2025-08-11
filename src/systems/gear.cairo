#[dojo::contract]
pub mod GearActions {
    use crate::interfaces::gear::IGear;
    use dojo::event::EventStorage;
    use super::super::super::models::gear::GearTrait;
    use starknet::ContractAddress;
    use crate::models::player::PlayerTrait;
    use starknet::get_caller_address;
    use dojo::world::WorldStorage;
    use dojo::model::ModelStorage;
    use crate::models::gear::{Gear, GearProperties, GearType};
    use crate::models::core::{Operator, Contract};
    use crate::helpers::base::generate_id;
    use crate::helpers::base::ContractAddressDefault;
    use crate::helpers::gear::parse_id;
    // Import session model for validation
    use crate::models::session::SessionKey;
    // Import ERC1155 interface for burning items
    use crate::erc1155::erc1155::{IERC1155MintableDispatcher, IERC1155MintableDispatcherTrait};

    const GEAR: felt252 = 'GEAR';

    fn dojo_init(ref self: ContractState) {
        let mut world = self.world_default();
        self._assert_admin();
        self._initialize_gear_assets(ref world);
    }
    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct ItemPicked {
        #[key]
        pub player_id: ContractAddress,
        #[key]
        pub item_id: u256,
        pub equipped: bool,
        pub via_vehicle: bool,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct ItemUsed {
        #[key]
        pub player_id: ContractAddress,
        #[key]
        pub item_id: u256,
        pub target_id: Option<u256>,
        pub item_type: GearType,
    }

    #[derive(Drop, Copy, Serde)]
    #[dojo::event]
    pub struct ItemWielded {
        #[key]
        pub player_id: ContractAddress,
        #[key]
        pub item_id: u256,
        pub wielded: bool,
    }


    #[abi(embed_v0)]
    pub impl GearActionsImpl of IGear<ContractState> {
        fn upgrade_gear(ref self: ContractState, item_id: u256, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
            // check if the available upgrade materials `id` is present in the caller's address
        // TODO: Security
        // for now, you must check if if the item_id with id is available in the game.
        // This would be done accordingly, so the item struct must have the id of the material
        // or the ids of the list of materials that can upgrade it, and the quantity needed per
        // level and the max level attained.
        }

        fn equip(ref self: ContractState, item_id: Array<u256>, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
        }

        fn equip_on(ref self: ContractState, item_id: u256, target: u256, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
        }

        // unequips an item and equips another item at that slot.
        fn exchange(
            ref self: ContractState, in_item_id: u256, out_item_id: u256, session_id: felt252,
        ) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
        }

        fn refresh(ref self: ContractState, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
            // might be moved to player. when players transfer off contract, then there's a problem
        }

        fn get_item_details(ref self: ContractState, item_id: u256, session_id: felt252) -> Gear {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            // might not return a gear
            Default::default()
        }

        // Some Item Details struct.
        fn total_held_of(
            ref self: ContractState, gear_type: GearType, session_id: felt252,
        ) -> u256 {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            0
        }

        // use the caller and read the model of both the caller, and the target
        // the target only refers to one target type for now
        // This target type is raidable.
        fn raid(ref self: ContractState, target: u256, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
        }

        fn unequip(ref self: ContractState, item_id: Array<u256>, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
        }

        fn get_configuration(
            ref self: ContractState, item_id: u256, session_id: felt252,
        ) -> Option<GearProperties> {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            Option::None
        }

        // This configure should take in an enum that lists all Gear Types with their structs
        // This function would be blocked at the moment, we shall use the default configuration
        // of the gameplay and how items interact with each other.
        // e.g. guns auto-reload once the time has run out
        // and TODO: Add a delay for auto reload.
        // for a base gun, we default the auto reload to exactly 6 seconds...
        //
        fn configure(ref self: ContractState, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
            // params to be completed
        }

        fn auction(ref self: ContractState, item_ids: Array<u256>, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
        }

        fn dismantle(ref self: ContractState, item_ids: Array<u256>, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
        }

        fn transfer(ref self: ContractState, item_ids: Array<u256>, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
        }

        fn grant(ref self: ContractState, asset: GearType) {
            let mut world = self.world_default();
            self._assert_admin();

            // Create a new gear instance based on the asset type
            let new_gear_id = generate_id(GEAR, ref world);
            // Implementation would create gear based on asset type
        }

        // These functions might be reserved for players within a specific faction

        // this function forges and creates a new item id based
        // normally, this function should be called only when the player is in a forging place.
        fn forge(ref self: ContractState, item_ids: Array<u256>, session_id: felt252) -> u256 {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            // should create a new asset. Perhaps deduct credits from the player.
            0
        }

        fn awaken(ref self: ContractState, exchange: Array<u256>, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);
        }

        fn can_be_awakened(
            ref self: ContractState, item_ids: Array<u256>, session_id: felt252,
        ) -> Span<bool> {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            array![].span()
        }

        fn pick_items(
            ref self: ContractState, item_id: Array<u256>, session_id: felt252,
        ) -> Array<u256> {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut player: crate::models::player::Player = world.read_model(caller);

            // Initialize player
            player.init('default');

            let mut successfully_picked: Array<u256> = array![];
            let contract: Contract = world.read_model('CONTRACT');
            let erc1155_address = contract.erc1155;

            let has_vehicle = player.has_vehicle_equipped();

            let mut i = 0;
            while i < item_id.len() {
                let item_id = *item_id.at(i);
                let mut gear: Gear = world.read_model(item_id);

                assert(gear.is_available_for_pickup(), 'Item not available');

                // Check if player meets XP requirement
                if player.xp < gear.min_xp_needed {
                    i += 1;
                    continue;
                }

                let mut equipped = false;
                let mut mint_item = false;

                if has_vehicle {
                    // If player has vehicle, mint all items directly to inventory
                    mint_item = true;
                } else {
                    if player.is_equippable(item_id) {
                        PlayerTrait::equip(ref player, item_id);
                        equipped = true;
                        mint_item = true;
                    } else {
                        if player.has_free_inventory_slot() {
                            mint_item = true;
                        }
                    }
                }

                if mint_item {
                    // Mint the item to player's inventory
                    player.mint(item_id, erc1155_address, 1);

                    // Update gear ownership and spawned state
                    gear.transfer_to(caller);
                    world.write_model(@gear);

                    // Add to successfully picked array
                    successfully_picked.append(item_id);

                    // Emit itempicked event
                    world
                        .emit_event(
                            @ItemPicked {
                                player_id: caller,
                                item_id: item_id,
                                equipped: equipped,
                                via_vehicle: has_vehicle,
                            },
                        );
                }

                i += 1;
            };

            // Update Player state
            world.write_model(@player);

            successfully_picked
        }

        fn use_item(
            ref self: ContractState, item_id: u256, target_id: Option<u256>, session_id: felt252,
        ) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut player: crate::models::player::Player = world.read_model(caller);
            let gear: Gear = world.read_model(item_id);

            // Verify the item exists and player owns it
            assert(gear.owner == caller, 'ITEM_NOT_OWNED');

            // Verify the item is equipped before use
            let mut is_equipped = false;
            let mut i = 0;
            while i < player.equipped.len() {
                if *player.equipped.at(i) == item_id {
                    is_equipped = true;
                    break;
                }
                i += 1;
            };
            assert(is_equipped, 'ITEM_NOT_EQUIPPED');

            // Verify the item is consumable
            assert(gear.is_consumable(), 'ITEM_NOT_CONSUMABLE');

            // Apply item effects based on type
            let item_type = parse_id(gear.asset_id);
            match item_type {
                GearType::HealthPotion => {
                    let heal_amount: u256 = 100;
                    let new_hp = if player.hp + heal_amount > player.max_hp {
                        player.max_hp
                    } else {
                        player.hp + heal_amount
                    };
                    player.hp = new_hp;
                },
                GearType::XpBooster => {
                    let xp_amount: u256 = 200;
                    player.add_xp(xp_amount);
                },
                GearType::EnergyDrink => {
                    // Temporary stat boost - increase max HP temporarily
                    let boost_amount: u256 = 50;
                    player.max_hp += boost_amount;
                    player.hp += boost_amount;
                },
                GearType::RepairKit => { // Repair all equipped gear (placeholder - would need durability system)
                // For now, just emit an event
                },
                GearType::Stimpack => {
                    // Damage boost - would need temporary effects system
                    // For now, heal and add XP
                    let heal_amount: u256 = 50;
                    player
                        .hp =
                            if player.hp + heal_amount > player.max_hp {
                                player.max_hp
                            } else {
                                player.hp + heal_amount
                            };
                    player.add_xp(100);
                },
                GearType::ArmorRepair => { // Repair armor durability (placeholder)
                },
                GearType::WeaponOil => { // Enhance weapon performance temporarily (placeholder)
                },
                _ => { assert(false, 'INVALID_CONSUMABLE_TYPE'); },
            }

            // Remove item from player's equipped list
            let mut new_equipped: Array<u256> = array![];
            let mut i = 0;
            while i < player.equipped.len() {
                let equipped_item = *player.equipped.at(i);
                if equipped_item != item_id {
                    new_equipped.append(equipped_item);
                }
                i += 1;
            };
            player.equipped = new_equipped;

            // Burn the item - reduce total_count or remove completely
            let contract: Contract = world.read_model('CONTRACT');
            let erc1155_address = contract.erc1155;
            let erc1155_contract = IERC1155MintableDispatcher { contract_address: erc1155_address };
            erc1155_contract.burn(caller, item_id, 1);

            // Update player and gear state
            let mut updated_gear = gear;
            if updated_gear.total_count > 1 {
                updated_gear.total_count = updated_gear.total_count - 1;
            } else {
                // Clear ownership for fully consumed item
                updated_gear.owner = ContractAddressDefault::default();
                updated_gear.spawned = false;
            }
            world.write_model(@updated_gear);
            world.write_model(@player);

            // Emit ItemUsed event
            world
                .emit_event(
                    @ItemUsed {
                        player_id: caller,
                        item_id: item_id,
                        target_id: target_id,
                        item_type: item_type,
                    },
                );
        }

        fn wield_item(ref self: ContractState, item_id: u256, session_id: felt252) {
            // Validate session before proceeding
            self.validate_session_for_action(session_id);

            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut player: crate::models::player::Player = world.read_model(caller);
            let gear: Gear = world.read_model(item_id);

            // Verify the item exists and player owns it
            assert(gear.owner == caller, 'ITEM_NOT_OWNED');

            // Verify the item is equipped before wielding
            let mut is_equipped = false;
            let mut i = 0;
            while i < player.equipped.len() {
                if *player.equipped.at(i) == item_id {
                    is_equipped = true;
                    break;
                }
                i += 1;
            };
            assert(is_equipped, 'ITEM_NOT_EQUIPPED');

            // Verify the item can be wielded
            assert(gear.is_wieldable(), 'ITEM_NOT_WIELDABLE');

            // Set item as "in_action" to indicate it's being wielded
            let mut updated_gear = gear;
            updated_gear.in_action = true;
            world.write_model(@updated_gear);

            // Emit ItemWielded event
            world.emit_event(@ItemWielded { player_id: caller, item_id: item_id, wielded: true });
        }
    }

    #[generate_trait]
    pub impl GearInternalImpl of GearInternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"coa")
        }

        fn _assert_admin(self: @ContractState) { // assert the admin here.
            let world = self.world_default();
            let caller = get_caller_address();
            let operator: Operator = world.read_model(caller);
            assert(operator.is_operator, 'Caller is not admin');
        }

        fn validate_session_for_action(ref self: ContractState, session_id: felt252) {
            // Basic validation - session_id must not be zero
            assert(session_id != 0, 'INVALID_SESSION');

            // Get the caller's address
            let caller = get_caller_address();

            // Read session from storage
            let mut world = self.world_default();
            let mut session: SessionKey = world.read_model((session_id, caller));

            // Validate session exists
            assert(session.session_id != 0, 'SESSION_NOT_FOUND');

            // Validate session belongs to the caller
            assert(session.player_address == caller, 'UNAUTHORIZED_SESSION');

            // Validate session is active
            assert(session.is_valid, 'SESSION_INVALID');
            assert(session.status == 0, 'SESSION_NOT_ACTIVE');

            // Validate session has not expired
            let current_time = starknet::get_block_timestamp();
            assert(current_time < session.expires_at, 'SESSION_EXPIRED');

            // Validate session has transactions left
            assert(session.used_transactions < session.max_transactions, 'NO_TRANSACTIONS_LEFT');

            // Check if session needs auto-renewal (less than 5 minutes remaining)
            let time_remaining = if current_time >= session.expires_at {
                0
            } else {
                session.expires_at - current_time
            };

            // Auto-renew if less than 5 minutes remaining (300 seconds)
            if time_remaining < 300 {
                // Auto-renew session for 1 hour with 100 transactions
                let mut updated_session = session;
                updated_session.expires_at = current_time + 3600; // 1 hour
                updated_session.last_used = current_time;
                updated_session.max_transactions = 100;
                updated_session.used_transactions = 0; // Reset transaction count

                // Write updated session back to storage
                world.write_model(@updated_session);

                // Update session reference for validation
                session = updated_session;
            }

            // Increment transaction count for this action
            session.used_transactions += 1;
            session.last_used = current_time;

            // Write updated session back to storage
            world.write_model(@session);
        }

        fn _retrieve(
            ref self: ContractState, item_id: u256,
        ) { // this function should probably return an enum
        // or use an external function in the helper trait that returns an enum
        }

        fn erc1155mint(contract_address: ContractAddress) -> IERC1155MintableDispatcher {
            IERC1155MintableDispatcher { contract_address }
        }

        fn _initialize_gear_assets(ref self: ContractState, ref world: WorldStorage) {
            // Weapons - using ERC1155 token IDs as primary keys
            let weapon_1_id = u256 { low: 0x0001, high: 0x1 };
            // let weapon_1_gear = Gear {
        //     id: generate_id(GEAR, ref world), // WEAPON_1 from ERC1155
        //     item_type: 'WEAPON',
        //     asset_id: weapon_1_id, // u256.high for weapons
        //     variation_ref: 1,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 10,
        //     mix_xp_needed: 0,
        // };
        // world.write_model(@weapon_1_gear);

            // // Weapon 1 stats
        // let weapon_1_stats = crate::models::weapon_stats::WeaponStats {
        //     asset_id: weapon_1_id,
        //     damage: 45,
        //     range: 100,
        //     accuracy: 85,
        //     fire_rate: 15,
        //     ammo_capacity: 30,
        //     reload_time: 3,
        // };
        // world.write_model(@weapon_1_stats);

            // let weapon_2_id = u256 { low: 0x0002, high: 0x1 };
        // let weapon_2_gear = Gear {
        //     id: generate_id(GEAR, ref world), // WEAPON_2 from ERC1155
        //     item_type: 'WEAPON',
        //     asset_id: weapon_2_id, // u256.high for weapons
        //     variation_ref: 2,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 10,
        //     min_xp_needed: 0,
        //     spawned: false,
        // };
        // world.write_model(@weapon_2_gear);

            // // Weapon 2 stats
        // let weapon_2_stats = crate::models::weapon_stats::WeaponStats {
        //     asset_id: weapon_2_id,
        //     damage: 60,
        //     range: 80,
        //     accuracy: 90,
        //     fire_rate: 10,
        //     ammo_capacity: 20,
        //     reload_time: 4,
        // };
        // world.write_model(@weapon_2_stats);

            // // Armor Types
        // let helmet_id = u256 { low: 0x0001, high: 0x2000 };
        // let helmet_gear = Gear {
        //     id: generate_id(GEAR, ref world), // HELMET from ERC1155
        //     item_type: 'ARMOR',
        //     asset_id: helmet_id, // u256.high for helmet
        //     variation_ref: 1,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 8,
        //     min_xp_needed: 0,
        //     spawned: false,
        // };
        // world.write_model(@helmet_gear);

            // // Helmet stats
        // let helmet_stats = crate::models::armor_stats::ArmorStats {
        //     asset_id: helmet_id, defense: 25, durability: 100, weight: 2, slot_type:
        //     'HELMET',
        // };
        // world.write_model(@helmet_stats);

            // let chest_armor_id = u256 { low: 0x0001, high: 0x2001 };
        // let chest_armor_gear = Gear {
        //     id: generate_id(GEAR, ref world), // CHEST_ARMOR from ERC1155
        //     item_type: 'ARMOR',
        //     asset_id: chest_armor_id, // u256.high for chest armor
        //     variation_ref: 1,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 8,
        //     min_xp_needed: 0,
        //     spawned: false,
        // };
        // world.write_model(@chest_armor_gear);

            // // Chest armor stats
        // let chest_armor_stats = crate::models::armor_stats::ArmorStats {
        //     asset_id: chest_armor_id,
        //     defense: 50,
        //     durability: 150,
        //     weight: 8,
        //     slot_type: 'CHEST',
        // };
        // world.write_model(@chest_armor_stats);

            // let leg_armor_id = u256 { low: 0x0001, high: 0x2002 };
        // let leg_armor_gear = Gear {
        //     id: generate_id(GEAR, ref world), // LEG_ARMOR from ERC1155
        //     item_type: 'ARMOR',
        //     asset_id: leg_armor_id, // u256.high for leg armor
        //     variation_ref: 1,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 8,
        //     min_xp_needed: 0,
        //     spawned: false,
        // };
        // world.write_model(@leg_armor_gear);

            // // Leg armor stats
        // let leg_armor_stats = crate::models::armor_stats::ArmorStats {
        //     asset_id: leg_armor_id, defense: 35, durability: 120, weight: 6, slot_type:
        //     'LEGS',
        // };
        // world.write_model(@leg_armor_stats);

            // let boots_id = u256 { low: 0x0001, high: 0x2003 };
        // let boots_gear = Gear {
        //     id: generate_id(GEAR, ref world), // BOOTS from ERC1155
        //     item_type: 'ARMOR',
        //     asset_id: boots_id, // u256.high for boots
        //     variation_ref: 1,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 8,
        //     min_xp_needed: 0,
        //     spawned: false,
        // };
        // world.write_model(@boots_gear);

            // // Boots stats
        // let boots_stats = crate::models::armor_stats::ArmorStats {
        //     asset_id: boots_id, defense: 20, durability: 80, weight: 3, slot_type: 'BOOTS',
        // };
        // world.write_model(@boots_stats);

            // let gloves_id = u256 { low: 0x0001, high: 0x2004 };
        // let gloves_gear = Gear {
        //     id: generate_id(GEAR, ref world), // GLOVES from ERC1155
        //     item_type: 'ARMOR',
        //     asset_id: gloves_id, // u256.high for gloves
        //     variation_ref: 1,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 8,
        //     min_xp_needed: 0,
        //     spawned: true,
        // };
        // world.write_model(@gloves_gear);

            // // Gloves stats
        // let gloves_stats = crate::models::armor_stats::ArmorStats {
        //     asset_id: gloves_id, defense: 15, durability: 60, weight: 1, slot_type: 'GLOVES',
        // };
        // world.write_model(@gloves_stats);

            // // Vehicles
        // let vehicle_id = u256 { low: 0x0001, high: 0x30000 };
        // let vehicle_gear = Gear {
        //     id: generate_id(GEAR, ref world), // VEHICLE from ERC1155
        //     item_type: 'VEHICLE',
        //     asset_id: vehicle_id, // u256.high for vehicles
        //     variation_ref: 1,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 5,
        //     min_xp_needed: 0,
        //     spawned: false,
        // };
        // world.write_model(@vehicle_gear);

            // // Vehicle 1 stats
        // let vehicle_stats = crate::models::vehicle_stats::VehicleStats {
        //     asset_id: vehicle_id,
        //     speed: 80,
        //     armor: 60,
        //     fuel_capacity: 100,
        //     cargo_capacity: 500,
        //     maneuverability: 70,
        // };
        // world.write_model(@vehicle_stats);

            // let vehicle_2_id = u256 { low: 0x0002, high: 0x30000 };
        // let vehicle_2_gear = Gear {
        //     id: generate_id(GEAR, ref world), // VEHICLE_2 from ERC1155
        //     item_type: 'VEHICLE',
        //     asset_id: vehicle_2_id,
        //     variation_ref: 2,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 5,
        //     min_xp_needed: 0,
        //     spawned: false,
        // };
        // world.write_model(@vehicle_2_gear);

            // // Vehicle 2 stats (different variation)
        // let vehicle_2_stats = crate::models::vehicle_stats::VehicleStats {
        //     asset_id: vehicle_2_id,
        //     speed: 60,
        //     armor: 90,
        //     fuel_capacity: 150,
        //     cargo_capacity: 800,
        //     maneuverability: 50,
        // };
        // world.write_model(@vehicle_2_stats);

            // // Pets / Drones
        // let pet_1_id = u256 { low: 0x0001, high: 0x800000 };
        // let pet_1_gear = Gear {
        //     id: generate_id(GEAR, ref world), // PET_1 from ERC1155
        //     item_type: 'PET',
        //     asset_id: pet_1_id, // u256.high for pets
        //     variation_ref: 1,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 15,
        //     min_xp_needed: 0,
        //     spawned: false,
        // };
        // world.write_model(@pet_1_gear);

            // // Pet 1 stats
        // let pet_1_stats = crate::models::pet_stats::PetStats {
        //     asset_id: pet_1_id,
        //     loyalty: 85,
        //     intelligence: 75,
        //     agility: 90,
        //     special_ability: 'STEALTH',
        //     energy: 100,
        // };
        // world.write_model(@pet_1_stats);

            // let pet_2_id = u256 { low: 0x0002, high: 0x800000 };
        // let pet_2_gear = Gear {
        //     id: generate_id(GEAR, ref world), // PET_2 from ERC1155
        //     item_type: 'PET',
        //     asset_id: pet_2_id, // u256.high for pets
        //     variation_ref: 2,
        //     total_count: 1,
        //     in_action: false,
        //     upgrade_level: 0,
        //     max_upgrade_level: 15,
        //     min_xp_needed: 0,
        //     spawned: false,
        // };
        // world.write_model(@pet_2_gear);

            // Pet 2 stats
        // let pet_2_stats = crate::models::pet_stats::PetStats {
        //     asset_id: pet_2_id,
        //     loyalty: 95,
        //     intelligence: 85,
        //     agility: 70,
        //     special_ability: 'COMBAT_SUPPORT',
        //     energy: 120,
        // };
        // world.write_model(@pet_2_stats);
        }
    }
}
