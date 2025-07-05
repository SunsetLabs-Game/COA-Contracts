import { Account, Contract, RpcProvider } from 'starknet';
import { readFileSync } from 'fs';
import dotenv from 'dotenv';

dotenv.config();

// Configuration
const PLAYER_CONTRACT_ADDRESS = process.env.PLAYER_CONTRACT_ADDRESS || '0x2'; // Default to placeholder
const RPC_URL = process.env.RPC_URL || 'http://localhost:5050';
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const ACCOUNT_ADDRESS = process.env.ACCOUNT_ADDRESS;
const REFRESH_INTERVAL_MS = parseInt(process.env.REFRESH_INTERVAL_MS || '300000'); // Default to 5 minutes

// Load ABI
const playerAbi = JSON.parse(
  readFileSync('./target/dev/coa_PlayerActions.contract_class.json', 'utf8')
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

async function refreshInventory(account: Account) {
  try {
    console.log('Refreshing inventory...');
    
    const playerContract = new Contract(playerAbi, PLAYER_CONTRACT_ADDRESS, account);
    
    // Call the refresh_inventory function
    const result = await playerContract.refresh_inventory();
    
    console.log('Inventory refreshed successfully:', result);
    return true;
  } catch (error) {
    console.error('Error refreshing inventory:', error);
    return false;
  }
}

async function startRefreshLoop() {
  try {
    const { account } = await setupProvider();
    
    console.log(`Starting inventory refresh loop every ${REFRESH_INTERVAL_MS / 1000} seconds`);
    
    // Initial refresh
    await refreshInventory(account);
    
    // Set up interval
    setInterval(async () => {
      await refreshInventory(account);
    }, REFRESH_INTERVAL_MS);
    
  } catch (error) {
    console.error('Error in refresh loop:', error);
    process.exit(1);
  }
}

// Start the refresh loop
startRefreshLoop().catch(console.error);
