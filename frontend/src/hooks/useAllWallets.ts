import { useStacks } from './useStacks';
import { useAppKitIntegration } from './useAppKitIntegration';
import { useWalletKitHook } from './useWalletKit';
import { getStacksAddress as getStacksAddressUtil } from '../utils/validation';

/**
 * Unified hook that aggregates all wallet connection states
 * Provides a single interface to check wallet connections across all providers
 */
export const useAllWallets = () => {
  const stacks = useStacks();
  const appKit = useAppKitIntegration();
  const walletKit = useWalletKitHook();

  const isAnyConnected = stacks.isConnected || appKit.isConnected || walletKit.isConnected;
  
  // Helper to extract Stacks address from userData (supports both old and new API formats)
  const getStacksAddress = () => {
    return getStacksAddressUtil(stacks.userData);
  };

  const connectedWallets = [
    stacks.isConnected && { type: 'stacks', address: getStacksAddress() },
    appKit.isConnected && { type: 'appkit', address: appKit.address },
    walletKit.isConnected && { type: 'walletkit', address: walletKit.address },
  ].filter(Boolean) as Array<{ type: string; address: string }>;

  return {
    // Individual wallet states
    stacks,
    appKit,
    walletKit,
    
    // Aggregated states
    isAnyConnected,
    connectedWallets,
    connectedCount: connectedWallets.length,
    
    // Helper methods
    getPrimaryAddress: () => {
      // Priority: Stacks > AppKit > WalletKit
      if (stacks.isConnected) {
        const stacksAddress = getStacksAddress();
        if (stacksAddress) return stacksAddress;
      }
      if (appKit.isConnected && appKit.address) {
        return appKit.address;
      }
      if (walletKit.isConnected && walletKit.address) {
        return walletKit.address;
      }
      return null;
    },
  };
};

