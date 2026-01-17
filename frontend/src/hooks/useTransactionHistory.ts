import { useAccount } from 'wagmi';
import { useStacks } from './useStacks';
import { getStacksAddress } from '../utils/validation';
import { useEffect, useState } from 'react';

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

  // Fetch AppKit transactions
  useEffect(() => {
    const fetchAppKitTransactions = async () => {
      if (!appKitConnected || !appKitAddress) {
        setAppKitTransactions([]);
        return;
      }

      setIsLoading(true);
      try {
        // In production, use a block explorer API or indexer
        // For now, this is a placeholder
        await fetch(
          `https://api.etherscan.io/api?module=account&action=txlist&address=${appKitAddress}&startblock=0&endblock=99999999&sort=desc&apikey=YourApiKeyToken`
        );
        // Note: This requires an API key and proper error handling
        // For demo purposes, we'll use empty array
        setAppKitTransactions([]);
      } catch (error) {
        console.error('Error fetching AppKit transactions:', error);
        setAppKitTransactions([]);
      } finally {
        setIsLoading(false);
      }
    };

    fetchAppKitTransactions();
  }, [appKitConnected, appKitAddress]);

  // Fetch Stacks transactions
  useEffect(() => {
    const fetchStacksTransactions = async () => {
      if (!stacksConnected || !userData) {
        setStacksTransactions([]);
        return;
      }

      const address = getStacksAddress(userData);
      if (!address) {
        setStacksTransactions([]);
        return;
      }

      setIsLoading(true);
      try {
        const response = await fetch(
          `https://api.hiro.so/extended/v1/address/${address}/transactions?limit=10`
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
        setIsLoading(false);
      }
    };

    fetchStacksTransactions();
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

