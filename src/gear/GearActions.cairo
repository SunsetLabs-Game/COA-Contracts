use starknet::{ContractAddress, get_caller_address};
use core::num::traits::Zero;
use crate::models::gear::{Gear};
use crate::models::player::{Player, Body, PlayerTrait, Errors};
use crate::models::core::Contract;
use crate::erc1155::erc1155::{IERC1155Dispatcher, IERC1155DispatcherTrait};
use crate::helpers::gear::{get_high};
use crate::helpers::body::BodyTrait;
use dojo::event::EventStorage;
use dojo::model::{ModelStorage, Model};

const VEHICLE_ID: u256 = 0x30000;

#[starknet::interface]
pub trait GearActionsTrait<T> {
    fn exchange(ref self: T, in_item_id: u256, out_item_id: u256);
}

#[dojo::contract]
pub mod GearActions {
    use super::*;

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    struct ExchangedItem {
        #[key]
        player_id: ContractAddress,
        in_item_id: u256,
        out_item_id: u256,
    }

    #[abi(embed_v0)]
    impl GearActionsImpl of GearActionsTrait<ContractState> {
        fn exchange(ref self: ContractState, in_item_id: u256, out_item_id: u256) {
            assert(in_item_id != out_item_id, Errors::IN_ITEM_SAME_AS_OUT_ITEM);
            assert(!in_item_id.is_zero(), Errors::INVALID_ITEM_ID);
            assert(!out_item_id.is_zero(), Errors::INVALID_ITEM_ID);

            // Get the game world
            let mut world = self.world_default();
            let player_id = get_caller_address();

            // Read Contract model for ERC1155 address
            let contract: Contract = world.read_model('contract_id');
            let erc1155_address = contract.erc1155;
            let warehouse_address = contract.warehouse;
            let erc1155 = IERC1155Dispatcher { contract_address: erc1155_address };

            // Read Player and Body
            let mut player: Player = world.read_model(player_id);
            let mut body: Body = world
                .read_member(Model::<Player>::ptr_from_keys(player_id), selector!("body"));

            // Read in_item_id to determine scenario
            let mut in_gear: Gear = world.read_model(in_item_id);
            let mut out_gear: Gear = world.read_model(out_item_id);
            let in_asset_id = in_gear.asset_id;
            let out_asset_id = out_gear.asset_id;

            // Confirm possession of `out_item` before proceeding
            assert(out_gear.owner == player_id, Errors::OUT_ITEM_NOT_OWNED);

            // Verify the exact out_item_id is equipped
            assert(body.is_item_equipped(out_asset_id), Errors::OUT_ITEM_NOT_EQUIPPED);

            // Simple placeholder vehicle logic check for the moment
            // let vehicle_equipped = player.is_equipped(get_high(VEHICLE_ID)) != 0_u256;
            let vehicle_equipped = !body.vehicle.is_zero();
            let is_vehicle_scenario = !in_gear.spawned && vehicle_equipped;

            if is_vehicle_scenario {
                // Scenario 2: Player ⇄ Vehicle (Swapping `in_item` for `out_item`)

                // Verify `in_item` token ownership
                let balance = erc1155.balance_of(player_id, in_asset_id);
                assert(!balance.is_zero(), Errors::ITEM_TOKEN_NOT_OWNED);
                // Optional cross-check
                assert(in_gear.owner == player_id, Errors::IN_ITEM_NOT_OWNED);

                // Verify exact in_item_id is not already equipped
                assert(!body.is_item_equipped(in_asset_id), Errors::IN_ITEM_ALREADY_EQUIPPED);

                // Unequip out_item_id
                let _ = body.unequip(out_asset_id);

                // Update equipped array
                let mut equipped = player.equipped;
                let mut new_equipped = array![];
                let mut i = 0;
                while i < equipped.len() {
                    if *equipped.at(i) != out_asset_id {
                        new_equipped.append(*equipped.at(i));
                    }
                    i += 1;
                };
                player.equipped = new_equipped;

                if body.can_equip(in_asset_id) {
                    // Success: Equip in_item_id (no NFT transfers)
                    // Implicitly targets the unequipped slot
                    body.equip_item(in_asset_id);

                    player.equipped.append(in_asset_id);
                    world.write_model(@player);
                    world
                        .write_member(
                            Model::<Player>::ptr_from_keys(player_id), selector!("body"), body,
                        );

                    let event = ExchangedItem { player_id, in_item_id, out_item_id };
                    world.emit_event(@event);
                } else {
                    // Failure: Rollback out_item_id
                    body.equip_item(out_asset_id);
                    player.equipped.append(out_asset_id);
                    world.write_model(@player);
                    world
                        .write_member(
                            Model::<Player>::ptr_from_keys(player_id), selector!("body"), body,
                        );
                }
            } else {
                // Scenario 1: Player ⇄ Environment (Transfers and Swapping logic)

                // Unequip out_item_id
                let _ = body.unequip(out_asset_id);
                let mut equipped = player.equipped;
                let mut new_equipped = array![];
                let mut i = 0;
                while i < equipped.len() {
                    if *equipped.at(i) != out_asset_id {
                        new_equipped.append(*equipped.at(i));
                    }
                    i += 1;
                };
                player.equipped = new_equipped;

                if body.can_equip(in_asset_id) {
                    // Success: Transfer NFTs and equip in_item_id
                    // Player -> Warehouse
                    erc1155
                        .safe_transfer_from(
                            player_id, warehouse_address, out_asset_id, 1, array![].span(),
                        );

                    // let mut out_gear: Gear = world.read_model(out_item_id);
                    out_gear.spawned = true;
                    out_gear.owner = warehouse_address;
                    world.write_model(@out_gear);

                    // let mut in_gear: Gear = world.read_model(in_item_id);
                    if in_gear.spawned {
                        // Warehouse -> Player
                        erc1155
                            .safe_transfer_from(
                                warehouse_address, player_id, in_asset_id, 1, array![].span(),
                            );
                        in_gear.spawned = false;
                        in_gear.owner = player_id;
                        world.write_model(@in_gear);
                    }

                    body.equip_item(in_asset_id);
                    player.equipped.append(in_asset_id);
                    world.write_model(@player);
                    world
                        .write_member(
                            Model::<Player>::ptr_from_keys(player_id), selector!("body"), body,
                        );

                    let event = ExchangedItem { player_id, in_item_id, out_item_id };
                    world.emit_event(@event);
                } else {
                    // Failure: Rollback out_item_id
                    body.equip_item(out_asset_id);
                    player.equipped.append(out_asset_id);

                    world.write_model(@player);
                    world
                        .write_member(
                            Model::<Player>::ptr_from_keys(player_id), selector!("body"), body,
                        );
                }
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"coa")
        }
    }
}

