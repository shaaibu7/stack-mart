import { useState } from 'react';
import { useChainhooks } from '../hooks/useChainhooks';

export const ChainhookEvents = () => {
  const { 
    events, 
    isLoading, 
    error, 
    getLatestListings, 
    getLatestPurchases,
    getEscrowUpdates 
  } = useChainhooks();

  const [dismissed, setDismissed] = useState(false);

  const latestListings = getLatestListings();
  const latestPurchases = getLatestPurchases();
  const escrowUpdates = getEscrowUpdates();

  // If there's an error and it's not dismissed, show a small notification
  if (error && !dismissed) {
    return (
      <div style={{ 
        padding: '12px 16px', 
        backgroundColor: '#fff3cd',
        border: '1px solid #ffc107',
        borderRadius: '6px',
        margin: '10px 20px',
        color: '#856404',
        fontSize: '0.9em',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center'
      }}>
        <span>⚠️ Chainhook server unavailable. Real-time events disabled.</span>
        <button
          onClick={() => setDismissed(true)}
          style={{
            background: 'transparent',
            border: 'none',
            color: '#856404',
            cursor: 'pointer',
            fontSize: '18px',
            padding: '0 8px',
            marginLeft: '12px'
          }}
          aria-label="Dismiss"
        >
          ×
        </button>
      </div>
    );
  }

  // If error is dismissed, don't show the component at all
  if (error && dismissed) {
    return null;
  }

  return (
    <div style={{ padding: '20px', border: '1px solid #ddd', borderRadius: '8px', margin: '20px' }}>
      <h2>📡 Real-time Marketplace Events (Chainhooks)</h2>
      
      {isLoading && <p>Loading events...</p>}
      
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '20px', marginTop: '20px' }}>
        <div>
          <h3>New Listings ({latestListings.length})</h3>
          {latestListings.slice(0, 5).map((event, idx) => (
            <div key={idx} style={{ padding: '10px', margin: '5px 0', backgroundColor: '#f5f5f5', borderRadius: '4px' }}>
              <p><strong>TX:</strong> {event.txid.slice(0, 16)}...</p>
              <p><strong>Function:</strong> {event.function}</p>
              <p><strong>Time:</strong> {new Date(event.timestamp).toLocaleString()}</p>
            </div>
          ))}
        </div>
        
        <div>
          <h3>Recent Purchases ({latestPurchases.length})</h3>
          {latestPurchases.slice(0, 5).map((event, idx) => (
            <div key={idx} style={{ padding: '10px', margin: '5px 0', backgroundColor: '#e8f5e9', borderRadius: '4px' }}>
              <p><strong>TX:</strong> {event.txid.slice(0, 16)}...</p>
              <p><strong>Function:</strong> {event.function}</p>
              <p><strong>Time:</strong> {new Date(event.timestamp).toLocaleString()}</p>
            </div>
          ))}
        </div>
        
        <div>
          <h3>Escrow Updates ({escrowUpdates.length})</h3>
          {escrowUpdates.slice(0, 5).map((event, idx) => (
            <div key={idx} style={{ padding: '10px', margin: '5px 0', backgroundColor: '#fff3e0', borderRadius: '4px' }}>
              <p><strong>TX:</strong> {event.txid.slice(0, 16)}...</p>
              <p><strong>Function:</strong> {event.function}</p>
              <p><strong>Time:</strong> {new Date(event.timestamp).toLocaleString()}</p>
            </div>
          ))}
        </div>
      </div>
      
      <div style={{ marginTop: '20px', fontSize: '0.9em', color: '#666' }}>
        <p>Total events received: {events.length}</p>
        <p>Events update every 10 seconds</p>
      </div>
    </div>
  );
};

