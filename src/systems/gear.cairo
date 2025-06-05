#[dojo::contract]
pub mod GearActions {
    use dojo::model::ModelStorage;
    use dojo::world::WorldStorage;
    use starknet::{ContractAddress, get_caller_address};
    use crate::helpers::base::generate_id;
    use crate::interfaces::gear::IGear;
    use crate::models::core::{Contract, Operator};
    use crate::models::gear::{
        ArmorStats, Gear, GearProperties, GearTrait, GearType, PetStats, VehicleStats, WeaponStats,
    };

    const GEAR: felt252 = 'GEAR';

    fn dojo_init(ref self: ContractState, admin: ContractAddress) {
        let mut world = self.world_default();

        // Initialize admin for gear operations
        let operator = Operator { id: admin, is_operator: true };
        world.write_model(@operator);
    }

    #[abi(embed_v0)]
    pub impl GearActionsImpl of IGear<ContractState> {
        fn upgrade_gear(ref self: ContractState, item_id: u256) {
            let mut world = self.world_default();
            self._assert_admin();

            // Get the gear and check if it's upgradeable
            let mut gear: Gear = world.read_model(item_id);
            assert(gear.upgrade_level < gear.max_upgrade_level, 'Max upgrade level reached');

            // Upgrade the gear
            gear.upgrade_level += 1;
            world.write_model(@gear);
        }

        fn equip(ref self: ContractState, item_id: Array<u256>) {}

        fn equip_on(ref self: ContractState, item_id: u256, target: u256) {}

        // unequips an item and equips another item at that slot.
        fn exchange(ref self: ContractState, in_item_id: u256, out_item_id: u256) {}

        fn refresh(
            ref self: ContractState,
        ) { // might be moved to player. when players transfer off contract, then there's a problem
        }

        fn get_item_details(ref self: ContractState, item_id: u256) -> Gear {
            let world = self.world_default();
            world.read_model(item_id)
        }

        // Some Item Details struct.
        fn total_held_of(ref self: ContractState, gear_type: GearType) -> u256 {
            0
        }

        // use the caller and read the model of both the caller, and the target
        // the target only refers to one target type for now
        // This target type is raidable.
        fn raid(ref self: ContractState, target: u256) {}

        fn unequip(ref self: ContractState, item_id: Array<u256>) {}

        fn get_configuration(ref self: ContractState, item_id: u256) -> Option<GearProperties> {
            Option::None
        }

        // This configure should take in an enum that lists all Gear Types with their structs
        // This function would be blocked at the moment, we shall use the default configuration
        // of the gameplay and how items interact with each other.
        // e.g. guns auto-reload once the time has run out
        // and TODO: Add a delay for auto reload.
        // for a base gun, we default the auto reload to exactly 6 seconds...
        //
        fn configure(ref self: ContractState) { // params to be completed
        }

        fn auction(ref self: ContractState, item_ids: Array<u256>) {}
        fn dismantle(ref self: ContractState, item_ids: Array<u256>) {}
        fn transfer(ref self: ContractState, item_ids: Array<u256>) {}
        fn grant(ref self: ContractState, asset: GearType) {
            let mut world = self.world_default();
            self._assert_admin();

            // Create a new gear instance based on the asset type
            let new_gear_id = generate_id(GEAR, ref world);
            // Implementation would create gear based on asset type
        }

        // These functions might be reserved for players within a specific faction

        // this function forges and creates a new item id based
        fn forge(ref self: ContractState, item_ids: Array<u256>) {
            let mut world = self.world_default();
            // Create a new forged item with unique ID
            let forged_item_id = generate_id(GEAR, ref world);
            // Implementation would handle forging logic
        }

        fn awaken(ref self: ContractState, exchange: Array<u256>) {}

        fn can_be_awakened(self: @ContractState, item_ids: Array<u256>) -> Span<bool> {
            array![].span()
        }
    }

    #[generate_trait]
    pub impl GearInternalImpl of GearInternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"coa")
        }

        fn _assert_admin(self: @ContractState) {
            let world = self.world_default();
            let caller = get_caller_address();
            let operator: Operator = world.read_model(caller);
            assert(operator.is_operator, 'Caller is not admin');
        }

        fn _retrieve(
            ref self: ContractState, item_id: u256,
        ) { // this function should probably return an enum
        // or use an external function in the helper trait that returns an enum
        }
    }
}
