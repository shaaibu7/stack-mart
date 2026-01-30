import React from 'react';

interface Achievement {
    id: number;
    name: string;
    description: string;
    icon: string;
    unlocked: boolean;
    progress?: number;
    unlockedAt?: number;
}

interface AchievementBadgesProps {
    achievements: Achievement[];
}

const AchievementBadges: React.FC<AchievementBadgesProps> = ({ achievements }) => {
    return (
        <div className="achievement-badges-container">
            <h3 className="achievements-title">Achievements</h3>
            <div className="badges-grid">
                {achievements.map((achievement) => (
                    <div
                        key={achievement.id}
                        className={`badge-card ${achievement.unlocked ? 'unlocked' : 'locked'}`}
                        title={achievement.description}
                    >
                        <div className="badge-icon">{achievement.icon}</div>
                        <div className="badge-info">
                            <h4 className="badge-name">{achievement.name}</h4>
                            {!achievement.unlocked && achievement.progress !== undefined && (
                                <div className="progress-bar">
                                    <div
                                        className="progress-fill"
                                        style={{ width: `${achievement.progress}%` }}
                                    />
                                </div>
                            )}
                            {achievement.unlocked && achievement.unlockedAt && (
                                <span className="unlock-date">
                                    Unlocked {new Date(achievement.unlockedAt * 1000).toLocaleDateString()}
                                </span>
                            )}
                        </div>
                    </div>
                ))}
            </div>
            <style jsx>{`
        .achievement-badges-container {
          padding: 1.5rem;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          border-radius: 12px;
        }
        .achievements-title {
          color: white;
          margin-bottom: 1rem;
        }
        .badges-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
          gap: 1rem;
        }
        .badge-card {
          background: rgba(255, 255, 255, 0.1);
          backdrop-filter: blur(10px);
          border-radius: 8px;
          padding: 1rem;
          transition: all 0.3s ease;
          cursor: pointer;
        }
        .badge-card:hover {
          transform: translateY(-4px);
          background: rgba(255, 255, 255, 0.15);
        }
        .badge-card.locked {
          opacity: 0.5;
          filter: grayscale(100%);
        }
        .badge-icon {
          font-size: 2.5rem;
          text-align: center;
          margin-bottom: 0.5rem;
        }
        .badge-name {
          font-size: 0.9rem;
          color: white;
          text-align: center;
          margin: 0;
        }
        .progress-bar {
          height: 4px;
          background: rgba(255, 255, 255, 0.2);
          border-radius: 2px;
          margin-top: 0.5rem;
          overflow: hidden;
        }
        .progress-fill {
          height: 100%;
          background: #4ade80;
          transition: width 0.3s ease;
        }
        .unlock-date {
          font-size: 0.7rem;
          color: rgba(255, 255, 255, 0.7);
          display: block;
          text-align: center;
          margin-top: 0.25rem;
        }
      `}</style>
        </div>
    );
};

export default AchievementBadges;
