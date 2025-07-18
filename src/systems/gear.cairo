#[dojo::contract]
pub mod GearActions {
    use crate::interfaces::gear::IGear;
    use starknet::{ContractAddress, get_caller_address};
    use dojo::world::WorldStorage;
    use crate::models::gear::{Gear, GearTrait, GearProperties, GearType};
    use crate::helpers::base::generate_id;
    use crate::store::StoreTrait;

    fn dojo_init(ref self: ContractState, admin: ContractAddress) {
        let mut world = self.world(@"combat_game");
        let mut store = StoreTrait::new(world);
        store.init_gear();
    }

    #[abi(embed_v0)]
    pub impl GearActionsImpl of IGear<ContractState> {
        fn upgrade_gear(
            ref self: ContractState, item_id: u256,
        ) { // check if the available upgrade materials `id` is present in the caller's address
        // TODO: Security
        // for now, you must check if if the item_id with id is available in the game.
        // This would be done accordingly, so the item struct must have the id of the material
        // or the ids of the list of materials that can upgrade it, and the quantity needed per
        // level and the max level attained.
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
            // might not return a gear
            Default::default()
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
        fn grant(ref self: ContractState, asset: GearType) {}

        // These functions might be reserved for players within a specific faction

        // this function forges and creates a new item id based
        fn forge(
            ref self: ContractState, item_ids: Array<u256>,
        ) { // should create a new asset. Perhaps deduct credits from the player.
        // 0
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

        fn _assert_admin(self: @ContractState) { // assert the admin here.
        }

        fn _retrieve(
            ref self: ContractState, item_id: u256,
        ) { // this function should probably return an enum
        // or use an external function in the helper trait that returns an enum
        }
    }
}
