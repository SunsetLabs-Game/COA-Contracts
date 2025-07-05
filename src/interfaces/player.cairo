use crate::models::player::Player;

#[starknet::interface]
pub trait IPlayer<TContractState> {
    fn new(ref self: TContractState, faction: felt252);
    fn deal_damage(
        ref self: TContractState,
        target: Array<u256>,
        target_types: Array<felt252>,
        with_items: Array<u256>,
    );
    fn get_player(self: @TContractState, player_id: u256) -> Player;
    fn register_guild(ref self: TContractState);
    
    // Refresh player's equipped items based on current NFT ownership
    // This should be called periodically to ensure game state matches blockchain state
    fn refresh(ref self: TContractState);
}
