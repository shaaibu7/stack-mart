import { useState, useEffect } from 'react';
import { connect, isConnected, getLocalStorage } from '@stacks/connect';
import { formatAddress } from '../utils/validation';

interface BitcoinWalletSelectorProps {
  userSession: any; // Compatibility wrapper from useStacks
  onConnect: () => void;
  onDisconnect: () => void;
  isConnected: boolean;
  userData?: any;
  isLoading: boolean;
}

export const BitcoinWalletSelector = ({
  userSession,
  onConnect,
  onDisconnect,
  isConnected: isConnectedProp,
  userData,
  isLoading,
}: BitcoinWalletSelectorProps) => {
  const [localUserData, setLocalUserData] = useState(userData);
  const [isConnecting, setIsConnecting] = useState(false);

  // Listen for connection changes
  useEffect(() => {
    const checkSession = () => {
      try {
        if (isConnected()) {
          const data = getLocalStorage();
          setLocalUserData(data || undefined);
        } else {
          setLocalUserData(undefined);
        }
      } catch (error) {
        console.warn('Error checking session:', error);
        setLocalUserData(undefined);
      }
    };

    // Check immediately
    checkSession();

    // Poll for changes
    const interval = setInterval(checkSession, 500);
    
    return () => clearInterval(interval);
  }, []);

  // Update local state when prop changes
  useEffect(() => {
    setLocalUserData(userData);
  }, [userData]);

  const connectToWallet = async () => {
    setIsConnecting(true);
    
    try {
      // Check if already connected
      if (isConnected()) {
        console.log('Already authenticated');
        const data = getLocalStorage();
        if (data) {
          setLocalUserData(data);
        }
        setIsConnecting(false);
        onConnect();
        return;
      }

      // Connect to wallet using new API - this will show the Stacks Connect modal
      const response = await connect();
      console.log('Connected:', response.addresses);
      
      // Update local state
      const data = getLocalStorage();
      if (data) {
        setLocalUserData(data);
      }
      
      setIsConnecting(false);
      
      // Trigger the onConnect callback which will update state in the hook
      onConnect();
    } catch (error) {
      console.error('Error connecting wallet:', error);
      setIsConnecting(false);
    }
  };

  const handleDisconnect = () => {
    try {
      userSession.signUserOut();
      onDisconnect();
    } catch (error) {
      console.error('Error disconnecting wallet:', error);
    }
  };

  // Use local userData if available, fallback to prop
  const currentUserData = localUserData || userData;
  const currentIsConnected = isConnected() || isConnectedProp;

  // If connected, show connected state
  if (currentIsConnected && currentUserData) {
    const address = currentUserData?.profile?.stxAddress?.mainnet || currentUserData?.profile?.stxAddress?.testnet;
    const shortAddress = address ? formatAddress(address) : 'Connected';

    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
        <div style={{ 
          display: 'flex', 
          alignItems: 'center', 
          gap: '0.5rem',
          padding: '0.5rem 1rem',
          backgroundColor: 'rgba(255, 255, 255, 0.2)',
          borderRadius: 'var(--radius-md)',
          fontFamily: 'monospace',
          fontSize: '0.875rem'
        }}>
          <span style={{ 
            width: '8px', 
            height: '8px', 
            borderRadius: '50%', 
            backgroundColor: 'var(--success)',
            display: 'inline-block'
          }}></span>
          {shortAddress}
        </div>
        <button 
          className="btn btn-secondary btn-sm"
          onClick={handleDisconnect} 
          disabled={isLoading}
          style={{ backgroundColor: 'rgba(255, 255, 255, 0.2)', color: 'white', border: '1px solid rgba(255, 255, 255, 0.3)' }}
        >
          {isLoading ? (
            <>
              <span className="loading"></span>
              Disconnecting...
            </>
          ) : (
            'Disconnect'
          )}
        </button>
      </div>
    );
  }

  return (
    <button
      className="btn btn-primary"
      onClick={connectToWallet}
      disabled={isLoading || isConnecting}
      style={{ backgroundColor: 'rgba(255, 255, 255, 0.2)', color: 'white', border: '1px solid rgba(255, 255, 255, 0.3)' }}
    >
      {(isLoading || isConnecting) ? (
        <>
          <span className="loading"></span>
          Connecting...
        </>
      ) : (
        '🔗 Connect Wallet'
      )}
    </button>
  );
};

