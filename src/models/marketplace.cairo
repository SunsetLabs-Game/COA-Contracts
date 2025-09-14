use starknet::ContractAddress;
pub const SECONDS_PER_DAY: u64 = 86400;

// Configuration model
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Config {
    #[key]
    pub id: u8,
    pub next_market_id: u256,
    pub next_item_id: u256,
    pub next_auction_id: u256,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct DailyCounter {
    #[key]
    pub user: ContractAddress,
    #[key]
    pub day: u256,
    pub counter: u256,
}

// Market analytics model for tracking marketplace statistics
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MarketAnalytics {
    #[key]
    pub id: u8,
    pub total_listings: u256,
    pub total_sales: u256,
    pub total_volume: u256,
    pub total_bids: u256,
    pub active_auctions: u256,
}

// Market data model
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MarketData {
    #[key]
    pub market_id: u256,
    pub owner: ContractAddress,
    pub is_auction: bool,
    pub is_active: bool,
    pub registration_timestamp: u64,
}

// Market item model
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct MarketItem {
    #[key]
    pub item_id: u256,
    pub market_id: u256,
    pub token_id: u256,
    pub owner: ContractAddress,
    pub price: u256,
    pub quantity: u256,
    pub is_available: bool,
    pub is_auction_item: bool,
}

// Auction model
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Auction {
    #[key]
    pub auction_id: u256,
    pub market_id: u256,
    pub item_id: u256,
    pub highest_bid: u256,
    pub highest_bidder: ContractAddress,
    pub end_time: u64,
    pub active: bool,
}

// User market mapping
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct UserMarket {
    #[key]
    pub user: ContractAddress,
    pub market_id: u256,
}

// Enhanced error constants with additional validation errors
pub mod Errors {
    pub const NOT_ADMIN: felt252 = 'Not admin';
    pub const ALREADY_INITIALIZED: felt252 = 'Already initialized';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const NO_MARKET_REGISTERED: felt252 = 'No market registered';
    pub const UNAUTHORIZED_CALLER: felt252 = 'Unauthorized caller';
    pub const MARKET_INACTIVE: felt252 = 'Market inactive';
    pub const INVALID_PRICES_SIZE: felt252 = 'Invalid prices/items size';
    pub const NO_VALID_ITEMS: felt252 = 'No valid items to move';
    pub const ITEM_NOT_AVAILABLE: felt252 = 'Item not available';
    pub const INVALID_QUANTITY: felt252 = 'Invalid quantity';
    pub const NOT_ENOUGH_STOCK: felt252 = 'Not enough stock';
    pub const INVALID_PRICE: felt252 = 'Invalid price';
    pub const NOT_ITEM_OWNER: felt252 = 'Not item owner';
    pub const ITEM_NOT_LISTED: felt252 = 'Item not listed';
    pub const MARKET_NOT_AUCTION: felt252 = 'Market not auction enabled';
    pub const AUCTION_NOT_ACTIVE: felt252 = 'Auction not active';
    pub const AUCTION_ENDED: felt252 = 'Auction ended';
    pub const BID_TOO_LOW: felt252 = 'Bid too low';
    pub const INSUFFICIENT_FUNDS: felt252 = 'Insufficient funds';
    pub const AUCTION_NOT_ENDED: felt252 = 'Auction not ended';
    pub const ITEM_IS_AUCTION_ONLY: felt252 = 'Item is auction only';
    pub const ITEM_NOT_AUCTION_ITEM: felt252 = 'Item not auction item';
    pub const NOT_BUY_ITEM_OWNER_ALLOWED: felt252 = 'Item owner not_allow';
    pub const INVALID_GEAR_TYPE: felt252 = 'INVALID_GEAR_TYPE';
    pub const CONTRACT_PAUSED: felt252 = 'CONTRACT_PAUSED';
    pub const SELLER_CANNOT_BID: felt252 = 'SELLER_CANNOT_BID';
    pub const MARKET_ALREADY_REGISTERED: felt252 = 'MARKET_ALREADY_REGISTERED';
    pub const DAILY_LIMIT_EXCEEDED: felt252 = 'DAILY_LIMIT_EXCEEDED';
    pub const INVALID_AUCTION_DURATION: felt252 = 'INVALID_AUCTION_DURATION';
    pub const PRICE_TOO_LOW: felt252 = 'PRICE_TOO_LOW';
    pub const PRICE_TOO_HIGH: felt252 = 'PRICE_TOO_HIGH';
    pub const AUCTION_DURATION_TOO_SHORT: felt252 = 'AUCTION_DURATION_TOO_SHORT';
    pub const AUCTION_DURATION_TOO_LONG: felt252 = 'AUCTION_DURATION_TOO_LONG';
    pub const INSUFFICIENT_BID_INCREMENT: felt252 = 'INSUFFICIENT_BID_INCREMENT';
    pub const ESCROW_TRANSFER_FAILED: felt252 = 'ESCROW_TRANSFER_FAILED';
    pub const PLATFORM_FEE_CALCULATION_ERROR: felt252 = 'PLATFORM_FEE_CALC_ERROR';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'INSUFFICIENT_ALLOWANCE';
}

// Events
#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct MarketRegistered {
    #[key]
    pub market_id: u256,
    #[key]
    pub owner: ContractAddress,
    pub is_auction: bool,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct ItemsMovedToMarket {
    #[key]
    pub market_id: u256,
    pub item_ids: Array<u256>,
    pub seller: ContractAddress,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct GearAddedToMarket {
    #[key]
    pub item_id: u256,
    pub market_id: u256,
    pub seller: ContractAddress,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct ItemPurchased {
    #[key]
    pub buyer: ContractAddress,
    #[key]
    pub seller: ContractAddress,
    #[key]
    pub item_id: u256,
    pub quantity: u256,
    pub total_price: u256,
    pub platform_fee: u256,
    pub seller_amount: u256,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct ItemPriceUpdated {
    #[key]
    pub item_id: u256,
    pub old_price: u256,
    pub new_price: u256,
    pub owner: ContractAddress,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct ConfigUpdated {
    #[key]
    pub payment_token: ContractAddress,
    pub erc1155_address: ContractAddress,
    pub escrow_address: ContractAddress,
    pub registration_fee: u256,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct PlatformFeesWithdrawn {
    #[key]
    pub to: ContractAddress,
    pub amount: u256,
    pub withdrawn_by: ContractAddress,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct AuctionStarted {
    #[key]
    pub auction_id: u256,
    #[key]
    pub item_id: u256,
    pub market_id: u256,
    pub starting_bid: u256,
    pub end_time: u64,
    pub duration: u64,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct BidPlaced {
    #[key]
    pub auction_id: u256,
    #[key]
    pub bidder: ContractAddress,
    pub amount: u256,
    pub previous_bid: u256,
    pub previous_bidder: ContractAddress,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct AuctionEnded {
    #[key]
    pub auction_id: u256,
    #[key]
    pub winner: ContractAddress,
    pub final_bid: u256,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct ItemRemovedFromMarket {
    #[key]
    pub item_id: u256,
    pub owner: ContractAddress,
    pub reason: felt252,
}

// New events for enhanced functionality
#[derive(Drop, Serde)]
#[dojo::event]
pub struct MarketAnalyticsUpdated {
    #[key]
    pub timestamp: u64,
    pub total_listings: u256,
    pub total_sales: u256,
    pub total_volume: u256,
    pub total_bids: u256,
    pub active_auctions: u256,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct PriceValidationFailed {
    #[key]
    pub item_id: u256,
    pub attempted_price: u256,
    pub min_allowed: u256,
    pub max_allowed: u256,
    pub caller: ContractAddress,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct AuctionValidationFailed {
    #[key]
    pub auction_id: u256,
    pub attempted_duration: u64,
    pub min_duration: u64,
    pub max_duration: u64,
    pub caller: ContractAddress,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct EscrowOperation {
    #[key]
    pub item_id: u256,
    #[key]
    pub operation: felt252, // 'DEPOSIT', 'RELEASE', 'RETURN'
    pub from: ContractAddress,
    pub to: ContractAddress,
    pub token_id: u256,
    pub quantity: u256,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct PlatformFeeCalculated {
    #[key]
    pub transaction_id: u256,
    pub total_price: u256,
    pub fee_percentage: u256,
    pub platform_fee: u256,
    pub seller_amount: u256,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct MarketplaceEmergencyAction {
    #[key]
    pub action: felt252, // 'PAUSE', 'UNPAUSE', 'EMERGENCY_WITHDRAW'
    pub admin: ContractAddress,
    pub timestamp: u64,
    pub details: felt252,
}
