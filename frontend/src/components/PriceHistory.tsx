import React, { useState, useEffect } from 'react';
import { useContract } from '../hooks/useContract';

export const PriceHistory = ({ listingId }: { listingId: number }) => {
    const { getPriceHistory } = useContract();
    const [history, setHistory] = useState<any[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    useEffect(() => {
        const loadPriceHistory = async () => {
            try {
                const data: any = await getPriceHistory(listingId);
                const rawHistory = data?.history?.value || data?.history || [];
                setHistory(rawHistory);
            } catch (error) {
                console.error('Error loading price history:', error);
            } finally {
                setIsLoading(false);
            }
        };

        loadPriceHistory();
    }, [listingId, getPriceHistory]);

    if (isLoading) return <div className="loading-pulse" style={{ height: '60px' }}></div>;
    if (history.length <= 1) return null;

    return (
        <div className="price-history" style={{ marginTop: '1rem' }}>
            <h4 style={{ fontSize: '0.875rem', color: 'var(--gray-500)' }}>📈 Price History</h4>
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: '4px', height: '40px' }}>
                {history.map((point: any, i: number) => (
                    <div
                        key={i}
                        style={{
                            flex: 1,
                            backgroundColor: 'var(--primary)',
                            height: `${(Number(point.price?.value || point.price) / Math.max(...history.map(p => Number(p.price?.value || p.price)))) * 100}%`,
                            opacity: 0.5 + (i / history.length) * 0.5
                        }}
                    />
                ))}
            </div>
        </div>
    );
};
