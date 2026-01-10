import { useState, useEffect } from 'react';
import { connect, isConnected, getLocalStorage } from '@stacks/connect';
import { STACKS_MAINNET, STACKS_TESTNET } from '@stacks/network';
import { NETWORK } from '../config/contract';
import { formatAddress } from '../utils/validation';

// Wallet definitions
const BITCOIN_WALLETS = [
  {
    id: 'leather',
    name: 'Leather',
    description: 'Formerly Hiro Wallet - Bitcoin & Stacks',
    icon: '🟠',
    downloadUrl: 'https://leather.io/install-extension',
    extensionId: 'leather',
  },
  {
    id: 'xverse',
    name: 'Xverse',
    description: 'Bitcoin & Stacks Wallet',
    icon: '🟣',
    downloadUrl: 'https://www.xverse.app/',
    extensionId: 'xverse',
  },
  {
    id: 'okx',
    name: 'OKX Wallet',
    description: 'Multi-chain wallet with Bitcoin support',
    icon: '🔵',
    downloadUrl: 'https://www.okx.com/web3',
    extensionId: 'okx',
  },
  {
    id: 'unisat',
    name: 'UniSat Wallet',
    description: 'Bitcoin Ordinals & BRC-20',
    icon: '🟡',
    downloadUrl: 'https://unisat.io/',
    extensionId: 'unisat',
  },
];

