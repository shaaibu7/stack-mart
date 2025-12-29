import { useTransactionHistory } from '../hooks/useTransactionHistory';
import { formatAddress } from '../utils/validation';
import { formatEVMAddress } from '../utils/appkit';

/**
 * Transaction History Component
 * Displays transactions from all connected wallets
 */
export const TransactionHistory = () => {
  const { transactions, isLoading } = useTransactionHistory();

  if (isLoading) {
    return (
      <div style={{ padding: '2rem', textAlign: 'center', color: 'rgba(255, 255, 255, 0.7)' }}>
        Loading transaction history...
      </div>
    );
  }

  if (transactions.length === 0) {
    return (
      <div style={{
        padding: '2rem',
        textAlign: 'center',
        backgroundColor: 'rgba(255, 255, 255, 0.1)',
        borderRadius: 'var(--radius-md)',
        color: 'rgba(255, 255, 255, 0.7)',
      }}>
        No transactions found
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
      <h3 style={{ marginTop: 0, color: 'white', marginBottom: '1rem' }}>
        Transaction History
      </h3>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
        {transactions.map((tx, index) => (
          <div
            key={`${tx.hash}-${index}`}
            style={{
              padding: '1rem',
              backgroundColor: 'rgba(255, 255, 255, 0.1)',
              borderRadius: 'var(--radius-md)',
              border: '1px solid rgba(255, 255, 255, 0.2)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '0.5rem' }}>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.25rem' }}>
                  <span style={{ fontSize: '1.25rem' }}>
                    {tx.chain === 'stacks' ? '⛓️' : '🔷'}
                  </span>
                  <span style={{ 
                    fontSize: '0.875rem', 
                    color: 'rgba(255, 255, 255, 0.7)',
                    textTransform: 'uppercase',
                  }}>
                    {tx.chain}
                  </span>
                  <span style={{
                    padding: '0.25rem 0.5rem',
                    backgroundColor: tx.status === 'confirmed' 
                      ? 'rgba(34, 197, 94, 0.3)'
                      : tx.status === 'pending'
                      ? 'rgba(251, 191, 36, 0.3)'
                      : 'rgba(239, 68, 68, 0.3)',
                    borderRadius: 'var(--radius-sm)',
                    fontSize: '0.75rem',
                    color: 'white',
                  }}>
                    {tx.status}
                  </span>
                </div>
                <div style={{ fontFamily: 'monospace', fontSize: '0.75rem', color: 'rgba(255, 255, 255, 0.8)' }}>
                  {tx.chain === 'stacks' 
                    ? formatAddress(tx.hash)
                    : formatEVMAddress(tx.hash)}
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: '0.75rem', color: 'rgba(255, 255, 255, 0.6)' }}>
                  {new Date(tx.timestamp * 1000).toLocaleDateString()}
                </div>
                {tx.amount && (
                  <div style={{ fontSize: '0.875rem', fontWeight: 'bold', color: 'white', marginTop: '0.25rem' }}>
                    {tx.amount}
                  </div>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

