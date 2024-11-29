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

///
/// Generates a unique UUID for the world dispatcher by fetching the world UUID.
/// 1. `uuid`: Retrieves the world UUID from the dispatcher and converts it to a `u128`.
/// 
fn uuid(world: IWorldDispatcher) -> u128 {
    IWorldDispatcherTrait::uuid(world).into()
}

///
/// Generates a seed using the Pedersen hash with the contract address and transaction hash.
/// 1.`seed`: Computes a Pedersen hash of the transaction hash and the contract address (`salt`) to generate a seed.
/// 
fn seed(salt: ContractAddress) -> felt252 {
    pedersen::pedersen(starknet::get_tx_info().unbox().transaction_hash, salt.into())
}

//********************************************************************
//                         RANDOM STRUCTURE                         ||
//********************************************************************

///
/// The `Random` struct holds a `seed` and `nonce` for generating random values.
/// 1. `seed`: The seed used for random value generation.  
/// 2. `nonce`: A unique value used to ensure randomness.
/// 
#[derive(Copy, Drop, Serde)]
struct Random {
    seed: felt252,
    nonce: usize,
}

//********************************************************************
//                   RANDOM TRAIT IMPLEMENTATION                    ||
//********************************************************************

///
/// The `RandomImpl` provides methods to generate random values using the `Random` struct.
/// 1. `new`: Initialize `Random` struct with a new seed derived from the contract address and sets the nonce to 0.
/// 2. `next_seed`: Generates a new seed by applying the Pedersen hash using the current seed and nonce.
/// 3. `next`: Generates a random value of type `T` by applying bitwise NOT on the current seed.
/// 4. `next_capped`: Generates a random value capped by `cap` using the modulo operation on the current seed.
/// 
#[generate_trait]
#[generate_trait]
impl RandomImpl of RandomTrait {
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

//********************************************************************
//                   UUID GENERATION WITH POSEIDON                   ||
//********************************************************************

///
/// `get_uuid`: Hashes the transaction hash and world UUID using Poseidon and returns the resulting UUID as a `u128`.
/// 
fn get_uuid(self: IWorldDispatcher) -> u128 {
    let hash_felt = PoseidonTrait::new()
        .update(get_tx_info().unbox().transaction_hash)
        .update(self.uuid().into())
        .finalize();
    (hash_felt.into() & 0xffffffffffffffffffffffffffffffff_u256).try_into().unwrap()
}
