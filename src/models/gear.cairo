// This might be renamed to asset in the future
// For now we are sticking to gear, as some assets are not considered as gear
// These are all gears that are non-fungible

use crate::helpers::base::ContractAddressDefault;
use core::num::traits::Zero;
// use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
// use crate::erc1155::erc1155::{IERC1155MintableDispatcher, IERC1155MintableDispatcherTrait};
use starknet::ContractAddress;
// use dojo::world::WorldStorage;
use core::traits::{Into, TryInto};

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
    Drone // 0x800001
}

#[derive(Drop, Copy, Serde)]
pub struct GearDetails {
    // Type of gear (e.g., Weapon, Helmet, Vehicle)
    pub gear_type: GearType,
    // Minimum XP required to use the gear
    pub min_xp_needed: u256,
    // Base damage value for the gear (0 for non-damaging items)
    pub base_damage: u64,
    // Maximum upgrade level for the gear
    pub max_upgrade_level: u64,
    // Initial total count for fungible items (default 1 for non-fungible)
    pub total_count: u64,
    // Reference to variation (e.g., specific model like "Iron Sword")
    pub variation_ref: u256,
}

#[derive(Drop, Copy, Serde, Default)]
pub struct GearProperties {
    asset_id: u256,
    // asset: Gear,
}

// This model stores the pre-calculated stats for each level of a specific asset.
#[dojo::model]
#[derive(Drop, Copy, Default, Serde)]
pub struct GearLevelStats {
    #[key]
    pub asset_id: u256, // The specific asset, e.g., Iron Sword
    #[key]
    pub level: u64, // The level for which these stats apply
    // --- Pre-calculated Stat Fields ---
    pub damage: u64,
    pub range: u64,
    pub accuracy: u64,
    pub fire_rate: u64,
    pub defense: u64,
    pub durability: u64,
    pub weight: u64,
}

// Struct to define a material required for an upgrade
#[derive(Drop, Copy, Serde, Introspect)]
pub struct UpgradeMaterial {
    pub token_id: u256,
    pub amount: u256,
}

// Model to store upgrade costs for each gear type and level
#[dojo::model]
#[derive(Drop, Clone, Serde)]
pub struct UpgradeCost {
    #[key]
    pub gear_type: GearType,
    #[key]
    pub level: u64,
    pub materials: Array<UpgradeMaterial>,
}

// Model to store success rates for each gear type and level
#[dojo::model]
#[derive(Drop, Clone, Serde)]
pub struct UpgradeSuccessRate {
    #[key]
    pub gear_type: GearType,
    #[key]
    pub level: u64,
    pub rate: u8,
}

// Model to track the state of the upgrade data initialization process.
#[dojo::model]
#[derive(Drop, Clone, Serde, Default)]
pub struct UpgradeConfigState {
    #[key]
    pub singleton_key: u8, // Always 0, to ensure only one instance exists.
    pub initialized_types_count: u32,
    pub is_complete: bool,
}

#[dojo::model]
#[derive(Drop, Copy, Serde, Default)]
pub struct GearCounter {
    #[key]
    pub id: u128,
    pub counter: u128,
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
}

// Implementation of GearDetails with validation and default behavior
#[generate_trait]
pub impl GearDetailsImpl of GearDetailsTrait {
    // Creates a new GearDetails instance with validation
    fn new(
        gear_type: GearType,
        min_xp_needed: u256,
        base_damage: u64,
        max_upgrade_level: u64,
        total_count: u64,
        variation_ref: u256,
    ) -> GearDetails {
        // Validate inputs
        assert(gear_type != GearType::None, 'Gear type cannot be None');
        assert(min_xp_needed >= 0, 'Min XP cannot be negative');
        assert(base_damage <= 1000, 'Base damage exceeds max (1000)');
        assert(max_upgrade_level > 0, 'Max upgrade level must be > 0');
        assert(total_count > 0, 'Total count must be > 0');

        GearDetails {
            gear_type, min_xp_needed, base_damage, max_upgrade_level, total_count, variation_ref,
        }
    }

