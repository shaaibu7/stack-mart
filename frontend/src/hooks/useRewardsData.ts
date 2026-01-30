import { useState, useEffect, useMemo } from 'react';

interface UserStats {
    totalPoints: number;
    contractImpactPoints: number;
    libraryUsagePoints: number;
    githubContribPoints: number;
    reputationScore: number;
    lastActivityBlock: number;
}

interface LeaderboardEntry {
    address: string;
    points: number;
    rank: number;
}

interface RewardsData {
    userStats: UserStats | null;
    leaderboard: LeaderboardEntry[];
    claimableRewards: number;
    userTier: number;
    userStreak: number;
    loading: boolean;
    error: string | null;
}

export const useRewardsData = (userAddress: string | null, refreshInterval = 30000) => {
    const [data, setData] = useState<RewardsData>({
        userStats: null,
        leaderboard: [],
        claimableRewards: 0,
        userTier: 0,
        userStreak: 0,
        loading: true,
        error: null
    });

    const fetchRewardsData = async () => {
        if (!userAddress) {
            setData(prev => ({ ...prev, loading: false }));
            return;
        }

        try {
            setData(prev => ({ ...prev, loading: true, error: null }));

            // Fetch user stats from contract
            const statsResponse = await fetch(`/api/rewards/stats/${userAddress}`);
            const userStats = await statsResponse.json();

            // Fetch leaderboard
            const leaderboardResponse = await fetch('/api/rewards/leaderboard');
            const leaderboard = await leaderboardResponse.json();

            // Fetch claimable rewards
            const claimableResponse = await fetch(`/api/rewards/claimable/${userAddress}`);
            const { amount: claimableRewards } = await claimableResponse.json();

            // Fetch tier
            const tierResponse = await fetch(`/api/rewards/tier/${userAddress}`);
            const { tier: userTier } = await tierResponse.json();

            // Fetch streak
            const streakResponse = await fetch(`/api/rewards/streak/${userAddress}`);
            const { currentStreak: userStreak } = await streakResponse.json();

            setData({
                userStats,
                leaderboard,
                claimableRewards,
                userTier,
                userStreak,
                loading: false,
                error: null
            });
        } catch (error) {
            setData(prev => ({
                ...prev,
                loading: false,
                error: error instanceof Error ? error.message : 'Failed to fetch rewards data'
            }));
        }
    };

    useEffect(() => {
        fetchRewardsData();
        const interval = setInterval(fetchRewardsData, refreshInterval);
        return () => clearInterval(interval);
    }, [userAddress, refreshInterval]);

    const memoizedData = useMemo(() => data, [data]);

    return {
        ...memoizedData,
        refetch: fetchRewardsData
    };
};
