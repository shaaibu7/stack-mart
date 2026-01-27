import { useWalletBalance } from '../hooks/useWalletBalance';
import { useAllWallets } from '../hooks/useAllWallets';
import { formatEVMAddress } from '../utils/appkit';
import { formatWalletKitAddress } from '../utils/walletkit';
import { formatAddress, getStacksAddress } from '../utils/validation';

/**
 * Wallet Balance Display Component
 * Shows balances for all connected wallets (Stacks, AppKit, WalletKit)
 */
export const WalletBalanceDisplay = () => {
  const { 
    appKitBalance, 
    walletKitBalance, 
    stacksBalance, 
    isLoading 
  } = useWalletBalance();
  
  const { stacks, appKit, walletKit, isAnyConnected } = useAllWallets();

  if (!isAnyConnected) {
    return (
      <div style={{
        padding: '1rem',
        backgroundColor: 'rgba(255, 255, 255, 0.1)',
        borderRadius: 'var(--radius-md)',
        textAlign: 'center',
        color: 'rgba(255, 255, 255, 0.7)',
      }}>
        Connect a wallet to view balances
      </div>
    );
  }

  return (
    <div style={{
      padding: '1.5rem',
      backgroundColor: 'rgba(0, 0, 0, 0.3)',
      borderRadius: 'var(--radius-lg)',
      border: '1px solid rgba(255, 255, 255, 0.2)',
    }}>
      <h3 style={{ marginTop: 0, marginBottom: '1rem', color: 'white' }}>
        Wallet Balances
      </h3>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        {/* Stacks Balance */}
        {stacks.isConnected && getStacksAddress(stacks.userData) && (
          <div style={{
            padding: '1rem',
            backgroundColor: 'rgba(99, 102, 241, 0.2)',
            borderRadius: 'var(--radius-md)',
            border: '1px solid rgba(99, 102, 241, 0.3)',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: '0.875rem', color: 'rgba(255, 255, 255, 0.7)', marginBottom: '0.25rem' }}>
                  Stacks Wallet
                </div>
                <div style={{ fontFamily: 'monospace', fontSize: '0.75rem', color: 'rgba(255, 255, 255, 0.8)' }}>
                  {formatAddress(getStacksAddress(stacks.userData) || '')}
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                {isLoading ? (
                  <span style={{ color: 'rgba(255, 255, 255, 0.7)' }}>Loading...</span>
                ) : (
                  <div style={{ fontSize: '1.25rem', fontWeight: 'bold', color: 'white' }}>
                    {stacksBalance || '0.000000'} STX
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* AppKit Balance */}
        {appKit.isConnected && appKit.address && (
          <div style={{
            padding: '1rem',
            backgroundColor: 'rgba(34, 197, 94, 0.2)',
            borderRadius: 'var(--radius-md)',
            border: '1px solid rgba(34, 197, 94, 0.3)',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: '0.875rem', color: 'rgba(255, 255, 255, 0.7)', marginBottom: '0.25rem' }}>
                  AppKit Wallet (EVM)
                </div>
                <div style={{ fontFamily: 'monospace', fontSize: '0.75rem', color: 'rgba(255, 255, 255, 0.8)' }}>
                  {formatEVMAddress(appKit.address)}
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                {isLoading ? (
                  <span style={{ color: 'rgba(255, 255, 255, 0.7)' }}>Loading...</span>
                ) : appKitBalance ? (
                  <div>
                    <div style={{ fontSize: '1.25rem', fontWeight: 'bold', color: 'white' }}>
                      {appKitBalance.formatted} {appKitBalance.symbol}
                    </div>
                  </div>
                ) : (
                  <div style={{ fontSize: '1.25rem', fontWeight: 'bold', color: 'white' }}>
                    -- {appKit.chain?.nativeCurrency?.symbol || 'ETH'}
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* WalletKit Balance */}
        {walletKit.isConnected && walletKit.address && (
          <div style={{
            padding: '1rem',
            backgroundColor: 'rgba(251, 191, 36, 0.2)',
            borderRadius: 'var(--radius-md)',
            border: '1px solid rgba(251, 191, 36, 0.3)',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: '0.875rem', color: 'rgba(255, 255, 255, 0.7)', marginBottom: '0.25rem' }}>
                  WalletKit (Gasless)
                </div>
                <div style={{ fontFamily: 'monospace', fontSize: '0.75rem', color: 'rgba(255, 255, 255, 0.8)' }}>
                  {formatWalletKitAddress(walletKit.address)}
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                {isLoading ? (
                  <span style={{ color: 'rgba(255, 255, 255, 0.7)' }}>Loading...</span>
                ) : walletKitBalance ? (
                  <div style={{ fontSize: '1.25rem', fontWeight: 'bold', color: 'white' }}>
                    {walletKitBalance}
                  </div>
                ) : (
                  <div style={{ fontSize: '1.25rem', fontWeight: 'bold', color: 'white' }}>
                    -- ETH
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

