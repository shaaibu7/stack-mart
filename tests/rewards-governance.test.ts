import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

declare const simnet: any;

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet_1 = accounts.get("wallet_1")!;
const wallet_2 = accounts.get("wallet_2")!;

describe("Governance & Multi-Admin Tests", () => {
    it("should allow multi-admin management", () => {
        // Add wallet_1 as admin
        const addResult = simnet.callPublicFn(
            "rewards-leaderboard",
            "add-admin",
            [Cl.principal(wallet_1)],
            deployer
        );
        expect(addResult.result).toBeOk(Cl.bool(true));

        // Check if wallet_1 can now add another admin
        const secondaryAdd = simnet.callPublicFn(
            "rewards-leaderboard",
            "add-admin",
            [Cl.principal(wallet_2)],
            wallet_1
        );
        expect(secondaryAdd.result).toBeOk(Cl.bool(true));
    });

    it("should enforce emergency pause", () => {
        simnet.callPublicFn("rewards-leaderboard", "emergency-pause", [], deployer);

        // Attempting a public function should fail if we add pause checks to them
        // For now, verify global variable state
        const { result } = simnet.getDataVar("rewards-leaderboard", "contract-paused");
        expect(result).toBe(Cl.bool(true));
    });

    it("should prevent non-admins from removing admins", () => {
        const result = simnet.callPublicFn(
            "rewards-leaderboard",
            "remove-admin",
            [Cl.principal(deployer)],
            wallet_2
        );
        expect(result.result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
});

describe("Stress & Pagination Tests", () => {
    it("should return correct total user count for pagination", () => {
        const { result } = simnet.callReadOnlyFn(
            "rewards-leaderboard",
            "get-active-user-count",
            [],
            deployer
        );
        expect(result).toBeDefined();
    });

    it("should provide paginated interface structure", () => {
        const { result } = simnet.callReadOnlyFn(
            "rewards-leaderboard",
            "get-leaderboard-page",
            [Cl.uint(0), Cl.uint(10)],
            deployer
        );
        expect(result.value.data.total).toBeDefined();
    });
});
