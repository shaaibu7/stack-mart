import { openContractCall } from '@stacks/connect';
import { StacksNetwork } from '@stacks/network';
import { ReferralManager } from './ReferralManager';

/**
 * ActivityInterceptor Utility
 * Intercepts wrapper calls to @stacks/connect and @stacks/transactions
 * to automatically report activity to the rewards system.
 * 
 * Specifically targets:
 * - Contract deployments & interactions
 * - Library usage metrics
 */
export class ActivityInterceptor {
    private static reportEndpoint = '/api/rewards/log';

    /**
     * Wraps openContractCall to support automated activity reporting
     */
    static async wrappedContractCall(options: any, network: StacksNetwork) {
        const originalOnFinish = options.onFinish;

        const enhancedOptions = {
            ...options,
            onFinish: async (data: any) => {
                console.log("[ActivityInterceptor] Intercepted successful contract call");

                // Automatically report library usage (@stacks/connect)
                await this.logActivity('connect', { txId: data.txId });

                // Automatically report contract activity points
                await this.logActivity('contract-interaction', {
                    txId: data.txId,
                    contractAddress: options.contractAddress,
                    functionName: options.functionName
                });

                if (originalOnFinish) {
                    originalOnFinish(data);
                }
            }
        };

        return openContractCall(enhancedOptions);
    }

    /**
     * Internal: Securely log activity to the backend/oracle
     */
    private static async logActivity(type: string, metadata: any) {
        try {
            console.log(`[ActivityInterceptor] Reporting ${type} activity...`);
            // In production, this sends an authenticated request to the builder's rewards oracle
            // which then calls the Clarity contract to award points.
            const response = await fetch(this.reportEndpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    type,
                    metadata,
                    timestamp: Date.now(),
                    referralCode: ReferralManager.getReferralData().code
                })
            });

            return response.ok;
        } catch (error) {
            console.warn("[ActivityInterceptor] Failed to report activity:", error);
            return false;
        }
    }
}
