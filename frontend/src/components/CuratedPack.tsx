import { useState, useEffect, useRef } from 'react';
import { useStacks } from '../hooks/useStacks';
import { useContract } from '../hooks/useContract';
import { makeContractCall, broadcastTransaction, AnchorMode, PostConditionMode, uintCV, principalCV, listCV } from '@stacks/transactions';
import { CONTRACT_ID } from '../config/contract';
import { validatePrice } from '../utils/validation';

export const CuratedPack = () => {
  const { userSession, network, isConnected, userData } = useStacks();
  const { getAllListings, getPack } = useContract();
  const [listings, setListings] = useState<any[]>([]);
  const [packs, setPacks] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showCreate, setShowCreate] = useState(false);
  const [selectedListings, setSelectedListings] = useState<number[]>([]);
  const [packPrice, setPackPrice] = useState('');

  const hasLoadedRef = useRef(false);
  
  useEffect(() => {
    if (isConnected && !hasLoadedRef.current) {
      hasLoadedRef.current = true;
      loadListings();
      loadPacks();
    } else if (!isConnected) {
      hasLoadedRef.current = false;
    }
  }, [isConnected]);

  const loadListings = async () => {
    setIsLoading(true);
    try {
      const allListings = await getAllListings();
      setListings(allListings);
    } catch (error) {
      console.error('Error loading listings:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const loadPacks = async () => {
    // Try to load packs (in production, you'd track pack IDs)
    const packList = [];
    for (let id = 1; id <= 50; id++) {
      try {
        const packData = await getPack(id);
        if (packData?.value) {
          packList.push({ id, ...packData.value });
        }
      } catch (err) {
        // Pack doesn't exist
      }
    }
    setPacks(packList);
  };

  const handleCreatePack = async () => {
    if (selectedListings.length === 0) {
      alert('Please select at least one listing');
      return;
    }

    const priceValidation = validatePrice(packPrice);
    if (!priceValidation.valid) {
      alert(priceValidation.error || 'Please enter a valid pack price');
      return;
    }

    const userDataAny = userData as any;
    if (!userDataAny?.profile?.stxAddress?.mainnet) {
      alert('Please connect your wallet first');
      return;
    }

    setIsSubmitting(true);
    try {
      let userData;
      try {
        userData = userSession.loadUserData();
      } catch (error) {
        alert('Please connect your wallet first');
        setIsSubmitting(false);
        return;
      }

      if (!userData || !userData.appPrivateKey) {
        alert('Wallet not properly connected');
        setIsSubmitting(false);
        return;
      }

      const curatorAddress = userDataAny.profile.stxAddress.mainnet;
      const priceMicroSTX = Math.floor(parseFloat(packPrice) * 1000000);

      // Convert listing IDs to uintCV list (max 20)
      const listingIds = selectedListings.slice(0, 20).map(id => uintCV(id));

      const txOptions = {
        contractAddress: CONTRACT_ID.split('.')[0],
        contractName: CONTRACT_ID.split('.')[1],
        functionName: 'create-curated-pack',
        functionArgs: [
          listCV(listingIds),
          uintCV(priceMicroSTX),
          principalCV(curatorAddress),
        ],
        senderKey: userData.appPrivateKey,
        network,
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
        fee: 150000,
      };

      const transaction = await makeContractCall(txOptions);
      const broadcastResponse = await broadcastTransaction({ transaction, network });

      if ('error' in broadcastResponse) {
        alert(`Error: ${broadcastResponse.error}`);
      } else {
        alert(`Curated pack created! TX: ${broadcastResponse.txid}`);
        setSelectedListings([]);
        setPackPrice('');
        setShowCreate(false);
        loadPacks();
      }
    } catch (error) {
      console.error('Error creating pack:', error);
      alert('Failed to create curated pack');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleBuyPack = async (packId: number) => {
    setIsSubmitting(true);
    try {
      let userData;
      try {
        userData = userSession.loadUserData();
      } catch (error) {
        alert('Please connect your wallet first');
        setIsSubmitting(false);
        return;
      }

      if (!userData || !userData.appPrivateKey) {
        alert('Wallet not properly connected');
        setIsSubmitting(false);
        return;
      }

      const txOptions = {
        contractAddress: CONTRACT_ID.split('.')[0],
        contractName: CONTRACT_ID.split('.')[1],
        functionName: 'buy-curated-pack',
        functionArgs: [
          uintCV(packId),
        ],
        senderKey: userData.appPrivateKey,
        network,
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
        fee: 150000,
      };

      const transaction = await makeContractCall(txOptions);
      const broadcastResponse = await broadcastTransaction({ transaction, network });

      if ('error' in broadcastResponse) {
        alert(`Error: ${broadcastResponse.error}`);
      } else {
        alert(`Pack purchased! TX: ${broadcastResponse.txid}`);
        loadPacks();
      }
    } catch (error) {
      console.error('Error buying pack:', error);
      alert('Failed to buy pack');
    } finally {
      setIsSubmitting(false);
    }
  };

  const toggleListing = (listingId: number) => {
    if (selectedListings.includes(listingId)) {
      setSelectedListings(selectedListings.filter(id => id !== listingId));
    } else {
      if (selectedListings.length >= 20) {
        alert('Maximum 20 listings per pack');
        return;
      }
      setSelectedListings([...selectedListings, listingId]);
    }
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>🎁 Curated Packs</h2>
        {isConnected && (
          <button
            onClick={() => setShowCreate(!showCreate)}
            className="btn btn-success"
          >
            {showCreate ? 'Cancel' : '+ Create Pack'}
          </button>
        )}
      </div>

      {showCreate && (
        <div className="card" style={{ marginBottom: '30px' }}>
          <div className="card-body">
            <h3>Create Curated Pack</h3>
            <p>Select up to 20 listings and set a fixed price for the entire pack. You'll receive the payment as the curator.</p>

            <div className="form-group">
              <label className="form-label">Pack Price (STX)</label>
              <input
                className="form-input"
                type="number"
                step="0.000001"
                min="0"
                value={packPrice}
                onChange={(e) => setPackPrice(e.target.value)}
                placeholder="10.0"
              />
              <div className="form-help">
                This is the total price buyers will pay for the entire pack. You'll receive this as the curator.
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Select Listings ({selectedListings.length}/20)</label>
              <div style={{
                maxHeight: '300px',
                overflowY: 'auto',
                border: '1px solid #ddd',
                borderRadius: '4px',
                padding: '10px'
              }}>
                {isLoading ? (
                  <p>Loading listings...</p>
                ) : listings.length === 0 ? (
                  <p>No listings available</p>
                ) : (
                  listings.map((listing) => {
                    const isSelected = selectedListings.includes(listing.id);
                    const priceInSTX = (listing.price || 0) / 1000000;
                    return (
                      <label
                        key={listing.id}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          padding: '10px',
                          cursor: 'pointer',
                          backgroundColor: isSelected ? '#e8f5e9' : 'transparent',
                          borderRadius: '4px',
                          marginBottom: '5px',
                        }}
                      >
                        <input
                          type="checkbox"
                          checked={isSelected}
                          onChange={() => toggleListing(listing.id)}
                          style={{ marginRight: '10px' }}
                        />
                        <div style={{ flex: 1 }}>
                          <strong>Listing #{listing.id}</strong> - {priceInSTX} STX
                          <div style={{ fontSize: '0.9em', color: '#666' }}>
                            Seller: {listing.seller?.value || listing.seller}
                          </div>
                        </div>
                      </label>
                    );
                  })
                )}
              </div>
            </div>

            <button
              onClick={handleCreatePack}
              disabled={isSubmitting || selectedListings.length === 0 || !packPrice}
              className="btn btn-success btn-lg"
            >
              {isSubmitting ? 'Creating...' : 'Create Curated Pack'}
            </button>
          </div>
        </div>
      )}

      <div>
        {packs.length === 0 ? (
          <div className="card">
            <div className="card-body">
              <p>No curated packs available. Create one to get started!</p>
            </div>
          </div>
        ) : (
          <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '20px' }}>
            {packs.map((pack) => {
              const listingIds = pack['listing-ids']?.value || pack['listing-ids'] || [];
              const packPriceValue = pack.price?.value || pack.price || 0;
              const curator = pack.curator?.value || pack.curator || '';
              const priceInSTX = Number(packPriceValue) / 1000000;

              return (
                <div key={pack.id} className="card">
                  <div className="card-body">
                    <h3>🎁 Pack #{pack.id}</h3>
                    <div className="badge badge-info">
                      Curated Pack
                    </div>

                    <div style={{ marginTop: '15px' }}>
                      <p><strong>Listings:</strong> {listingIds.length} items</p>
                      <p><strong>Curator:</strong> <span style={{ fontFamily: 'monospace', fontSize: '0.9em' }}>{curator.slice(0, 10)}...</span></p>
                      <p style={{ fontSize: '1.2em', fontWeight: 'bold', color: '#007bff', marginTop: '10px' }}>
                        {priceInSTX.toFixed(6)} STX
                      </p>
                    </div>

                    <div style={{ marginTop: '15px', fontSize: '0.9em', color: '#666' }}>
                      <strong>Includes:</strong>
                      <ul style={{ marginTop: '5px', paddingLeft: '20px' }}>
                        {listingIds.slice(0, 5).map((id: any, idx: number) => (
                          <li key={idx}>Listing #{id.value || id}</li>
                        ))}
                        {listingIds.length > 5 && <li>...and {listingIds.length - 5} more</li>}
                      </ul>
                    </div>

                    {isConnected && (
                      <button
                        onClick={() => handleBuyPack(pack.id)}
                        disabled={isSubmitting}
                        className="btn btn-primary"
                        style={{ width: '100%', marginTop: '15px' }}
                      >
                        {isSubmitting ? 'Processing...' : 'Buy Pack'}
                      </button>
                    )}

                    {!isConnected && (
                      <p className="alert alert-info" style={{ marginTop: '15px', fontSize: '0.9em' }}>
                        Connect wallet to purchase
                      </p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

