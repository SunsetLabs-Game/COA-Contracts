#[starknet::contract]
mod CitizenArcanisERC1155 {
    use core::num::traits::Zero;
    use erc1155::utils::{is_FT, is_nft};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::interface::IOwnable;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::ERC1155Component::InternalTrait;
    use openzeppelin::token::erc1155::interface::ERC1155ABI;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};


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
        base_uri: ByteArray,
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
        NFTMinted: NFTMinted,
        FTMinted: FTMinted,
    }

    #[derive(Drop, starknet::Event)]
    struct NFTMinted {
        minter: ContractAddress,
        recipient: ContractAddress,
        token_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct FTMinted {
        minter: ContractAddress,
        recipient: ContractAddress,
        token_id: u256,
        amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, base_uri_: ByteArray) {
        assert(!owner.is_zero(), 'Owner_zero_address');
        self.erc1155.initializer(base_uri_);
        self.ownable.initializer(owner);
    }


    #[abi(embed_v0)]
    impl CitizenArcanisERC1155Impl of erc1155::IERC1155::ICitizenArcanisERC1155<ContractState> {
        fn Balance_of(self: @ContractState, account: ContractAddress, id: u256) -> u256 {
            self.erc1155.balance_of(account, id)
        }

        fn Balance_of_batch(
            self: @ContractState, accounts: Span<ContractAddress>, ids: Span<u256>,
        ) -> Span<u256> {
            self.erc1155.balance_of_batch(accounts, ids)
        }

        fn Is_approved_for_all(
            self: @ContractState, account: ContractAddress, operator: ContractAddress,
        ) -> bool {
            self.erc1155.is_approved_for_all(account, operator)
        }

        fn Set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool,
        ) {
            self.erc1155.set_approval_for_all(operator, approved);
        }

        fn Safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            id: u256,
            amount: u256,
            data: Span<felt252>,
        ) {
            self.erc1155.safe_transfer_from(from, to, id, amount, data);
        }

        fn Safe_batch_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            ids: Span<u256>,
            amounts: Span<u256>,
            data: Span<felt252>,
        ) {
            self.erc1155.safe_batch_transfer_from(from, to, ids, amounts, data);
        }


        /// @notice mints multiple token types FT and NFT in a single transaction.
        /// @dev Only callable by the contract owner.
        fn Batch_mint(
            ref self: ContractState,
            account: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>,
            data: Span<felt252>,
        ) {
            self.ownable.assert_only_owner();
            assert(!account.is_zero(), 'account_zero_address');
            assert(token_ids.len() == values.len(), 'length_mismatch');

            self.erc1155.batch_mint_with_acceptance_check(account, token_ids, values, data);

            let mut i = 0;
            loop {
                if i == token_ids.len() {
                    break;
                }
                let id = *token_ids.at(i);
                let value = *values.at(i);
                if is_nft(id) {
                    self
                        .emit(
                            NFTMinted {
                                minter: get_caller_address(), recipient: account, token_id: id,
                            },
                        );
                } else if is_FT(id) {
                    self
                        .emit(
                            FTMinted {
                                minter: get_caller_address(),
                                recipient: account,
                                token_id: id,
                                amount: value,
                            },
                        );
                }
                i += 1;
            };
        }


        fn mint_FT(
            ref self: ContractState, account: ContractAddress, token_id: u256, amount: u256,
        ) {
            self.ownable.assert_only_owner();
            assert(amount > 0, 'amount_must_>0');
            assert(is_FT(token_id), 'token_id_formate_of_NFT');

            let ids = array![token_id].span();
            let values = array![amount].span();
            let data = array![].span();

            self.erc1155.batch_mint_with_acceptance_check(account, ids, values, data);
            self
                .emit(
                    FTMinted { minter: self.ownable.owner(), recipient: account, token_id, amount },
                );
        }


        fn mint_NFT(ref self: ContractState, account: ContractAddress, token_id: u256) {
            self.ownable.assert_only_owner();
            assert(is_nft(token_id), 'Not_valid_NFT_id');
            assert(!account.is_zero(), 'account_zero_address');
            assert(
                self.erc1155.balance_of(account, token_id) == 0, 'account_already_owns_this_NFT',
            );

            let ids = array![token_id].span();
            let values = array![1_u256].span();
            let data = array![].span();

            self.erc1155.batch_mint_with_acceptance_check(account, ids, values, data);
            self.emit(NFTMinted { minter: self.ownable.owner(), recipient: account, token_id });
        }

        fn Uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.base_uri.read()
        }

        fn Set_base_uri(ref self: ContractState, new_base_uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.base_uri.write(new_base_uri);
        }
    }
}
