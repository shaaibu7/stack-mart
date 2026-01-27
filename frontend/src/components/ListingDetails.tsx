import { useState, useEffect } from 'react';
import { useContract } from '../hooks/useContract';
import { useStacks } from '../hooks/useStacks';
import { BuyListing } from './BuyListing';
import { EscrowManagement } from './EscrowManagement';
import { PriceHistory } from './PriceHistory';
import { formatAddress, formatSTX } from '../utils/validation';

interface ListingDetailsProps {
  listingId: number;
  onClose?: () => void;
}

export const ListingDetails = ({ listingId, onClose }: ListingDetailsProps) => {
  const { getListing } = useContract();
  const { userData, isConnected } = useStacks();
  const [listing, setListing] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadListing();
  }, [listingId]);

  const loadListing = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const data = await getListing(listingId);
      setListing(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load listing');
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div style={{ padding: '40px', textAlign: 'center' }}>
        <p>Loading listing details...</p>
      </div>
    );
  }

  if (error || !listing) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#dc3545' }}>
        <p>Error: {error || 'Listing not found'}</p>
        <button onClick={onClose} style={{ marginTop: '10px', padding: '8px 16px' }}>
          Close
        </button>
      </div>
    );
  }

  const listingData = listing.value || listing;
  const price = listingData.price || 0;
  const priceInSTX = formatSTX(price);
  const royaltyPercent = (listingData['royalty-bips'] || 0) / 100;
  const seller = listingData.seller || '';
  const licenseTerms = listingData['license-terms']?.value || listingData['license-terms'];
  const nftContract = listingData['nft-contract']?.value || listingData['nft-contract'];
  const tokenId = listingData['token-id']?.value || listingData['token-id'];

  const userDataAny = userData as any;
  const isSeller = isConnected && userDataAny?.profile?.stxAddress?.mainnet === seller;

  return (
    <div style={{ maxWidth: '800px', margin: '0 auto', padding: '20px' }}>
      {onClose && (
        <button
          onClick={onClose}
          style={{
            marginBottom: '20px',
            padding: '8px 16px',
            backgroundColor: '#6c757d',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
          }}
        >
          ← Back
        </button>
      )}

      <div style={{ border: '1px solid #ddd', borderRadius: '8px', padding: '30px', marginBottom: '20px' }}>
        <h1>Listing #{listingId}</h1>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginTop: '20px' }}>
          <div>
            <p><strong>Seller:</strong></p>
            <p style={{ fontFamily: 'monospace', fontSize: '0.9em' }}>{formatAddress(seller)}</p>
          </div>
          <div>
            <p><strong>Price:</strong></p>
            <p style={{ fontSize: '24px', fontWeight: 'bold', color: '#28a745' }}>{priceInSTX} STX</p>
          </div>
          <div>
            <p><strong>Royalty:</strong></p>
            <p>{royaltyPercent}%</p>
          </div>
          {nftContract && (
            <div>
              <p><strong>NFT Contract:</strong></p>
              <p style={{ fontFamily: 'monospace', fontSize: '0.9em' }}>{nftContract}</p>
              {tokenId && <p><strong>Token ID:</strong> {tokenId}</p>}
            </div>
          )}
        </div>

        {licenseTerms && (
          <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#f8f9fa', borderRadius: '4px' }}>
            <h3>License Terms</h3>
            <p style={{ whiteSpace: 'pre-wrap' }}>{licenseTerms}</p>
          </div>
        )}
      </div>

      {!isSeller && (
        <BuyListing
          listingId={listingId}
          price={price}
          onSuccess={(txid) => {
            alert(`Purchase initiated! TX: ${txid}`);
            loadListing();
          }}
          onError={(err) => alert(`Error: ${err}`)}
        />
      )}

      {isConnected && (
        <EscrowManagement
          listingId={listingId}
          userRole={isSeller ? 'seller' : 'buyer'}
        />
      )}

      <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#e9ecef', borderRadius: '4px' }}>
        <h3>Transaction History</h3>
        <p style={{ color: '#666', fontSize: '0.9em' }}>
          View transaction history on the explorer or check chainhook events above.
        </p>
      </div>
    </div>
  );
};

