import { useState, useEffect, useCallback } from 'react';

interface ChainhookEvent {
  txid: string;
  contract: string;
  function: string;
  args: any[];
  timestamp: string;
}

const CHAINHOOK_API_URL = import.meta.env.VITE_CHAINHOOK_API_URL || 'http://localhost:3001';

export const useChainhooks = () => {
  const [events, setEvents] = useState<ChainhookEvent[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [disabled, setDisabled] = useState(false);

  // Fetch recent events
  const fetchEvents = useCallback(async (limit = 50, contract?: string, functionName?: string) => {
    if (disabled) return;
    setIsLoading(true);
    setError(null);
    
    try {
      const params = new URLSearchParams();
      if (limit) params.append('limit', limit.toString());
      if (contract) params.append('contract', contract);
      if (functionName) params.append('function', functionName);
      
      const response = await fetch(`${CHAINHOOK_API_URL}/api/events?${params}`);
      
      if (!response.ok) {
        throw new Error(`Failed to fetch events: ${response.statusText}`);
      }
      
      const data = await response.json();
      setEvents(data.events || []);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error';
      // If the request is being blocked by a browser extension or network error,
      // disable further polling to avoid spamming the console.
      if (errorMessage.toLowerCase().includes('failed to fetch') || errorMessage.toLowerCase().includes('network')) {
        setDisabled(true);
      }
      setError(errorMessage);
      // Only log non-network errors to avoid noisy console output
      if (!errorMessage.toLowerCase().includes('failed to fetch')) {
        // eslint-disable-next-line no-console
        console.error('Error fetching chainhook events:', err);
      }
    } finally {
      setIsLoading(false);
    }
  }, [disabled]);

  // Fetch events for a specific transaction
  const fetchEventByTxid = useCallback(async (txid: string) => {
    setIsLoading(true);
    setError(null);
    
    try {
      const response = await fetch(`${CHAINHOOK_API_URL}/api/events/tx/${txid}`);
      
      if (!response.ok) {
        if (response.status === 404) {
          return null;
        }
        throw new Error(`Failed to fetch event: ${response.statusText}`);
      }
      
      const event = await response.json();
      return event;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error';
      setError(errorMessage);
      console.error('Error fetching event by txid:', err);
      return null;
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Poll for new events
  useEffect(() => {
    fetchEvents();
    
    // Poll every 10 seconds for new events
    const interval = setInterval(() => {
      // Don't keep polling if we've permanently disabled chainhooks
      if (!disabled) {
        fetchEvents();
      }
    }, 10000);
    
    return () => clearInterval(interval);
  }, [fetchEvents, disabled]);

  // Filter events by function name
  const getEventsByFunction = useCallback((functionName: string) => {
    return events.filter(event => event.function === functionName);
  }, [events]);

  // Get latest listing creation events
  const getLatestListings = useCallback(() => {
    return events.filter(event => 
      event.function === 'create-listing' || 
      event.function === 'create-listing-with-nft'
    );
  }, [events]);

  // Get latest purchase events
  const getLatestPurchases = useCallback(() => {
    return events.filter(event => 
      event.function === 'buy-listing' || 
      event.function === 'buy-listing-escrow'
    );
  }, [events]);

  // Get escrow status updates
  const getEscrowUpdates = useCallback(() => {
    return events.filter(event => 
      event.function === 'attest-delivery' ||
      event.function === 'confirm-receipt' ||
      event.function === 'release-escrow'
    );
  }, [events]);

  return {
    events,
    isLoading,
    error,
    fetchEvents,
    fetchEventByTxid,
    getEventsByFunction,
    getLatestListings,
    getLatestPurchases,
    getEscrowUpdates,
  };
};

