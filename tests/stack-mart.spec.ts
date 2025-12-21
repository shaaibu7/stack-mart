import { describe, it, expect } from "vitest";
import { Cl } from "@stacks/transactions";

const contractName = "stack-mart";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const seller = accounts.get("wallet_1")!;
const buyer = accounts.get("wallet_2")!;
const royaltyRecipient = accounts.get("wallet_3")!;

const getStxBalance = (addr: string): bigint => {
  const assets = simnet.getAssetsMap();
  const stx = assets.get("STX");
  return stx?.get(addr) ?? 0n;
};

describe("stack-mart listings", () => {
  it("creates a listing with royalty cap", () => {
    const res = simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(1_000), Cl.uint(500), Cl.principal(royaltyRecipient)],
      seller
    );

    expect(res.result).toBeOk(Cl.uint(1));

    const listing = simnet.callReadOnlyFn(
      contractName,
      "get-listing",
      [Cl.uint(1)],
      deployer
    );

    expect(listing.result).toBeOk(
      Cl.tuple({
        price: Cl.uint(1_000),
        "royalty-bips": Cl.uint(500),
        "royalty-recipient": Cl.principal(royaltyRecipient),
        seller: Cl.principal(seller),
        "nft-contract": Cl.none(),
        "token-id": Cl.none(),
        "license-terms": Cl.none(),
      })
    );
  });

  it("buys a listing and deletes it", () => {
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(2_000), Cl.uint(1000), Cl.principal(royaltyRecipient)],
      seller
    );

    const purchase = simnet.callPublicFn(
      contractName,
      "buy-listing",
      [Cl.uint(1)],
      buyer
    );

    expect(purchase.result).toBeOk(Cl.bool(true));

    const missing = simnet.callReadOnlyFn(
      contractName,
      "get-listing",
      [Cl.uint(1)],
      deployer
    );

    expect(missing.result).toBeErr(Cl.uint(404));
  });

  it("pays seller and royalty recipient on purchase", () => {
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(2_000), Cl.uint(1_000), Cl.principal(royaltyRecipient)],
      seller
    );

    const sellerBefore = getStxBalance(seller);
    const buyerBefore = getStxBalance(buyer);
    const royaltyBefore = getStxBalance(royaltyRecipient);

    const purchase = simnet.callPublicFn(
      contractName,
      "buy-listing",
      [Cl.uint(1)],
      buyer
    );

    expect(purchase.result).toBeOk(Cl.bool(true));

    expect(getStxBalance(buyer)).toBe(buyerBefore - 2_000n);
    expect(getStxBalance(seller)).toBe(sellerBefore + 1_800n);
    expect(getStxBalance(royaltyRecipient)).toBe(royaltyBefore + 200n);
  });
});

describe("stack-mart escrow flow", () => {
  it("creates escrow when buying with escrow option", () => {
    // Create listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(5_000), Cl.uint(500), Cl.principal(royaltyRecipient)],
      seller
    );

    const buyerBefore = getStxBalance(buyer);

    // Buy with escrow
    const escrowPurchase = simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    expect(escrowPurchase.result).toBeOk(Cl.bool(true));

    // Check escrow was created
    const escrowStatus = simnet.callReadOnlyFn(
      contractName,
      "get-escrow-status",
      [Cl.uint(1)],
      deployer
    );

    expect(escrowStatus.result).toBeOk(
      Cl.tuple({
        buyer: Cl.principal(buyer),
        amount: Cl.uint(5_000),
        "created-at-block": Cl.uint(0),
        state: Cl.stringAscii("pending"),
        "timeout-block": Cl.uint(144),
      })
    );

    // Buyer's balance should be reduced
    expect(getStxBalance(buyer)).toBe(buyerBefore - 5_000n);
  });
});
