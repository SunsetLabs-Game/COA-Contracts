use core::box::BoxTrait;
use core::hash::HashStateTrait;
use core::poseidon::{PoseidonTrait, HashState};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait,};
use starknet::{ContractAddress, get_contract_address, get_caller_address, get_tx_info};


fn uuid(world: IWorldDispatcher) -> u128 {
    IWorldDispatcherTrait::uuid(world).into()
}

fn seed(salt: ContractAddress) -> felt252 {
    pedersen::pedersen(starknet::get_tx_info().unbox().transaction_hash, salt.into())
}

#[derive(Copy, Drop, Serde)]
struct Random {
    seed: felt252,
    nonce: usize,
}

#[generate_trait]
impl RandomImpl of RandomTrait {
    // one instance by contract, then passed by ref to sub fns
    fn new() -> Random {
        Random { seed: seed(get_contract_address()), nonce: 0 }
    }

    fn next_seed(ref self: Random) -> felt252 {
        self.nonce += 1;
        self.seed = pedersen::pedersen(self.seed, self.nonce.into());
        self.seed
    }

    fn next<T, +Into<T, u256>, +Into<u8, T>, +TryInto<u256, T>, +BitNot<T>>(ref self: Random) -> T {
        let seed: u256 = self.next_seed().into();
        let mask: T = BitNot::bitnot(0_u8.into());
        (mask.into() & seed).try_into().unwrap()
    }

    fn next_capped<T, +Into<T, u256>, +TryInto<u256, T>, +Drop<T>>(ref self: Random, cap: T) -> T {
        let seed: u256 = self.next_seed().into();
        (seed % cap.into()).try_into().unwrap()
    }
}


fn get_uuid(self: IWorldDispatcher) -> u128 {
    let hash_felt = PoseidonTrait::new()
        .update(get_tx_info().unbox().transaction_hash)
        .update(self.uuid().into())
        .finalize();
    (hash_felt.into() & 0xffffffffffffffffffffffffffffffff_u256).try_into().unwrap()
}
