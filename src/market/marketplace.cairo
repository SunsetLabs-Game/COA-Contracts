#[dojo::contract]
pub mod MarketplaceActions {
    use coa::market::interface::{IMarketplace, AuctionUtils, FeeUtils};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_contract_address};
    use dojo::model::ModelStorage;
    use dojo::event::EventStorage;


    use crate::models::marketplace::{
        Config, MarketData, MarketItem, Auction, UserMarket, MarketAnalytics, Errors,
        MarketRegistered, ItemsMovedToMarket, GearAddedToMarket, ItemPurchased, AuctionStarted,
        BidPlaced, AuctionEnded, ItemRemovedFromMarket, ItemPriceUpdated, ConfigUpdated,
        PlatformFeesWithdrawn, DailyCounter, SECONDS_PER_DAY,
    };

    use crate::models::gear::{Gear, GearType};
    use crate::models::core::Contract;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc1155::interface::{IERC1155Dispatcher, IERC1155DispatcherTrait};
    use crate::erc1155::erc1155::{IERC1155MintableDispatcher, IERC1155MintableDispatcherTrait};
    use core::array::ArrayTrait;


    #[abi(embed_v0)]
    impl MarketplaceImpl of IMarketplace<ContractState> {
        fn init(ref self: ContractState) {
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);
            let admin = get_caller_address();

            assert(contract.admin == admin, Errors::UNAUTHORIZED_CALLER);

            let config = Config { id: 0, next_market_id: 1, next_item_id: 1, next_auction_id: 1 };

            let analytics = MarketAnalytics {
                id: 0,
                total_listings: 0,
                total_sales: 0,
                total_volume: 0,
                total_bids: 0,
                active_auctions: 0,
            };

            world.write_model(@config);
            world.write_model(@analytics);
        }

        fn set_admin(ref self: ContractState, new_admin: ContractAddress) {
            let mut world = self.world_default();
            let mut contract: Contract = world.read_model(0);
            assert(get_caller_address() == contract.admin, Errors::NOT_ADMIN);
            contract.admin = new_admin;
            world.write_model(@contract);
        }

        fn update_config(
            ref self: ContractState,
            payment_token: ContractAddress,
            erc1155_address: ContractAddress,
            escrow_address: ContractAddress,
            registration_fee: u256,
        ) {
            let mut world = self.world_default();
            let mut contract: Contract = world.read_model(0);
            let caller = get_caller_address();
            assert(caller == contract.admin, Errors::NOT_ADMIN);

            contract.payment_token = payment_token;
            contract.erc1155 = erc1155_address;
            contract.escrow_address = escrow_address;
            contract.registration_fee = registration_fee;
            world.write_model(@contract);

            let event = ConfigUpdated {
                payment_token, erc1155_address, escrow_address, registration_fee,
            };
            world.emit_event(@event);
        }

        fn withdraw_platform_fees(ref self: ContractState, to: ContractAddress, amount: u256) {
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);
            let caller = get_caller_address();
            assert(caller == contract.admin, Errors::NOT_ADMIN);

            let client = self.erc20_client();
            let contract_address = get_contract_address();
            let contract_balance = client.balance_of(contract_address);
            assert(amount <= contract_balance, Errors::INSUFFICIENT_BALANCE);

            client.transfer(to, amount);

            let event = PlatformFeesWithdrawn { to, amount, withdrawn_by: caller };
            world.emit_event(@event);
        }

        // Emergency Pause
        fn pause_marketplace(ref self: ContractState) {
            let mut world = self.world_default();
            let mut contract: Contract = world.read_model(0);
            let caller = get_caller_address();
            assert(caller == contract.admin, Errors::NOT_ADMIN);

            contract.paused = true;
            world.write_model(@contract);
        }

        // Emergency Unpause
        fn unpause_marketplace(ref self: ContractState) {
            let mut world = self.world_default();
            let mut contract: Contract = world.read_model(0);
            let caller = get_caller_address();
            assert(caller == contract.admin, Errors::NOT_ADMIN);

            contract.paused = false;
            world.write_model(@contract);
        }

        //  Admin emergency function for stuck items
        fn admin_emergency_return(ref self: ContractState, item_id: u256, to: ContractAddress) {
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);
            assert(get_caller_address() == contract.admin, Errors::NOT_ADMIN);

            let item: MarketItem = world.read_model(item_id);

            self
                .erc1155_client()
                .safe_transfer_from(
                    contract.escrow_address,
                    to,
                    item.token_id,
                    item.quantity,
                    ArrayTrait::new().span(),
                );
        }

        // Public Functions

        fn register_market(ref self: ContractState, is_auction: bool) -> u256 {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);
            let mut config: Config = world.read_model(0);

            let existing_market: UserMarket = world.read_model(caller);
            assert(existing_market.market_id == 0, Errors::MARKET_ALREADY_REGISTERED);
            assert(!contract.paused, Errors::CONTRACT_PAUSED);
            self._increment_daily_count(caller);

            let market_id = config.next_market_id;

            let market = MarketData {
                market_id,
                owner: caller,
                is_auction,
                is_active: true,
                registration_timestamp: get_block_timestamp(),
            };

            let user_market = UserMarket { user: caller, market_id };

            config.next_market_id += 1;

            world.write_model(@config);
            world.write_model(@market);
            world.write_model(@user_market);

            if caller != contract.admin {
                let client = self.erc20_client();
                assert(
                    client.balance_of(caller) >= contract.registration_fee,
                    Errors::INSUFFICIENT_BALANCE,
                );

                client.transfer_from(caller, get_contract_address(), contract.registration_fee);
            }

            let event = MarketRegistered { market_id, owner: caller, is_auction };
            world.emit_event(@event);

            market_id
        }

        fn move_to_market(ref self: ContractState, item_ids: Array<u256>, prices: Array<u256>) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);
            let mut config: Config = world.read_model(0);
            let user_market: UserMarket = world.read_model(caller);
            let market_id = user_market.market_id;

            assert(!contract.paused, Errors::CONTRACT_PAUSED);
            assert(market_id != 0, Errors::NO_MARKET_REGISTERED);
            assert(item_ids.len() == prices.len(), Errors::INVALID_PRICES_SIZE);
            assert(item_ids.len() > 0, Errors::NO_VALID_ITEMS);

            let market: MarketData = world.read_model(market_id);
            assert(market.owner == caller, Errors::UNAUTHORIZED_CALLER);
            assert(market.is_active, Errors::MARKET_INACTIVE);

            let client = self.erc1155_client();

            let mut ids: Array<u256> = array![];
            let mut amounts: Array<u256> = array![];

            let mut i = 0;
            loop {
                if i >= item_ids.len() {
                    break;
                }
                let id = *item_ids.at(i);
                let price = *prices.at(i);

                // Enhanced price validation
                assert(self._validate_price(price), Errors::INVALID_PRICE);

                if self._check_item_ownership(id, caller) {
                    ids.append(id);
                    amounts.append(1_u256);

                    let item_id = config.next_item_id;
                    config.next_item_id += 1;

                    let market_item = MarketItem {
                        item_id,
                        market_id,
                        token_id: id,
                        owner: caller,
                        price,
                        quantity: 1_u256,
                        is_available: true,
                        is_auction_item: market.is_auction,
                    };

                    world.write_model(@market_item);

                    // Track market activity
                    self._track_market_activity('LISTED', price);
                }

                i += 1;
            };

            assert(ids.len() > 0, Errors::NO_VALID_ITEMS);

            world.write_model(@config);

            client
                .safe_batch_transfer_from(
                    caller,
                    contract.escrow_address,
                    ids.span(),
                    amounts.span(),
                    ArrayTrait::new().span(),
                );

            let event = ItemsMovedToMarket { market_id, item_ids: ids, seller: caller };
            world.emit_event(@event);
        }

        fn add_to_market(ref self: ContractState, gear: Gear, price: u256, quantity: u256) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            let mut contract: Contract = world.read_model(0);
            let mut config: Config = world.read_model(0);
            assert(!contract.paused, Errors::CONTRACT_PAUSED);
            assert(caller == contract.admin, Errors::NOT_ADMIN);
            assert(self._validate_price(price), Errors::INVALID_PRICE);
            assert(quantity > 0, Errors::INVALID_QUANTITY);

            let user_market: UserMarket = world.read_model(caller);
            assert(user_market.market_id > 0, Errors::NO_MARKET_REGISTERED);
            let market_id = user_market.market_id;

            let market: MarketData = world.read_model(market_id);
            assert(market.is_active, Errors::MARKET_INACTIVE);

            let gear_type = crate::helpers::gear::parse_id(gear.id);
            assert(gear_type != GearType::None, Errors::INVALID_GEAR_TYPE);

            let item_id = config.next_item_id;
            config.next_item_id += 1;

            let market_item = MarketItem {
                item_id,
                market_id,
                token_id: gear.id,
                owner: caller,
                price,
                quantity,
                is_available: true,
                is_auction_item: market.is_auction,
            };

            world.write_model(@config);
            world.write_model(@market_item);

            let erc1155 = IERC1155MintableDispatcher { contract_address: contract.erc1155 };
            erc1155.mint(contract.escrow_address, gear.id, quantity, ArrayTrait::new().span());

            // Track market activity
            self._track_market_activity('LISTED', price * quantity);

            let event = GearAddedToMarket { item_id, market_id, seller: caller };
            world.emit_event(@event);
        }

        fn purchase_item(ref self: ContractState, item_id: u256, quantity: u256) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let mut item: MarketItem = world.read_model(item_id);
            let contract: Contract = world.read_model(0);

            assert(!contract.paused, Errors::CONTRACT_PAUSED);
            assert(item.is_available, Errors::ITEM_NOT_AVAILABLE);
            assert(quantity > 0, Errors::INVALID_QUANTITY);
            assert(item.quantity >= quantity, Errors::NOT_ENOUGH_STOCK);
            assert(!item.is_auction_item, Errors::ITEM_IS_AUCTION_ONLY);
            assert(item.owner != caller, Errors::NOT_BUY_ITEM_OWNER_ALLOWED);

            let total_price = item.price * quantity;
            assert(total_price > 0, Errors::INVALID_PRICE);

            // Calculate platform fee
            let platform_fee = self._calculate_platform_fee(total_price);
            let seller_amount = total_price - platform_fee;

            item.quantity -= quantity;
            if item.quantity == 0 {
                item.is_available = false;
            }
            world.write_model(@item);

            let client = self.erc20_client();
            assert(client.balance_of(caller) >= total_price, Errors::INSUFFICIENT_BALANCE);

            let allowance = client.allowance(caller, get_contract_address());
            assert(allowance >= total_price, Errors::INSUFFICIENT_ALLOWANCE);
            client.transfer_from(caller, get_contract_address(), platform_fee);
            client.transfer_from(caller, item.owner, seller_amount);

            // Transfer item from escrow to buyer
            self
                .erc1155_client()
                .safe_transfer_from(
                    contract.escrow_address,
                    caller,
                    item.token_id,
                    quantity,
                    ArrayTrait::new().span(),
                );

            // Track market activity
            self._track_market_activity('SOLD', total_price);

            let event = ItemPurchased {
                buyer: caller,
                seller: item.owner,
                item_id,
                quantity,
                total_price,
                platform_fee,
                seller_amount,
            };
            world.emit_event(@event);
        }

        fn update_item_price(ref self: ContractState, item_id: u256, new_price: u256) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);

            assert(!contract.paused, Errors::CONTRACT_PAUSED);
            assert(self._validate_price(new_price), Errors::INVALID_PRICE);

            let mut item: MarketItem = world.read_model(item_id);

            assert(item.owner == caller, Errors::NOT_ITEM_OWNER);
            assert(item.is_available, Errors::ITEM_NOT_AVAILABLE);

            let old_price = item.price;
            item.price = new_price;
            world.write_model(@item);

            let event = ItemPriceUpdated { item_id, old_price, new_price, owner: caller };
            world.emit_event(@event);
        }

        fn bulk_update_prices(
            ref self: ContractState, item_ids: Array<u256>, new_prices: Array<u256>,
        ) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);

            assert(!contract.paused, Errors::CONTRACT_PAUSED);
            assert(item_ids.len() == new_prices.len(), Errors::INVALID_PRICES_SIZE);

            let mut i = 0;
            loop {
                if i >= item_ids.len() {
                    break;
                }
                let item_id = *item_ids.at(i);
                let new_price = *new_prices.at(i);

                assert(self._validate_price(new_price), Errors::INVALID_PRICE);

                let mut item: MarketItem = world.read_model(item_id);

                assert(item.owner == caller, Errors::NOT_ITEM_OWNER);
                assert(item.is_available, Errors::ITEM_NOT_AVAILABLE);

                let old_price = item.price;
                item.price = new_price;
                world.write_model(@item);

                let event = ItemPriceUpdated { item_id, old_price, new_price, owner: caller };
                world.emit_event(@event);

                i += 1;
            }
        }

        fn start_auction(
            ref self: ContractState, item_id: u256, duration: u64, starting_bid: u256,
        ) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let user_market: UserMarket = world.read_model(caller);
            let mut contract: Contract = world.read_model(0);
            let mut config: Config = world.read_model(0);
            let market_id = user_market.market_id;

            assert(!contract.paused, Errors::CONTRACT_PAUSED);
            assert(market_id != 0, Errors::NO_MARKET_REGISTERED);
            assert(self._validate_auction_duration(duration), Errors::INVALID_AUCTION_DURATION);
            assert(self._validate_price(starting_bid), Errors::INVALID_PRICE);

            let market: MarketData = world.read_model(market_id);
            assert(market.owner == caller, Errors::UNAUTHORIZED_CALLER);
            assert(market.is_auction, Errors::MARKET_NOT_AUCTION);

            let item: MarketItem = world.read_model(item_id);
            assert(item.owner == caller, Errors::NOT_ITEM_OWNER);
            assert(item.is_available, Errors::ITEM_NOT_LISTED);
            assert(item.is_auction_item, Errors::ITEM_NOT_AUCTION_ITEM);

            let auction_id = config.next_auction_id;
            config.next_auction_id += 1;

            let end_time = get_block_timestamp() + duration;
            let new_auction = Auction {
                auction_id,
                market_id,
                item_id,
                highest_bid: starting_bid,
                highest_bidder: caller,
                end_time,
                active: true,
            };

            world.write_model(@new_auction);
            world.write_model(@config);

            // Track auction activity
            self._track_auction_activity('STARTED');

            let event = AuctionStarted {
                auction_id, item_id, market_id, end_time, starting_bid, duration,
            };
            world.emit_event(@event);
        }

        fn place_bid(ref self: ContractState, auction_id: u256, amount: u256) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let mut auction: Auction = world.read_model(auction_id);
            let contract: Contract = world.read_model(0);
            let item: MarketItem = world.read_model(auction.item_id);

            assert(!contract.paused, Errors::CONTRACT_PAUSED);
            assert(auction.active, Errors::AUCTION_NOT_ACTIVE);
            assert(get_block_timestamp() < auction.end_time, Errors::AUCTION_ENDED);
            assert(caller != item.owner, Errors::SELLER_CANNOT_BID);

            //  bid validation with minimum increment
            let min_increment = AuctionUtils::calculate_minimum_bid_increment(auction.highest_bid);
            assert(amount >= auction.highest_bid + min_increment, Errors::BID_TOO_LOW);

            let client = self.erc20_client();
            assert(client.balance_of(caller) >= amount, Errors::INSUFFICIENT_FUNDS);

            let previous_bid = auction.highest_bid;
            let previous_bidder = auction.highest_bidder;

            let allowance = client.allowance(caller, get_contract_address());
            assert(allowance >= amount, Errors::INSUFFICIENT_ALLOWANCE);

            client.transfer_from(caller, get_contract_address(), amount);

            if auction.highest_bidder != item.owner {
                client.transfer(previous_bidder, previous_bid);
            }

            auction.highest_bid = amount;
            auction.highest_bidder = caller;
            world.write_model(@auction);

            self._check_and_extend_auction(auction_id);
            self._track_market_activity('BID', amount);

            let event = BidPlaced {
                auction_id, bidder: caller, amount, previous_bid, previous_bidder,
            };
            world.emit_event(@event);
        }

        fn end_auction(ref self: ContractState, auction_id: u256) {
            let mut world = self.world_default();
            let mut auction: Auction = world.read_model(auction_id);
            let contract: Contract = world.read_model(0);

            assert(auction.active, Errors::AUCTION_NOT_ACTIVE);
            assert(get_block_timestamp() >= auction.end_time, Errors::AUCTION_NOT_ENDED);

            auction.active = false;

            let mut item: MarketItem = world.read_model(auction.item_id);

            // Check if there were any valid bids
            if auction.highest_bidder == item.owner {
                // No valid bids - return item to seller
                self._return_item_to_seller(auction.item_id);
            } else {
                // Complete the sale with fee calculation
                let total_bid = auction.highest_bid;
                let platform_fee = self._calculate_platform_fee(total_bid);
                let seller_amount = total_bid - platform_fee;

                item.is_available = false;
                item.quantity = 0;

                self.erc20_client().transfer(item.owner, seller_amount);

                // Transfer item to winner
                self
                    .erc1155_client()
                    .safe_transfer_from(
                        contract.escrow_address,
                        auction.highest_bidder,
                        item.token_id,
                        1_u256,
                        ArrayTrait::new().span(),
                    );

                // Track sale activity
                self._track_market_activity('SOLD', total_bid);
            }

            world.write_model(@auction);
            world.write_model(@item);

            // Track auction completion
            self._track_auction_activity('ENDED');

            let event = AuctionEnded {
                auction_id, winner: auction.highest_bidder, final_bid: auction.highest_bid,
            };
            world.emit_event(@event);
        }

        fn remove_item_from_market(ref self: ContractState, item_id: u256, reason: felt252) {
            let caller = get_caller_address();
            let mut world = self.world_default();

            let mut item: MarketItem = world.read_model(item_id);
            let contract: Contract = world.read_model(0);
            let market: MarketData = world.read_model(item.market_id);

            assert(item.owner == caller, Errors::NOT_ITEM_OWNER);
            assert(item.is_available, Errors::ITEM_NOT_AVAILABLE);
            assert(market.owner == caller, Errors::UNAUTHORIZED_CALLER);
            assert(market.is_active, Errors::MARKET_INACTIVE);

            item.is_available = false;
            world.write_model(@item);

            self
                .erc1155_client()
                .safe_transfer_from(
                    contract.escrow_address,
                    caller,
                    item.token_id,
                    item.quantity,
                    ArrayTrait::new().span(),
                );

            let event = ItemRemovedFromMarket { item_id, owner: caller, reason };
            world.emit_event(@event);
        }

        fn bulk_remove_items(
            ref self: ContractState, item_ids: Array<u256>, reasons: Array<felt252>,
        ) {
            let caller = get_caller_address();
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);

            let mut i = 0;
            loop {
                if i >= item_ids.len() {
                    break;
                }
                let item_id = *item_ids.at(i);
                let mut item: MarketItem = world.read_model(item_id);
                let market: MarketData = world.read_model(item.market_id);

                if item.owner == caller
                    && item.is_available
                    && market.owner == caller
                    && market.is_active {
                    item.is_available = false;
                    world.write_model(@item);

                    self
                        .erc1155_client()
                        .safe_transfer_from(
                            contract.escrow_address,
                            caller,
                            item.token_id,
                            item.quantity,
                            ArrayTrait::new().span(),
                        );

                    let event = ItemRemovedFromMarket {
                        item_id, owner: caller, reason: *reasons.at(i),
                    };
                    world.emit_event(@event);
                }

                i += 1;
            }
        }

        // View functions
        fn get_market_data(self: @ContractState, market_id: u256) -> MarketData {
            let world = self.world_default();
            world.read_model(market_id)
        }

        fn get_market_item(self: @ContractState, item_id: u256) -> MarketItem {
            let world = self.world_default();
            world.read_model(item_id)
        }

        fn get_auction(self: @ContractState, auction_id: u256) -> Auction {
            let world = self.world_default();
            world.read_model(auction_id)
        }

        fn get_user_market(self: @ContractState, user: ContractAddress) -> u256 {
            let world = self.world_default();
            let user_market: UserMarket = world.read_model(user);
            user_market.market_id
        }

        fn get_counters(self: @ContractState) -> (u256, u256, u256) {
            let world = self.world_default();
            let config: Config = world.read_model(0);
            (config.next_market_id, config.next_item_id, config.next_auction_id)
        }

        fn get_config(self: @ContractState) -> Config {
            let world = self.world_default();
            world.read_model(0)
        }

        fn get_market_analytics(self: @ContractState) -> MarketAnalytics {
            let world = self.world_default();
            world.read_model(0)
        }

        fn get_total_collected_fees(self: @ContractState) -> u256 {
            self.erc20_client().balance_of(get_contract_address())
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"coa")
        }

        fn erc20_client(self: @ContractState) -> IERC20Dispatcher {
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);
            IERC20Dispatcher { contract_address: contract.payment_token }
        }
        fn erc1155_client(self: @ContractState) -> IERC1155Dispatcher {
            let mut world = self.world_default();
            let contract: Contract = world.read_model(0);
            IERC1155Dispatcher { contract_address: contract.erc1155 }
        }

        fn _check_item_ownership(
            ref self: ContractState, token_id: u256, owner: ContractAddress,
        ) -> bool {
            let world = self.world_default();
            let contract: Contract = world.read_model(0);
            IERC1155Dispatcher { contract_address: contract.erc1155 }
                .balance_of(owner, token_id) > 0
        }

        fn _increment_daily_count(ref self: ContractState, user: ContractAddress) {
            let day = get_block_timestamp() / SECONDS_PER_DAY;
            let mut world = self.world_default();
            let key = (user, day);
            let mut count: DailyCounter = world.read_model(key);
            assert(count.counter < 5_u256, Errors::DAILY_LIMIT_EXCEEDED);
            count.counter += 1;
            world.write_model(@count);
        }

        fn _validate_price(self: @ContractState, price: u256) -> bool {
            price > 0 && price <= 1000000000000000000000
        }

        fn _validate_auction_duration(self: @ContractState, duration: u64) -> bool {
            let (min, max) = AuctionUtils::get_duration_bounds();
            duration >= min && duration <= max
        }

        fn _calculate_platform_fee(self: @ContractState, price: u256) -> u256 {
            FeeUtils::calculate_platform_fee(price)
        }

        fn _track_market_activity(ref self: ContractState, action: felt252, price: u256) {
            let mut world = self.world_default();
            let mut analytics: MarketAnalytics = world.read_model(0);

            if action == 'LISTED' {
                analytics.total_listings += 1;
            } else if action == 'SOLD' {
                analytics.total_sales += 1;
                analytics.total_volume += price;
            } else if action == 'BID' {
                analytics.total_bids += 1;
            }

            world.write_model(@analytics);
        }

        fn _track_auction_activity(ref self: ContractState, action: felt252) {
            let mut world = self.world_default();
            let mut analytics: MarketAnalytics = world.read_model(0);

            if action == 'STARTED' {
                analytics.active_auctions += 1;
            } else if action == 'ENDED' {
                if analytics.active_auctions > 0 {
                    analytics.active_auctions -= 1;
                }
            }

            world.write_model(@analytics);
        }

        fn _return_item_to_seller(ref self: ContractState, item_id: u256) {
            let mut world = self.world_default();
            let mut item: MarketItem = world.read_model(item_id);
            let contract: Contract = world.read_model(0);

            item.is_available = false;
            item.quantity = 0;
            world.write_model(@item);

            IERC1155Dispatcher { contract_address: contract.erc1155 }
                .safe_transfer_from(
                    contract.escrow_address,
                    item.owner,
                    item.token_id,
                    1_u256,
                    ArrayTrait::new().span(),
                );
        }

        fn _check_and_extend_auction(ref self: ContractState, auction_id: u256) {
            let mut world = self.world_default();
            let mut auction: Auction = world.read_model(auction_id);

            if auction.active {
                let current_time = get_block_timestamp();
                let time_remaining = auction.end_time - current_time;

                if time_remaining < 600 {
                    auction.end_time = current_time + 600;
                    world.write_model(@auction);
                }
            }
        }
    }
}
