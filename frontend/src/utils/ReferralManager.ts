/**
 * ReferralManager Utility
 * Manages unique referral code generation, tracking, and bonus logic.
 */

export interface ReferralData {
    code: string;
    referredBy?: string;
    referralCount: number;
    totalBonusEarned: number;
}

export class ReferralManager {
    private static STORAGE_KEY = 'stacks_mart_referral_data';

    /**
     * Initializes or retrieves user referral data
     */
    static getReferralData(): ReferralData {
        const stored = localStorage.getItem(this.STORAGE_KEY);
        if (stored) {
            return JSON.parse(stored);
        }

        const newData: ReferralData = {
            code: this.generateUniqueCode(),
            referralCount: 0,
            totalBonusEarned: 0
        };
        this.saveData(newData);
        return newData;
    }

    /**
     * Generates a unique 8-character referral code
     */
    private static generateUniqueCode(): string {
        return Math.random().toString(36).substring(2, 10).toUpperCase();
    }

    /**
     * Records a new referral (mocked for frontend demo)
     */
    static recordReferral(referredBy: string) {
        const data = this.getReferralData();
        if (data.referredBy) return; // Already referred by someone

        data.referredBy = referredBy;
        this.saveData(data);
    }

    /**
     * Gets the current referral link
     */
    static getReferralLink(): string {
        const data = this.getReferralData();
        const baseUrl = window.location.origin;
        return `${baseUrl}?ref=${data.code}`;
    }

    private static saveData(data: ReferralData) {
        localStorage.setItem(this.STORAGE_KEY, JSON.stringify(data));
    }

    /**
     * Processes referral codes from URL parameters
     */
    static processUrlParams() {
        const params = new URLSearchParams(window.location.search);
        const refCode = params.get('ref');
        if (refCode) {
            console.log(`[ReferralManager] Processing referral code: ${refCode}`);
            this.recordReferral(refCode);
            // In a real app, this would trigger a backend event
        }
    }
}
