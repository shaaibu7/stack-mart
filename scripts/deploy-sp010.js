#!/usr/bin/env node

/**
 * SP-010 Token Deployment Script
 * 
 * This script handles the deployment of the SP-010 SIP-010 compliant token contract
 * to the Stacks blockchain network.
 */

const { StacksNetwork, StacksTestnet, StacksMainnet } = require('@stacks/network');
const { makeContractDeploy, broadcastTransaction } = require('@stacks/transactions');
const { readFileSync } = require('fs');
const { join } = require('path');

// Configuration
const NETWORKS = {
  testnet: new StacksTestnet(),
  mainnet: new StacksMainnet()
};

async function deployContract(network = 'testnet', privateKey) {
  console.log(`🚀 Deploying SP-010 token contract to ${network}...`);
  
  try {
    // Read contract source
    const contractSource = readFileSync(join(__dirname, '../contracts/sp-010.clar'), 'utf8');
    
    // Create deployment transaction
    const txOptions = {
      contractName: 'sp-010',
      codeBody: contractSource,
      senderKey: privateKey,
      network: NETWORKS[network],
      fee: 75000,
      nonce: 0 // Should be fetched from account
    };
    
    const transaction = await makeContractDeploy(txOptions);
    
    // Broadcast transaction
    const broadcastResponse = await broadcastTransaction(transaction, NETWORKS[network]);
    
    console.log('✅ Contract deployment transaction broadcasted!');
    console.log('Transaction ID:', broadcastResponse.txid);
    console.log('Check status at:', `https://explorer.stacks.co/txid/${broadcastResponse.txid}?chain=${network}`);
    
    return broadcastResponse;
    
  } catch (error) {
    console.error('❌ Deployment failed:', error);
    throw error;
  }
}

// CLI interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const network = args[0] || 'testnet';
  const privateKey = args[1] || process.env.STACKS_PRIVATE_KEY;
  
  if (!privateKey) {
    console.error('❌ Private key required. Provide as argument or STACKS_PRIVATE_KEY env var.');
    process.exit(1);
  }
  
  deployContract(network, privateKey)
    .then(() => {
      console.log('🎉 Deployment completed successfully!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('💥 Deployment failed:', error.message);
      process.exit(1);
    });
}

module.exports = { deployContract };