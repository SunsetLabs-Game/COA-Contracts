use starknet::ContractAddress;
use crate::helpers::base::ContractAddressDefault;

#[dojo::model]
#[derive(Drop, Copy, Serde, Default)]
pub struct Operator {
    #[key]
    pub id: ContractAddress,
    pub is_operator: bool,
}

#[dojo::model]
#[derive(Drop, Copy, Serde, Default)]
pub struct Contract {
    #[key]
    pub id: felt252,
    pub admin: ContractAddress,
    pub erc1155: ContractAddress,
    pub payment_token: ContractAddress,
    pub escrow_address: ContractAddress,
    pub warehouse: ContractAddress,
    pub registration_fee: u256,
    pub paused: bool,
}
