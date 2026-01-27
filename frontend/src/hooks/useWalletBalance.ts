import { useAccount, useBalance } from 'wagmi';
import { useWalletKitLink } from '@walletkit/react-link';
import { useStacks } from './useStacks';
import { getStacksAddress } from '../utils/validation';
import { useEffect, useState, useRef } from 'react';

/**
 * Hook to get wallet balances across all connected wallets
 * Supports Stacks, AppKit (EVM), and WalletKit
 */
export const useWalletBalance = () => {
  const { address: appKitAddress, isConnected: appKitConnected } = useAccount();
  const { data: appKitBalance } = useBalance({
    address: appKitAddress,
  });
  
  const walletKit = useWalletKitLink() as any;
  const { userData, isConnected: stacksConnected } = useStacks();
  
  const [walletKitBalance, setWalletKitBalance] = useState<string | null>(null);
  const [stacksBalance, setStacksBalance] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  // Fetch WalletKit balance
  useEffect(() => {
    const fetchWalletKitBalance = async () => {
      const isConnected = walletKit?.isConnected;
      const address = walletKit?.address;
      
      if (isConnected && address) {
        setIsLoading(true);
        try {
          // WalletKit balance fetching (if available)
          const balance = await walletKit.getBalance?.();
          if (balance) {
            setWalletKitBalance(balance);
          }
        } catch (error) {
          console.error('Error fetching WalletKit balance:', error);
        } finally {
          setIsLoading(false);
        }
      } else {
        setWalletKitBalance(null);
      }
    };

    fetchWalletKitBalance();
  }, [walletKit]);

  // Fetch Stacks balance
  const lastAddressRef = useRef<string | null>(null);
  const balanceFetchTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  
  useEffect(() => {
    // Clear any pending fetch
    if (balanceFetchTimeoutRef.current) {
      clearTimeout(balanceFetchTimeoutRef.current);
    }

    const fetchStacksBalance = async () => {
      if (!stacksConnected || !userData) {
        setStacksBalance(null);
        lastAddressRef.current = null;
        return;
      }

      const address = getStacksAddress(userData);
      if (!address) {
        setStacksBalance(null);
        lastAddressRef.current = null;
        return;
      }

      // Skip if same address
      if (address === lastAddressRef.current) {
        return;
      }

      lastAddressRef.current = address;
      setIsLoading(true);
      
      // Debounce the fetch
      balanceFetchTimeoutRef.current = setTimeout(async () => {
        try {
          const response = await fetch(
            `https://api.hiro.so/v2/accounts/${address}?proof=0`
          );
          if (response.ok) {
            const data = await response.json();
            const balance = (data.balance / 1000000).toFixed(6); // Convert microSTX to STX
            setStacksBalance(balance);
          }
        } catch (error) {
          console.error('Error fetching Stacks balance:', error);
        } finally {
          setIsLoading(false);
        }
      }, 300); // 300ms debounce
    };

    fetchStacksBalance();

    return () => {
      if (balanceFetchTimeoutRef.current) {
        clearTimeout(balanceFetchTimeoutRef.current);
      }
    };
  }, [stacksConnected, userData]);

  return {
    // AppKit balance (EVM chains)
    appKitBalance: appKitBalance ? {
      value: appKitBalance.value,
      decimals: appKitBalance.decimals,
      symbol: appKitBalance.symbol,
      formatted: String(Number(appKitBalance.value) / Math.pow(10, appKitBalance.decimals)),
    } : null,
    appKitBalanceLoading: false,
    
    // WalletKit balance
    walletKitBalance,
    
    // Stacks balance
    stacksBalance,
    
    // Aggregated
    isLoading: isLoading,
    hasAnyBalance: !!(appKitBalance || walletKitBalance || stacksBalance),
  };
};

