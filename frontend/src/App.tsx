import { useState } from 'react';
import { WalletButton } from './components/WalletButton';
import { CreateListing } from './components/CreateListing';
import { ListingCard } from './components/ListingCard';
import { ChainhookEvents } from './components/ChainhookEvents';
import { useStacks } from './hooks/useStacks';
import './App.css';

function App() {
  const { isConnected } = useStacks();
  const [listings, setListings] = useState<any[]>([]);
  const [selectedListingId, setSelectedListingId] = useState<number | null>(null);

  // Mock listings for now - will be replaced with actual contract calls
  const mockListings = [
    {
      id: 1,
      seller: 'SP1EQNTKNRGME36P9EEXZCFFNCYBA50VN51676JB',
      price: 1000000, // 1 STX in microSTX
      royaltyBips: 500, // 5%
      royaltyRecipient: 'SP3J75H6FYTCJJW5R0CHVGWDFN8JPZP3DD4DPJRSP',
    },
  ];

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

      <main style={{ padding: '20px' }}>
        <section>
          <h2>Create Listing</h2>
          <CreateListing />
        </section>

        <section style={{ marginTop: '40px' }}>
          <h2>Available Listings</h2>
          <div style={{ display: 'flex', flexWrap: 'wrap' }}>
            {mockListings.map((listing) => (
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
        </section>

        <section style={{ marginTop: '40px' }}>
          <ChainhookEvents />
        </section>
      </main>
    </div>
  );
}

export default App;
