import React, { useState, useEffect } from 'react';

interface Notification {
    id: string;
    type: 'points' | 'level-up' | 'achievement' | 'tier-up';
    title: string;
    message: string;
}

const NotificationOverlay: React.FC = () => {
    const [notifications, setNotifications] = useState<Notification[]>([]);

    const addNotification = (notif: Omit<Notification, 'id'>) => {
        const id = Math.random().toString(36).substr(2, 9);
        setNotifications(prev => [...prev, { ...notif, id }]);
        setTimeout(() => {
            setNotifications(prev => prev.filter(n => n.id !== id));
        }, 5000);
    };

    // Mock listener for system events
    useEffect(() => {
        const handleAchievement = (e: any) => {
            addNotification({
                type: 'achievement',
                title: 'Achievement Unlocked!',
                message: e.detail.achievement.name
            });
        };
        window.addEventListener('achievement-unlocked', handleAchievement);
        return () => window.removeEventListener('achievement-unlocked', handleAchievement);
    }, []);

    return (
        <div className="notification-container">
            {notifications.map(n => (
                <div key={n.id} className={`notification-toast ${n.type}`}>
                    <div className="toast-icon">
                        {n.type === 'points' && '✨'}
                        {n.type === 'level-up' && '⭐'}
                        {n.type === 'achievement' && '🏆'}
                        {n.type === 'tier-up' && '💎'}
                    </div>
                    <div className="toast-content">
                        <strong>{n.title}</strong>
                        <p>{n.message}</p>
                    </div>
                </div>
            ))}
            <style jsx>{`
        .notification-container {
          position: fixed;
          top: 2rem;
          right: 2rem;
          z-index: 10000;
          display: flex;
          flex-direction: column;
          gap: 1rem;
        }
        .notification-toast {
          background: white;
          border-radius: 12px;
          padding: 1rem;
          display: flex;
          align-items: center;
          gap: 1rem;
          box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
          border-left: 4px solid #667eea;
          min-width: 280px;
          animation: slideIn 0.3s ease-out;
        }
        .notification-toast.achievement { border-color: #f6e05e; }
        .notification-toast.level-up { border-color: #4ade80; }
        .notification-toast.tier-up { border-color: #667eea; }
        .toast-icon { font-size: 1.5rem; }
        .toast-content strong { display: block; font-size: 0.95rem; }
        .toast-content p { margin: 0; font-size: 0.85rem; color: #718096; }
        @keyframes slideIn {
          from { transform: translateX(100%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
      `}</style>
        </div>
    );
};

export default NotificationOverlay;
