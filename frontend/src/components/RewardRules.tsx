import React from 'react';

const RewardRules: React.FC = () => {
    const rules = [
        {
            title: 'Smart Contract Activity',
            description: "Points based on the complexity and transaction volume of contracts you've deployed on Stacks.",
            points: '50+ per interaction',
            icon: '📜'
        },
        {
            title: 'Stacks SDK Usage',
            description: 'Integrate @stacks/connect or @stacks/transactions in your projects to earn points.',
            points: '25 per verified repo',
            icon: '📚'
        },
        {
            title: 'GitHub Contributions',
            description: 'Weekly rewards for commits and PRs to public Stacks-related repositories.',
            points: 'Variable (up to 500/week)',
            icon: '💻'
        },
        {
            title: 'Referrals',
            description: 'Invite other developers to join StackMart and earn bonuses on their activity.',
            points: '100 per user',
            icon: '👥'
        }
    ];

    return (
        <div className="reward-rules-card">
            <h3 className="rules-title">How Rewards Work</h3>
            <p className="rules-intro">
                Rewards are based on your leaderboard position, which is determined by your activity across these categories:
            </p>
            <div className="rules-list">
                {rules.map((rule, index) => (
                    <div key={index} className="rule-item">
                        <span className="rule-icon">{rule.icon}</span>
                        <div className="rule-detail">
                            <h4>{rule.title}</h4>
                            <p>{rule.description}</p>
                            <span className="points-badge">{rule.points}</span>
                        </div>
                    </div>
                ))}
            </div>
            <style jsx>{`
        .reward-rules-card {
          background: #ffffff;
          border: 1px solid #e2e8f0;
          border-radius: 12px;
          padding: 1.5rem;
          box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        .rules-title {
          margin: 0 0 0.5rem 0;
          color: #1a202c;
          font-size: 1.25rem;
        }
        .rules-intro {
          font-size: 0.9rem;
          color: #4a5568;
          margin-bottom: 1.5rem;
        }
        .rule-item {
          display: flex;
          gap: 1rem;
          margin-bottom: 1.25rem;
          align-items: flex-start;
        }
        .rule-icon {
          font-size: 1.5rem;
          padding-top: 0.25rem;
        }
        .rule-detail h4 {
          margin: 0;
          font-size: 1rem;
          color: #2d3748;
        }
        .rule-detail p {
          font-size: 0.85rem;
          color: #718096;
          margin: 0.25rem 0 0.5rem 0;
        }
        .points-badge {
          display: inline-block;
          background: #edf2f7;
          color: #4a5568;
          padding: 0.1rem 0.6rem;
          border-radius: 9999px;
          font-size: 0.75rem;
          font-weight: 600;
        }
      `}</style>
        </div>
    );
};

export default RewardRules;
