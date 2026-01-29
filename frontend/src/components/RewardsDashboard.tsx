import React from 'react';

interface RewardStatProps {
    label: string;
    value: string | number;
    icon: string;
    trend?: string;
}

const RewardStat: React.FC<RewardStatProps> = ({ label, value, icon, trend }) => (
    <div className="bg-white/5 backdrop-blur-md border border-white/10 rounded-xl p-6 transition-all hover:bg-white/10 group">
        <div className="flex items-center justify-between mb-4">
            <span className="text-3xl group-hover:scale-110 transition-transform">{icon}</span>
            {trend && (
                <span className={`text-xs font-semibold px-2 py-1 rounded-full ${trend.startsWith('+') ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'
                    }`}>
                    {trend}
                </span>
            )}
        </div>
        <div className="text-sm text-gray-400 font-medium mb-1">{label}</div>
        <div className="text-2xl font-bold bg-gradient-to-r from-white to-gray-400 bg-clip-text text-transparent">
            {value}
        </div>
    </div>
);

export const RewardsDashboard: React.FC = () => {
    return (
        <div className="min-h-screen bg-[#0a0a0b] text-white p-8">
            <div className="max-w-7xl mx-auto">
                <header className="mb-12">
                    <h1 className="text-4xl font-extrabold mb-2 bg-gradient-to-r from-orange-500 to-pink-500 bg-clip-text text-transparent">
                        StackMart Rewards
                    </h1>
                    <p className="text-gray-400 max-w-2xl">
                        Track your impact, contract activity, and GitHub contributions to earn premium
                        on-chain rewards and climb the global leaderboard.
                    </p>
                </header>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-12">
                    <RewardStat
                        label="Total Points"
                        value="24,500"
                        icon="✨"
                        trend="+12% this week"
                    />
                    <RewardStat
                        label="Contract Impact"
                        value="1,200"
                        icon="📜"
                    />
                    <RewardStat
                        label="Library Usage"
                        value="850"
                        icon="🛠️"
                    />
                    <RewardStat
                        label="GitHub Contribs"
                        value="5,000"
                        icon="🐙"
                        trend="+2 PRs"
                    />
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                    <div className="lg:col-span-2 space-y-8">
                        <div className="bg-white/5 border border-white/10 rounded-2xl p-8">
                            <h2 className="text-xl font-bold mb-6 flex items-center gap-2">
                                <span>📈</span> Activity History
                            </h2>
                            <div className="h-64 flex items-center justify-center text-gray-500 border border-dashed border-white/10 rounded-xl">
                                Charts and activity logs will appear here
                            </div>
                        </div>
                    </div>

                    <div className="space-y-8">
                        <div className="bg-gradient-to-br from-indigo-600/20 to-purple-600/20 border border-white/10 rounded-2xl p-8">
                            <h2 className="text-xl font-bold mb-4 flex items-center gap-2">
                                <span>🏆</span> Current Rank
                            </h2>
                            <div className="text-5xl font-black mb-2 text-center py-4">#42</div>
                            <p className="text-sm text-center text-gray-400">
                                You are in the top 5% of active developers!
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};