    // Validates the GearDetails instance
    fn validate(self: @GearDetails) -> bool {
        *self.gear_type != GearType::None
            && *self.min_xp_needed >= 0
            && *self.base_damage <= 1000
            && *self.max_upgrade_level > 0
            && *self.total_count > 0
    }

    // Creates a default GearDetails for testing or fallback
    fn default() -> GearDetails {
        GearDetails {
            gear_type: GearType::Weapon,
            min_xp_needed: 5,
            base_damage: 10,
            max_upgrade_level: 1,
            total_count: 1,
            variation_ref: 0,
        }
    }
}

// Implementation of conversion from GearType to felt252
impl GearTypeIntoFelt252 of Into<GearType, felt252> {
    fn into(self: GearType) -> felt252 {
        match self {
            GearType::None => 0x0,
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
        }
    }
}

impl GearTypeIntoU256 of Into<GearType, u256> {
    fn into(self: GearType) -> u256 {
        match self {
            GearType::None => u256 { low: 0, high: 0 },
            GearType::Weapon => u256 { low: 0, high: 0x1 },
            GearType::BluntWeapon => u256 { low: 0, high: 0x101 },
            GearType::Sword => u256 { low: 0, high: 0x102 },
            GearType::Bow => u256 { low: 0, high: 0x103 },
            GearType::Firearm => u256 { low: 0, high: 0x104 },
            GearType::Polearm => u256 { low: 0, high: 0x105 },
            GearType::HeavyFirearms => u256 { low: 0, high: 0x106 },
            GearType::Explosives => u256 { low: 0, high: 0x107 },
            GearType::Helmet => u256 { low: 0, high: 0x2000 },
            GearType::ChestArmor => u256 { low: 0, high: 0x2001 },
            GearType::LegArmor => u256 { low: 0, high: 0x2002 },
            GearType::Boots => u256 { low: 0, high: 0x2003 },
            GearType::Gloves => u256 { low: 0, high: 0x2004 },
            GearType::Shield => u256 { low: 0, high: 0x2005 },
            GearType::Vehicle => u256 { low: 0, high: 0x30000 },
            GearType::Pet => u256 { low: 0, high: 0x800000 },
            GearType::Drone => u256 { low: 0, high: 0x800001 },
        }
    }
}


// Implementation of conversion from felt252 to GearType
impl Felt252TryIntoGearType of TryInto<felt252, GearType> {
    fn try_into(self: felt252) -> Option<GearType> {
        if self == 0x1 {
            Option::Some(GearType::Weapon)
        } else if self == 0x101 {
            Option::Some(GearType::BluntWeapon)
        } else if self == 0x102 {
            Option::Some(GearType::Sword)
        } else if self == 0x103 {
            Option::Some(GearType::Bow)
        } else if self == 0x104 {
            Option::Some(GearType::Firearm)
        } else if self == 0x105 {
            Option::Some(GearType::Polearm)
        } else if self == 0x106 {
            Option::Some(GearType::HeavyFirearms)
        } else if self == 0x107 {
            Option::Some(GearType::Explosives)
        } else if self == 0x2000 {
            Option::Some(GearType::Helmet)
        } else if self == 0x2001 {
            Option::Some(GearType::ChestArmor)
        } else if self == 0x2002 {
            Option::Some(GearType::LegArmor)
        } else if self == 0x2003 {
            Option::Some(GearType::Boots)
        } else if self == 0x2004 {
            Option::Some(GearType::Gloves)
        } else if self == 0x2005 {
            Option::Some(GearType::Shield)
        } else if self == 0x30000 {
            Option::Some(GearType::Vehicle)
        } else if self == 0x800000 {
            Option::Some(GearType::Pet)
        } else if self == 0x800001 {
            Option::Some(GearType::Drone)
        } else {
            // If self is 0x0 or any other invalid code, return None.
            // Explicitly checking for 0x0 handles the default case.
            if self == 0x0 {
                Option::Some(GearType::None)
            } else {
                Option::None
            }
        }
    }
}

