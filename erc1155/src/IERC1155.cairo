use core::byte_array::ByteArray;
use starknet::ContractAddress;

#[starknet::interface]
pub trait ICitizenArcanisERC1155<TContractState> {
    fn Balance_of(self: @TContractState, account: ContractAddress, id: u256) -> u256;


    fn Balance_of_batch(
        self: @TContractState, accounts: Span<ContractAddress>, ids: Span<u256>,
    ) -> Span<u256>;


    fn Is_approved_for_all(
        self: @TContractState, account: ContractAddress, operator: ContractAddress,
    ) -> bool;


    fn Set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);

    fn Safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        amount: u256,
        data: Span<felt252>,
    );

    fn Safe_batch_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        amounts: Span<u256>,
        data: Span<felt252>,
    );


    fn Batch_mint(
        ref self: TContractState,
        account: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>,
    );


    fn mint_FT(ref self: TContractState, account: ContractAddress, token_id: u256, amount: u256);


    fn mint_NFT(ref self: TContractState, account: ContractAddress, token_id: u256);

    fn Uri(self: @TContractState, token_id: u256) -> ByteArray;


    fn Set_base_uri(ref self: TContractState, new_base_uri: ByteArray);
}
