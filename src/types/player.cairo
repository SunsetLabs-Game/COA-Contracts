#[derive(Drop, Copy, Debug, Introspect, PartialEq, Serde, Default)]
pub struct Rank {
    #[default]
    value: PlayerRank,
    xp: u256,
}

#[derive(Drop, Copy, Debug, Introspect, PartialEq, Serde, Default)]
pub enum PlayerRank {
    #[default]
    Beginner: Beginner,
    Intermediate: Intermediate,
}

#[derive(Drop, Copy, Debug, Introspect, PartialEq, Serde, Default)]
pub enum Beginner {
    #[default]
    Rookie,
    Novice,
    Apprentice,
    Amateur,
    Iron,
    Silver,
}

// impl DerefRankPlayerRank of Deref<PlayerRank> {
//     type Target = Beginner;
//     fn deref(self: PlayerRank) -> Beginner {
//         self::value
//     }
// }

#[derive(Drop, Copy, Debug, Introspect, PartialEq, Serde)]
pub enum Intermediate {
    Silver,
    Gold,
    Warrior,
    Challenger,
    Guardian
}

#[generate_trait]
pub impl PlayerRankImpl of PlayerRankTrait {
    fn add_val(ref self: PlayerRank, val: u32) -> bool {
        let rank_changed = false;
        let mut xp: u128 = self.into();

    }

    #[inline(always)]
    fn compute_max_val(ref self: PlayerRank) -> u64 {
        // the value per rank increases exponentially
    }

    fn get_multiplier(ref self: PlayerRank) -> u32 {
        // should increase exponentially too.
    }
}

// converts the rank to the total XP gained.
pub impl PlayerRankXP of Into<PlayerRank, u128> {
    #[inline(always)]
    fn into(self: PlayerRank) -> u128 {
        let next val
        match self {

        }
    }
}

// compute the max value
// 

// pub mod Multipliers {
//     Rookie: u32,
//     Novice: u32,
//     Apprentice: u32,
//     Amateur: u32,
//     Iron: u32,
//     Silver: u32,
// }

fn exponential_next_val(val: u256) -> u256 {

}