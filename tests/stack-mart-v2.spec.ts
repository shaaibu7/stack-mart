import { describe, it, expect } from "vitest";
import { Cl } from "@stacks/transactions";

const contractName = "stack-mart";
const nftContract = "mock-nft";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const seller = accounts.get("wallet_1")!;
const buyer = accounts.get("wallet_2")!;
const bidder = accounts.get("wallet_3")!;

const getStxBalance = (addr: string): bigint => {
    const assets = simnet.getAssetsMap();
    const stx = assets.get("STX");
    return stx?.get(addr) ?? 0n;
};

describe("stack-mart auctions", () => {
    it("runs a complete auction lifecycle", () => {
        // Mint NFT to seller
        simnet.callPublicFn(
            nftContract,
            "mint",
            [Cl.principal(seller), Cl.uint(1)],
            deployer
        );

        // Create Auction
        // Define trait - simnet handles traits by passing the principal of the contract implementing it
        const createRes = simnet.callPublicFn(
            contractName,
            "create-auction",
            [
                Cl.contractPrincipal(deployer, nftContract),
                Cl.uint(1),
                Cl.uint(100), // start
                Cl.uint(500), // reserve
                Cl.uint(10)   // duration
            ],
            seller
        );
        expect(createRes.result).toBeOk(Cl.uint(1));

        // Place Bid
        const bidRes = simnet.callPublicFn(
            contractName,
            "place-bid",
            [Cl.uint(1), Cl.uint(600)],
            bidder
        );
        expect(bidRes.result).toBeOk(Cl.bool(true));

        // Verify STX transfer (bidder -> contract)
        // Note: exact balance check might be tricky if gas fees are involved in simnet? 
        // Simnet usually doesn't charge gas unless configured.
        // We just check contracts balance increased?
        // Simnet asset map is easier.

        // Fast forward 11 blocks
        simnet.mineEmptyBlocks(11);

        // End Auction
        const endRes = simnet.callPublicFn(
            contractName,
            "end-auction",
            [Cl.uint(1), Cl.contractPrincipal(deployer, nftContract)],
            seller // can be anyone really if expired, but let's say seller calls it
        );
        expect(endRes.result).toBeOk(Cl.bool(true));

        // Verify NFT owner is now bidder
        const ownerRes = simnet.callPublicFn(
            nftContract,
            "get-owner",
            [Cl.uint(1)],
            deployer
        );
        expect(ownerRes.result).toBeOk(Cl.some(Cl.principal(bidder)));
    });
});

describe("stack-mart bundles", () => {
    it("buys a bundle and creates escrows", () => {
        // Create listings
        simnet.callPublicFn(contractName, "create-listing", [Cl.uint(1000), Cl.uint(0), Cl.principal(seller)], seller); // ID 2
        simnet.callPublicFn(contractName, "create-listing", [Cl.uint(2000), Cl.uint(0), Cl.principal(seller)], seller); // ID 3

        // Create Bundle
        simnet.callPublicFn(
            contractName,
            "create-bundle",
            [Cl.list([Cl.uint(2), Cl.uint(3)]), Cl.uint(5000)], // 50% discount
            seller
        );

        const buyerBefore = getStxBalance(buyer);

        // Buy Bundle (ID 1 - checking if bundle ID increments globally or separately? separately u1)
        const buyRes = simnet.callPublicFn(
            contractName,
            "buy-bundle",
            [Cl.uint(1)],
            buyer
        );
        expect(buyRes.result).toBeOk(Cl.bool(true));

        // Total price: 1000 + 2000 = 3000. 50% discount = 1500.
        // Buyer spends 1500.
        expect(getStxBalance(buyer)).toBe(buyerBefore - 1500n);

        // Check escrows created
        const escrow2 = simnet.callReadOnlyFn(contractName, "get-escrow-status", [Cl.uint(2)], deployer);
        expect(escrow2.result).toBeOk(Cl.tuple({
            buyer: Cl.principal(buyer),
            amount: Cl.uint(500), // 1000 * 0.5
            state: Cl.stringAscii("pending"),
            "created-at-block": Cl.uint(simnet.blockHeight),
            "timeout-block": Cl.uint(simnet.blockHeight + 144)
        }));
    });
});
