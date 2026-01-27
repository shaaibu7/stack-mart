/**
 * SP-010 Token Usage Examples
 * 
 * This file demonstrates how to interact with the SP-010 token contract
 * using the Stacks.js library.
 */

const { 
  makeContractCall,
  makeContractCallWithTransferSTX,
  callReadOnlyFunction,
  broadcastTransaction,
  AnchorMode,
  PostConditionMode,
  createSTXPostCondition,
  FungibleConditionCode,
  makeStandardSTXPostCondition
} = require('@stacks/transactions');
const { StacksTestnet } = require('@stacks/network');
const { Cl } = require('@stacks/transactions');

const network = new StacksTestnet();
const contractAddress = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const contractName = 'sp-010';

/**
 * Get token balance for a principal
 */
async function getBalance(principalAddress) {
  try {
    const result = await callReadOnlyFunction({
      contractAddress,
      contractName,
      functionName: 'get-balance',
      functionArgs: [Cl.principal(principalAddress)],
      network,
      senderAddress: principalAddress
    });
    
    console.log(`Balance for ${principalAddress}:`, result);
    return result;
  } catch (error) {
    console.error('Error getting balance:', error);
    throw error;
  }
}

/**
 * Get token metadata
 */
async function getTokenMetadata() {
  try {
    const [name, symbol, decimals, uri, totalSupply] = await Promise.all([
      callReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: 'get-name',
        functionArgs: [],
        network,
        senderAddress: contractAddress
      }),
      callReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: 'get-symbol',
        functionArgs: [],
        network,
        senderAddress: contractAddress
      }),
      callReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: 'get-decimals',
        functionArgs: [],
        network,
        senderAddress: contractAddress
      }),
      callReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: 'get-token-uri',
        functionArgs: [],
        network,
        senderAddress: contractAddress
      }),
      callReadOnlyFunction({
        contractAddress,
        contractName,
        functionName: 'get-total-supply',
        functionArgs: [],
        network,
        senderAddress: contractAddress
      })
    ]);
    
    const metadata = {
      name: name.value,
      symbol: symbol.value,
      decimals: decimals.value,
      uri: uri.value,
      totalSupply: totalSupply.value
    };
    
    console.log('Token Metadata:', metadata);
    return metadata;
  } catch (error) {
    console.error('Error getting metadata:', error);
    throw error;
  }
}

/**
 * Transfer tokens
 */
async function transferTokens(amount, senderKey, recipientAddress, memo = null) {
  try {
    const txOptions = {
      contractAddress,
      contractName,
      functionName: 'transfer',
      functionArgs: [
        Cl.uint(amount),
        Cl.principal(senderAddress), // Will be derived from senderKey
        Cl.principal(recipientAddress),
        memo ? Cl.some(Cl.bufferFromUtf8(memo)) : Cl.none()
      ],
      senderKey,
      network,
      anchorMode: AnchorMode.Any,
      postConditionMode: PostConditionMode.Allow,
      fee: 10000
    };
    
    const transaction = await makeContractCall(txOptions);
    const broadcastResponse = await broadcastTransaction(transaction, network);
    
    console.log('Transfer transaction broadcasted:', broadcastResponse.txid);
    return broadcastResponse;
  } catch (error) {
    console.error('Error transferring tokens:', error);
    throw error;
  }
}

/**
 * Example usage
 */
async function main() {
  console.log('🪙 SP-010 Token Usage Examples\n');
  
  try {
    // Get token metadata
    console.log('📋 Getting token metadata...');
    await getTokenMetadata();
    console.log('');
    
    // Get balance example
    console.log('💰 Getting balance...');
    await getBalance(contractAddress);
    console.log('');
    
    console.log('✅ Examples completed successfully!');
  } catch (error) {
    console.error('❌ Example failed:', error);
  }
}

// Run examples if called directly
if (require.main === module) {
  main();
}

module.exports = {
  getBalance,
  getTokenMetadata,
  transferTokens
};