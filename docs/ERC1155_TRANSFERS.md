# ERC1155 Token Transfer Implementation Guide

This document explains how the ERC1155 token transfer functionality works in Citizen of Arcanis, including the periodic refresh mechanism that synchronizes player inventories with their actual ERC1155 token ownership.

## Overview

In Citizen of Arcanis, game items are represented as ERC1155 tokens on Starknet. Players can:

1. Transfer items to other players
2. Have their in-game inventory automatically synchronized with their actual token ownership

This implementation ensures that when players transfer NFTs through external means (like a marketplace), the game state remains consistent with their token ownership.

## Key Components

### 1. Gear System

The Gear system handles the logic for transferring and refreshing items:

- `transfer`: Unequips items before they are transferred out
- `refresh`: Checks if the player still owns all equipped items and unequips any that have been transferred away

### 2. Player System

The Player system provides a user-friendly interface to the Gear system:

- `transfer_objects`: Calls the Gear system's transfer function
- `refresh_inventory`: Calls the Gear system's refresh function

### 3. Scripts

Two helper scripts are provided to facilitate these operations:

- `refresh_inventory.ts`: Periodically calls the refresh function to keep the game state in sync
- `transfer_items.ts`: Helps players transfer their ERC1155 tokens

## How to Use

### Setting Up

1. Create a `.env` file with the following variables:
   ```
   PLAYER_CONTRACT_ADDRESS=<deployed_player_contract_address>
   ERC1155_CONTRACT_ADDRESS=<deployed_erc1155_contract_address>
   RPC_URL=<starknet_rpc_url>
   PRIVATE_KEY=<your_private_key>
   ACCOUNT_ADDRESS=<your_account_address>
   REFRESH_INTERVAL_MS=300000  # 5 minutes by default
   ```

### Transferring Items

To transfer items to another player:

```bash
npm install  # Install dependencies first
node scripts/transfer_items.js <recipient_address> <item_id_1> <item_id_2> ...
```

This script will:
1. Call the player contract to unequip the items
2. Call the ERC1155 contract to transfer the tokens

### Running the Periodic Refresh

To keep player inventories in sync with their token ownership:

```bash
npm install  # Install dependencies first
node scripts/refresh_inventory.js
```

This script will:
1. Call the refresh_inventory function periodically (every 5 minutes by default)
2. Log the results of each refresh operation

You can run this script as a background service or scheduled task to ensure game state consistency.

## Implementation Details

### Unequipping Items Before Transfer

Before transferring an item, the system checks if it's currently equipped by the player. If it is, the item is automatically unequipped to prevent inconsistencies.

```cairo
fn transfer(ref self: ContractState, item_ids: Array<u256>) {
    // Get the caller address (player) and recipient (to be specified by the caller)
    let caller = get_caller_address();
    let world = self.world_default();
    
    // Get the player model
    let mut player = get!(world, caller, Player);
    
    // For each item, check if it's equipped and unequip it if necessary
    let mut i = 0;
    let items_len = item_ids.len();
    while i < items_len {
        let item_id = *item_ids.at(i);
        
        // Check if the item is equipped
        let is_equipped = self._is_item_equipped(ref player, item_id);
        
        // If equipped, unequip it first
        if is_equipped {
            self._unequip_item(ref world, ref player, item_id);
        }
        
        i += 1;
    }
    
    // Save the updated player model if any changes were made
    set!(world, (player));
    
    // Note: The actual transfer of the ERC1155 token should be done through a separate call
    // to the ERC1155 contract's safe_transfer_from or safe_batch_transfer_from methods
    // This function just ensures that equipped items are unequipped before transfer
}
```

### Refreshing Inventory

The refresh function checks if the player still owns all equipped items by querying the ERC1155 contract:

```cairo
fn refresh(ref self: ContractState) {
    // Get the caller address (player)
    let caller = get_caller_address();
    let world = self.world_default();
    
    // Get the player model
    let mut player = get!(world, caller, Player);
    
    // Get all equipped items to check
    let mut items_to_check = array![];
    
    // Add all equipped items to the check list
    // ...
    
    // Check each item to see if the player still owns it
    let erc1155 = self._get_erc1155_dispatcher();
    
    // Process each item
    let mut i = 0;
    let items_len = items_to_check.len();
    while i < items_len {
        let item_id = *items_to_check.at(i);
        let balance = erc1155.balance_of(caller, item_id);
        
        // If balance is 0, the item has been transferred away
        if balance == 0 {
            // Unequip the item
            self._unequip_item(ref world, ref player, item_id);
        }
        
        i += 1;
    }
    
    // Save the updated player model
    set!(world, (player));
}
```

## Notes for Developers

1. The ERC1155 contract address is currently hardcoded as a placeholder (`0x1`). Replace this with the actual deployed contract address.
2. The Gear contract address is currently hardcoded as a placeholder (`0x2`). Replace this with the actual deployed contract address.
3. The refresh interval can be adjusted by changing the `REFRESH_INTERVAL_MS` environment variable.
4. Consider implementing a more robust error handling mechanism in the scripts for production use.

## Future Improvements

1. Add support for batch transfers to improve efficiency
2. Implement a more sophisticated refresh mechanism that only checks recently transferred tokens
3. Add events to track transfers and refreshes for better monitoring
4. Create a UI for players to manage their inventory and transfers
