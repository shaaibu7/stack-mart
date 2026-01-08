import { useState, useEffect, useRef } from 'react';
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
          if (data) {
            setUserData(data);
            setIsLoading(false);
          } else {
            setUserData(undefined);
          }
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
    const interval = setInterval(checkUserSession, 500); // More frequent polling
    
    // Also listen for storage events (when wallet connects in another tab)
    const handleStorageChange = (e: StorageEvent) => {
      // Only react to relevant storage changes
      if (e.key && e.key.includes('stacks')) {
        checkUserSession();
      }
    };
    
    window.addEventListener('storage', handleStorageChange);
    
    // Also listen for focus events (user might have connected in another tab)
    const handleFocus = () => {
      checkUserSession();
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
      // Force a check immediately
      const checkConnection = () => {
        try {
          const isSignedIn = userSession.isUserSignedIn();
          setIsStacksConnected(isSignedIn);
          
          if (isSignedIn) {
            const data = userSession.loadUserData();
            if (data) {
              setUserData(data);
              setIsLoading(false);
              return true;
            }
          }
          return false;
        } catch (error) {
          console.error('Error checking connection:', error);
          return false;
        }
      };

      // Check immediately
      if (checkConnection()) {
        return;
      }

      // If not connected yet, poll for changes
      let attempts = 0;
      const maxAttempts = 20; // Increased attempts
      
      const interval = setInterval(() => {
        attempts++;
        if (checkConnection()) {
          clearInterval(interval);
          return;
        }
        
        // If max attempts reached, stop checking
        if (attempts >= maxAttempts) {
          setIsLoading(false);
          clearInterval(interval);
          // Final check
          try {
            const data = userSession.loadUserData();
            setUserData(data || undefined);
            setIsStacksConnected(userSession.isUserSignedIn());
          } catch (error) {
            console.error('Error loading user data after connect:', error);
            setUserData(undefined);
            setIsStacksConnected(false);
          }
        }
      }, 300); // Check every 300ms
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
