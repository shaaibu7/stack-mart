interface Listing {
  id: number;
  seller: string;
  price: number;
  royaltyBips?: number;
  'royalty-bips'?: number;
  royaltyRecipient?: string;
  'royalty-recipient'?: string;
  nftContract?: string;
  'nft-contract'?: string;
  tokenId?: number;
  'token-id'?: number;
  licenseTerms?: string;
  'license-terms'?: string;
}

interface ListingCardProps {
  listing: Listing;
  onBuy?: (id: number) => void;
  onViewDetails?: (id: number) => void;
}

export const ListingCard = ({ listing, onBuy, onViewDetails }: ListingCardProps) => {
  const priceInSTX = (listing.price || 0) / 1000000; // Convert microSTX to STX
  const royaltyBips = listing.royaltyBips || listing['royalty-bips'] || 0;
  const royaltyPercent = royaltyBips / 100;
  const hasNFT = !!(listing.nftContract || listing['nft-contract']);

  const formatAddress = (address: string) => {
    if (!address) return 'Unknown';
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  return (
    <div className="card" style={{ maxWidth: '100%' }}>
      <div className="card-header">
        <h3 className="card-title">Listing #{listing.id}</h3>
        {hasNFT && (
          <span className="badge badge-info">NFT</span>
        )}
      </div>
      
      <div className="card-body">
        <div style={{ marginBottom: '0.75rem' }}>
          <div style={{ fontSize: '0.875rem', color: 'var(--gray-500)', marginBottom: '0.25rem' }}>
            Seller
          </div>
          <div style={{ fontFamily: 'monospace', fontSize: '0.875rem' }}>
            {formatAddress(listing.seller)}
          </div>
        </div>

        <div style={{ marginBottom: '0.75rem' }}>
          <div style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--primary)' }}>
            {priceInSTX.toFixed(2)} STX
          </div>
        </div>

        {royaltyBips > 0 && (
          <div style={{ marginBottom: '0.75rem', fontSize: '0.875rem', color: 'var(--gray-600)' }}>
            <span style={{ fontWeight: 500 }}>Royalty:</span> {royaltyPercent}%
          </div>
        )}

        {(listing.licenseTerms || listing['license-terms']) && (
          <div style={{ 
            marginTop: '0.75rem', 
            padding: '0.5rem', 
            backgroundColor: 'var(--gray-50)', 
            borderRadius: '0.375rem',
            fontSize: '0.875rem',
            color: 'var(--gray-600)'
          }}>
            <strong>License:</strong> {(listing.licenseTerms || listing['license-terms'])?.slice(0, 100)}
            {(listing.licenseTerms || listing['license-terms'])?.length > 100 && '...'}
          </div>
        )}
      </div>

      <div className="card-footer">
        {onViewDetails && (
          <button 
            className="btn btn-outline btn-sm"
            onClick={() => onViewDetails(listing.id)}
            style={{ flex: 1 }}
          >
            View Details
          </button>
        )}
        {onBuy && (
          <button 
            className="btn btn-primary btn-sm"
            onClick={() => onBuy(listing.id)}
            style={{ flex: 1 }}
          >
            Buy Now
          </button>
        )}
      </div>
    </div>
  );
};

