#!/usr/bin/env node

/**
 * SIP-090 NFT Contract Deployment Script
 * Deploys and initializes the StackMart NFT contract
 */

const { StacksTestnet, StacksMainnet } = require('@stacks/network');
const { 
  makeContractDeploy,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode
} = require('@stacks/transactions');
const { readFileSync } = require('fs');
const path = require('path');

// Configuration
const NETWORK = process.env.NETWORK || 'testnet';
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const CONTRACT_NAME = 'sip-090-nft';

if (!PRIVATE_KEY) {
  console.error('Error: PRIVATE_KEY environment variable is required');
  process.exit(1);
}

async function deployContract() {
  try {
    console.log(`Deploying SIP-090 NFT contract to ${NETWORK}...`);
    
    // Read contract source
    const contractPath = path.join(__dirname, '..', 'contracts', 'sip-090-nft.clar');
    const contractSource = readFileSync(contractPath, 'utf8');
    
    // Set up network
    const network = NETWORK === 'mainnet' ? new StacksMainnet() : new StacksTestnet();
    
    // Create deployment transaction
    const txOptions = {
      contractName: CONTRACT_NAME,
      codeBody: contractSource,
      senderKey: PRIVATE_KEY,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
      fee: 10000 // 0.01 STX
    };
    
    const transaction = await makeContractDeploy(txOptions);
    
    console.log('Broadcasting transaction...');
    const broadcastResponse = await broadcastTransaction(transaction, network);
    
    if (broadcastResponse.error) {
      console.error('Deployment failed:', broadcastResponse.error);
      console.error('Reason:', broadcastResponse.reason);
      process.exit(1);
    }
    
    console.log('✅ Contract deployed successfully!');
    console.log('Transaction ID:', broadcastResponse.txid);
    console.log(`Contract ID: ${transaction.auth.spendingCondition.signer}.${CONTRACT_NAME}`);
    
    // Wait for confirmation
    console.log('Waiting for transaction confirmation...');
    await waitForConfirmation(broadcastResponse.txid, network);
    
    console.log('🎉 Deployment complete and confirmed!');
    
  } catch (error) {
    console.error('Deployment error:', error);
    process.exit(1);
  }
}

async function waitForConfirmation(txid, network) {
  const maxAttempts = 30;
  let attempts = 0;
  
  while (attempts < maxAttempts) {
    try {
      const response = await fetch(`${network.coreApiUrl}/extended/v1/tx/${txid}`);
      const txData = await response.json();
      
      if (txData.tx_status === 'success') {
        console.log('✅ Transaction confirmed in block:', txData.block_height);
        return;
      } else if (txData.tx_status === 'abort_by_response' || txData.tx_status === 'abort_by_post_condition') {
        throw new Error(`Transaction failed: ${txData.tx_status}`);
      }
      
      console.log(`Attempt ${attempts + 1}/${maxAttempts}: Status = ${txData.tx_status}`);
      await new Promise(resolve => setTimeout(resolve, 10000)); // Wait 10 seconds
      attempts++;
      
    } catch (error) {
      console.log(`Confirmation check failed (attempt ${attempts + 1}):`, error.message);
      attempts++;
      await new Promise(resolve => setTimeout(resolve, 10000));
    }
  }
  
  console.log('⚠️  Could not confirm transaction within timeout period');
}

// Run deployment
deployContract();