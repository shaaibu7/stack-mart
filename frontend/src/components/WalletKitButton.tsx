import { useWalletKitLink } from '@walletkit/react-link';
import { useState } from 'react';

/**
 * WalletKit Connect Button Component
 * Provides gasless wallet connection with email/social login
 */
export const WalletKitButton = () => {
  const walletKit = useWalletKitLink() as any;
  const [isConnecting, setIsConnecting] = useState(false);

  const handleConnect = async () => {
    if (!walletKit) {
      console.error('WalletKit not initialized');
      return;
    }

    setIsConnecting(true);
    try {
      await walletKit.connect();
    } catch (error) {
      console.error('Error connecting WalletKit:', error);
    } finally {
      setIsConnecting(false);
    }
  };

  const handleDisconnect = async () => {
    if (!walletKit) return;

    try {
      await walletKit.disconnect();
    } catch (error) {
      console.error('Error disconnecting WalletKit:', error);
    }
  };

  if (walletKit?.isConnected && walletKit?.address) {
    const shortAddress = `${walletKit.address.slice(0, 6)}...${walletKit.address.slice(-4)}`;

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
          {shortAddress} (WalletKit)
        </div>
        <button
          className="btn btn-secondary btn-sm"
          onClick={handleDisconnect}
          disabled={isConnecting}
          style={{ backgroundColor: 'rgba(255, 255, 255, 0.2)', color: 'white', border: '1px solid rgba(255, 255, 255, 0.3)' }}
        >
          Disconnect
        </button>
      </div>
    );
  }

  return (
    <button
      className="btn btn-primary"
      onClick={handleConnect}
      disabled={isConnecting || !walletKit}
      style={{ backgroundColor: 'rgba(255, 255, 255, 0.2)', color: 'white', border: '1px solid rgba(255, 255, 255, 0.3)' }}
    >
      {isConnecting ? (
        <>
          <span className="loading"></span>
          Connecting...
        </>
      ) : (
        '🔗 Connect WalletKit (Gasless)'
      )}
    </button>
  );
};

