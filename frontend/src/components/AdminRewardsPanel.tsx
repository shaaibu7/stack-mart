import React, { useState } from 'react';

const AdminRewardsPanel: React.FC = () => {
    const [loading, setLoading] = useState(false);
    const [eventName, setEventName] = useState('');

    const triggerSnapshot = async () => {
        setLoading(true);
        // API call mock: await fetch('/api/admin/snapshot', { method: 'POST' });
        setTimeout(() => {
            setLoading(false);
            alert('Snapshot triggered successfully');
        }, 1000);
    };

    return (
        <div className="admin-rewards-panel">
            <h3 className="panel-title">Admin Rewards Controls</h3>

            <div className="admin-section">
                <label>Trigger Manual Snapshot</label>
                <p className="section-desc">Records current leaderboard state for weekly/monthly rewards.</p>
                <button
                    className="admin-btn snapshot-btn"
                    onClick={triggerSnapshot}
                    disabled={loading}
                >
                    {loading ? 'Processing...' : 'Capture Snapshot'}
                </button>
            </div>

            <div className="admin-section">
                <label>Create Bonus Point Event</label>
                <div className="event-form">
                    <input
                        type="text"
                        placeholder="Event Name (e.g. Hackathon Weekend)"
                        value={eventName}
                        onChange={(e) => setEventName(e.target.value)}
                    />
                    <button className="admin-btn event-btn">Launch Event</button>
                </div>
            </div>

            <div className="admin-section">
                <label>Global Multiplier Cap</label>
                <div className="cap-control">
                    <span>Max Effective Multiplier:</span>
                    <strong>5.0x</strong>
                    <button className="text-btn">Edit</button>
                </div>
            </div>

            <style jsx>{`
        .admin-rewards-panel {
          background: #1a202c;
          color: white;
          padding: 2rem;
          border-radius: 16px;
          margin-top: 2rem;
        }
        .panel-title {
          margin: 0 0 2rem 0;
          font-size: 1.5rem;
          border-bottom: 1px solid #2d3748;
          padding-bottom: 1rem;
        }
        .admin-section {
          margin-bottom: 2rem;
        }
        .admin-section label {
          display: block;
          font-weight: 600;
          margin-bottom: 0.5rem;
          font-size: 1.1rem;
        }
        .section-desc {
          color: #a0aec0;
          font-size: 0.85rem;
          margin-bottom: 1rem;
        }
        .admin-btn {
          padding: 0.75rem 1.5rem;
          border-radius: 8px;
          border: none;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.2s;
        }
        .snapshot-btn {
          background: #667eea;
          color: white;
        }
        .event-form {
          display: flex;
          gap: 1rem;
        }
        .event-form input {
          flex: 1;
          background: #2d3748;
          border: 1px solid #4a5568;
          border-radius: 8px;
          padding: 0.75rem;
          color: white;
        }
        .event-btn {
          background: #4ade80;
          color: #1a202c;
        }
        .cap-control {
          display: flex;
          align-items: center;
          gap: 1rem;
          background: #2d3748;
          padding: 1rem;
          border-radius: 8px;
        }
        .text-btn {
          background: none;
          border: none;
          color: #667eea;
          cursor: pointer;
          font-size: 0.9rem;
          text-decoration: underline;
        }
      `}</style>
        </div>
    );
};

export default AdminRewardsPanel;
