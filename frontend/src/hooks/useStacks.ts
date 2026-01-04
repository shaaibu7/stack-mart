import { useState, useEffect } from 'react';
import { AppConfig, UserSession, showConnect } from '@stacks/connect';
import { STACKS_MAINNET, STACKS_TESTNET } from '@stacks/network';
import { NETWORK } from '../config/contract';
import { useAppKit } from '@reown/appkit/react';
import { useAccount } from 'wagmi';

const appConfig = new AppConfig(['store_write', 'publish_data']);
const userSession = new UserSession({ appConfig });

const network = NETWORK === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;

export const useStacks = () => {
  // AppKit hooks for modern wallet UI
  const { open } = useAppKit();
  const { address: appKitAddress, isConnected: isAppKitConnected } = useAccount();
  
  const [userData, setUserData] = useState(() => {
    try {
      return userSession.isUserSignedIn() ? userSession.loadUserData() : undefined;
    } catch (error) {
      console.warn('Error loading user data:', error);
      return undefined;
    }
  });
  const [isLoading, setIsLoading] = useState(false);
  const [isStacksConnected, setIsStacksConnected] = useState(() => {
    try {
      return userSession.isUserSignedIn();
    } catch (error) {
      return false;
    }
  });

  useEffect(() => {
    const checkUserSession = () => {
      try {
        const isSignedIn = userSession.isUserSignedIn();
        setIsStacksConnected(isSignedIn);
        
        if (isSignedIn) {
          const data = userSession.loadUserData();
          setUserData(data || undefined);
        } else {
          setUserData(undefined);
        }
      } catch (error) {
        console.warn('Error in useStacks useEffect:', error);
        setIsStacksConnected(false);
        setUserData(undefined);
      }
    };

    // Check immediately
    checkUserSession();

    // Poll for changes (in case wallet connects externally)
    const interval = setInterval(checkUserSession, 1000);
    
    // Also listen for storage events (when wallet connects in another tab)
    const handleStorageChange = () => {
      checkUserSession();
    };
    
    window.addEventListener('storage', handleStorageChange);
    
    return () => {
      clearInterval(interval);
      window.removeEventListener('storage', handleStorageChange);
    };
  }, []);

  const connectWallet = async () => {
    setIsLoading(true);
    try {
      // Wait a bit for userSession to be updated by showConnect
      // Then check multiple times to ensure we get the updated data
      let attempts = 0;
      const maxAttempts = 10;
      
      const checkConnection = setInterval(() => {
        attempts++;
        try {
          const isSignedIn = userSession.isUserSignedIn();
          setIsStacksConnected(isSignedIn);
          
          if (isSignedIn) {
            const data = userSession.loadUserData();
            if (data) {
              setUserData(data);
              setIsLoading(false);
              clearInterval(checkConnection);
              return;
            }
          }
          
          // If max attempts reached, stop checking
          if (attempts >= maxAttempts) {
            setIsLoading(false);
            clearInterval(checkConnection);
            // Final check
            try {
              const data = userSession.loadUserData();
              setUserData(data || undefined);
            } catch (error) {
              console.error('Error loading user data after connect:', error);
              setUserData(undefined);
            }
          }
        } catch (error) {
          console.error('Error checking connection:', error);
          if (attempts >= maxAttempts) {
            setIsLoading(false);
            clearInterval(checkConnection);
          }
        }
      }, 200); // Check every 200ms
    } catch (error) {
      console.error('Error in connectWallet:', error);
      setIsLoading(false);
    }
  };

  const disconnectWallet = () => {
    try {
      userSession.signUserOut();
    } catch (error) {
      console.warn('Error signing out:', error);
    }
    setUserData(undefined);
  };

  // Check if either Stacks or AppKit wallet is connected
  const isConnected = isStacksConnected || isAppKitConnected;

  return {
    userData,
    isConnected,
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