// Comprehensive gear details structure
#[derive(Drop, Clone, Serde)]
pub struct GearDetailsComplete {
    pub gear: Gear,
    pub calculated_stats: GearStatsCalculated,
    pub upgrade_info: Option<UpgradeInfo>,
    pub ownership_status: OwnershipStatus,
}

// Calculated stats based on current upgrade level
#[derive(Drop, Clone, Serde)]
pub struct GearStatsCalculated {
    pub damage: u64,
    pub range: u64,
    pub accuracy: u64,
    pub fire_rate: u64,
    pub defense: u64,
    pub durability: u64,
    pub weight: u64,
    pub speed: u64,
    pub armor: u64,
    pub fuel_capacity: u64,
    pub loyalty: u64,
    pub intelligence: u64,
    pub agility: u64,
}

// Upgrade information
#[derive(Drop, Clone, Serde)]
pub struct UpgradeInfo {
    pub current_level: u64,
    pub max_level: u64,
    pub can_upgrade: bool,
    pub next_level_cost: Option<UpgradeCost>,
    pub success_rate: Option<u8>,
    pub next_level_stats: Option<GearStatsCalculated>,
    pub total_upgrade_cost: Option<Array<(u256, u256)>> // (token_id, total_amount)
}

// Ownership and availability status
#[derive(Drop, Copy, Serde)]
pub struct OwnershipStatus {
    pub is_owned: bool,
    pub owner: ContractAddress,
    pub is_spawned: bool,
    pub is_available_for_pickup: bool,
    pub is_equipped: bool,
    pub meets_xp_requirement: bool,
}

// Filtering parameters
#[derive(Drop, Serde)]
pub struct GearFilters {
    pub gear_types: Option<Array<GearType>>,
    pub min_level: Option<u64>,
    pub max_level: Option<u64>,
    pub ownership_filter: Option<OwnershipFilter>,
    pub min_xp_required: Option<u256>,
    pub max_xp_required: Option<u256>,
    pub spawned_only: Option<bool>,
}

// Ownership filtering options
#[derive(Drop, Serde, PartialEq)]
pub enum OwnershipFilter {
    Owned,
    NotOwned,
    Available,
    Equipped,
    All,
}

// Pagination parameters
#[derive(Drop, Serde)]
pub struct PaginationParams {
    pub offset: u32,
    pub limit: u32,
}

// Sort parameters
#[derive(Drop, Copy, Serde)]
pub struct SortParams {
    pub sort_by: SortField,
    pub ascending: bool,
}

#[derive(Drop, Copy, Serde, PartialEq)]
pub enum SortField {
    Level,
    Damage,
    Defense,
    XpRequired,
    AssetId,
}

// Paginated result structure
#[derive(Drop, Clone, Serde)]
pub struct PaginatedGearResult {
    pub items: Array<GearDetailsComplete>,
    pub total_count: u32,
    pub has_more: bool,
}

// Equipment slot information
#[derive(Drop, Copy, Serde)]
pub struct EquipmentSlotInfo {
    pub slot_type: felt252,
    pub equipped_item: Option<Gear>,
    pub is_empty: bool,
}

// Combined equipment effects
#[derive(Drop, Clone, Serde)]
pub struct CombinedEquipmentEffects {
    pub total_damage: u64,
    pub total_defense: u64,
    pub total_weight: u64,
    pub equipped_slots: Array<EquipmentSlotInfo>,
    pub empty_slots: Array<felt252>,
    pub set_bonuses: Array<(felt252, u64)> // (bonus_type, bonus_value)
}

#[derive(Drop, Copy, Serde, PartialEq)]
pub enum ItemRarity {
    Common, // 70% drop rate
    Uncommon, // 20% drop rate
    Rare, // 7% drop rate
    Epic, // 2.5% drop rate
    Legendary // 0.5% drop rate
}

