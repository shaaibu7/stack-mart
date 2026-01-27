import { useAccount } from 'wagmi';
import { useStacks } from './useStacks';
import { getStacksAddress } from '../utils/validation';
import { useEffect, useState, useRef } from 'react';

interface Transaction {
  hash: string;
  chain: 'stacks' | 'evm';
  type: 'payment' | 'contract' | 'other';
  timestamp: number;
  amount?: string;
  status: 'pending' | 'confirmed' | 'failed';
}

/**
 * Hook to fetch transaction history from all connected wallets
 */
export const useTransactionHistory = () => {
  const { address: appKitAddress, isConnected: appKitConnected } = useAccount();
  const { userData, isConnected: stacksConnected } = useStacks();
  
  const [appKitTransactions, setAppKitTransactions] = useState<Transaction[]>([]);
  const [stacksTransactions, setStacksTransactions] = useState<Transaction[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const loadingRef = useRef({ appKit: false, stacks: false });

  const updateLoadingState = () => {
    setIsLoading(loadingRef.current.appKit || loadingRef.current.stacks);
  };

  // Fetch AppKit transactions
  useEffect(() => {
    const fetchAppKitTransactions = async () => {
      if (!appKitConnected || !appKitAddress) {
        setAppKitTransactions([]);
        loadingRef.current.appKit = false;
        updateLoadingState();
        return;
      }

      loadingRef.current.appKit = true;
      updateLoadingState();
      try {
        // In production, use a block explorer API or indexer
        // For now, this is a placeholder - transactions will be fetched via indexer or block explorer
        // Note: This requires an API key from environment variables and proper error handling
        // For demo purposes, we'll use empty array
        const apiKey = import.meta.env.VITE_ETHERSCAN_API_KEY;
        if (apiKey) {
          const response = await fetch(
            `https://api.etherscan.io/api?module=account&action=txlist&address=${appKitAddress}&startblock=0&endblock=99999999&sort=desc&apikey=${apiKey}`
          );
          if (response.ok) {
            const data = await response.json();
            // Parse and set transactions if API returns data
            // For now, keeping empty array as placeholder
            // TODO: Parse data.result and map to Transaction[] format
          }
        }
        // For demo purposes, we'll use empty array
        setAppKitTransactions([]);
      } catch (error) {
        console.error('Error fetching AppKit transactions:', error);
        setAppKitTransactions([]);
      } finally {
        loadingRef.current.appKit = false;
        updateLoadingState();
      }
    };

    fetchAppKitTransactions();
  }, [appKitConnected, appKitAddress]);

  // Fetch Stacks transactions
  const lastTxAddressRef = useRef<string | null>(null);
  const txFetchTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    // Clear any pending fetch
    if (txFetchTimeoutRef.current) {
      clearTimeout(txFetchTimeoutRef.current);
    }

    const fetchStacksTransactions = async () => {
      if (!stacksConnected || !userData) {
        setStacksTransactions([]);
        loadingRef.current.stacks = false;
        updateLoadingState();
        return;
      }

      const address = getStacksAddress(userData);
      if (!address) {
        setStacksTransactions([]);
        loadingRef.current.stacks = false;
        updateLoadingState();
        return;
      }

      loadingRef.current.stacks = true;
      updateLoadingState();
      try {
        const response = await fetch(
          `https://api.hiro.so/extended/v1/address/${address}/transactions?limit=50`
        );
        
        if (response.ok) {
          const data = await response.json();
          const transactions: Transaction[] = data.results?.map((tx: any) => ({
            hash: tx.tx_id,
            chain: 'stacks',
            type: tx.tx_type === 'contract_call' ? 'contract' : 'other',
            timestamp: tx.burn_block_time,
            status: tx.tx_status === 'success' ? 'confirmed' : 'pending',
          })) || [];
          setStacksTransactions(transactions);
        }
      } catch (error) {
        console.error('Error fetching Stacks transactions:', error);
        setStacksTransactions([]);
      } finally {
        loadingRef.current.stacks = false;
        updateLoadingState();
      }
    };

    fetchStacksTransactions();

    return () => {
      if (txFetchTimeoutRef.current) {
        clearTimeout(txFetchTimeoutRef.current);
      }
    };
  }, [stacksConnected, userData]);

  const allTransactions = [
    ...stacksTransactions,
    ...appKitTransactions,
  ].sort((a, b) => b.timestamp - a.timestamp);

  return {
    transactions: allTransactions,
    stacksTransactions,
    appKitTransactions,
    isLoading,
  };
};

