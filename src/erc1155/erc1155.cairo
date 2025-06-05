use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC1155Mintable<TContractState> {
    fn mint(
        ref self: TContractState,
        to: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>,
    );
    fn batch_mint(
        ref self: TContractState,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>,
    );
    fn burn(ref self: TContractState, from: ContractAddress, token_id: u256, value: u256);
    fn batch_burn(
        ref self: TContractState, from: ContractAddress, token_ids: Span<u256>, values: Span<u256>,
    );
}

#[starknet::contract]
pub mod IERC1155 {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl ERC1155MixinImpl = ERC1155Component::ERC1155MixinImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC1155HooksImpl = ERC1155HooksEmptyImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, token_uri: ByteArray, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.erc1155.initializer(token_uri);
    }

    #[abi(embed_v0)]
    pub impl ERC1155MintableImpl of super::IERC1155Mintable<ContractState> {
        fn mint(
            ref self: ContractState,
            to: ContractAddress,
            token_id: u256,
            value: u256,
            data: Span<felt252>,
        ) {
            self.ownable.assert_only_owner();
            self.erc1155.mint_with_acceptance_check(to, token_id, value, data);
        }
        fn batch_mint(
            ref self: ContractState,
            to: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>,
        ) {
            self.ownable.assert_only_owner();
            self.erc1155.batch_mint_with_acceptance_check(to, token_ids, values, data);
        }
        fn burn(ref self: ContractState, from: ContractAddress, token_id: u256, value: u256) {
            self.ownable.assert_only_owner();
            self.erc1155.burn(from, token_id, value);
        }
        fn batch_burn(
            ref self: ContractState,
            from: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
        ) {
            self.ownable.assert_only_owner();
            self.erc1155.batch_burn(from, token_ids, values);
        }
    }
}

