#!/usr/bin/env node

/**
 * SIP-090 Contract Validation Script
 * 
 * This script validates that the SIP-090 NFT contract is fully compliant
 * with the SIP-090 standard and all functions work as expected.
 */

const { StacksTestnet } = require('@stacks/network');
const { 
  callReadOnlyFunction,
  cvToJSON,
  standardPrincipalCV,
  uintCV
} = require('@stacks/transactions');

// Configuration
const NETWORK = new StacksTestnet();
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const CONTRACT_NAME = 'sip-090-nft';

// SIP-090 Required Functions
const REQUIRED_FUNCTIONS = [
  'get-last-token-id',
  'get-token-uri', 
  'get-owner',
  'transfer'
];

// Additional Standard Functions
const STANDARD_FUNCTIONS = [
  'get-total-supply',
  'get-contract-info'
];

async function validateContract() {
  console.log('🔍 Validating SIP-090 NFT Contract...');
  console.log(`Contract: ${CONTRACT_ADDRESS}.${CONTRACT_NAME}`);
  console.log('Network:', NETWORK.isMainnet() ? 'Mainnet' : 'Testnet');
  console.log('');

  let allTestsPassed = true;

  try {
    // Test 1: Contract Info
    console.log('📋 Testing Contract Information...');
    const contractInfo = await callReadOnlyFunction({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CONTRACT_NAME,
      functionName: 'get-contract-info',
      functionArgs: [],
      network: NETWORK,
      senderAddress: CONTRACT_ADDRESS
    });

    if (contractInfo.type === 'ok') {
      const info = cvToJSON(contractInfo.value);
      console.log('✅ Contract Info:', info);
      
      // Validate required fields
      if (!info.name || !info.symbol || !info['base-uri']) {
        console.log('❌ Missing required contract metadata fields');
        allTestsPassed = false;
      }
    } else {
      console.log('❌ Failed to get contract info');
      allTestsPassed = false;
    }

    // Test 2: Total Supply
    console.log('\n📊 Testing Total Supply...');
    const totalSupply = await callReadOnlyFunction({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CONTRACT_NAME,
      functionName: 'get-total-supply',
      functionArgs: [],
      network: NETWORK,
      senderAddress: CONTRACT_ADDRESS
    });

    if (totalSupply.type === 'ok') {
      const supply = cvToJSON(totalSupply.value);
      console.log('✅ Total Supply:', supply);
    } else {
      console.log('❌ Failed to get total supply');
      allTestsPassed = false;
    }

    // Test 3: Last Token ID
    console.log('\n🆔 Testing Last Token ID...');
    const lastTokenId = await callReadOnlyFunction({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CONTRACT_NAME,
      functionName: 'get-last-token-id',
      functionArgs: [],
      network: NETWORK,
      senderAddress: CONTRACT_ADDRESS
    });

    if (lastTokenId.type === 'ok') {
      const tokenId = cvToJSON(lastTokenId.value);
      console.log('✅ Last Token ID:', tokenId);
    } else {
      console.log('❌ Failed to get last token ID');
      allTestsPassed = false;
    }

    // Test 4: Token Owner (for token 1 if it exists)
    console.log('\n👤 Testing Token Owner Query...');
    const tokenOwner = await callReadOnlyFunction({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CONTRACT_NAME,
      functionName: 'get-owner',
      functionArgs: [uintCV(1)],
      network: NETWORK,
      senderAddress: CONTRACT_ADDRESS
    });

    if (tokenOwner.type === 'ok') {
      const owner = cvToJSON(tokenOwner.value);
      console.log('✅ Token 1 Owner:', owner);
    } else {
      const error = cvToJSON(tokenOwner.value);
      if (error === 404) {
        console.log('✅ Token 1 does not exist (expected for new contract)');
      } else {
        console.log('❌ Unexpected error getting token owner:', error);
        allTestsPassed = false;
      }
    }

    // Test 5: Token URI (for token 1 if it exists)
    console.log('\n🔗 Testing Token URI Query...');
    const tokenUri = await callReadOnlyFunction({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CONTRACT_NAME,
      functionName: 'get-token-uri',
      functionArgs: [uintCV(1)],
      network: NETWORK,
      senderAddress: CONTRACT_ADDRESS
    });

    if (tokenUri.type === 'ok') {
      const uri = cvToJSON(tokenUri.value);
      console.log('✅ Token 1 URI:', uri);
    } else {
      const error = cvToJSON(tokenUri.value);
      if (error === 404) {
        console.log('✅ Token 1 URI not found (expected for new contract)');
      } else {
        console.log('❌ Unexpected error getting token URI:', error);
        allTestsPassed = false;
      }
    }

    // Test 6: Contract Status
    console.log('\n⚡ Testing Contract Status...');
    const contractStatus = await callReadOnlyFunction({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CONTRACT_NAME,
      functionName: 'get-contract-status',
      functionArgs: [],
      network: NETWORK,
      senderAddress: CONTRACT_ADDRESS
    });

    if (contractStatus.type === 'ok') {
      const status = cvToJSON(contractStatus.value);
      console.log('✅ Contract Status:', status);
      
      // Check if contract is paused
      if (status.paused) {
        console.log('⚠️  Contract is currently paused');
      }
    } else {
      console.log('❌ Failed to get contract status');
      allTestsPassed = false;
    }

    // Test 7: Pause State
    console.log('\n⏸️  Testing Pause State...');
    const isPaused = await callReadOnlyFunction({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CONTRACT_NAME,
      functionName: 'is-paused',
      functionArgs: [],
      network: NETWORK,
      senderAddress: CONTRACT_ADDRESS
    });

    if (isPaused.type === 'ok') {
      const paused = cvToJSON(isPaused.value);
      console.log('✅ Is Paused:', paused);
    } else {
      console.log('❌ Failed to check pause state');
      allTestsPassed = false;
    }

    // Final Results
    console.log('\n' + '='.repeat(50));
    if (allTestsPassed) {
      console.log('🎉 All validation tests passed!');
      console.log('✅ Contract appears to be SIP-090 compliant');
      process.exit(0);
    } else {
      console.log('❌ Some validation tests failed');
      console.log('⚠️  Contract may not be fully compliant');
      process.exit(1);
    }

  } catch (error) {
    console.error('💥 Validation failed with error:', error);
    process.exit(1);
  }
}

// Function availability check
async function checkFunctionAvailability() {
  console.log('🔧 Checking SIP-090 Function Availability...');
  
  const allFunctions = [...REQUIRED_FUNCTIONS, ...STANDARD_FUNCTIONS];
  
  for (const functionName of allFunctions) {
    try {
      const result = await callReadOnlyFunction({
        contractAddress: CONTRACT_ADDRESS,
        contractName: CONTRACT_NAME,
        functionName: functionName,
        functionArgs: functionName === 'get-owner' || functionName === 'get-token-uri' 
          ? [uintCV(1)] 
          : [],
        network: NETWORK,
        senderAddress: CONTRACT_ADDRESS
      });
      
      console.log(`✅ ${functionName}: Available`);
    } catch (error) {
      console.log(`❌ ${functionName}: Not available or error`);
    }
  }
  console.log('');
}

// Run validation
async function main() {
  await checkFunctionAvailability();
  await validateContract();
}

main();