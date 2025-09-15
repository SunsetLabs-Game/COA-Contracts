use starknet::ContractAddress;
use crate::models::marketplace::{Config, MarketData, MarketItem, Auction, MarketAnalytics};
use crate::models::gear::Gear;
use core::array::Array;

#[starknet::interface]
pub trait IMarketplace<TContractState> {
    // Admin functions
    fn init(ref self: TContractState);
    fn set_admin(ref self: TContractState, new_admin: ContractAddress);
    fn update_config(
        ref self: TContractState,
        payment_token: ContractAddress,
        erc1155_address: ContractAddress,
        escrow_address: ContractAddress,
        registration_fee: u256,
    );
    fn withdraw_platform_fees(ref self: TContractState, to: ContractAddress, amount: u256);
    fn pause_marketplace(ref self: TContractState);
    fn unpause_marketplace(ref self: TContractState);
    fn admin_emergency_return(ref self: TContractState, item_id: u256, to: ContractAddress);

    // Core marketplace functions
    fn register_market(ref self: TContractState, is_auction: bool) -> u256;
    fn move_to_market(ref self: TContractState, item_ids: Array<u256>, prices: Array<u256>);
    fn add_to_market(ref self: TContractState, gear: Gear, price: u256, quantity: u256);
    fn purchase_item(ref self: TContractState, item_id: u256, quantity: u256);
    fn update_item_price(ref self: TContractState, item_id: u256, new_price: u256);
    fn bulk_update_prices(ref self: TContractState, item_ids: Array<u256>, new_prices: Array<u256>);
    fn remove_item_from_market(ref self: TContractState, item_id: u256, reason: felt252);
    fn bulk_remove_items(ref self: TContractState, item_ids: Array<u256>, reasons: Array<felt252>);

    // Auction functions
    fn start_auction(ref self: TContractState, item_id: u256, duration: u64, starting_bid: u256);
    fn place_bid(ref self: TContractState, auction_id: u256, amount: u256);
    fn end_auction(ref self: TContractState, auction_id: u256);

    // View functions
    fn get_market_data(self: @TContractState, market_id: u256) -> MarketData;
    fn get_market_item(self: @TContractState, item_id: u256) -> MarketItem;
    fn get_auction(self: @TContractState, auction_id: u256) -> Auction;
    fn get_user_market(self: @TContractState, user: ContractAddress) -> u256;
    fn get_counters(self: @TContractState) -> (u256, u256, u256);
    fn get_config(self: @TContractState) -> Config;
    fn get_market_analytics(self: @TContractState) -> MarketAnalytics;
    fn get_total_collected_fees(self: @TContractState) -> u256;
    fn get_contract_token_balance(self: @TContractState) -> u256;
    fn get_platform_fees_details(self: @TContractState) -> (u256, u256, u256);
}


// Fee calculation utilities
pub mod FeeUtils {
    pub const DEFAULT_PLATFORM_FEE_BASIS_POINTS: u256 = 250; // 2.5%
    pub const BASIS_POINTS_DIVISOR: u256 = 10000;

    pub fn calculate_platform_fee(price: u256) -> u256 {
        (price * DEFAULT_PLATFORM_FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR
    }

    pub fn calculate_seller_amount(total_price: u256, platform_fee: u256) -> u256 {
        total_price - platform_fee
    }
}


// Auction validation utilities
pub mod AuctionUtils {
    pub const MIN_AUCTION_DURATION_SECONDS: u64 = 3600; // 1 hour
    pub const MAX_AUCTION_DURATION_SECONDS: u64 = 2592000; // 30 days
    pub const DEFAULT_BID_INCREMENT_BASIS_POINTS: u256 = 500; // 5%

    pub fn is_valid_duration(duration: u64) -> bool {
        duration >= MIN_AUCTION_DURATION_SECONDS && duration <= MAX_AUCTION_DURATION_SECONDS
    }

    pub fn calculate_minimum_bid_increment(current_bid: u256) -> u256 {
        (current_bid * DEFAULT_BID_INCREMENT_BASIS_POINTS) / 10000
    }

    pub fn get_duration_bounds() -> (u64, u64) {
        (MIN_AUCTION_DURATION_SECONDS, MAX_AUCTION_DURATION_SECONDS)
    }
}
