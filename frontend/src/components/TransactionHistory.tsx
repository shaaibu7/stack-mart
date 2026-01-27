import { useState, useMemo, useEffect } from 'react';
import { useTransactionHistory } from '../hooks/useTransactionHistory';
import { formatAddress } from '../utils/validation';
import { formatEVMAddress } from '../utils/appkit';

const ITEMS_PER_PAGE = 5;

/**
 * Transaction History Component
 * Displays transactions from all connected wallets with pagination
 */
export const TransactionHistory = () => {
  const { transactions, isLoading } = useTransactionHistory();
  const [currentPage, setCurrentPage] = useState(1);

  // Calculate pagination
  const totalPages = Math.ceil(transactions.length / ITEMS_PER_PAGE);
  const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
  const endIndex = startIndex + ITEMS_PER_PAGE;
  const paginatedTransactions = useMemo(
    () => transactions.slice(startIndex, endIndex),
    [transactions, startIndex, endIndex]
  );

  // Reset to page 1 when transactions change and current page is out of bounds
  useEffect(() => {
    if (currentPage > totalPages && totalPages > 0) {
      setCurrentPage(1);
    }
  }, [transactions.length, currentPage, totalPages]);

  const handlePrevious = () => {
    setCurrentPage(prev => Math.max(1, prev - 1));
  };

  const handleNext = () => {
    setCurrentPage(prev => Math.min(totalPages, prev + 1));
  };

  const handlePageClick = (page: number) => {
    setCurrentPage(page);
  };

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
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
        <h3 style={{ marginTop: 0, color: 'white', margin: 0 }}>
          Transaction History
        </h3>
        {transactions.length > 0 && (
          <div style={{ fontSize: '0.875rem', color: 'rgba(255, 255, 255, 0.7)' }}>
            Showing {startIndex + 1}-{Math.min(endIndex, transactions.length)} of {transactions.length}
          </div>
        )}
      </div>
      
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
        {paginatedTransactions.map((tx, index) => (
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

      {/* Pagination Controls */}
      {totalPages > 1 && (
        <div style={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          gap: '0.5rem',
          marginTop: '1.5rem',
          paddingTop: '1rem',
          borderTop: '1px solid rgba(255, 255, 255, 0.2)',
        }}>
          <button
            onClick={handlePrevious}
            disabled={currentPage === 1}
            style={{
              padding: '0.5rem 1rem',
              backgroundColor: currentPage === 1 
                ? 'rgba(255, 255, 255, 0.1)' 
                : 'rgba(255, 255, 255, 0.2)',
              color: currentPage === 1 
                ? 'rgba(255, 255, 255, 0.4)' 
                : 'white',
              border: '1px solid rgba(255, 255, 255, 0.2)',
              borderRadius: 'var(--radius-md)',
              cursor: currentPage === 1 ? 'not-allowed' : 'pointer',
              fontSize: '0.875rem',
              fontWeight: '500',
              transition: 'all 0.2s',
            }}
            onMouseEnter={(e) => {
              if (currentPage !== 1) {
                e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.3)';
              }
            }}
            onMouseLeave={(e) => {
              if (currentPage !== 1) {
                e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.2)';
              }
            }}
          >
            Previous
          </button>

          <div style={{ display: 'flex', gap: '0.25rem', alignItems: 'center' }}>
            {Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => {
              // Show first page, last page, current page, and pages around current
              const showPage = 
                page === 1 ||
                page === totalPages ||
                (page >= currentPage - 1 && page <= currentPage + 1);

              if (!showPage) {
                // Show ellipsis
                if (page === currentPage - 2 || page === currentPage + 2) {
                  return (
                    <span key={page} style={{ color: 'rgba(255, 255, 255, 0.5)', padding: '0 0.25rem' }}>
                      ...
                    </span>
                  );
                }
                return null;
              }

              return (
                <button
                  key={page}
                  onClick={() => handlePageClick(page)}
                  style={{
                    minWidth: '2rem',
                    height: '2rem',
                    padding: '0 0.5rem',
                    backgroundColor: page === currentPage
                      ? 'rgba(59, 130, 246, 0.5)'
                      : 'rgba(255, 255, 255, 0.1)',
                    color: 'white',
                    border: page === currentPage
                      ? '1px solid rgba(59, 130, 246, 0.8)'
                      : '1px solid rgba(255, 255, 255, 0.2)',
                    borderRadius: 'var(--radius-sm)',
                    cursor: 'pointer',
                    fontSize: '0.875rem',
                    fontWeight: page === currentPage ? '600' : '400',
                    transition: 'all 0.2s',
                  }}
                  onMouseEnter={(e) => {
                    if (page !== currentPage) {
                      e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.2)';
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (page !== currentPage) {
                      e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                    }
                  }}
                >
                  {page}
                </button>
              );
            })}
          </div>

          <button
            onClick={handleNext}
            disabled={currentPage === totalPages}
            style={{
              padding: '0.5rem 1rem',
              backgroundColor: currentPage === totalPages
                ? 'rgba(255, 255, 255, 0.1)'
                : 'rgba(255, 255, 255, 0.2)',
              color: currentPage === totalPages
                ? 'rgba(255, 255, 255, 0.4)'
                : 'white',
              border: '1px solid rgba(255, 255, 255, 0.2)',
              borderRadius: 'var(--radius-md)',
              cursor: currentPage === totalPages ? 'not-allowed' : 'pointer',
              fontSize: '0.875rem',
              fontWeight: '500',
              transition: 'all 0.2s',
            }}
            onMouseEnter={(e) => {
              if (currentPage !== totalPages) {
                e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.3)';
              }
            }}
            onMouseLeave={(e) => {
              if (currentPage !== totalPages) {
                e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.2)';
              }
            }}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
};

