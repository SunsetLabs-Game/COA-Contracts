use erc1155::IERC1155::{
    ICitizenArcanisERC1155Dispatcher as IERC1155Dispatcher, ICitizenArcanisERC1155DispatcherTrait,
};
use erc1155::utils::{CHEST_ARMOR, CREDITS, HANDGUN_AMMO, PET_1, WEAPON_1};
use openzeppelin::utils::serde::SerializedAppend;
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::ContractAddress;

fn owner() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn zero() -> ContractAddress {
    0.try_into().unwrap()
}

fn account1() -> ContractAddress {
    reciver_deploy()
}

fn account2() -> ContractAddress {
    'thurston'.try_into().unwrap()
}

fn account3() -> ContractAddress {
    'lee'.try_into().unwrap()
}

fn deploy() -> ContractAddress {
    let owner = owner();
    let base_uri: ByteArray = "ipfs://initial/";
    let contract = declare("CitizenArcanisERC1155").unwrap().contract_class();

    let mut calldata = array![];
    calldata.append_serde(owner);
    calldata.append_serde(base_uri);

    let (contract_address, _) = contract.deploy(@calldata).expect('Contract deployment failed');

    contract_address
}
fn reciver_deploy() -> ContractAddress {
    let contract = declare("MyTokenReceiver").unwrap().contract_class();
    let mut calldata = array![];

    let (contract_address, _) = contract.deploy(@calldata).expect('Contract deployment failed');

    contract_address
}

#[test]
fn test_mint_nft_success() {
    let reciver_address = reciver_deploy();
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));

    erc1155_dispatcher.mint_NFT(reciver_address, WEAPON_1);

    assert(erc1155_dispatcher.Balance_of(reciver_address, WEAPON_1) == 1, 'NFT_balance_mismatch');
    assert(erc1155_dispatcher.Balance_of(owner(), WEAPON_1) == 0, 'Owner_NFT_balance_nonzero');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_nft_fail_not_owner() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let recipient = account1();

    // Set caller to non-owner
    cheat_caller_address(contract_address, account2(), CheatSpan::TargetCalls(1));

    erc1155_dispatcher.mint_NFT(recipient, WEAPON_1);
}

#[test]
#[should_panic(expected: ('Not_valid_NFT_id',))]
fn test_mint_nft_fail_ft_id() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let recipient = account1();

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));

    erc1155_dispatcher.mint_NFT(recipient, CREDITS);
}

#[test]
#[should_panic(expected: ('account_zero_address',))]
fn test_mint_nft_fail_zero_recipient() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));

    erc1155_dispatcher.mint_NFT(zero(), WEAPON_1);
}

#[test]
#[should_panic(expected: ('account_already_owns_this_NFT',))]
fn test_mint_nft_fail_already_owned() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let recipient = account1();

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(2));

    erc1155_dispatcher.mint_NFT(recipient, WEAPON_1);
    erc1155_dispatcher.mint_NFT(recipient, WEAPON_1);
}

#[test]
fn test_mint_ft_success() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let recipient = account1();

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));

    erc1155_dispatcher.mint_FT(recipient, CREDITS, 100);

    assert(erc1155_dispatcher.Balance_of(recipient, CREDITS) == 100, 'FT balance mismatch');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_mint_ft_fail_not_owner() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };

    cheat_caller_address(contract_address, account2(), CheatSpan::TargetCalls(1));

    erc1155_dispatcher.mint_FT(account1(), CREDITS, 100);
}

#[test]
#[should_panic(expected: ('token_id_formate_of_NFT',))]
fn test_mint_ft_fail_nft_id() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));

    erc1155_dispatcher.mint_FT(account1(), WEAPON_1, 100);
}

#[test]
#[should_panic(expected: ('amount_must_>0',))]
fn test_mint_ft_fail_zero_amount() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));

    erc1155_dispatcher.mint_FT(account1(), CREDITS, 0);
}

#[test]
fn test_batch_mint_success() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let recipient = account1();

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));

    let ids = array![CREDITS, CHEST_ARMOR, HANDGUN_AMMO, PET_1].span();
    let values = array![100, 1, 100, 1].span();
    let data = array![].span();

    erc1155_dispatcher.Batch_mint(recipient, ids, values, data);

    assert(erc1155_dispatcher.Balance_of(recipient, *ids[0]) == 100, 'mint FT1 balance_100');
    assert(erc1155_dispatcher.Balance_of(recipient, *ids[1]) == 1, 'mint NFT1 balance_1');
    assert(erc1155_dispatcher.Balance_of(recipient, *ids[2]) == 100, 'Batch mint FT2 balance_100');
    assert(erc1155_dispatcher.Balance_of(recipient, *ids[3]) == 1, 'Batch mint NFT2 balance_1');
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_batch_mint_fail_not_owner() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let recipient = account1();

    cheat_caller_address(contract_address, account2(), CheatSpan::TargetCalls(1));

    let ids = array![CREDITS, CHEST_ARMOR, HANDGUN_AMMO, PET_1].span();
    let values = array![100, 1, 100, 1].span();
    let data = array![].span();

    erc1155_dispatcher.Batch_mint(recipient, ids, values, data);
}

#[test]
#[should_panic(expected: ('length_mismatch',))]
fn test_batch_mint_fail_length_mismatch() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let recipient = account1();

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));

    let ids = array![CREDITS, CHEST_ARMOR, HANDGUN_AMMO, PET_1].span();
    let values = array![100, 1, 100, 1, 100].span();
    let data = array![].span();

    erc1155_dispatcher.Batch_mint(recipient, ids, values, data);
}

#[test]
#[should_panic(expected: ('account_zero_address',))]
fn test_batch_mint_fail_zero_recipient() {
    let contract_address = deploy();
    let erc1155_dispatcher = IERC1155Dispatcher { contract_address };
    let recipient = zero();

    cheat_caller_address(contract_address, owner(), CheatSpan::TargetCalls(1));

    let ids = array![CREDITS, CHEST_ARMOR, HANDGUN_AMMO, PET_1].span();
    let values = array![100, 1, 100, 1].span();
    let data = array![].span();

    erc1155_dispatcher.Batch_mint(recipient, ids, values, data);
}

