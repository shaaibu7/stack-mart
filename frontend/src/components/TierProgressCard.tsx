import React from 'react';

interface TierProgressCardProps {
    currentTier: string;
    currentPoints: number;
    nextTierThreshold: number;
    tierBenefits: string[];
}

const TierProgressCard: React.FC<TierProgressCardProps> = ({
    currentTier,
    currentPoints,
    nextTierThreshold,
    tierBenefits
}) => {
    const progress = (currentPoints / nextTierThreshold) * 100;
    const pointsNeeded = nextTierThreshold - currentPoints;

    const tierIcons: Record<string, string> = {
        Bronze: '🥉',
        Silver: '🥈',
        Gold: '🥇',
        Platinum: '💎',
        Diamond: '👑'
    };

    return (
        <div className="tier-progress-card">
            <div className="tier-header">
                <div className="tier-icon">{tierIcons[currentTier] || '🏆'}</div>
                <div className="tier-info">
                    <h3 className="tier-name">{currentTier} Tier</h3>
                    <p className="tier-description">
                        Rewards are based on your leaderboard position, which is determined by your activity across:
                    </p>
                    <ul className="activity-list">
                        <li>The activity and impact of the smart contracts you've deployed on Stacks</li>
                        <li>Use of <code>@stacks/connect</code> and <code>@stacks/transactions</code> in your repos</li>
                        <li>GitHub contributions to public repositories</li>
                    </ul>
                </div>
            </div>

            <div className="progress-section">
                <div className="progress-header">
                    <span className="current-points">{currentPoints.toLocaleString()} points</span>
                    <span className="points-needed">{pointsNeeded.toLocaleString()} to next tier</span>
                </div>
                <div className="progress-bar">
                    <div className="progress-fill" style={{ width: `${Math.min(progress, 100)}%` }} />
                </div>
            </div>

            <div className="benefits-section">
                <h4>Tier Benefits</h4>
                <ul className="benefits-list">
                    {tierBenefits.map((benefit, index) => (
                        <li key={index}>{benefit}</li>
                    ))}
                </ul>
            </div>

            <style jsx>{`
        .tier-progress-card {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          border-radius: 16px;
          padding: 1.5rem;
          color: white;
        }
        .tier-header {
          display: flex;
          gap: 1rem;
          margin-bottom: 1.5rem;
        }
        .tier-icon {
          font-size: 3rem;
        }
        .tier-name {
          margin: 0 0 0.5rem 0;
          font-size: 1.5rem;
        }
        .tier-description {
          font-size: 0.9rem;
          margin: 0.5rem 0;
          opacity: 0.9;
        }
        .activity-list {
          font-size: 0.85rem;
          opacity: 0.85;
          margin: 0.5rem 0;
          padding-left: 1.2rem;
        }
        .activity-list li {
          margin: 0.25rem 0;
        }
        .activity-list code {
          background: rgba(255, 255, 255, 0.2);
          padding: 0.1rem 0.3rem;
          border-radius: 3px;
          font-size: 0.8rem;
        }
        .progress-section {
          margin-bottom: 1.5rem;
        }
        .progress-header {
          display: flex;
          justify-content: space-between;
          margin-bottom: 0.5rem;
          font-size: 0.9rem;
        }
        .current-points {
          font-weight: 600;
        }
        .points-needed {
          opacity: 0.8;
        }
        .progress-bar {
          height: 8px;
          background: rgba(255, 255, 255, 0.2);
          border-radius: 4px;
          overflow: hidden;
        }
        .progress-fill {
          height: 100%;
          background: linear-gradient(90deg, #4ade80 0%, #22c55e 100%);
          transition: width 0.5s ease;
        }
        .benefits-section h4 {
          margin: 0 0 0.75rem 0;
          font-size: 1rem;
        }
        .benefits-list {
          list-style: none;
          padding: 0;
          margin: 0;
        }
        .benefits-list li {
          padding: 0.5rem;
          background: rgba(255, 255, 255, 0.1);
          border-radius: 6px;
          margin-bottom: 0.5rem;
          font-size: 0.9rem;
        }
      `}</style>
        </div>
    );
};

export default TierProgressCard;
