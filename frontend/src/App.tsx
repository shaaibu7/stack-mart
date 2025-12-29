import { useState, useEffect } from 'react';
import { WalletButton } from './components/WalletButton';
import { UnifiedWalletSelector } from './components/UnifiedWalletSelector';
import { CreateListing } from './components/CreateListing';
import { ListingCard } from './components/ListingCard';
import { ListingDetails } from './components/ListingDetails';
import { ChainhookEvents } from './components/ChainhookEvents';
import { LoadingSkeleton } from './components/LoadingSkeleton';
import { BundleManagement } from './components/BundleManagement';
import { CuratedPack } from './components/CuratedPack';
import { DisputeResolution } from './components/DisputeResolution';
import { Dashboard } from './components/Dashboard';
import { useStacks } from './hooks/useStacks';
import { useContract } from './hooks/useContract';
import './App.css';

type TabType = 'listings' | 'bundles' | 'packs' | 'disputes' | 'dashboard';

function App() {
  const { isConnected } = useStacks();
  const { getAllListings } = useContract();
  const [listings, setListings] = useState<any[]>([]);
  const [selectedListingId, setSelectedListingId] = useState<number | null>(null);
  const [isLoadingListings, setIsLoadingListings] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<TabType>('listings');
  const [disputeEscrowId, setDisputeEscrowId] = useState<number | null>(null);

  const loadListings = async () => {
    setIsLoadingListings(true);
    setError(null);
    try {
      const contractListings = await getAllListings(50);
      if (contractListings && contractListings.length > 0) {
        setListings(contractListings);
      } else {
        // Fallback to mock data if no listings found
        setListings([{
          id: 1,
          seller: 'SP1EQNTKNRGME36P9EEXZCFFNCYBA50VN51676JB',
          price: 1000000,
          'royalty-bips': 500,
          'royalty-recipient': 'SP3J75H6FYTCJJW5R0CHVGWDFN8JPZP3DD4DPJRSP',
        }]);
      }
    } catch (error) {
      console.error('Error loading listings:', error);
      setError(error instanceof Error ? error.message : 'Failed to load listings');
      // Use mock data on error
      setListings([{
        id: 1,
        seller: 'SP1EQNTKNRGME36P9EEXZCFFNCYBA50VN51676JB',
        price: 1000000,
        'royalty-bips': 500,
        'royalty-recipient': 'SP3J75H6FYTCJJW5R0CHVGWDFN8JPZP3DD4DPJRSP',
      }]);
    } finally {
      setIsLoadingListings(false);
    }
  };

  // Load listings from contract - with error handling
  useEffect(() => {
    // Use setTimeout to ensure component is mounted
    const timer = setTimeout(() => {
      try {
        loadListings();
      } catch (err) {
        console.error('Error in loadListings:', err);
        setError('Failed to initialize listings');
        // Set mock data as fallback
        setListings([{
          id: 1,
          seller: 'SP1EQNTKNRGME36P9EEXZCFFNCYBA50VN51676JB',
          price: 1000000,
          'royalty-bips': 500,
          'royalty-recipient': 'SP3J75H6FYTCJJW5R0CHVGWDFN8JPZP3DD4DPJRSP',
        }]);
      }
    }, 100);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Use unified wallet selector for better UX (supports all wallet types)
  const useUnifiedSelector = import.meta.env.VITE_USE_UNIFIED_WALLET === 'true' || true;

  if (selectedListingId) {
    return (
      <div className="App">
        <header>
          <h1>StackMart Marketplace</h1>
          {useUnifiedSelector ? <UnifiedWalletSelector /> : <WalletButton />}
        </header>
        <ListingDetails
          listingId={selectedListingId}
          onClose={() => setSelectedListingId(null)}
        />
      </div>
    );
  }

  return (
    <div className="App">
      <header>
        <h1>StackMart Marketplace</h1>
        {useUnifiedSelector ? <UnifiedWalletSelector /> : <WalletButton />}
      </header>

      <main>
        {error && (
          <div className="alert alert-error">
            <strong>Error:</strong> {error}
          </div>
        )}

        {/* Tab Navigation */}
        <div style={{
          display: 'flex',
          gap: '10px',
          marginBottom: '2rem',
          borderBottom: '2px solid var(--gray-200)',
          paddingBottom: '10px'
        }}>
          <button
            className={`btn ${activeTab === 'dashboard' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('dashboard')}
            style={{ borderRadius: '8px 8px 0 0' }}
          >
            👤 Dashboard
          </button>
          <button
            className={`btn ${activeTab === 'listings' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('listings')}
            style={{ borderRadius: '8px 8px 0 0' }}
          >
            🛍️ Listings
          </button>
          <button
            className={`btn ${activeTab === 'bundles' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('bundles')}
            style={{ borderRadius: '8px 8px 0 0' }}
          >
            📦 Bundles
          </button>
          <button
            className={`btn ${activeTab === 'packs' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('packs')}
            style={{ borderRadius: '8px 8px 0 0' }}
          >
            🎁 Packs
          </button>
          <button
            className={`btn ${activeTab === 'disputes' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('disputes')}
            style={{ borderRadius: '8px 8px 0 0' }}
          >
            ⚖️ Disputes
          </button>
        </div>

        {/* Tab Content */}
        {activeTab === 'listings' && (
          <>
            <section>
              <h2>📝 Create Listing</h2>
              <CreateListing />
            </section>

            <section>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem', flexWrap: 'wrap', gap: '1rem' }}>
                <h2 style={{ marginBottom: 0 }}>🛍️ Available Listings</h2>
                <button
                  className="btn btn-secondary"
                  onClick={loadListings}
                  disabled={isLoadingListings}
                >
                  {isLoadingListings ? (
                    <>
                      <span className="loading"></span>
                      Loading...
                    </>
                  ) : (
                    '🔄 Refresh'
                  )}
                </button>
              </div>

              {isLoadingListings ? (
                <div className="grid grid-cols-1" style={{
                  gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
                  gap: '1.5rem'
                }}>
                  <LoadingSkeleton count={6} />
                </div>
              ) : listings.length === 0 ? (
                <div style={{
                  textAlign: 'center',
                  padding: '3rem',
                  color: 'var(--gray-500)',
                  backgroundColor: 'var(--gray-50)',
                  borderRadius: 'var(--radius-lg)'
                }}>
                  <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>📦</div>
                  <h3 style={{ marginBottom: '0.5rem', color: 'var(--gray-700)' }}>No listings available</h3>
                  <p>Be the first to create a listing!</p>
                </div>
              ) : (
                <div className="grid grid-cols-1" style={{
                  gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
                  gap: '1.5rem'
                }}>
                  {listings.map((listing) => (
                    <ListingCard
                      key={listing.id}
                      listing={listing}
                      onBuy={(id) => {
                        if (!isConnected) {
                          alert('Please connect your wallet to buy');
                          return;
                        }
                        setSelectedListingId(id);
                      }}
                      onViewDetails={(id) => setSelectedListingId(id)}
                    />
                  ))}
                </div>
              )}
            </section>
          </>
        )}

        {activeTab === 'bundles' && (
          <section>
            <BundleManagement />
          </section>
        )}

        {activeTab === 'packs' && (
          <section>
            <CuratedPack />
          </section>
        )}

        {activeTab === 'disputes' && (
          <section>
            <h2>⚖️ Dispute Resolution</h2>
            <div className="form-group" style={{ marginBottom: '20px' }}>
              <label className="form-label">Escrow ID (for dispute)</label>
              <input
                className="form-input"
                type="number"
                min="1"
                value={disputeEscrowId || ''}
                onChange={(e) => setDisputeEscrowId(e.target.value ? parseInt(e.target.value) : null)}
                placeholder="Enter escrow ID"
                style={{ maxWidth: '300px' }}
              />
              <div className="form-help">
                Enter the listing ID that has an escrow you want to dispute or view disputes for
              </div>
            </div>
            {disputeEscrowId && (
              <DisputeResolution
                listingId={disputeEscrowId}
                escrowId={disputeEscrowId}
              />
            )}
            {!disputeEscrowId && (
              <div className="card">
                <div className="card-body">
                  <p>Enter an escrow ID above to view or create disputes.</p>
                </div>
              </div>
            )}
          </section>
        )}

        {activeTab === 'dashboard' && (
          <Dashboard />
        )}

        <section>
          <ChainhookEvents />
        </section>
      </main>
    </div>
  );
}

export default App;
