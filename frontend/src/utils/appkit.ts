/**
 * AppKit Utility Functions
 * Helper functions for working with Reown AppKit
 */

/**
 * Format EVM address for display
 */
export const formatEVMAddress = (address: string): string => {
  if (!address) return '';
  if (address.length < 10) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
};

/**
 * Check if address is a valid EVM address
 */
export const isValidEVMAddress = (address: string): boolean => {
  return /^0x[a-fA-F0-9]{40}$/.test(address);
};

/**
 * Get network name from chain ID
 */
export const getNetworkName = (chainId?: number): string => {
  const networks: Record<number, string> = {
    1: 'Ethereum Mainnet',
    11155111: 'Sepolia Testnet',
  };
  return chainId ? networks[chainId] || `Chain ${chainId}` : 'Unknown';
};

