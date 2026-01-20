import React, { useState, useEffect } from 'react';
import { useStacks } from '../hooks/useStacks';
import { useContract } from '../hooks/useContract';
import { ListingCard } from './ListingCard';
import { LoadingSkeleton } from './LoadingSkeleton';
import { getStacksAddress } from '../utils/validation';

export const Wishlist = () => {
    const { userData } = useStacks();
    const address = getStacksAddress(userData as any) || null;
    const { getWishlist, getListing } = useContract();
    const [listings, setListings] = useState<any[]>([]);
    const [isLoading, setIsLoading] = useState(true);

    useEffect(() => {
        const loadWishlist = async () => {
            if (!address) {
                setIsLoading(false);
                return;
            }

            try {
                const wishlistData: any = await getWishlist(address);
                const ids = wishlistData?.listing_ids?.value || wishlistData?.listing_ids || [];

                if (ids.length > 0) {
                    const loadedListings = await Promise.all(
                        ids.map(async (id: number) => {
                            try {
                                const listing = await getListing(id);
                                return { id, ...listing.value };
                            } catch (err) {
                                return null;
                            }
                        })
                    );
                    setListings(loadedListings.filter(l => l !== null));
                }
            } catch (error) {
                console.error('Error loading wishlist:', error);
            } finally {
                setIsLoading(false);
            }
        };

        loadWishlist();
    }, [address, getWishlist, getListing]);

    if (isLoading) return <LoadingSkeleton count={3} />;

    if (!address) {
        return (
            <div className="alert alert-info">
                Please connect your wallet to view your wishlist.
            </div>
        );
    }

    return (
        <div className="wishlist-container">
            <h2 style={{ marginBottom: '1.5rem' }}>⭐ My Wishlist ({listings.length})</h2>
            {listings.length === 0 ? (
                <div className="card" style={{ textAlign: 'center', padding: '2rem' }}>
                    <p style={{ color: 'var(--gray-500)' }}>Your wishlist is empty.</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {listings.map(listing => (
                        <ListingCard key={listing.id} listing={listing} />
                    ))}
                </div>
            )}
        </div>
    );
};
