import { useState, useEffect, useRef } from 'react';
import { useStacks } from '../hooks/useStacks';
import { useContract } from '../hooks/useContract';
import { makeContractCall, broadcastTransaction, AnchorMode, PostConditionMode, uintCV, listCV } from '@stacks/transactions';
import { CONTRACT_ID } from '../config/contract';
import { TRANSACTION_FEE } from '../config/constants';
import { validateBasisPoints } from '../utils/validation';


export const BundleManagement = () => {
  const { userSession, network, isConnected } = useStacks();
  const { getAllListings, getBundle } = useContract();
  const [listings, setListings] = useState<any[]>([]);
  const [bundles, setBundles] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showCreate, setShowCreate] = useState(false);
  const [selectedListings, setSelectedListings] = useState<number[]>([]);
  const [discountBips, setDiscountBips] = useState('');

  const hasLoadedRef = useRef(false);
  
  useEffect(() => {
    if (isConnected && !hasLoadedRef.current) {
      hasLoadedRef.current = true;
      loadListings();
      loadBundles();
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

  const loadBundles = async () => {
    // Try to load bundles (in production, you'd track bundle IDs)
    const bundleList = [];
    // Limit the number of attempts to avoid excessive 404s
    const maxAttempts = 10;
    for (let id = 1; id <= maxAttempts; id++) {
      const bundleData = await getBundle(id);
      if (bundleData?.value) {
        bundleList.push({ id, ...bundleData.value });
      } else {
        // If we didn't get a bundle for this id, stop trying further ids
        // to avoid spamming the API with non-existent IDs
        if (id > 1) break;
      }
    }
    setBundles(bundleList);
  };

  const handleCreateBundle = async () => {
    if (selectedListings.length === 0) {
      alert('Please select at least one listing');
      return;
    }

    const discountValidation = validateBasisPoints(discountBips, 5000);
    if (!discountValidation.valid) {
      alert(discountValidation.error || 'Discount must be between 0 and 5000 basis points (0-50%)');
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

      // Convert listing IDs to uintCV list (max 10)
      const listingIds = selectedListings.slice(0, 10).map(id => uintCV(id));

      const txOptions = {
        contractAddress: CONTRACT_ID.split('.')[0],
        contractName: CONTRACT_ID.split('.')[1],
        functionName: 'create-bundle',
        functionArgs: [
          listCV(listingIds),
          uintCV(parseInt(discountBips)),
        ],
        senderKey: userData.appPrivateKey,
        network,
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
        fee: TRANSACTION_FEE,
      };

      const transaction = await makeContractCall(txOptions);
      const broadcastResponse = await broadcastTransaction({ transaction, network });

      if ('error' in broadcastResponse) {
        alert(`Error: ${broadcastResponse.error}`);
      } else {
        alert(`Bundle created! TX: ${broadcastResponse.txid}`);
        setSelectedListings([]);
        setDiscountBips('');
        setShowCreate(false);
        loadBundles();
      }
    } catch (error) {
      console.error('Error creating bundle:', error);
      alert('Failed to create bundle');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleBuyBundle = async (bundleId: number) => {
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
        functionName: 'buy-bundle',
        functionArgs: [
          uintCV(bundleId),
        ],
        senderKey: userData.appPrivateKey,
        network,
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
        fee: TRANSACTION_FEE,
      };

      const transaction = await makeContractCall(txOptions);
      const broadcastResponse = await broadcastTransaction({ transaction, network });

      if ('error' in broadcastResponse) {
        alert(`Error: ${broadcastResponse.error}`);
      } else {
        alert(`Bundle purchased! TX: ${broadcastResponse.txid}`);
        loadBundles();
      }
    } catch (error) {
      console.error('Error buying bundle:', error);
      alert('Failed to buy bundle');
    } finally {
      setIsSubmitting(false);
    }
  };

  const toggleListing = (listingId: number) => {
    if (selectedListings.includes(listingId)) {
      setSelectedListings(selectedListings.filter(id => id !== listingId));
    } else {
      if (selectedListings.length >= 10) {
        alert('Maximum 10 listings per bundle');
        return;
      }
      setSelectedListings([...selectedListings, listingId]);
    }
  };

  const calculateBundlePrice = (bundle: any) => {
    const listingIds = bundle['listing-ids']?.value || bundle['listing-ids'] || [];
    const discountBips = bundle['discount-bips']?.value || bundle['discount-bips'] || 0;

    let totalPrice = 0;
    listingIds.forEach((id: any) => {
      const listing = listings.find(l => l.id === (id.value || id));
      if (listing) {
        totalPrice += listing.price || 0;
      }
    });

    const discount = (totalPrice * Number(discountBips)) / 10000;
    return totalPrice - discount;
  };

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>📦 Bundles</h2>
        {isConnected && (
          <button
            onClick={() => setShowCreate(!showCreate)}
            className="btn btn-success"
          >
            {showCreate ? 'Cancel' : '+ Create Bundle'}
          </button>
        )}
      </div>

      {showCreate && (
        <div className="card" style={{ marginBottom: '30px' }}>
          <div className="card-body">
            <h3>Create New Bundle</h3>
            <p>Select up to 10 listings and set a discount percentage.</p>

            <div className="form-group">
              <label className="form-label">Discount (basis points)</label>
              <input
                className="form-input"
                type="number"
                min="0"
                max="5000"
                value={discountBips}
                onChange={(e) => setDiscountBips(e.target.value)}
                placeholder="500"
              />
              <div className="form-help">
                Max 5000 (50%). Example: 500 = 5% discount, 1000 = 10% discount
              </div>
            </div>

            <div className="form-group">
              <label className="form-label">Select Listings ({selectedListings.length}/10)</label>
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
              onClick={handleCreateBundle}
              disabled={isSubmitting || selectedListings.length === 0}
              className="btn btn-success btn-lg"
            >
              {isSubmitting ? 'Creating...' : 'Create Bundle'}
            </button>
          </div>
        </div>
      )}

      <div>
        {bundles.length === 0 ? (
          <div className="card">
            <div className="card-body">
              <p>No bundles available. Create one to get started!</p>
            </div>
          </div>
        ) : (
          <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '20px' }}>
            {bundles.map((bundle) => {
              const listingIds = bundle['listing-ids']?.value || bundle['listing-ids'] || [];
              const discountBips = bundle['discount-bips']?.value || bundle['discount-bips'] || 0;
              const discountPercent = Number(discountBips) / 100;
              const totalPrice = calculateBundlePrice(bundle);
              const priceInSTX = totalPrice / 1000000;

              return (
                <div key={bundle.id} className="card">
                  <div className="card-body">
                    <h3>Bundle #{bundle.id}</h3>
                    <div className="badge badge-success">
                      {discountPercent}% OFF
                    </div>

                    <div style={{ marginTop: '15px' }}>
                      <p><strong>Listings:</strong> {listingIds.length} items</p>
                      <p><strong>Discount:</strong> {discountPercent}%</p>
                      <p style={{ fontSize: '1.2em', fontWeight: 'bold', color: '#28a745', marginTop: '10px' }}>
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
                        onClick={() => handleBuyBundle(bundle.id)}
                        disabled={isSubmitting}
                        className="btn btn-primary"
                        style={{ width: '100%', marginTop: '15px' }}
                      >
                        {isSubmitting ? 'Processing...' : 'Buy Bundle'}
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