const network = NETWORK === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;

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
  isConnected,
  userData,
  isLoading,
}: BitcoinWalletSelectorProps) => {
  const [showWalletList, setShowWalletList] = useState(false);
  const [availableWallets, setAvailableWallets] = useState<string[]>([]);
  const [localUserData, setLocalUserData] = useState(userData);
  const [connectingWallet, setConnectingWallet] = useState<string | null>(null);

  // Listen for userSession changes
  useEffect(() => {
    const checkSession = () => {
      try {
        if (userSession.isUserSignedIn()) {
          const data = userSession.loadUserData();
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
  }, [userSession]);

  // Update local state when prop changes
  useEffect(() => {
    setLocalUserData(userData);
  }, [userData]);

  // Detect available wallets
  useEffect(() => {
    const detectWallets = () => {
      const wallets: string[] = [];
      
      // Check for Leather (Hiro Wallet)
      if (typeof window !== 'undefined' && (window as any).LeatherProvider || (window as any).hiroWalletProvider) {
        wallets.push('leather');
      }
      
      // Check for Xverse
      if (typeof window !== 'undefined' && (window as any).XverseProviders) {
        wallets.push('xverse');
      }
      
      // Check for OKX
      if (typeof window !== 'undefined' && (window as any).okxwallet) {
        wallets.push('okx');
      }
      
      // Check for UniSat
      if (typeof window !== 'undefined' && (window as any).unisat) {
        wallets.push('unisat');
      }
      
      setAvailableWallets(wallets);
    };

    detectWallets();
    
    // Re-check periodically in case wallet is installed after page load
    const interval = setInterval(detectWallets, 2000);
    return () => clearInterval(interval);
  }, []);

  const connectToWallet = async (walletId?: string) => {
    setShowWalletList(false);
    setConnectingWallet(walletId || null);
    
    try {
      console.log('Connecting to wallet:', walletId);
      
      // Check if already connected
      if (isConnected()) {
        console.log('Already authenticated');
        const data = getLocalStorage();
        if (data) {
          setLocalUserData(data);
        }
        setConnectingWallet(null);
        onConnect();
        return;
      }

      // Connect to wallet using new API
      const response = await connect();
      console.log('Connected:', response.addresses);
      
      // Update local state
      const data = getLocalStorage();
      if (data) {
        setLocalUserData(data);
      }
      
      setConnectingWallet(null);
      
      // Trigger the onConnect callback which will update state in the hook
      onConnect();
    } catch (error) {
      console.error('Error connecting wallet:', error);
      setConnectingWallet(null);
      setShowWalletList(true); // Re-show the wallet list on error
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
  const currentIsConnected = userSession.isUserSignedIn() || isConnected;

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
    <div style={{ position: 'relative' }}>
      {!showWalletList ? (
        <button
          className="btn btn-primary"
          onClick={() => setShowWalletList(true)}
          disabled={isLoading}
          style={{ backgroundColor: 'rgba(255, 255, 255, 0.2)', color: 'white', border: '1px solid rgba(255, 255, 255, 0.3)' }}
        >
          {isLoading ? (
            <>
              <span className="loading"></span>
              Connecting...
            </>
          ) : (
            '🔗 Connect Bitcoin Wallet'
          )}
        </button>
      ) : (
        <div style={{
          position: 'absolute',
          top: '100%',
          right: 0,
          marginTop: '0.5rem',
          backgroundColor: 'rgba(0, 0, 0, 0.95)',
          borderRadius: 'var(--radius-lg)',
          padding: '1.5rem',
          minWidth: '350px',
          zIndex: 1000,
          border: '1px solid rgba(255, 255, 255, 0.2)',
          boxShadow: '0 10px 40px rgba(0, 0, 0, 0.5)',
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
            <h3 style={{ margin: 0, fontSize: '1.1rem', color: 'white', fontWeight: 'bold' }}>
              Connect Bitcoin Wallet
            </h3>
            <button
              onClick={() => setShowWalletList(false)}
              style={{ 
                background: 'none', 
                border: 'none', 
                color: 'white', 
                cursor: 'pointer', 
                fontSize: '1.5rem',
                padding: '0.25rem 0.5rem',
                lineHeight: 1,
              }}
            >
              ×
            </button>
          </div>
          
          <div style={{ 
            display: 'flex', 
            flexDirection: 'column', 
            gap: '0.75rem',
            marginBottom: '1rem'
          }}>
            {BITCOIN_WALLETS.map((wallet) => {
              const isAvailable = availableWallets.includes(wallet.id);
              const isInstalled = isAvailable;
              
              return (
                <button
                  key={wallet.id}
                  onClick={() => {
                    if (isInstalled) {
                      connectToWallet(wallet.id);
                    } else {
                      window.open(wallet.downloadUrl, '_blank');
                    }
                  }}
                  disabled={connectingWallet === wallet.id || isLoading}
                  style={{
                    padding: '1rem',
                    backgroundColor: isInstalled 
                      ? 'rgba(99, 102, 241, 0.2)' 
                      : 'rgba(255, 255, 255, 0.05)',
                    border: `2px solid ${isInstalled 
                      ? 'rgba(99, 102, 241, 0.5)' 
                      : 'rgba(255, 255, 255, 0.2)'}`,
                    borderRadius: 'var(--radius-md)',
                    color: 'white',
                    cursor: 'pointer',
                    textAlign: 'left',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '1rem',
                    transition: 'all 0.2s',
                    opacity: isInstalled ? 1 : 0.7,
                  }}
                  onMouseEnter={(e) => {
                    if (isInstalled) {
                      e.currentTarget.style.backgroundColor = 'rgba(99, 102, 241, 0.3)';
                      e.currentTarget.style.transform = 'translateY(-2px)';
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (isInstalled) {
                      e.currentTarget.style.backgroundColor = 'rgba(99, 102, 241, 0.2)';
                      e.currentTarget.style.transform = 'translateY(0)';
                    }
                  }}
                >
                  <span style={{ fontSize: '2rem' }}>{wallet.icon}</span>
                  <div style={{ flex: 1 }}>
                    <div style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: '0.5rem',
                      marginBottom: '0.25rem'
                    }}>
                      <span style={{ fontWeight: 'bold', fontSize: '1rem' }}>
                        {wallet.name}
                      </span>
                      {connectingWallet === wallet.id ? (
                        <span style={{
                          fontSize: '0.75rem',
                          padding: '0.125rem 0.5rem',
                          backgroundColor: 'rgba(99, 102, 241, 0.2)',
                          color: '#6366f1',
                          borderRadius: 'var(--radius-sm)',
                          fontWeight: 'bold',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '0.25rem',
                        }}>
                          <span className="loading" style={{ width: '12px', height: '12px', borderWidth: '2px' }}></span>
                          Connecting...
                        </span>
                      ) : isInstalled ? (
                        <span style={{
                          fontSize: '0.75rem',
                          padding: '0.125rem 0.5rem',
                          backgroundColor: 'rgba(34, 197, 94, 0.2)',
                          color: '#22c55e',
                          borderRadius: 'var(--radius-sm)',
                          fontWeight: 'bold',
                        }}>
                          Installed
                        </span>
                      ) : null}
                    </div>
                    <div style={{ fontSize: '0.875rem', opacity: 0.8 }}>
                      {wallet.description}
                    </div>
                  </div>
                  {!isInstalled && (
                    <span style={{ fontSize: '0.75rem', opacity: 0.6 }}>
                      Install →
                    </span>
                  )}
                </button>
              );
            })}
          </div>

          <div style={{
            paddingTop: '1rem',
            borderTop: '1px solid rgba(255, 255, 255, 0.2)',
            fontSize: '0.875rem',
            color: 'rgba(255, 255, 255, 0.7)',
            textAlign: 'center',
          }}>
            <button
              onClick={() => connectToWallet()}
              style={{
                width: '100%',
                padding: '0.75rem',
                backgroundColor: 'rgba(255, 255, 255, 0.1)',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                borderRadius: 'var(--radius-md)',
                color: 'white',
                cursor: 'pointer',
                fontSize: '0.875rem',
              }}
            >
              Show All Available Wallets
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

