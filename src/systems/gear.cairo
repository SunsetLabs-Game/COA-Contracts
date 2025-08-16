#[dojo::contract]
pub mod GearActions {
    use crate::interfaces::gear::IGear;
    use dojo::event::EventStorage;
    use crate::models::gear::GearTrait;
    use crate::helpers::gear::*;
    use crate::helpers::session_validation::*;
    use starknet::{ContractAddress, get_block_timestamp, get_contract_address, get_caller_address};
    use crate::models::player::{Player, PlayerTrait};
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
    // A constant key for our singleton UpgradeConfigState model
    const UPGRADE_CONFIG_KEY: u8 = 0;

    fn dojo_init(ref self: ContractState) {
        let mut world = self.world_default();
        self._assert_admin();
        self._initialize_gear_assets(ref world);
        world
            .write_model(
                @UpgradeConfigState {
                    singleton_key: UPGRADE_CONFIG_KEY,
                    initialized_types_count: 0,
                    is_complete: false,
                },
            );
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
        fn upgrade_gear(
            ref self: ContractState,
            item_id: u256,
            session_id: felt252,
            materials_erc1155_address: ContractAddress,
        ) {
            self.validate_session_for_action(session_id);
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mut gear: Gear = world.read_model(item_id);

            // Validation Rules
            assert(gear.owner == caller, 'Caller is not owner');
            assert(gear.upgrade_level < gear.max_upgrade_level, 'Gear at max level');

            let next_level = gear.upgrade_level + 1;
            let gear_type: GearType = gear.item_type.try_into().expect('Invalid gear type');

            // Assert that the stats for the next level are defined before proceeding.
            // This prevents players from losing materials on an impossible upgrade.
            let new_stats: GearLevelStats = world.read_model((gear.asset_id, next_level));
            // Ensure the exact next-level record exists
            assert(new_stats.level == next_level, 'Next level stats not defined');
            let upgrade_cost: UpgradeCost = world.read_model((gear_type, gear.upgrade_level));
            let success_rate: UpgradeSuccessRate = world
                .read_model((gear_type, gear.upgrade_level));

            assert(upgrade_cost.materials.len() > 0, 'No upgrade path for item');

            // Material Consumption
            let erc1155 = IERC1155Dispatcher { contract_address: materials_erc1155_address };
            let mut materials = upgrade_cost.materials;
            let mut i = 0;
            while i != materials.len() {
                let material = *materials.at(i);
                let balance = erc1155.balance_of(caller, material.token_id);
                assert(balance >= material.amount, 'Insufficient materials');

                // Consume materials on attempt
                erc1155
                    .safe_transfer_from(
                        caller,
                        get_contract_address(),
                        material.token_id,
                        material.amount,
                        array![].span(),
                    );
                i += 1;
            };

            // Probability System using seeded dice with on-chain entropy
            let tx_hash: felt252 = starknet::get_tx_info().unbox().transaction_hash;
            let seed: felt252 = tx_hash
                + caller.into()
                + item_id.low.into()
                + get_block_timestamp().into();
            let mut dice = DiceTrait::new(100, seed);
            let pseudo_random: u8 = dice.roll();

            if pseudo_random < success_rate.rate.into() {
                // Successful Upgrade
                gear.upgrade_level = next_level;

                // By incrementing the level, the gear now implicitly uses the `new_stats`
                // we've already confirmed exist. No further action is needed to "apply" them
                // in this ECS architecture.

                world.write_model(@gear);

                world
                    .emit_event(
                        @UpgradeSuccess {
                            player_id: caller,
                            gear_id: item_id,
                            new_level: gear.upgrade_level,
                            materials_consumed: materials.span(),
                        },
                    );
            } else {
                // Failed Upgrade (materials are still consumed)
                world
                    .emit_event(
                        @UpgradeFailed {
                            player_id: caller,
                            gear_id: item_id,
                            level: gear.upgrade_level,
                            materials_consumed: materials.span(),
                        },
                    );
            }
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
            let mut player: Player = world.read_model(caller);

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

        fn get_gear_details_complete(
            ref self: ContractState, item_id: u256, session_id: felt252,
        ) -> Option<GearDetailsComplete> {
            if !self.validate_session_for_read_action(session_id) {
                return Option::None;
            }

            let world = self.world_default();
            let gear: Gear = world.read_model(item_id);

            if gear.id == 0 {
                return Option::None;
            }

            let calculated_stats = self._calculate_gear_stats(@gear);
            let upgrade_info = self._get_upgrade_info(@gear);
            let ownership_status = self._get_ownership_status(@gear);

            Option::Some(
                GearDetailsComplete { gear, calculated_stats, upgrade_info, ownership_status },
            )
        }

        fn get_gear_details_batch(
            ref self: ContractState, item_ids: Array<u256>, session_id: felt252,
        ) -> Array<Option<GearDetailsComplete>> {
            if !self.validate_session_for_read_action(session_id) {
                return array![];
            }

            let mut results = array![];
            let mut i = 0;
            while i < item_ids.len() {
                let item_id = *item_ids.at(i);
                let details = self.get_gear_details_complete(item_id, session_id);
                results.append(details);
                i += 1;
            };
            results
        }

        fn get_calculated_stats(
            ref self: ContractState, item_id: u256, session_id: felt252,
        ) -> Option<GearStatsCalculated> {
            if !self.validate_session_for_read_action(session_id) {
                return Option::None;
            }

            let world = self.world_default();
            let gear: Gear = world.read_model(item_id);

            if gear.id == 0 {
                return Option::None;
            }

            Option::Some(self._calculate_gear_stats(@gear))
        }

        fn get_upgrade_preview(
            ref self: ContractState, item_id: u256, target_level: u64, session_id: felt252,
        ) -> Option<UpgradeInfo> {
            if !self.validate_session_for_read_action(session_id) {
                return Option::None;
            }

            let world = self.world_default();
            let gear: Gear = world.read_model(item_id);

            if gear.id == 0 || target_level > gear.max_upgrade_level {
                return Option::None;
            }

            Option::Some(self._calculate_upgrade_preview(@gear, target_level))
        }

        fn get_player_inventory(
            ref self: ContractState,
            player: ContractAddress,
            filters: Option<GearFilters>,
            pagination: Option<PaginationParams>,
            sort: Option<SortParams>,
            session_id: felt252,
        ) -> PaginatedGearResult {
            if !self.validate_session_for_read_action(session_id) {
                return PaginatedGearResult { items: array![], total_count: 0, has_more: false };
            }

            self._get_filtered_gear(filters, pagination, sort, Option::Some(player))
        }

        fn get_equipped_gear(
            ref self: ContractState, player: ContractAddress, session_id: felt252,
        ) -> CombinedEquipmentEffects {
            if !self.validate_session_for_read_action(session_id) {
                return CombinedEquipmentEffects {
                    total_damage: 0,
                    total_defense: 0,
                    total_weight: 0,
                    equipped_slots: array![],
                    empty_slots: array![],
                    set_bonuses: array![],
                };
            }

            let world = self.world_default();
            let player_data: Player = world.read_model(player);

            self._calculate_combined_effects(@player_data)
        }

        fn get_available_items(
            ref self: ContractState,
            player_xp: u256,
            filters: Option<GearFilters>,
            pagination: Option<PaginationParams>,
            session_id: felt252,
        ) -> PaginatedGearResult {
            if !self.validate_session_for_read_action(session_id) {
                return PaginatedGearResult { items: array![], total_count: 0, has_more: false };
            }

            // Filter for spawned items that meet XP requirements
            let mut available_filters = match filters {
                Option::Some(f) => f,
                Option::None => GearFilters {
                    gear_types: Option::None,
                    min_level: Option::None,
                    max_level: Option::None,
                    ownership_filter: Option::Some(OwnershipFilter::Available),
                    min_xp_required: Option::None,
                    max_xp_required: Option::Some(player_xp),
                    spawned_only: Option::Some(true),
                },
            };

            available_filters.spawned_only = Option::Some(true);
            available_filters.max_xp_required = Option::Some(player_xp);

            self
                ._get_filtered_gear(
                    Option::Some(available_filters), pagination, Option::None, Option::None,
                )
        }

        fn calculate_upgrade_costs(
            ref self: ContractState, item_id: u256, target_level: u64, session_id: felt252,
        ) -> Option<Array<(u256, u256)>> {
            if !self.validate_session_for_read_action(session_id) {
                return Option::None;
            }

            let world = self.world_default();
            let gear: Gear = world.read_model(item_id);

            if gear.id == 0
                || target_level > gear.max_upgrade_level
                || target_level <= gear.upgrade_level {
                return Option::None;
            }

            Option::Some(self._calculate_total_upgrade_costs(@gear, target_level))
        }

        fn check_upgrade_feasibility(
            ref self: ContractState,
            item_id: u256,
            target_level: u64,
            player_materials: Array<(u256, u256)>,
            session_id: felt252,
        ) -> (bool, Array<(u256, u256)>) {
            if !self.validate_session_for_read_action(session_id) {
                return (false, array![]);
            }

            let result = match self.calculate_upgrade_costs(item_id, target_level, session_id) {
                Option::Some(costs) => self._check_material_availability(costs, player_materials),
                Option::None => (false, array![]),
            };

            result
        }

        fn filter_gear_by_type(
            ref self: ContractState,
            gear_type: GearType,
            pagination: Option<PaginationParams>,
            session_id: felt252,
        ) -> PaginatedGearResult {
            if !self.validate_session_for_read_action(session_id) {
                return PaginatedGearResult { items: array![], total_count: 0, has_more: false };
            }

            let filters = GearFilters {
                gear_types: Option::Some(array![gear_type]),
                min_level: Option::None,
                max_level: Option::None,
                ownership_filter: Option::None,
                min_xp_required: Option::None,
                max_xp_required: Option::None,
                spawned_only: Option::None,
            };

            self._get_filtered_gear(Option::Some(filters), pagination, Option::None, Option::None)
        }

        fn search_gear_by_criteria(
            ref self: ContractState,
            filters: GearFilters,
            pagination: Option<PaginationParams>,
            sort: Option<SortParams>,
            session_id: felt252,
        ) -> PaginatedGearResult {
            if !self.validate_session_for_read_action(session_id) {
                return PaginatedGearResult { items: array![], total_count: 0, has_more: false };
            }

            self._get_filtered_gear(Option::Some(filters), pagination, sort, Option::None)
        }

        fn compare_gear_stats(
            ref self: ContractState, item_ids: Array<u256>, session_id: felt252,
        ) -> Array<GearStatsCalculated> {
            if !self.validate_session_for_read_action(session_id) {
                return array![];
            }

            let world = self.world_default();
            let mut stats_array = array![];
            let mut i = 0;

            while i < item_ids.len() {
                let item_id = *item_ids.at(i);
                let gear: Gear = world.read_model(item_id);

                if gear.id != 0 {
                    let stats = self._calculate_gear_stats(@gear);
                    stats_array.append(stats);
                }
                i += 1;
            };

            stats_array
        }

        fn get_gear_summary(
            ref self: ContractState, item_id: u256, session_id: felt252,
        ) -> Option<(Gear, u64, u64, u64)> {
            if !self.validate_session_for_read_action(session_id) {
                return Option::None;
            }

            let world = self.world_default();
            let gear: Gear = world.read_model(item_id);

            if gear.id == 0 {
                return Option::None;
            }

            let stats = self._calculate_gear_stats(@gear);
            Option::Some((gear, stats.damage, stats.defense, stats.weight))
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

        // Full implementation of upgrade data initialization
        fn _initialize_upgrade_data_for_gear_type(
            self: @ContractState, ref world: WorldStorage, gear_type: GearType,
        ) {
            // ... (The logic from the previous answer is perfect and stays here)
            // Material Fungible Token IDs (placeholders)
            let scrap_metal: u256 = 1;
            let wiring: u256 = 2;
            let advanced_alloy: u256 = 3;
            let cybernetic_core: u256 = 4;

            // Base rates and costs
            let success_rates = array![95, 90, 85, 80, 75, 50, 40, 30, 20, 10];
            let costs_scrap = array![10, 20, 40, 80, 120, 180, 250, 350, 500, 750];
            let costs_wiring = array![0, 5, 10, 20, 40, 80, 120, 180, 250, 350];
            let costs_alloy = array![0, 0, 0, 0, 10, 20, 40, 80, 120, 180];
            let costs_core = array![0, 0, 0, 0, 0, 0, 5, 10, 20, 40];

            let mut level: u32 = 0;
            while level != 10 {
                world
                    .write_model(
                        @UpgradeSuccessRate {
                            gear_type: gear_type,
                            level: level.into(),
                            rate: *success_rates.at(level),
                        },
                    );

                let mut materials_for_level = array![];
                let scrap_cost = *costs_scrap.at(level);
                if scrap_cost > 0 {
                    materials_for_level
                        .append(UpgradeMaterial { token_id: scrap_metal, amount: scrap_cost });
                }
                let wiring_cost = *costs_wiring.at(level);
                if wiring_cost > 0 {
                    materials_for_level
                        .append(UpgradeMaterial { token_id: wiring, amount: wiring_cost });
                }
                let alloy_cost = *costs_alloy.at(level);
                if alloy_cost > 0 {
                    materials_for_level
                        .append(UpgradeMaterial { token_id: advanced_alloy, amount: alloy_cost });
                }
                let core_cost = *costs_core.at(level);
                if (gear_type == GearType::Pet || gear_type == GearType::Drone) && core_cost > 0 {
                    materials_for_level
                        .append(UpgradeMaterial { token_id: cybernetic_core, amount: core_cost });
                }

                world
                    .write_model(
                        @UpgradeCost {
                            gear_type: gear_type,
                            level: level.into(),
                            materials: materials_for_level,
                        },
                    );
                level += 1;
            };
        }

        fn _retrieve(
            ref self: ContractState, item_id: u256,
        ) { // this function should probably return an enum
        // or use an external function in the helper trait that returns an enum
        }

        fn validate_session_for_read_action(ref self: ContractState, session_id: felt252) -> bool {
            // Basic validation - session_id must not be zero
            if session_id == 0 {
                return false;
            }

            let caller = get_caller_address();
            let world = self.world_default();
            let session: SessionKey = world.read_model((session_id, caller));

            // Use helper function for validation (read-only, so no transaction increment)
            validate_session_parameters(session, caller)
        }

        fn _calculate_gear_stats(self: @ContractState, gear: @Gear) -> GearStatsCalculated {
            let mut world = self.world_default();
            // Get level-based stats
            let level_stats: GearLevelStats = world
                .read_model((*gear.asset_id, *gear.upgrade_level));

            // Initialize with level stats
            let mut calculated = GearStatsCalculated {
                damage: level_stats.damage,
                range: level_stats.range,
                accuracy: level_stats.accuracy,
                fire_rate: level_stats.fire_rate,
                defense: level_stats.defense,
                durability: level_stats.durability,
                weight: level_stats.weight,
                speed: 0,
                armor: 0,
                fuel_capacity: 0,
                loyalty: 0,
                intelligence: 0,
                agility: 0,
            };

            // Get gear type and load specific stats
            let gear_type = parse_id(*gear.asset_id);

            match gear_type {
                GearType::Weapon | GearType::BluntWeapon | GearType::Sword | GearType::Bow |
                GearType::Firearm | GearType::Polearm | GearType::HeavyFirearms |
                GearType::Explosives => {
                    let weapon_stats: WeaponStats = world.read_model(*gear.asset_id);
                    // Apply upgrade multipliers to weapon stats
                    calculated
                        .damage = self
                        ._apply_upgrade_multiplier(weapon_stats.damage, *gear.upgrade_level);
                    calculated
                        .range = self
                        ._apply_upgrade_multiplier(weapon_stats.range, *gear.upgrade_level);
                    calculated
                        .accuracy = self
                        ._apply_upgrade_multiplier(weapon_stats.accuracy, *gear.upgrade_level);
                    calculated
                        .fire_rate = self
                        ._apply_upgrade_multiplier(weapon_stats.fire_rate, *gear.upgrade_level);
                },
                GearType::Helmet | GearType::ChestArmor | GearType::LegArmor | GearType::Boots |
                GearType::Gloves |
                GearType::Shield => {
                    let armor_stats: Armor = world.read_model(*gear.asset_id);
                    // Apply upgrade multipliers to armor stats
                    calculated
                        .defense = self
                        ._apply_upgrade_multiplier(armor_stats.defense, *gear.upgrade_level);
                    calculated
                        .durability = self
                        ._apply_upgrade_multiplier(armor_stats.durability, *gear.upgrade_level);
                    calculated.weight = armor_stats.weight; // Weight doesn't scale with upgrades
                },
                GearType::Vehicle => {
                    let vehicle_stats: VehicleStats = world.read_model(*gear.asset_id);
                    // Apply upgrade multipliers to vehicle stats
                    calculated
                        .speed = self
                        ._apply_upgrade_multiplier(vehicle_stats.speed, *gear.upgrade_level);
                    calculated
                        .armor = self
                        ._apply_upgrade_multiplier(vehicle_stats.armor, *gear.upgrade_level);
                    calculated
                        .fuel_capacity = self
                        ._apply_upgrade_multiplier(
                            vehicle_stats.fuel_capacity, *gear.upgrade_level,
                        );
                },
                GearType::Pet |
                GearType::Drone => {
                    let pet_stats: PetStats = world.read_model(*gear.asset_id);
                    // Apply upgrade multipliers to pet stats
                    calculated
                        .loyalty = self
                        ._apply_upgrade_multiplier(pet_stats.loyalty, *gear.upgrade_level);
                    calculated
                        .intelligence = self
                        ._apply_upgrade_multiplier(pet_stats.intelligence, *gear.upgrade_level);
                    calculated
                        .agility = self
                        ._apply_upgrade_multiplier(pet_stats.agility, *gear.upgrade_level);
                },
                _ => { // Default case - use level stats as-is
                },
            }

            calculated
        }

        fn _apply_upgrade_multiplier(self: @ContractState, base_stat: u64, level: u64) -> u64 {
            // Base multiplier starts at 100% (level 0) and increases by 10% per level
            let multiplier = 100 + (level * 10);
            (base_stat * multiplier) / 100
        }

        fn _get_upgrade_info(self: @ContractState, gear: @Gear) -> Option<UpgradeInfo> {
            if gear.upgrade_level >= gear.max_upgrade_level {
                return Option::Some(
                    UpgradeInfo {
                        current_level: *gear.upgrade_level,
                        max_level: *gear.max_upgrade_level,
                        can_upgrade: false,
                        next_level_cost: Option::None,
                        success_rate: Option::None,
                        next_level_stats: Option::None,
                        total_upgrade_cost: Option::None,
                    },
                );
            }

            let gear_type = parse_id(*gear.asset_id);
            let next_level = *gear.upgrade_level + 1;
            let mut world = self.world_default();

            let upgrade_cost: UpgradeCost = world.read_model((gear_type, *gear.upgrade_level));
            let success_rate: UpgradeSuccessRate = world
                .read_model((gear_type, *gear.upgrade_level));

            // Calculate next level stats
            let next_level_gear = Gear {
                id: *gear.id,
                item_type: *gear.item_type,
                asset_id: *gear.asset_id,
                variation_ref: *gear.variation_ref,
                total_count: *gear.total_count,
                in_action: *gear.in_action,
                upgrade_level: next_level,
                owner: *gear.owner,
                max_upgrade_level: *gear.max_upgrade_level,
                min_xp_needed: *gear.min_xp_needed,
                spawned: *gear.spawned,
            };

            let next_stats = self._calculate_gear_stats(@next_level_gear);

            Option::Some(
                UpgradeInfo {
                    current_level: *gear.upgrade_level,
                    max_level: *gear.max_upgrade_level,
                    can_upgrade: true,
                    next_level_cost: Option::Some(upgrade_cost),
                    success_rate: Option::Some(success_rate.rate),
                    next_level_stats: Option::Some(next_stats),
                    total_upgrade_cost: Option::None // Would need to calculate for multiple levels
                },
            )
        }

        fn _get_ownership_status(self: @ContractState, gear: @Gear) -> OwnershipStatus {
            let caller = get_caller_address();

            OwnershipStatus {
                is_owned: !gear.owner.is_zero(),
                owner: *gear.owner,
                is_spawned: *gear.spawned,
                is_available_for_pickup: *gear.spawned && gear.owner.is_zero(),
                is_equipped: *gear.in_action,
                meets_xp_requirement: true // Would need player XP to calculate properly
            }
        }

        fn _calculate_upgrade_preview(
            self: @ContractState, gear: @Gear, target_level: u64,
        ) -> UpgradeInfo {
            let gear_type = parse_id(*gear.asset_id);
            let total_costs = self._calculate_total_upgrade_costs(gear, target_level);

            // Create gear at target level for stats calculation
            let target_gear = Gear {
                id: *gear.id,
                item_type: *gear.item_type,
                asset_id: *gear.asset_id,
                variation_ref: *gear.variation_ref,
                total_count: *gear.total_count,
                in_action: *gear.in_action,
                upgrade_level: target_level,
                owner: *gear.owner,
                max_upgrade_level: *gear.max_upgrade_level,
                min_xp_needed: *gear.min_xp_needed,
                spawned: *gear.spawned,
            };

            let target_stats = self._calculate_gear_stats(@target_gear);

            UpgradeInfo {
                current_level: *gear.upgrade_level,
                max_level: *gear.max_upgrade_level,
                can_upgrade: target_level <= *gear.max_upgrade_level,
                next_level_cost: Option::None,
                success_rate: Option::None,
                next_level_stats: Option::Some(target_stats),
                total_upgrade_cost: Option::Some(total_costs),
            }
        }

        fn _calculate_total_upgrade_costs(
            self: @ContractState, gear: @Gear, target_level: u64,
        ) -> Array<(u256, u256)> {
            let mut total_costs: Array<(u256, u256)> = array![];
            let gear_type = parse_id(*gear.asset_id);
            let mut world = self.world_default();

            let mut current_level = *gear.upgrade_level;
            while current_level < target_level {
                let upgrade_cost: UpgradeCost = world.read_model((gear_type, current_level));

                // Add materials to total costs
                let mut i = 0;
                while i < upgrade_cost.materials.len() {
                    let material = *upgrade_cost.materials.at(i);
                    // This is simplified - in reality you'd need to aggregate costs properly
                    total_costs.append((material.token_id, material.amount));
                    i += 1;
                };

                current_level += 1;
            };

            total_costs
        }

        fn _check_material_availability(
            self: @ContractState,
            required_materials: Array<(u256, u256)>,
            available_materials: Array<(u256, u256)>,
        ) -> (bool, Array<(u256, u256)>) {
            let mut missing_materials: Array<(u256, u256)> = array![];
            let mut feasible = true;

            let mut i = 0;
            while i < required_materials.len() {
                let (token_id, required_amount) = *required_materials.at(i);
                let mut available_amount = 0;

                // Find available amount for this token
                let mut j = 0;
                while j < available_materials.len() {
                    let (avail_token_id, avail_amount) = *available_materials.at(j);
                    if avail_token_id == token_id {
                        available_amount = avail_amount;
                        break;
                    }
                    j += 1;
                };

                if available_amount < required_amount {
                    feasible = false;
                    missing_materials.append((token_id, required_amount - available_amount));
                }

                i += 1;
            };

            (feasible, missing_materials)
        }

        fn _get_filtered_gear(
            self: @ContractState,
            filters: Option<GearFilters>,
            pagination: Option<PaginationParams>,
            sort: Option<SortParams>,
            owner_filter: Option<ContractAddress>,
        ) -> PaginatedGearResult {
            let world = self.world_default();

            // Simple pagination defaults
            let limit = match @pagination {
                Option::Some(p) => if *p.limit > 100 {
                    100
                } else {
                    *p.limit
                }, // Max 100 items
                Option::None => 20,
            };
            let offset = match pagination {
                Option::Some(p) => p.offset,
                Option::None => 0,
            };

            let mut result_items: Array<GearDetailsComplete> = array![];
            let mut total_checked = 0_u32;
            let mut items_found = 0_u32;

            // Check limited range to control gas usage
            let max_checks = 500_u256;
            let mut current_id = 1_u256;

            while current_id <= max_checks && result_items.len() < limit {
                let gear: Gear = world.read_model(current_id);

                // Skip non-existent items
                if gear.id == 0 {
                    current_id += 1;
                    continue;
                }

                // Quick owner check
                if let Option::Some(owner) = owner_filter {
                    if gear.owner != owner {
                        current_id += 1;
                        continue;
                    }
                }

                // Basic filtering (minimal)
                let passes_filters = match @filters {
                    Option::Some(f) => {
                        // Only check essential filters
                        if let Option::Some(spawned_only) = f.spawned_only {
                            if *spawned_only && !gear.spawned {
                                false
                            } else {
                                true
                            }
                        } else {
                            true
                        }
                    },
                    Option::None => true,
                };

                if passes_filters {
                    items_found += 1;

                    // Skip for offset
                    if items_found <= offset {
                        current_id += 1;
                        continue;
                    }

                    // Create minimal gear details
                    let calculated_stats = self._calculate_gear_stats(@gear);
                    let ownership_status = OwnershipStatus {
                        is_owned: !gear.owner.is_zero(),
                        owner: gear.owner,
                        is_spawned: gear.spawned,
                        is_available_for_pickup: gear.spawned && gear.owner.is_zero(),
                        is_equipped: gear.in_action,
                        meets_xp_requirement: true,
                    };

                    let gear_details = GearDetailsComplete {
                        gear,
                        calculated_stats,
                        upgrade_info: Option::None, // Skip for performance
                        ownership_status,
                    };

                    result_items.append(gear_details);
                }

                current_id += 1;
                total_checked += 1;
            };

            PaginatedGearResult {
                items: result_items,
                total_count: items_found,
                has_more: current_id <= max_checks && items_found > (offset + limit),
            }
        }

        fn _passes_filters(
            self: @ContractState, gear: @Gear, filters: Option<GearFilters>,
        ) -> bool {
            if filters.is_none() {
                return false;
            }
            let filters = filters.unwrap();

            // Check gear type filter
            if let Option::Some(allowed_types) = filters.gear_types {
                let gear_type = parse_id(*gear.asset_id);
                let mut type_matches = false;
                let mut i = 0;
                while i < allowed_types.len() {
                    if gear_type == *allowed_types.at(i) {
                        type_matches = true;
                        break;
                    }
                    i += 1;
                };
                if !type_matches {
                    return false;
                }
            }

            // Check level range
            if let Option::Some(min_level) = filters.min_level {
                if *gear.upgrade_level < min_level {
                    return false;
                }
            }

            if let Option::Some(max_level) = filters.max_level {
                if *gear.upgrade_level > max_level {
                    return false;
                }
            }

            // Check XP requirements
            if let Option::Some(min_xp) = filters.min_xp_required {
                if *gear.min_xp_needed < min_xp {
                    return false;
                }
            }

            if let Option::Some(max_xp) = filters.max_xp_required {
                if *gear.min_xp_needed > max_xp {
                    return false;
                }
            }

            // Check ownership filter
            if let Option::Some(ownership_filter) = filters.ownership_filter {
                match ownership_filter {
                    OwnershipFilter::Owned => { if gear.owner.is_zero() {
                        return false;
                    } },
                    OwnershipFilter::NotOwned => { if !gear.owner.is_zero() {
                        return false;
                    } },
                    OwnershipFilter::Available => {
                        if !(*gear.spawned && gear.owner.is_zero()) {
                            return false;
                        }
                    },
                    OwnershipFilter::Equipped => { if !*gear.in_action {
                        return false;
                    } },
                    OwnershipFilter::All => { // All items pass this filter
                    },
                }
            }

            // Check spawned filter
            if let Option::Some(spawned_only) = filters.spawned_only {
                if spawned_only && !*gear.spawned {
                    return false;
                }
            }

            true
        }

        fn _sort_gear_items(
            self: @ContractState, items: Array<GearDetailsComplete>, sort_params: SortParams,
        ) -> Array<@GearDetailsComplete> {
            // For simplicity, we'll implement a basic bubble sort
            // In production, you'd want a more efficient sorting algorithm
            let mut sorted_items = array![];
            let len = sorted_items.len();

            if len <= 1 {
                return sorted_items;
            }

            // Convert to a mutable array for sorting
            let mut i = 0;
            while i < len - 1 {
                let mut j = 0;
                while j < len - 1 - i {
                    let should_swap = self
                        ._should_swap_items(items.at(j), items.at(j + 1), sort_params);

                    if should_swap {
                        // In Cairo, we can't easily swap array elements in place
                        // So we'll rebuild the array with swapped elements
                        // This is inefficient but works for the implementation
                        let mut new_array = array![];
                        let mut k = 0;
                        while k < items.len() {
                            if k == j {
                                new_array.append(items.at(j + 1));
                            } else if k == j + 1 {
                                new_array.append(items.at(j));
                            } else {
                                new_array.append(items.at(k));
                            }
                            k += 1;
                        };
                        sorted_items = new_array;
                    }
                    j += 1;
                };
                i += 1;
            };

            sorted_items
        }

        fn _should_swap_items(
            self: @ContractState,
            item1: @GearDetailsComplete,
            item2: @GearDetailsComplete,
            sort_params: SortParams,
        ) -> bool {
            let value1 = self._get_sort_value(item1, sort_params.sort_by);
            let value2 = self._get_sort_value(item2, sort_params.sort_by);

            if sort_params.ascending {
                value1 > value2
            } else {
                value1 < value2
            }
        }

        fn _get_sort_value(
            self: @ContractState, item: @GearDetailsComplete, sort_field: SortField,
        ) -> u256 {
            match sort_field {
                SortField::Level => Into::<u64, u256>::into(*item.gear.upgrade_level),
                SortField::Damage => Into::<u64, u256>::into(*item.calculated_stats.damage),
                SortField::Defense => Into::<u64, u256>::into(*item.calculated_stats.defense),
                SortField::XpRequired => *item.gear.min_xp_needed,
                SortField::AssetId => *item.gear.asset_id,
            }
        }

        fn _paginate_items(
            self: @ContractState, items: Array<GearDetailsComplete>, offset: u32, limit: u32,
        ) -> Array<GearDetailsComplete> {
            let mut paginated = array![];
            let total_items = items.len();

            if offset >= total_items {
                return paginated; // Return empty array if offset is beyond items
            }

            let start_index = offset;
            let end_index = if start_index + limit > total_items {
                total_items
            } else {
                start_index + limit
            };

            let mut i = start_index;
            while i < end_index {
                paginated.append(items.at(i).clone());
                i += 1;
            };

            paginated
        }

        fn _calculate_combined_effects(
            self: @ContractState, player: @Player,
        ) -> CombinedEquipmentEffects {
            let world = self.world_default();

            let mut total_damage = 0_u64;
            let mut total_defense = 0_u64;
            let mut total_weight = 0_u64;
            let mut equipped_slots: Array<EquipmentSlotInfo> = array![];
            let mut empty_slots: Array<felt252> = array![];
            let mut equipped_gear_types: Array<GearType> = array![];

            // Process head slot (helmet)
            if *player.body.head != 0 {
                let gear: Gear = world.read_model(*player.body.head);
                if gear.id != 0 {
                    let stats = self._calculate_gear_stats(@gear);
                    total_defense += stats.defense;
                    total_weight += stats.weight;

                    let slot_info = EquipmentSlotInfo {
                        slot_type: 'HEAD', equipped_item: Option::Some(gear), is_empty: false,
                    };
                    equipped_slots.append(slot_info);
                    equipped_gear_types.append(parse_id(gear.asset_id));
                } else {
                    empty_slots.append('HEAD');
                }
            } else {
                empty_slots.append('HEAD');
            }

            // Process hands (gloves)
            if player.body.hands.len() > 0 {
                let mut hands_equipped = false;
                let mut i = 0;
                while i < player.body.hands.len() {
                    let gear_id = *player.body.hands.at(i);
                    if gear_id != 0 {
                        let gear: Gear = world.read_model(gear_id);
                        if gear.id != 0 {
                            let stats = self._calculate_gear_stats(@gear);
                            total_defense += stats.defense;
                            total_weight += stats.weight;

                            if !hands_equipped {
                                let slot_info = EquipmentSlotInfo {
                                    slot_type: 'HANDS',
                                    equipped_item: Option::Some(gear),
                                    is_empty: false,
                                };
                                equipped_slots.append(slot_info);
                                equipped_gear_types.append(parse_id(gear.asset_id));
                                hands_equipped = true;
                            }
                        }
                    }
                    i += 1;
                };
                if !hands_equipped {
                    empty_slots.append('HANDS');
                }
            } else {
                empty_slots.append('HANDS');
            }

            // Process weapons (left and right hand)
            let mut weapon_equipped = false;

            // Left hand weapons
            let mut i = 0;
            while i < player.body.left_hand.len() {
                let gear_id = *player.body.left_hand.at(i);
                if gear_id != 0 {
                    let gear: Gear = world.read_model(gear_id);
                    if gear.id != 0 {
                        let stats = self._calculate_gear_stats(@gear);
                        total_damage += stats.damage;
                        total_weight += stats.weight;

                        if !weapon_equipped {
                            let slot_info = EquipmentSlotInfo {
                                slot_type: 'WEAPON',
                                equipped_item: Option::Some(gear),
                                is_empty: false,
                            };
                            equipped_slots.append(slot_info);
                            equipped_gear_types.append(parse_id(gear.asset_id));
                            weapon_equipped = true;
                        }
                    }
                }
                i += 1;
            };

            // Right hand weapons
            let mut i = 0;
            while i < player.body.right_hand.len() {
                let gear_id = *player.body.right_hand.at(i);
                if gear_id != 0 {
                    let gear: Gear = world.read_model(gear_id);
                    if gear.id != 0 {
                        let stats = self._calculate_gear_stats(@gear);
                        total_damage += stats.damage;
                        total_weight += stats.weight;

                        if !weapon_equipped {
                            let slot_info = EquipmentSlotInfo {
                                slot_type: 'WEAPON',
                                equipped_item: Option::Some(gear),
                                is_empty: false,
                            };
                            equipped_slots.append(slot_info);
                            equipped_gear_types.append(parse_id(gear.asset_id));
                            weapon_equipped = true;
                        }
                    }
                }
                i += 1;
            };

            if !weapon_equipped {
                empty_slots.append('WEAPON');
            }

            // Process upper torso (chest armor)
            let mut chest_equipped = false;
            let mut i = 0;
            while i < player.body.upper_torso.len() {
                let gear_id = *player.body.upper_torso.at(i);
                if gear_id != 0 {
                    let gear: Gear = world.read_model(gear_id);
                    if gear.id != 0 {
                        let stats = self._calculate_gear_stats(@gear);
                        total_defense += stats.defense;
                        total_weight += stats.weight;

                        if !chest_equipped {
                            let slot_info = EquipmentSlotInfo {
                                slot_type: 'CHEST',
                                equipped_item: Option::Some(gear),
                                is_empty: false,
                            };
                            equipped_slots.append(slot_info);
                            equipped_gear_types.append(parse_id(gear.asset_id));
                            chest_equipped = true;
                        }
                    }
                }
                i += 1;
            };
            if !chest_equipped {
                empty_slots.append('CHEST');
            }

            // Process lower torso (leg armor)
            let mut legs_equipped = false;
            let mut i = 0;
            while i < player.body.lower_torso.len() {
                let gear_id = *player.body.lower_torso.at(i);
                if gear_id != 0 {
                    let gear: Gear = world.read_model(gear_id);
                    if gear.id != 0 {
                        let stats = self._calculate_gear_stats(@gear);
                        total_defense += stats.defense;
                        total_weight += stats.weight;

                        if !legs_equipped {
                            let slot_info = EquipmentSlotInfo {
                                slot_type: 'LEGS',
                                equipped_item: Option::Some(gear),
                                is_empty: false,
                            };
                            equipped_slots.append(slot_info);
                            equipped_gear_types.append(parse_id(gear.asset_id));
                            legs_equipped = true;
                        }
                    }
                }
                i += 1;
            };
            if !legs_equipped {
                empty_slots.append('LEGS');
            }

            // Process feet (boots)
            let mut feet_equipped = false;
            let mut i = 0;
            while i < player.body.feet.len() {
                let gear_id = *player.body.feet.at(i);
                if gear_id != 0 {
                    let gear: Gear = world.read_model(gear_id);
                    if gear.id != 0 {
                        let stats = self._calculate_gear_stats(@gear);
                        total_defense += stats.defense;
                        total_weight += stats.weight;

                        if !feet_equipped {
                            let slot_info = EquipmentSlotInfo {
                                slot_type: 'FEET',
                                equipped_item: Option::Some(gear),
                                is_empty: false,
                            };
                            equipped_slots.append(slot_info);
                            equipped_gear_types.append(parse_id(gear.asset_id));
                            feet_equipped = true;
                        }
                    }
                }
                i += 1;
            };
            if !feet_equipped {
                empty_slots.append('FEET');
            }

            // Process off-body items (pets/drones)
            let mut companion_equipped = false;
            let mut i = 0;
            while i < player.body.off_body.len() {
                let gear_id = *player.body.off_body.at(i);
                if gear_id != 0 {
                    let gear: Gear = world.read_model(gear_id);
                    if gear.id != 0 {
                        let stats = self._calculate_gear_stats(@gear);
                        // Pets/drones might provide different bonuses
                        total_damage += stats.loyalty / 10; // Convert loyalty to damage bonus

                        if !companion_equipped {
                            let slot_info = EquipmentSlotInfo {
                                slot_type: 'COMPANION',
                                equipped_item: Option::Some(gear),
                                is_empty: false,
                            };
                            equipped_slots.append(slot_info);
                            equipped_gear_types.append(parse_id(gear.asset_id));
                            companion_equipped = true;
                        }
                    }
                }
                i += 1;
            };
            if !companion_equipped {
                empty_slots.append('COMPANION');
            }

            // Calculate set bonuses
            let set_bonuses = self._calculate_set_bonuses(@equipped_gear_types);

            CombinedEquipmentEffects {
                total_damage, total_defense, total_weight, equipped_slots, empty_slots, set_bonuses,
            }
        }

        fn _calculate_set_bonuses(
            self: @ContractState, equipped_types: @Array<GearType>,
        ) -> Array<(felt252, u64)> {
            let mut bonuses: Array<(felt252, u64)> = array![];

            // Count different gear types
            let mut armor_count = 0_u32;
            let mut weapon_count = 0_u32;
            let mut companion_count = 0_u32;

            let mut i = 0;
            while i < equipped_types.len() {
                let gear_type = *equipped_types.at(i);
                match gear_type {
                    GearType::Helmet | GearType::ChestArmor | GearType::LegArmor | GearType::Boots |
                    GearType::Gloves | GearType::Shield => { armor_count += 1; },
                    GearType::Weapon | GearType::BluntWeapon | GearType::Sword | GearType::Bow |
                    GearType::Firearm | GearType::Polearm | GearType::HeavyFirearms |
                    GearType::Explosives => { weapon_count += 1; },
                    GearType::Pet | GearType::Drone => { companion_count += 1; },
                    _ => {},
                }
                i += 1;
            };

            // Armor set bonuses
            if armor_count >= 2 {
                bonuses.append(('ARMOR_PAIR', 10)); // +10% defense for 2+ armor pieces
            }
            if armor_count >= 3 {
                bonuses.append(('ARMOR_SET', 25)); // +25% defense for 3+ armor pieces
            }
            if armor_count >= 5 {
                bonuses.append(('FULL_ARMOR', 50)); // +50% defense for full armor set
            }

            // Weapon bonuses
            if weapon_count >= 2 {
                bonuses.append(('DUAL_WIELD', 20)); // +20% damage for dual wielding
            }

            // Companion bonuses
            if companion_count >= 1 {
                bonuses.append(('COMPANION', 15)); // +15% overall effectiveness
            }

            // Mixed set bonuses
            if armor_count >= 2 && weapon_count >= 1 {
                bonuses.append(('WARRIOR_SET', 30)); // +30% combat effectiveness
            }

            bonuses
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
        // let weapon_1_stats = WeaponStats {
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
        // let weapon_2_stats = WeaponStats {
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
