import { useState, useEffect } from 'react';
import { WalletButton } from './components/WalletButton';
import { CreateListing } from './components/CreateListing';
import { ListingCard } from './components/ListingCard';
import { ListingDetails } from './components/ListingDetails';
import { ChainhookEvents } from './components/ChainhookEvents';
import { useStacks } from './hooks/useStacks';
import { useContract } from './hooks/useContract';
import './App.css';

function App() {
  const { isConnected } = useStacks();
  const { getAllListings } = useContract();
  const [listings, setListings] = useState<any[]>([]);
  const [selectedListingId, setSelectedListingId] = useState<number | null>(null);
  const [isLoadingListings, setIsLoadingListings] = useState(false);
  const [error, setError] = useState<string | null>(null);

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

  if (selectedListingId) {
    return (
      <div className="App">
        <header style={{ 
          padding: '20px', 
          borderBottom: '1px solid #ddd',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}>
          <h1>StackMart Marketplace</h1>
          <WalletButton />
        </header>
        <ListingDetails 
          listingId={selectedListingId} 
          onClose={() => setSelectedListingId(null)}
        />
      </div>
    );
  }

  return (
    <div className="App" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      <header style={{ 
        padding: '20px', 
        borderBottom: '1px solid #ddd',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        backgroundColor: 'white',
      }}>
        <h1 style={{ margin: 0, color: '#333' }}>StackMart Marketplace</h1>
        <WalletButton />
      </header>

      <main style={{ padding: '20px', maxWidth: '1200px', margin: '0 auto' }}>
        {error && (
          <div style={{ 
            padding: '15px', 
            backgroundColor: '#f8d7da', 
            color: '#721c24', 
            borderRadius: '4px', 
            marginBottom: '20px' 
          }}>
            <strong>Error:</strong> {error}
          </div>
        )}
        <section style={{ backgroundColor: 'white', borderRadius: '8px', padding: '30px', marginBottom: '30px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
          <h2 style={{ marginTop: 0 }}>Create Listing</h2>
          <CreateListing />
        </section>

        <section style={{ backgroundColor: 'white', borderRadius: '8px', padding: '30px', marginBottom: '30px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
            <h2 style={{ marginTop: 0 }}>Available Listings</h2>
            <button
              onClick={loadListings}
              disabled={isLoadingListings}
              style={{
                padding: '8px 16px',
                backgroundColor: '#6c757d',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                cursor: isLoadingListings ? 'not-allowed' : 'pointer',
              }}
            >
              {isLoadingListings ? 'Loading...' : 'Refresh'}
            </button>
          </div>
          {isLoadingListings ? (
            <p>Loading listings...</p>
          ) : (
            <div style={{ display: 'flex', flexWrap: 'wrap' }}>
              {listings.length === 0 ? (
                <p>No listings available. Create one above!</p>
              ) : (
                listings.map((listing) => (
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
                ))
              )}
            </div>
          )}
        </section>

        <section style={{ backgroundColor: 'white', borderRadius: '8px', padding: '30px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
          <ChainhookEvents />
        </section>
      </main>
    </div>
  );
}

export default App;
