import { Account, Contract, RpcProvider, uint256, cairo } from 'starknet';
import { readFileSync } from 'fs';
import dotenv from 'dotenv';

dotenv.config();

// Configuration
const PLAYER_CONTRACT_ADDRESS = process.env.PLAYER_CONTRACT_ADDRESS || '0x2'; // Default to placeholder
const ERC1155_CONTRACT_ADDRESS = process.env.ERC1155_CONTRACT_ADDRESS || '0x1'; // Default to placeholder
const RPC_URL = process.env.RPC_URL || 'http://localhost:5050';
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const ACCOUNT_ADDRESS = process.env.ACCOUNT_ADDRESS;

// Load ABIs
const playerAbi = JSON.parse(
  readFileSync('./target/dev/coa_PlayerActions.contract_class.json', 'utf8')
).abi;

const erc1155Abi = JSON.parse(
  readFileSync('./target/dev/coa_ERC1155.contract_class.json', 'utf8')
).abi;

async function setupProvider() {
  const provider = new RpcProvider({ nodeUrl: RPC_URL });
  
  if (!PRIVATE_KEY || !ACCOUNT_ADDRESS) {
    throw new Error('PRIVATE_KEY and ACCOUNT_ADDRESS must be set in .env file');
  }
  
  const account = new Account(
    provider,
    ACCOUNT_ADDRESS,
    PRIVATE_KEY
  );
  
  return { provider, account };
}

async function transferItems(account: Account, toAddress: string, itemIds: string[]) {
  try {
    console.log(`Transferring items ${itemIds.join(', ')} to ${toAddress}...`);
    
    // Convert item IDs to Cairo u256 format
    const cairoItemIds = itemIds.map(id => cairo.uint256(id));
    
    // 1. First call the player contract to unequip items
    const playerContract = new Contract(playerAbi, PLAYER_CONTRACT_ADDRESS, account);
    await playerContract.transfer_objects(cairoItemIds);
    console.log('Items unequipped successfully');
    
    // 2. Then call the ERC1155 contract to transfer the tokens
    const erc1155Contract = new Contract(erc1155Abi, ERC1155_CONTRACT_ADDRESS, account);
    
    // For each item, call safe_transfer_from
    for (const itemId of cairoItemIds) {
      await erc1155Contract.safe_transfer_from(
        account.address,
        toAddress,
        itemId,
        cairo.uint256('1'), // Assuming each item has a quantity of 1
        [] // Empty data
      );
      console.log(`Item ${itemId} transferred successfully`);
    }
    
    console.log('All items transferred successfully');
    return true;
  } catch (error) {
    console.error('Error transferring items:', error);
    return false;
  }
}

// Example usage
async function main() {
  try {
    const { account } = await setupProvider();
    
    // Get command line arguments
    const args = process.argv.slice(2);
    if (args.length < 2) {
      console.log('Usage: node transfer_items.js <recipient_address> <item_id_1> [<item_id_2> ...]');
      process.exit(1);
    }
    
    const toAddress = args[0];
    const itemIds = args.slice(1);
    
    await transferItems(account, toAddress, itemIds);
    
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

// Run the script
main().catch(console.error);
