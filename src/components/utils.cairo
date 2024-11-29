//********************************************************************
//                          IMPORTS                                 ||
//********************************************************************
use core::box::BoxTrait;
use core::hash::HashStateTrait;
use core::poseidon::{PoseidonTrait, HashState};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait,};
use starknet::{ContractAddress, get_contract_address, get_caller_address, get_tx_info};

//********************************************************************
//                         RANDOM NUMBER GENERATION                 ||
//********************************************************************

// Generates a unique UUID for the world dispatcher by fetching the world UUID.
fn uuid(world: IWorldDispatcher) -> u128 {
    IWorldDispatcherTrait::uuid(world).into()
}

// Generates a seed using the Pedersen hash with the contract address and transaction hash.
fn seed(salt: ContractAddress) -> felt252 {
    pedersen::pedersen(starknet::get_tx_info().unbox().transaction_hash, salt.into())
}

//********************************************************************
//                         RANDOM STRUCTURE                         ||
//********************************************************************

// `Random` struct holds `seed` and `nonce` for generating random values.
#[derive(Copy, Drop, Serde)]
struct Random {
    seed: felt252,
    nonce: usize,
}

//********************************************************************
//                   RANDOM TRAIT IMPLEMENTATION                    ||
//********************************************************************

// `RandomImpl` provides methods to generate random values using the `Random` struct.
#[generate_trait]
impl RandomImpl of RandomTrait {
    // one instance by contract, then passed by ref to sub fns
    //Initializes `Random` struct with a new seed and nonce.
    fn new() -> Random {
        Random { seed: seed(get_contract_address()), nonce: 0 }
    }
    //Generates a new seed by applying the Pedersen hash with the current nonce.
    fn next_seed(ref self: Random) -> felt252 {
        self.nonce += 1;
        self.seed = pedersen::pedersen(self.seed, self.nonce.into());
        self.seed
    }
    // Generates a random value of type `T` using the current seed and applying bitwise NOT.
    fn next<T, +Into<T, u256>, +Into<u8, T>, +TryInto<u256, T>, +BitNot<T>>(ref self: Random) -> T {
        let seed: u256 = self.next_seed().into();
        let mask: T = BitNot::bitnot(0_u8.into());
        (mask.into() & seed).try_into().unwrap()
    }
    // Generates a random value capped by `cap` using modulo operation.
    fn next_capped<T, +Into<T, u256>, +TryInto<u256, T>, +Drop<T>>(ref self: Random, cap: T) -> T {
        let seed: u256 = self.next_seed().into();
        (seed % cap.into()).try_into().unwrap()
    }
}

//********************************************************************
//                   UUID GENERATION WITH POSEIDON                   ||
//********************************************************************

// Generates a unique UUID for the world by hashing the transaction hash and world UUID with Poseidon.
fn get_uuid(self: IWorldDispatcher) -> u128 {
    let hash_felt = PoseidonTrait::new()
        .update(get_tx_info().unbox().transaction_hash)
        .update(self.uuid().into())
        .finalize();
    (hash_felt.into() & 0xffffffffffffffffffffffffffffffff_u256).try_into().unwrap()
}
