import { useState, useEffect, useCallback, useRef } from 'react';
import { WalletButton } from './components/WalletButton';
import { LandingPage } from './components/LandingPage';
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
  // Always start on the landing page, even after reload
  const [showLanding, setShowLanding] = useState(true);
  const [listings, setListings] = useState<any[]>([]);
  const [selectedListingId, setSelectedListingId] = useState<number | null>(null);
  const [isLoadingListings, setIsLoadingListings] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Always start at listings tab (home) when in the marketplace
  const [activeTab, setActiveTab] = useState<TabType>('listings');
  const [disputeEscrowId, setDisputeEscrowId] = useState<number | null>(null);

  const goHome = () => {
    setSelectedListingId(null);
    setActiveTab('listings');
    setDisputeEscrowId(null);
    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const showLandingPage = () => {
    setShowLanding(true);
  };

  const loadListings = useCallback(async () => {
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
  }, [getAllListings]);

  // Load listings from contract - with error handling
  const hasLoadedListingsRef = useRef(false);
  
  useEffect(() => {
    // Only load listings if not on landing page
    if (showLanding) {
      hasLoadedListingsRef.current = false;
      return;
    }
    
    // Only load once per marketplace entry
    if (hasLoadedListingsRef.current) return;
    
    hasLoadedListingsRef.current = true;
    
    // Use setTimeout to ensure component is mounted
    const timer = setTimeout(() => {
      loadListings().catch((err) => {
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
      });
    }, 100);
    return () => clearTimeout(timer);
  }, [showLanding, loadListings]);

  const enterMarketplace = () => {
    setShowLanding(false);
    // Always go to listings (home) tab when entering marketplace
    setActiveTab('listings');
    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  // Show landing page first (after all hooks are called)
  if (showLanding) {
    return <LandingPage onEnter={enterMarketplace} />;
  }

  if (selectedListingId) {
    return (
      <div className="App">
        <header>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%', gap: '1rem' }}>
            <div 
              onClick={showLandingPage}
              style={{ 
                display: 'flex', 
                alignItems: 'center', 
                gap: '0.5rem',
                cursor: 'pointer',
                transition: 'opacity 0.2s'
              }}
              onMouseEnter={(e) => e.currentTarget.style.opacity = '0.7'}
              onMouseLeave={(e) => e.currentTarget.style.opacity = '1'}
              title="Click to go to home"
            >
              <div style={{
                width: '32px',
                height: '32px',
                borderRadius: '8px',
                border: '2px solid #333333',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#333333',
                fontSize: '1.1rem'
              }}>
                🛍️
              </div>
              <span style={{
                fontSize: '1.4rem',
                fontWeight: 700,
                color: '#333333'
              }}>
                StackMart
              </span>
            </div>
            <div style={{ marginLeft: 'auto' }}>
              <WalletButton />
            </div>
          </div>
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
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%', gap: '1rem' }}>
          <div 
            onClick={showLandingPage}
            style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '0.5rem',
              cursor: 'pointer',
              transition: 'opacity 0.2s'
            }}
            onMouseEnter={(e) => e.currentTarget.style.opacity = '0.7'}
            onMouseLeave={(e) => e.currentTarget.style.opacity = '1'}
            title="Click to go to home"
          >
            <div style={{
              width: '32px',
              height: '32px',
              borderRadius: '8px',
              border: '2px solid #333333',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#333333',
              fontSize: '1.1rem'
            }}>
              🛍️
            </div>
            <span style={{
              fontSize: '1.4rem',
              fontWeight: 700,
              color: '#333333'
            }}>
              StackMart
            </span>
          </div>
          <div style={{ marginLeft: 'auto' }}>
            <WalletButton />
          </div>
        </div>
      </header>

      <div style={{ display: 'flex', minHeight: 'calc(100vh - 80px)' }}>
        {/* Sidebar Navigation */}
        <aside style={{
          width: '250px',
          backgroundColor: '#f8f9fa',
          borderRight: '1px solid #e0e0e0',
          padding: '1.5rem 0',
          display: 'flex',
          flexDirection: 'column',
          gap: '0.25rem'
        }}>
          <button
            className={`btn ${activeTab === 'dashboard' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('dashboard')}
            style={{ 
              borderRadius: '0',
              margin: '0 0.75rem 0.25rem 0.75rem',
              textAlign: 'left',
              justifyContent: 'flex-start',
              padding: '0.875rem 1rem',
              width: 'calc(100% - 1.5rem)',
              borderLeft: activeTab === 'dashboard' ? '3px solid var(--primary)' : '3px solid transparent',
              backgroundColor: activeTab === 'dashboard' ? 'var(--primary)' : 'transparent',
              color: activeTab === 'dashboard' ? '#ffffff' : 'var(--gray-700)',
              fontWeight: activeTab === 'dashboard' ? '600' : '400'
            }}
          >
            👤 Dashboard
          </button>
          <button
            className={`btn ${activeTab === 'listings' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('listings')}
            style={{ 
              borderRadius: '0',
              margin: '0 0.75rem',
              textAlign: 'left',
              justifyContent: 'flex-start',
              padding: '0.875rem 1rem',
              width: 'calc(100% - 1.5rem)',
              borderLeft: activeTab === 'listings' ? '3px solid var(--primary)' : '3px solid transparent',
              backgroundColor: activeTab === 'listings' ? 'var(--primary)' : 'transparent',
              color: activeTab === 'listings' ? '#ffffff' : 'var(--gray-700)',
              fontWeight: activeTab === 'listings' ? '600' : '400'
            }}
          >
            🛍️ Listings
          </button>
          <button
            className={`btn ${activeTab === 'bundles' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('bundles')}
            style={{ 
              borderRadius: '0',
              margin: '0 0.75rem',
              textAlign: 'left',
              justifyContent: 'flex-start',
              padding: '0.875rem 1rem',
              width: 'calc(100% - 1.5rem)',
              borderLeft: activeTab === 'bundles' ? '3px solid var(--primary)' : '3px solid transparent',
              backgroundColor: activeTab === 'bundles' ? 'var(--primary)' : 'transparent',
              color: activeTab === 'bundles' ? '#ffffff' : 'var(--gray-700)',
              fontWeight: activeTab === 'bundles' ? '600' : '400'
            }}
          >
            📦 Bundles
          </button>
          <button
            className={`btn ${activeTab === 'packs' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('packs')}
            style={{ 
              borderRadius: '0',
              margin: '0 0.75rem',
              textAlign: 'left',
              justifyContent: 'flex-start',
              padding: '0.875rem 1rem',
              width: 'calc(100% - 1.5rem)',
              borderLeft: activeTab === 'packs' ? '3px solid var(--primary)' : '3px solid transparent',
              backgroundColor: activeTab === 'packs' ? 'var(--primary)' : 'transparent',
              color: activeTab === 'packs' ? '#ffffff' : 'var(--gray-700)',
              fontWeight: activeTab === 'packs' ? '600' : '400'
            }}
          >
            🎁 Packs
          </button>
          <button
            className={`btn ${activeTab === 'disputes' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('disputes')}
            style={{ 
              borderRadius: '0',
              margin: '0 0.75rem',
              textAlign: 'left',
              justifyContent: 'flex-start',
              padding: '0.875rem 1rem',
              width: 'calc(100% - 1.5rem)',
              borderLeft: activeTab === 'disputes' ? '3px solid var(--primary)' : '3px solid transparent',
              backgroundColor: activeTab === 'disputes' ? 'var(--primary)' : 'transparent',
              color: activeTab === 'disputes' ? '#ffffff' : 'var(--gray-700)',
              fontWeight: activeTab === 'disputes' ? '600' : '400'
            }}
          >
            ⚖️ Disputes
          </button>
        </aside>

        {/* Main Content */}
        <main style={{ flex: 1, padding: '2rem', overflow: 'auto' }}>
          {error && (
            <div className="alert alert-error">
              <strong>Error:</strong> {error}
            </div>
          )}

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
    </div>
  );
}

export default App;
