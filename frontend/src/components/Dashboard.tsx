import { useState, useEffect, useRef } from 'react';
import { useStacks } from '../hooks/useStacks';
import { useContract } from '../hooks/useContract';
import { ListingCard } from './ListingCard';
import { LoadingSkeleton } from './LoadingSkeleton';
import { WalletBalanceDisplay } from './WalletBalanceDisplay';
import { NetworkSwitcher } from './NetworkSwitcher';
import { TransactionHistory } from './TransactionHistory';
import { useAllWallets } from '../hooks/useAllWallets';
import { Wishlist } from './Wishlist';
import { formatSTX } from '../utils/validation';

export const Dashboard = () => {
    const { userSession } = useStacks();
    const { getAllListings, getSellerReputation, getBuyerReputation, getTransactionHistory } = useContract();

    const [activeListings, setActiveListings] = useState<any[]>([]);
    const [history, setHistory] = useState<any[]>([]);
    const [sellerRep, setSellerRep] = useState<any>(null);
    const [buyerRep, setBuyerRep] = useState<any>(null);
    const [isLoading, setIsLoading] = useState(true);

    const getPrincipal = () => {
        try {
            const userData = userSession.loadUserData() as any;
            return userData?.profile?.stxAddress?.mainnet || userData?.profile?.stxAddress?.testnet;
        } catch (e) {
            return null;
        }
    };

    const loadData = async () => {
        const principal = getPrincipal();
        if (!principal) return;

        setIsLoading(true);
        try {
            // Load reputation
            const [sRep, bRep] = await Promise.all([
                getSellerReputation(principal),
                getBuyerReputation(principal)
            ]);

            if (sRep?.value) setSellerRep(sRep.value);
            if (bRep?.value) setBuyerRep(bRep.value);

            // Load active listings
            const allListings = await getAllListings(50);
            const myListings = allListings.filter((l: any) => l.seller === principal);
            setActiveListings(myListings);

            // Load history
            const txHistory = await getTransactionHistory(principal);
            setHistory(txHistory);
        } catch (error) {
            console.error("Error loading dashboard data:", error);
        } finally {
            setIsLoading(false);
        }
    };

    const hasLoadedRef = useRef(false);
    const lastPrincipalRef = useRef<string | null>(null);

    useEffect(() => {
        const principal = getPrincipal();
        // Only load if principal changed or hasn't loaded yet
        if (principal && principal !== lastPrincipalRef.current) {
            lastPrincipalRef.current = principal;
            hasLoadedRef.current = false;
        }
        
        if (!principal || hasLoadedRef.current) return;
        
        hasLoadedRef.current = true;
        loadData();
    }, [userSession]);

    if (!userSession.isUserSignedIn()) {
        return (
            <div className="card" style={{ textAlign: 'center', padding: '3rem' }}>
                <h3>Please connect your wallet to view your dashboard</h3>
            </div>
        );
    }

    const { isAnyConnected } = useAllWallets();

    return (
        <div className="dashboard">
            {/* Wallet Integration Section */}
            {isAnyConnected && (
                <div style={{ marginBottom: '2rem', display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem' }}>
                    <WalletBalanceDisplay />
                    <NetworkSwitcher />
                </div>
            )}

            {/* Reputation Overview */}
            <div className="grid grid-cols-2" style={{ marginBottom: '2rem' }}>
                <div className="card">
                    <div className="card-header">
                        <h3 className="card-title">🛍️ Seller Reputation</h3>
                    </div>
                    <div className="card-body">
                        {sellerRep ? (
                            <div style={{ display: 'flex', gap: '2rem' }}>
                                <div>
                                    <div style={{ fontSize: '0.875rem', color: 'var(--gray-500)' }}>Sales</div>
                                    <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--success)' }}>
                                        {sellerRep['successful-txs']?.value || 0}
                                    </div>
                                </div>
                                <div style={{ borderLeft: '1px solid var(--gray-200)', paddingLeft: '2rem' }}>
                                    <div style={{ fontSize: '0.875rem', color: 'var(--gray-500)' }}>Total Volume</div>
                                    <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--primary)' }}>
                                        {formatSTX(sellerRep['total-volume']?.value || 0)} STX
                                    </div>
                                </div>
                            </div>
                        ) : (
                            <div className="skeleton-text" />
                        )}
                    </div>
                </div>

                <div className="card">
                    <div className="card-header">
                        <h3 className="card-title">🛒 Buyer Reputation</h3>
                    </div>
                    <div className="card-body">
                        {buyerRep ? (
                            <div style={{ display: 'flex', gap: '2rem' }}>
                                <div>
                                    <div style={{ fontSize: '0.875rem', color: 'var(--gray-500)' }}>Purchases</div>
                                    <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--info)' }}>
                                        {buyerRep['successful-txs']?.value || 0}
                                    </div>
                                </div>
                                <div style={{ borderLeft: '1px solid var(--gray-200)', paddingLeft: '2rem' }}>
                                    <div style={{ fontSize: '0.875rem', color: 'var(--gray-500)' }}>Total Spent</div>
                                    <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'var(--primary)' }}>
                                        {formatSTX(buyerRep['total-volume']?.value || 0)} STX
                                    </div>
                                </div>
                            </div>
                        ) : (
                            <div className="skeleton-text" />
                        )}
                    </div>
                </div>
            </div>

            {/* Wishlist Section */}
            <div style={{ marginBottom: '2rem' }}>
                <Wishlist />
            </div>

            {/* Active Listings */}
            <section>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
                    <h2>My Active Listings</h2>
                    <button className="btn btn-secondary btn-sm" onClick={loadData}>🔄 Refresh</button>
                </div>

                {isLoading ? (
                    <div className="grid grid-cols-1" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))' }}>
                        <LoadingSkeleton count={3} />
                    </div>
                ) : activeListings.length > 0 ? (
                    <div className="grid grid-cols-1" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '1.5rem' }}>
                        {activeListings.map((listing) => (
                            <ListingCard
                                key={listing.id}
                                listing={listing}
                                onBuy={() => { }} // Can't buy own listing
                                onViewDetails={() => { }}
                            />
                        ))}
                    </div>
                ) : (
                    <div className="info-box">You have no active listings.</div>
                )}
            </section>

            {/* Transaction History - Multi-Chain */}
            <section>
                <h2>Recent Activity</h2>
                <div style={{ marginBottom: '1.5rem' }}>
                    {isAnyConnected ? (
                        <TransactionHistory />
                    ) : (
                        <div className="info-box">
                            Connect a wallet to view transaction history
                        </div>
                    )}
                </div>
                {isLoading ? (
                    <LoadingSkeleton count={1} />
                ) : history.length > 0 ? (
                    <div className="card">
                        <h3 style={{ marginBottom: '1rem' }}>Stacks Contract Transactions</h3>
                        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                            <thead>
                                <tr style={{ borderBottom: '1px solid var(--gray-200)', textAlign: 'left' }}>
                                    <th style={{ padding: '1rem' }}>Type</th>
                                    <th style={{ padding: '1rem' }}>Listing ID</th>
                                    <th style={{ padding: '1rem' }}>Amount</th>
                                    <th style={{ padding: '1rem' }}>Counterparty</th>
                                    <th style={{ padding: '1rem' }}>Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                {history.map((tx, i) => (
                                    <tr key={i} style={{ borderBottom: '1px solid var(--gray-100)' }}>
                                        <td style={{ padding: '1rem' }}>
                                            {tx.listing_id ? 'Sale/Purchase' : 'Transaction'}
                                        </td>
                                        <td style={{ padding: '1rem' }}>#{tx['listing-id']?.value || tx['listing-id']}</td>
                                        <td style={{ padding: '1rem' }}>{tx.amount?.value || tx.amount} STX</td>
                                        <td style={{ padding: '1rem', fontFamily: 'monospace' }}>
                                            {(tx.counterparty?.value || tx.counterparty || '').substring(0, 8)}...
                                        </td>
                                        <td style={{ padding: '1rem' }}>
                                            {tx.completed?.value || tx.completed ? (
                                                <span className="badge badge-success">Completed</span>
                                            ) : (
                                                <span className="badge badge-error">Failed</span>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                ) : (
                    <div className="info-box">No transaction history found.</div>
                )}
            </section>
        </div>
    );
};