#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct MarketConditions {
    #[key]
    pub id: u8, // Always 0 for singleton
    pub cost_multiplier: u256,
}

#[dojo::model]
#[derive(Drop, Copy, Serde)]
pub struct MarketActivity {
    #[key]
    pub id: u8, // Always 0 for singleton
    pub activity_count: u256, // Number of upgrade attempts
    pub last_reset_timestamp: u64,
}

// Important Clone impl
impl OptionUpgradeCostImpl of Clone<Option<UpgradeCost>> {
    fn clone(self: @Option<UpgradeCost>) -> Option<UpgradeCost> {
        match self {
            Option::Some(cost) => Option::Some(cost.clone()),
            Option::None => Option::None,
        }
    }
}

impl OptionUpgradeInfoImpl of Clone<Option<UpgradeInfo>> {
    fn clone(self: @Option<UpgradeInfo>) -> Option<UpgradeInfo> {
        match self {
            Option::Some(info) => Option::Some(info.clone()),
            Option::None => Option::None,
        }
    }
}

impl OptionGearStatsCalculatedImpl of Clone<Option<GearStatsCalculated>> {
    fn clone(self: @Option<GearStatsCalculated>) -> Option<GearStatsCalculated> {
        match self {
            Option::Some(geat_stats) => Option::Some(geat_stats.clone()),
            Option::None => Option::None,
        }
    }
}

impl OptionArrayTupleImpl of Clone<Option<Array<(u256, u256)>>> {
    fn clone(self: @Option<Array<(u256, u256)>>) -> Option<Array<(u256, u256)>> {
        match self {
            Option::Some(arr) => Option::Some(arr.clone()),
            Option::None => Option::None,
        }
    }
}

// Tests for GearDetails struct
#[cfg(test)]
mod tests {
    use super::{GearDetailsImpl, GearType};

    #[test]
    fn test_valid_gear_details() {
        let gear = GearDetailsImpl::new(GearType::Sword, 30, 50, 10, 1, 1);
        assert!(gear.validate(), "Valid gear should pass validation");
        assert(gear.gear_type == GearType::Sword, 'Gear type mismatch');
        assert(gear.min_xp_needed == 30, 'Min XP mismatch');
        assert(gear.base_damage == 50, 'Base damage mismatch');
        assert(gear.max_upgrade_level == 10, 'Max upgrade level mismatch');
        assert(gear.total_count == 1, 'Total count mismatch');
        assert(gear.variation_ref == 1, 'Variation ref mismatch');
    }

    #[test]
    #[should_panic(expected: ('Gear type cannot be None',))]
    fn test_invalid_gear_type() {
        GearDetailsImpl::new(GearType::None, 5, 10, 1, 1, 0);
    }

    #[test]
    #[should_panic(expected: ('Base damage exceeds max (1000)',))]
    fn test_invalid_base_damage() {
        GearDetailsImpl::new(GearType::Weapon, 5, 1001, 1, 1, 0);
    }

    #[test]
    #[should_panic(expected: ('Max upgrade level must be > 0',))]
    fn test_invalid_max_upgrade_level() {
        GearDetailsImpl::new(GearType::Weapon, 5, 10, 0, 1, 0);
    }

    #[test]
    #[should_panic(expected: ('Total count must be > 0',))]
    fn test_invalid_total_count() {
        GearDetailsImpl::new(GearType::Weapon, 5, 10, 1, 0, 0);
    }

    #[test]
    fn test_default_gear_details() {
        let gear = GearDetailsImpl::default();
        assert(gear.validate(), 'Default gear should be valid');
        assert(gear.gear_type == GearType::Weapon, 'Default gear type mismatch');
        assert(gear.min_xp_needed == 5, 'Default min XP mismatch');
        assert(gear.base_damage == 10, 'Default base damage mismatch');
        assert!(gear.max_upgrade_level == 1, "Default max upgrade level mismatch");
        assert(gear.total_count == 1, 'Default total count mismatch');
        assert(gear.variation_ref == 0, 'Default variation ref mismatch');
    }
}
