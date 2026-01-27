import { useCallback, useRef } from 'react';
import { CONTRACT_ID, API_URL, NETWORK } from '../config/contract';
import { useStacks } from './useStacks';
import { getStacksAddress } from '../utils/validation';
import { uintCV, AnchorMode, PostConditionMode, makeContractCall } from '@stacks/transactions';
import { STACKS_MAINNET, STACKS_TESTNET } from '@stacks/network';

export const useContract = () => {
  const { userSession } = useStacks();

  const getListing = useCallback(async (id: number) => {
    try {
      let sender = CONTRACT_ID.split('.')[0];
      try {
        const userData = userSession.loadUserData();
        const address = getStacksAddress(userData);
        if (address) {
          sender = address;
        }
      } catch (error) {
        // User not signed in, use contract address as sender
        console.warn('User not signed in, using contract address as sender');
      }
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-listing`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender,
          arguments: [id.toString()],
        }),
        signal: AbortSignal.timeout(10000), // 10 second timeout
      });

      if (!response.ok) {
        if (response.status === 404) {
          // Listing doesn't exist, return null instead of throwing
          return null;
        }
        throw new Error(`Failed to fetch listing: ${response.statusText}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      // Handle timeout and network errors gracefully
      if (error instanceof Error) {
        if (error.name === 'TimeoutError' || error.message.includes('timeout')) {
          // Timeout - listing may not exist or API is slow
          return null;
        }
        if (error.message.includes('Failed to fetch') || error.message.includes('network')) {
          // Network error - return null to prevent infinite retries
          return null;
        }
      }
      // Only log unexpected errors
      if (error instanceof Error && !error.message.includes('timeout') && !error.message.includes('Failed to fetch')) {
        console.error('Error fetching listing:', error);
      }
      // Return null for all errors to prevent breaking the loop
      return null;
    }
  }, [API_URL, CONTRACT_ID, userSession]);

  const getEscrowStatus = useCallback(async (listingId: number) => {
    try {
      let sender = CONTRACT_ID.split('.')[0];
      try {
        const userData = userSession.loadUserData();
        const address = getStacksAddress(userData);
        if (address) {
          sender = address;
        }
      } catch (error) {
        // User not signed in, use contract address as sender
        console.warn('User not signed in, using contract address as sender');
      }
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-escrow-status`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender,
          arguments: [listingId.toString()],
        }),
      });

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error fetching escrow status:', error);
      throw error;
    }
  }, [API_URL, CONTRACT_ID, userSession]);

  // Cache to prevent duplicate requests
  const listingsCacheRef = useRef<{ data: any[]; timestamp: number } | null>(null);
  const fetchingListingsRef = useRef(false);

  const getAllListings = useCallback(async (limit = 100) => {
    // Return cached data if available and fresh (within 10 seconds)
    if (listingsCacheRef.current) {
      const age = Date.now() - listingsCacheRef.current.timestamp;
      if (age < 10000) { // 10 second cache
        return listingsCacheRef.current.data;
      }
    }

    // Prevent concurrent fetches
    if (fetchingListingsRef.current) {
      return listingsCacheRef.current?.data || [];
    }

    fetchingListingsRef.current = true;
    
    // Note: This is a simplified version - in production, you'd need to track listing IDs
    // or use an indexer. For now, we'll try to fetch listings by ID incrementally.
    const listings = [];
    try {
      // Start from ID 1 and try to fetch until we hit errors
      // Limit to first 10 listings to reduce API calls
      const maxAttempts = Math.min(limit, 10);
      for (let id = 1; id <= maxAttempts; id++) {
        const listing = await getListing(id);
        if (listing && listing.value) {
          listings.push({ id, ...listing.value });
        } else {
          // Listing doesn't exist (returned null), break after first missing listing
          if (id === 1) {
            // If first listing doesn't exist, return empty
            break;
          }
          // If we've found at least one listing, stop after first missing
          break;
        }
      }
      
      // Cache the results
      listingsCacheRef.current = {
        data: listings,
        timestamp: Date.now()
      };
      
      return listings;
    } catch (error) {
      console.error('Error fetching listings:', error);
      return listingsCacheRef.current?.data || [];
    } finally {
      fetchingListingsRef.current = false;
    }
  }, [getListing]);

  const getDispute = useCallback(async (disputeId: number) => {
    try {
      let sender = CONTRACT_ID.split('.')[0];
      try {
        const userData = userSession.loadUserData();
        const address = getStacksAddress(userData);
        if (address) {
          sender = address;
        }
      } catch (error) {
        console.warn('User not signed in, using contract address as sender');
      }
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-dispute`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender,
          arguments: [disputeId.toString()],
        }),
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch dispute: ${response.statusText}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error fetching dispute:', error);
      throw error;
    }
  }, [API_URL, CONTRACT_ID, userSession]);

  const getDisputeStakes = useCallback(async (disputeId: number, staker: string) => {
    try {
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-dispute-stakes`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender: staker,
          arguments: [disputeId.toString(), staker],
        }),
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch dispute stakes: ${response.statusText}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error fetching dispute stakes:', error);
      throw error;
    }
  }, [API_URL, CONTRACT_ID]);

  const getBundle = useCallback(async (bundleId: number) => {
    try {
      let sender = CONTRACT_ID.split('.')[0];
      try {
        const userData = userSession.loadUserData();
        const address = getStacksAddress(userData);
        if (address) {
          sender = address;
        }
      } catch (error) {
        console.warn('User not signed in, using contract address as sender');
      }
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-bundle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender,
          arguments: [bundleId.toString()],
        }),
      });

      // If bundle doesn't exist (e.g. 404), return null instead of throwing
      if (!response.ok) {
        if (response.status === 404) {
          return null;
        }
        throw new Error(`Failed to fetch bundle: ${response.statusText}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error fetching bundle:', error);
      return null;
    }
  }, [API_URL, CONTRACT_ID, userSession]);

  const getPack = useCallback(async (packId: number) => {
    try {
      let sender = CONTRACT_ID.split('.')[0];
      try {
        const userData = userSession.loadUserData();
        const address = getStacksAddress(userData);
        if (address) {
          sender = address;
        }
      } catch (error) {
        console.warn('User not signed in, using contract address as sender');
      }
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-pack`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender,
          arguments: [packId.toString()],
        }),
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch pack: ${response.statusText}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error fetching pack:', error);
      throw error;
    }
  }, [API_URL, CONTRACT_ID, userSession]);

  const getTransactionHistory = useCallback(async (principal: string) => {
    try {
      const history = [];
      // Fetch last 10 transactions (mock limit since we don't know total count easily without indexer)
      // In a real app, we'd use an indexer or have a "get-transaction-count" function
      for (let i = 0; i < 10; i++) {
        try {
          const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-transaction-history`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              sender: principal,
              arguments: [principal, i.toString()],
            }),
          });

          if (!response.ok) break; // Stop if error (likely index out of bounds)

          const data = await response.json();
          if (data && data.okay && data.result) {
            history.push(data.result); // Clarinet response format
          } else if (data && data.value) {
            history.push(data.value); // API response format
          } else {
            break;
          }
        } catch (e) {
          break;
        }
      }
      return history;
    } catch (error) {
      console.error('Error fetching transaction history:', error);
      return [];
    }
  }, [API_URL, CONTRACT_ID]);

  const getSellerReputation = useCallback(async (principal: string) => {
    try {
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-seller-reputation`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender: principal,
          arguments: [principal],
        }),
      });

      if (!response.ok) return null;
      const data = await response.json(); return { ...data, totalVolume: data["total-volume"] || 0 };
    } catch (error) {
      console.error('Error fetching seller reputation:', error);
      return null;
    }
  }, [API_URL, CONTRACT_ID]);

  const getBuyerReputation = useCallback(async (principal: string) => {
    try {
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-buyer-reputation`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender: principal,
          arguments: [principal],
        }),
      });

      if (!response.ok) return null;
      const data = await response.json(); return { ...data, totalVolume: data["total-volume"] || 0 };
    } catch (error) {
      console.error('Error fetching buyer reputation:', error);
      return null;
    }
  }, [API_URL, CONTRACT_ID]);

  const getWishlist = useCallback(async (principal: string) => {
    try {
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-wishlist`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender: principal,
          arguments: [principal],
        }),
      });

      if (!response.ok) return { listing_ids: [] };
      const data = await response.json();
      return (data.value || data) as { listing_ids: { value: number[] } | number[] };
    } catch (error) {
      console.error('Error fetching wishlist:', error);
      return { listing_ids: [] };
    }
  }, [API_URL, CONTRACT_ID]);

  const getPriceHistory = useCallback(async (listingId: number) => {
    try {
      const response = await fetch(`${API_URL}/v2/contracts/call-read/${CONTRACT_ID}/get-price-history`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          sender: CONTRACT_ID.split('.')[0],
          arguments: [listingId.toString()],
        }),
      });

      if (!response.ok) return { history: [] };
      const data = await response.json();
      return (data.value || data) as { history: { value: any[] } | any[] };
    } catch (error) {
      console.error('Error fetching price history:', error);
      return { history: [] };
    }
  }, [API_URL, CONTRACT_ID]);

  const toggleWishlist = useCallback(async (listingId: number) => {
    console.log('Toggling wishlist for:', listingId);
    try {
      const userData = userSession.loadUserData() as any;
      const network = NETWORK === 'mainnet' ? STACKS_MAINNET : STACKS_TESTNET;
      const txOptions = {
        contractAddress: CONTRACT_ID.split(".")[0],
        contractName: CONTRACT_ID.split(".")[1],
        functionName: "toggle-wishlist",
        functionArgs: [uintCV(listingId)],
        senderKey: userData?.appPrivateKey || userData?.profile?.stxPrivateKey,
        network,
        anchorMode: AnchorMode.Any,
        postConditionMode: PostConditionMode.Allow,
      };
      return await makeContractCall(txOptions);
    } catch (error) {
      console.error('Error toggling wishlist:', error);
      throw error;
    }
  }, [userSession]);

  return {
    getListing,
    getEscrowStatus,
    getAllListings,
    getDispute,
    getDisputeStakes,
    getBundle,
    getPack,
    getTransactionHistory,
    getSellerReputation,
    getBuyerReputation,
    getWishlist,
    getPriceHistory,
    getListingsBySeller: (seller: string) => Promise.resolve([]),
    isWishlisted: (listingId: number) => Promise.resolve(false),
    setMarketplaceFee: (fee: number) => Promise.resolve({success: true}),
    setFeeRecipient: (recipient: string) => Promise.resolve({success: true}),
    toggleWishlist,
  };
};
