import { useState, useEffect, useRef } from 'react';
import { connect, isConnected, disconnect, getLocalStorage } from '@stacks/connect';
import { STACKS_MAINNET, STACKS_TESTNET } from '@stacks/network';
import { NETWORK } from '../config/contract';
import { useAccount } from 'wagmi';

const network = NETWORK === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;

export const useStacks = () => {
  // AppKit hooks for modern wallet UI
  const { address: appKitAddress, isConnected: isAppKitConnected } = useAccount();
  
  const prevDataString = useRef<string>('');
  
  const [userData, setUserData] = useState(() => {
    try {
      const data = getLocalStorage();
      const dataString = data ? JSON.stringify(data) : '';
      prevDataString.current = dataString;
      return data || undefined;
    } catch (error) {
      console.warn('Error loading user data:', error);
      prevDataString.current = '';
      return undefined;
    }
  });
  const [isLoading, setIsLoading] = useState(false);
  const [isStacksConnected, setIsStacksConnected] = useState(() => {
    try {
      return isConnected();
    } catch (error) {
      return false;
    }
  });

  useEffect(() => {
    const checkConnection = () => {
      try {
        const connected = isConnected();
        setIsStacksConnected(connected);
        
        if (connected) {
          const data = getLocalStorage();
          // Only update if data actually changed (compare JSON strings)
          const dataString = data ? JSON.stringify(data) : '';
          if (dataString !== prevDataString.current) {
            prevDataString.current = dataString;
            setUserData(data || undefined);
            setIsLoading(false);
          }
        } else {
          // Only update if we had data before
          if (prevDataString.current !== '') {
            prevDataString.current = '';
            setUserData(undefined);
          }
        }
      } catch (error) {
        console.warn('Error in useStacks useEffect:', error);
        setIsStacksConnected(false);
        if (prevDataString.current !== '') {
          prevDataString.current = '';
          setUserData(undefined);
        }
      }
    };

    // Check immediately
    checkConnection();

    // Poll for changes (in case wallet connects externally) - reduced frequency
    const interval = setInterval(checkConnection, 2000); // Changed from 500ms to 2000ms
    
    // Also listen for storage events (when wallet connects in another tab)
    const handleStorageChange = (e: StorageEvent) => {
      // Only react to relevant storage changes
      if (e.key && e.key.includes('stacks')) {
        checkConnection();
      }
    };
    
    window.addEventListener('storage', handleStorageChange);
    
    // Also listen for focus events (user might have connected in another tab)
    const handleFocus = () => {
      checkConnection();
    };
    
    window.addEventListener('focus', handleFocus);
    
    return () => {
      clearInterval(interval);
      window.removeEventListener('storage', handleStorageChange);
      window.removeEventListener('focus', handleFocus);
    };
  }, []); // Empty dependency array - only run on mount

  const connectWallet = async () => {
    setIsLoading(true);
    try {
      // Check if already connected
      if (isConnected()) {
        console.log('Already authenticated');
        const data = getLocalStorage();
        if (data) {
          setUserData(data);
        }
        setIsStacksConnected(true);
        setIsLoading(false);
        return;
      }

      // Connect to wallet
      const response = await connect();
      console.log('Connected:', response.addresses);
      
      // Update state with connection data
      // After connect(), get the data from localStorage
      // The response.addresses is already stored in localStorage by the connect() function
      const data = getLocalStorage();
      if (data) {
        setUserData(data);
        setIsStacksConnected(true);
      }
      
      setIsLoading(false);
    } catch (error) {
      console.error('Error in connectWallet:', error);
      setIsLoading(false);
      setIsStacksConnected(false);
      setUserData(undefined);
    }
  };

  const disconnectWallet = () => {
    try {
      disconnect();
      console.log('User disconnected');
      setUserData(undefined);
      setIsStacksConnected(false);
    } catch (error) {
      console.warn('Error signing out:', error);
      setUserData(undefined);
      setIsStacksConnected(false);
    }
  };

  // Check if either Stacks or AppKit wallet is connected
  const isConnectedValue = isStacksConnected || isAppKitConnected;

  // Compatibility wrapper for userSession (for backward compatibility with existing code)
  const userSession = {
    isUserSignedIn: () => {
      try {
        return isConnected();
      } catch (error) {
        return false;
      }
    },
    loadUserData: () => {
      try {
        return getLocalStorage();
      } catch (error) {
        console.warn('Error loading user data:', error);
        return undefined;
      }
    },
    signUserOut: () => {
      try {
        disconnect();
        setUserData(undefined);
        setIsStacksConnected(false);
      } catch (error) {
        console.warn('Error signing out:', error);
      }
    },
  };

  return {
    userData,
    isConnected: isConnectedValue,
    isLoading,
    connectWallet,
    disconnectWallet,
    network,
    userSession,
    // AppKit specific exports
    appKitAddress,
    isAppKitConnected,
  };
};
