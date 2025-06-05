#[cfg(test)]
mod TestConsumableSystem {
    use dojo::test_utils::deploy_contract;
    use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use starknet::testing::{set_caller_address, set_contract_address};
    use starknet::{ContractAddress, contract_address_const};
    use super::ConsumableSystem;
    use super::ConsumableSystem::ConsumableUsed;

    fn setup() -> (ConsumableSystem::ContractState, IERC1155Dispatcher, ContractAddress) {
        let player = contract_address_const::<0x123>();
        // Deploy mock ERC1155 (replace with actual ERC1155 if available)
        let erc1155_address = deploy_mock_erc1155();
        let consumable_system = deploy_contract(
            :ConsumableSystem, array![erc1155_address.into()].span(),
        );
        set_contract_address(player);
        set_caller_address(player);
        // Mint tokens
        let erc1155 = IERC1155Dispatcher { contract_address: erc1155_address };
        // Assume mint function exists; adjust based on actual ERC1155
        // erc1155.mint(player, 1, 100, array![].span());
        consumable_system.update_inventory(player, 1, 100);
        (consumable_system, erc1155, player)
    }

    fn deploy_mock_erc1155() -> ContractAddress {
        // Simplified mock; replace with actual ERC1155 deployment
        contract_address_const::<0x456>()
    }

    #[test]
    fn test_use_consumable_success() {
        let (mut consumable_system, erc1155, player) = setup();
        consumable_system.use_consumable(player, 1, 50);
        // Adjust assertions based on actual ERC1155 implementation
        // assert_eq!(erc1155.balance_of(player, 1), 50);
        assert_eq!(consumable_system.local_inventory.read((player, 1)), 50);
    }

    #[test]
    #[should_panic(expected: ('Insufficient token balance',))]
    fn test_use_consumable_insufficient_balance() {
        let (mut consumable_system, _, player) = setup();
        consumable_system.use_consumable(player, 1, 150);
    }

    #[test]
    #[should_panic(expected: ('Only player can use consumables',))]
    fn test_use_consumable_non_player() {
        let (mut consumable_system, _, player) = setup();
        set_caller_address(contract_address_const::<0x789>());
        consumable_system.use_consumable(player, 1, 50);
    }
}
