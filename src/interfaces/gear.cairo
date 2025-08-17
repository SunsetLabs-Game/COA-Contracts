use crate::models::gear::{
    Gear, GearType, GearProperties, GearDetailsComplete, GearStatsCalculated, UpgradeInfo,
    GearFilters, PaginationParams, SortParams, PaginatedGearResult, CombinedEquipmentEffects,
};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IGear<TContractState> {
    fn initialize_upgrade_data(ref self: TContractState);
    fn upgrade_gear(
        ref self: TContractState,
        item_id: u256,
        session_id: felt252,
        materials_erc1155_address: ContractAddress,
    );
    fn equip(ref self: TContractState, item_id: Array<u256>, session_id: felt252);
    // unequips an item and equips another item at that slot.
    fn exchange(ref self: TContractState, in_item_id: u256, out_item_id: u256, session_id: felt252);
    // to equip an object on another object, if necessary
    // blocked for now.
    fn equip_on(ref self: TContractState, item_id: u256, target: u256, session_id: felt252);
    fn refresh(
        ref self: TContractState, session_id: felt252,
    ); // might be moved to player. when players transfer off contract, then there's a problem
    fn get_item_details(
        ref self: TContractState, item_id: u256, session_id: felt252,
    ) -> Gear; // Some Item Details struct.
    fn total_held_of(ref self: TContractState, gear_type: GearType, session_id: felt252) -> u256;
    // use the caller and read the model of both the caller, and the target
    // the target only refers to one target type for now
    // This target type is raidable.
    fn raid(ref self: TContractState, target: u256, session_id: felt252);
    fn unequip(ref self: TContractState, item_id: Array<u256>, session_id: felt252);
    fn get_configuration(
        ref self: TContractState, item_id: u256, session_id: felt252,
    ) -> Option<GearProperties>;
    // This configure should take in an enum that lists all Gear Types with their structs
    // This function would be blocked at the moment, we shall use the default configuration
    // of the gameplay and how items interact with each other.
    // e.g. guns auto-reload once the time has run out
    // and TODO: Add a delay for auto reload.
    // for a base gun, we default the auto reload to exactly 6 seconds...
    //
    fn configure(ref self: TContractState, session_id: felt252);
    fn auction(ref self: TContractState, item_ids: Array<u256>, session_id: felt252);
    fn dismantle(ref self: TContractState, item_ids: Array<u256>, session_id: felt252);
    fn transfer(ref self: TContractState, item_ids: Array<u256>, session_id: felt252);
    // This is an admin function, might take in more params to grant a specific player a gear.
    fn grant(ref self: TContractState, asset: GearType);

    // These functions might be reserved for players within a specific faction

    // this function forges and creates a new item id based
    fn forge(ref self: TContractState, item_ids: Array<u256>, session_id: felt252) -> u256;
    fn awaken(ref self: TContractState, exchange: Array<u256>, session_id: felt252);
    fn can_be_awakened(
        ref self: TContractState, item_ids: Array<u256>, session_id: felt252,
    ) -> Span<bool>;
    fn pick_items(
        ref self: TContractState, item_id: Array<u256>, session_id: felt252,
    ) -> Array<u256>; // returns an array of items that were picked

    // adds an item to the list of items

    fn use_item(
        ref self: TContractState, item_id: u256, target_id: Option<u256>, session_id: felt252,
    );
    fn wield_item(ref self: TContractState, item_id: u256, session_id: felt252);


}
/// TODO: Implement gear levels: Rare, Mythical, etc... these levels would determine its base stats
/// and the max upgradeable stats.


