import { useState } from 'react';
import { useStacks } from '../hooks/useStacks';
import { makeContractCall, broadcastTransaction, AnchorMode, PostConditionMode, uintCV, principalCV } from '@stacks/transactions';
import { CONTRACT_ID } from '../config/contract';
import { validatePrice, validateBasisPoints, validateStacksAddress } from '../utils/validation';

export const CreateListing = () => {
  const { userSession, network, isConnected } = useStacks();
  const [price, setPrice] = useState('');
  const [royaltyBips, setRoyaltyBips] = useState('');
  const [royaltyRecipient, setRoyaltyRecipient] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!isConnected || !userSession) {
      alert('Please connect your wallet first');
      return;
    }

    // Validate inputs
    const priceValidation = validatePrice(price);
    if (!priceValidation.valid) {
      alert(priceValidation.error);
      return;
    }

    const bipsValidation = validateBasisPoints(royaltyBips, 1000);
    if (!bipsValidation.valid) {
      alert(bipsValidation.error);
      return;
    }

    if (!validateStacksAddress(royaltyRecipient)) {
      alert('Please enter a valid Stacks address (starts with SP or ST)');
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

      const priceMicroSTX = Math.floor(parseFloat(price) * 1000000);
      const royaltyBipsNum = parseInt(royaltyBips);

      const txOptions = {
        contractAddress: CONTRACT_ID.split('.')[0],
        contractName: CONTRACT_ID.split('.')[1],
        functionName: 'create-listing',
        functionArgs: [
          uintCV(priceMicroSTX),
          uintCV(royaltyBipsNum),
          principalCV(royaltyRecipient),
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
        alert(`Listing created! TX: ${broadcastResponse.txid}`);
        // Reset form
        setPrice('');
        setRoyaltyBips('');
        setRoyaltyRecipient('');
      }
    } catch (error) {
      console.error('Error creating listing:', error);
      alert('Failed to create listing');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isConnected) {
    return (
      <div className="alert alert-info">
        <strong>Wallet Required:</strong> Please connect your wallet to create a listing.
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit}>
      <div className="form-group">
        <label className="form-label">
          Price (STX)
        </label>
        <input
          className="form-input"
          type="number"
          step="0.000001"
          min="0"
          value={price}
          onChange={(e) => setPrice(e.target.value)}
          required
          placeholder="0.00"
        />
        <div className="form-help">Enter the price in STX (e.g., 1.5 for 1.5 STX)</div>
      </div>

      <div className="form-group">
        <label className="form-label">
          Royalty (basis points)
        </label>
        <input
          className="form-input"
          type="number"
          min="0"
          max="1000"
          value={royaltyBips}
          onChange={(e) => setRoyaltyBips(e.target.value)}
          required
          placeholder="500"
        />
        <div className="form-help">Max 1000 (10%). Example: 500 = 5%</div>
      </div>

      <div className="form-group">
        <label className="form-label">
          Royalty Recipient (STX address)
        </label>
        <input
          className="form-input"
          type="text"
          value={royaltyRecipient}
          onChange={(e) => setRoyaltyRecipient(e.target.value)}
          required
          placeholder="SP..."
          style={{ fontFamily: 'monospace' }}
        />
        <div className="form-help">Stacks address that will receive royalty payments</div>
      </div>

      <button
        type="submit"
        className="btn btn-success btn-lg"
        disabled={isSubmitting}
        style={{ width: '100%', marginTop: '1rem' }}
      >
        {isSubmitting ? (
          <>
            <span className="loading"></span>
            Creating Listing...
          </>
        ) : (
          '✨ Create Listing'
        )}
      </button>
    </form>
  );
};

