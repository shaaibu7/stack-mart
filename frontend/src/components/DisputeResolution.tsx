import { useState, useEffect } from 'react';
import { useStacks } from '../hooks/useStacks';
import { useContract } from '../hooks/useContract';
import { makeContractCall, broadcastTransaction, AnchorMode, PostConditionMode, uintCV, stringAsciiCV, boolCV } from '@stacks/transactions';
import { CONTRACT_ID } from '../config/contract';
import { TRANSACTION_FEE, DISPUTE_RESOLUTION_THRESHOLD_MICROSTX } from '../config/constants';

interface DisputeResolutionProps {
  listingId: number;
  escrowId: number;
}

export const DisputeResolution = ({ escrowId }: DisputeResolutionProps) => {
  const { userSession, network, isConnected, userData } = useStacks();
  const { getDispute, getDisputeStakes } = useContract();
  const [dispute, setDispute] = useState<any>(null);
  const [userStake, setUserStake] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [reason, setReason] = useState('');
  const [stakeAmount, setStakeAmount] = useState('');
  const [stakeSide, setStakeSide] = useState<boolean>(true); // true = buyer, false = seller
  const [vote, setVote] = useState<boolean>(true);

  useEffect(() => {
    if (escrowId && isConnected) {
      loadDispute();
    }
  }, [escrowId, isConnected]);

  const loadDispute = async () => {
    setIsLoading(true);
    try {
      // Try to find dispute for this escrow
      // Note: In production, you'd need a way to map escrow-id to dispute-id
      // For now, we'll try dispute IDs starting from 1
      for (let id = 1; id <= 100; id++) {
        try {
          const disputeData = await getDispute(id);
          if (disputeData?.value && disputeData.value['escrow-id']?.value === escrowId) {
            setDispute({ id, ...disputeData.value });

            // Load user's stake if connected
            if (userData?.profile?.stxAddress?.mainnet) {
              try {
                const stakeData = await getDisputeStakes(id, userData.profile.stxAddress.mainnet);
                if (stakeData?.value) {
                  setUserStake(stakeData.value);
                }
              } catch (err) {
                // No stake found
              }
            }
            break;
          }
        } catch (err) {
          // Dispute doesn't exist, continue
        }
      }
    } catch (error) {
      console.error('Error loading dispute:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreateDispute = async () => {
    if (!reason.trim()) {
      alert('Please enter a reason for the dispute');
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

      const txOptions = {
        contractAddress: CONTRACT_ID.split('.')[0],
        contractName: CONTRACT_ID.split('.')[1],
        functionName: 'create-dispute',
        functionArgs: [
          uintCV(escrowId),
          stringAsciiCV(reason),
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
        alert(`Dispute created! TX: ${broadcastResponse.txid}`);
        setReason('');
        loadDispute();
      }
    } catch (error) {
      console.error('Error creating dispute:', error);
      alert('Failed to create dispute');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleStake = async () => {
    if (!stakeAmount || parseFloat(stakeAmount) <= 0) {
      alert('Please enter a valid stake amount');
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

      const amountMicroSTX = Math.floor(parseFloat(stakeAmount) * 1000000);

      const txOptions = {
        contractAddress: CONTRACT_ID.split('.')[0],
        contractName: CONTRACT_ID.split('.')[1],
        functionName: 'stake-on-dispute',
        functionArgs: [
          uintCV(dispute.id),
          uintCV(amountMicroSTX),
          boolCV(stakeSide),
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
        alert(`Stake placed! TX: ${broadcastResponse.txid}`);
        setStakeAmount('');
        loadDispute();
      }
    } catch (error) {
      console.error('Error staking on dispute:', error);
      alert('Failed to stake on dispute');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleVote = async () => {
    if (!userStake || !userStake.amount || userStake.amount.value === '0') {
      alert('You must stake before voting');
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

      const txOptions = {
        contractAddress: CONTRACT_ID.split('.')[0],
        contractName: CONTRACT_ID.split('.')[1],
        functionName: 'vote-on-dispute',
        functionArgs: [
          uintCV(dispute.id),
          boolCV(vote),
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
        alert(`Vote cast! TX: ${broadcastResponse.txid}`);
        loadDispute();
      }
    } catch (error) {
      console.error('Error voting on dispute:', error);
      alert('Failed to vote on dispute');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleResolve = async () => {
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
        functionName: 'resolve-dispute',
        functionArgs: [
          uintCV(dispute.id),
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
        alert(`Dispute resolved! TX: ${broadcastResponse.txid}`);
        loadDispute();
      }
    } catch (error) {
      console.error('Error resolving dispute:', error);
      alert('Failed to resolve dispute');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="card">
        <div className="card-body">
          <p>Loading dispute information...</p>
        </div>
      </div>
    );
  }

  if (!dispute) {
    return (
      <div className="card">
        <div className="card-body">
          <h3>⚖️ Create Dispute</h3>
          <p>If there's an issue with the escrow, you can create a dispute for community resolution.</p>

          <div className="form-group">
            <label className="form-label">Dispute Reason</label>
            <textarea
              className="form-input"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Describe the issue..."
              rows={4}
              maxLength={500}
            />
            <div className="form-help">Maximum 500 characters</div>
          </div>

          <button
            onClick={handleCreateDispute}
            disabled={isSubmitting || !isConnected}
            className="btn btn-danger"
          >
            {isSubmitting ? 'Creating...' : 'Create Dispute'}
          </button>

          {!isConnected && (
            <p className="alert alert-warning" style={{ marginTop: '10px' }}>
              Please connect your wallet to create a dispute
            </p>
          )}
        </div>
      </div>
    );
  }

  const disputeData = dispute;
  const buyerStakes = disputeData['buyer-stakes']?.value || disputeData['buyer-stakes'] || 0;
  const sellerStakes = disputeData['seller-stakes']?.value || disputeData['seller-stakes'] || 0;
  const isResolved = disputeData.resolved?.value || disputeData.resolved || false;
  const disputeReason = disputeData.reason?.value || disputeData.reason || '';

  return (
    <div className="card">
      <div className="card-body">
        <h3>⚖️ Dispute #{dispute.id}</h3>

        <div className="info-box" style={{ marginBottom: '20px' }}>
          <p><strong>Status:</strong> {isResolved ? '✅ Resolved' : '⏳ Active'}</p>
          <p><strong>Reason:</strong> {disputeReason}</p>
          <p><strong>Buyer Stakes:</strong> {(Number(buyerStakes) / 1000000).toFixed(6)} STX</p>
          <p><strong>Seller Stakes:</strong> {(Number(sellerStakes) / 1000000).toFixed(6)} STX</p>
        </div>

        {!isResolved && (
          <>
            <div className="form-group">
              <label className="form-label">Stake Amount (STX)</label>
              <input
                className="form-input"
                type="number"
                step="0.000001"
                min="0.001"
                value={stakeAmount}
                onChange={(e) => setStakeAmount(e.target.value)}
                placeholder="0.001"
              />
              <div className="form-help">Minimum 0.001 STX</div>
            </div>

            <div className="form-group">
              <label className="form-label">Side</label>
              <select
                className="form-input"
                value={stakeSide ? 'buyer' : 'seller'}
                onChange={(e) => setStakeSide(e.target.value === 'buyer')}
              >
                <option value="buyer">Buyer</option>
                <option value="seller">Seller</option>
              </select>
            </div>

            <button
              onClick={handleStake}
              disabled={isSubmitting || !isConnected}
              className="btn btn-primary"
              style={{ marginBottom: '10px' }}
            >
              {isSubmitting ? 'Staking...' : 'Stake on Dispute'}
            </button>

            {userStake && userStake.amount && Number(userStake.amount.value || userStake.amount) > 0 && (
              <>
                <div className="form-group" style={{ marginTop: '20px' }}>
                  <label className="form-label">Your Vote</label>
                  <select
                    className="form-input"
                    value={vote ? 'buyer' : 'seller'}
                    onChange={(e) => setVote(e.target.value === 'buyer')}
                  >
                    <option value="buyer">Support Buyer</option>
                    <option value="seller">Support Seller</option>
                  </select>
                </div>

                <button
                  onClick={handleVote}
                  disabled={isSubmitting || !isConnected}
                  className="btn btn-success"
                  style={{ marginBottom: '10px' }}
                >
                  {isSubmitting ? 'Voting...' : 'Cast Vote'}
                </button>
              </>
            )}

            {Number(buyerStakes) + Number(sellerStakes) >= DISPUTE_RESOLUTION_THRESHOLD_MICROSTX && (
              <button
                onClick={handleResolve}
                disabled={isSubmitting || !isConnected}
                className="btn btn-warning"
              >
                {isSubmitting ? 'Resolving...' : 'Resolve Dispute'}
              </button>
            )}
          </>
        )}

        {!isConnected && (
          <p className="alert alert-warning" style={{ marginTop: '10px' }}>
            Please connect your wallet to participate
          </p>
        )}
      </div>
    </div>
  );
};

