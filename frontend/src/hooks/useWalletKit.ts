import { useWalletKitLink } from '@walletkit/react-link';
import { useState, useEffect } from 'react';

/**
 * Custom hook for WalletKit SDK integration
 * Provides access to WalletKit's gasless wallet features
 */
export const useWalletKitHook = () => {
  const walletKit = useWalletKitLink() as any;
  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    if (walletKit) {
      setIsInitialized(true);
    }
  }, [walletKit]);

  return {
    walletKit,
    isInitialized,
    // WalletKit provides methods like:
    // - connect(): Connect to wallet
    // - disconnect(): Disconnect wallet
    // - signMessage(): Sign messages
    // - sendTransaction(): Send gasless transactions
    isConnected: walletKit?.isConnected || false,
    address: walletKit?.address || null,
    chain: walletKit?.chain || null,
  };
};

