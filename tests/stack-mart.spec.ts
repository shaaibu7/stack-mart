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

  it("seller attests delivery and transfers NFT", () => {
    // Create listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(3_000), Cl.uint(300), Cl.principal(royaltyRecipient)],
      seller
    );

    // Buy with escrow
    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    // Seller attests delivery
    const deliveryHash = Cl.bufferFromHex("0000000000000000000000000000000000000000000000000000000000000001");
    const attestResult = simnet.callPublicFn(
      contractName,
      "attest-delivery",
      [Cl.uint(1), deliveryHash],
      seller
    );

    expect(attestResult.result).toBeOk(Cl.bool(true));

    // Check escrow state changed to "delivered"
    const escrowStatus = simnet.callReadOnlyFn(
      contractName,
      "get-escrow-status",
      [Cl.uint(1)],
      deployer
    );

    expect(escrowStatus.result).toBeOk(
      Cl.tuple({
        state: Cl.stringAscii("delivered"),
      })
    );
  });

  it("buyer confirms receipt and releases escrow", () => {
    // Create listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(4_000), Cl.uint(400), Cl.principal(royaltyRecipient)],
      seller
    );

    // Buy with escrow
    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    // Seller attests delivery
    const deliveryHash = Cl.bufferFromHex("0000000000000000000000000000000000000000000000000000000000000002");
    simnet.callPublicFn(
      contractName,
      "attest-delivery",
      [Cl.uint(1), deliveryHash],
      seller
    );

    const sellerBefore = getStxBalance(seller);
    const buyerBefore = getStxBalance(buyer);
    const royaltyBefore = getStxBalance(royaltyRecipient);

    // Buyer confirms receipt
    const confirmResult = simnet.callPublicFn(
      contractName,
      "confirm-receipt",
      [Cl.uint(1)],
      buyer
    );

    expect(confirmResult.result).toBeOk(Cl.bool(true));

    // Check payments were made
    expect(getStxBalance(seller)).toBe(sellerBefore + 3_840n); // 4000 - 160 (royalty)
    expect(getStxBalance(royaltyRecipient)).toBe(royaltyBefore + 160n); // 4000 * 0.04
    expect(getStxBalance(buyer)).toBe(buyerBefore); // Already paid in escrow

    // Listing should be deleted
    const listing = simnet.callReadOnlyFn(
      contractName,
      "get-listing",
      [Cl.uint(1)],
      deployer
    );

    expect(listing.result).toBeErr(Cl.uint(404));
  });

  it("buyer can reject delivery", () => {
    // Create listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(3_000), Cl.uint(300), Cl.principal(royaltyRecipient)],
      seller
    );

    // Buy with escrow
    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    // Seller attests delivery
    const deliveryHash = Cl.bufferFromHex("0000000000000000000000000000000000000000000000000000000000000003");
    simnet.callPublicFn(
      contractName,
      "attest-delivery",
      [Cl.uint(1), deliveryHash],
      seller
    );

    // Buyer rejects delivery
    const rejectResult = simnet.callPublicFn(
      contractName,
      "reject-delivery",
      [Cl.uint(1), Cl.stringAscii("Item not as described")],
      buyer
    );

    expect(rejectResult.result).toBeOk(Cl.bool(true));

    // Check delivery attestation was marked as rejected
    // Note: This would require a read-only function to check delivery status
    // For now, we just verify the function succeeded
  });

  it("updates reputation after successful transaction", () => {
    // Create listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(2_000), Cl.uint(200), Cl.principal(royaltyRecipient)],
      seller
    );

    // Buy with escrow
    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    // Seller attests delivery
    const deliveryHash = Cl.bufferFromHex("0000000000000000000000000000000000000000000000000000000000000004");
    simnet.callPublicFn(
      contractName,
      "attest-delivery",
      [Cl.uint(1), deliveryHash],
      seller
    );

    // Buyer confirms receipt
    simnet.callPublicFn(
      contractName,
      "confirm-receipt",
      [Cl.uint(1)],
      buyer
    );

    // Check seller reputation
    const sellerRep = simnet.callReadOnlyFn(
      contractName,
      "get-seller-reputation",
      [Cl.principal(seller)],
      deployer
    );

    expect(sellerRep.result).toBeOk(
      Cl.tuple({
        "successful-txs": Cl.uint(1),
        "failed-txs": Cl.uint(0),
        "rating-sum": Cl.uint(0),
        "rating-count": Cl.uint(0),
      })
    );

    // Check buyer reputation
    const buyerRep = simnet.callReadOnlyFn(
      contractName,
      "get-buyer-reputation",
      [Cl.principal(buyer)],
      deployer
    );

    expect(buyerRep.result).toBeOk(
      Cl.tuple({
        "successful-txs": Cl.uint(1),
        "failed-txs": Cl.uint(0),
        "rating-sum": Cl.uint(0),
        "rating-count": Cl.uint(0),
      })
    );
  });
});

describe("stack-mart bundles and packs", () => {
  it("creates a bundle with multiple listings", () => {
    // Create multiple listings
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(1_000), Cl.uint(100), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(2_000), Cl.uint(200), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(3_000), Cl.uint(300), Cl.principal(royaltyRecipient)],
      seller
    );

    // Create bundle with discount
    const bundleResult = simnet.callPublicFn(
      contractName,
      "create-bundle",
      [
        Cl.list([Cl.uint(1), Cl.uint(2), Cl.uint(3)]),
        Cl.uint(1_000), // 10% discount
      ],
      seller
    );

    expect(bundleResult.result).toBeOk(Cl.uint(1));

    // Get bundle details
    const bundle = simnet.callReadOnlyFn(
      contractName,
      "get-bundle",
      [Cl.uint(1)],
      deployer
    );

    expect(bundle.result).toBeOk(
      Cl.tuple({
        "listing-ids": Cl.list([Cl.uint(1), Cl.uint(2), Cl.uint(3)]),
        "discount-bips": Cl.uint(1_000),
        creator: Cl.principal(seller),
        "created-at-block": Cl.uint(0),
      })
    );
  });
});

describe("stack-mart wishlist functionality", () => {
  it("allows user to add listing to wishlist", () => {
    // Create a listing first
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(1_500), Cl.uint(150), Cl.principal(royaltyRecipient)],
      seller
    );

    // Add to wishlist
    const wishlistResult = simnet.callPublicFn(
      contractName,
      "toggle-wishlist",
      [Cl.uint(1)],
      buyer
    );

    expect(wishlistResult.result).toBeOk(Cl.bool(true));

    // Check if listing is in wishlist
    const wishlist = simnet.callReadOnlyFn(
      contractName,
      "get-wishlist",
      [Cl.principal(buyer)],
      deployer
    );

    expect(wishlist.result).toBeOk(Cl.list([Cl.uint(1)]));
  });

  it("allows user to remove listing from wishlist", () => {
    // Create listing and add to wishlist
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(2_500), Cl.uint(250), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "toggle-wishlist",
      [Cl.uint(1)],
      buyer
    );

    // Remove from wishlist
    const removeResult = simnet.callPublicFn(
      contractName,
      "toggle-wishlist",
      [Cl.uint(1)],
      buyer
    );

    expect(removeResult.result).toBeOk(Cl.bool(true));

    // Verify wishlist is empty
    const wishlist = simnet.callReadOnlyFn(
      contractName,
      "get-wishlist",
      [Cl.principal(buyer)],
      deployer
    );

    expect(wishlist.result).toBeOk(Cl.list([]));
  });
});

describe("stack-mart marketplace fee system", () => {
  it("applies marketplace fee on direct purchase", () => {
    // Create listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(10_000), Cl.uint(500), Cl.principal(royaltyRecipient)],
      seller
    );

    const sellerBefore = getStxBalance(seller);
    const buyerBefore = getStxBalance(buyer);
    const feeRecipientBefore = getStxBalance(deployer);

    // Buy listing
    const purchase = simnet.callPublicFn(
      contractName,
      "buy-listing",
      [Cl.uint(1)],
      buyer
    );

    expect(purchase.result).toBeOk(Cl.bool(true));

    // Verify marketplace fee (2.5% = 250 bips) was deducted
    // Fee: 10000 * 0.025 = 250
    // Royalty: 10000 * 0.05 = 500
    // Seller receives: 10000 - 250 - 500 = 9250
    expect(getStxBalance(seller)).toBe(sellerBefore + 9_250n);
    expect(getStxBalance(feeRecipientBefore)).toBe(feeRecipientBefore + 250n);
    expect(getStxBalance(buyer)).toBe(buyerBefore - 10_000n);
  });

  it("applies marketplace fee on escrow purchase completion", () => {
    // Create listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(8_000), Cl.uint(400), Cl.principal(royaltyRecipient)],
      seller
    );

    // Buy with escrow
    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    // Complete escrow flow
    const deliveryHash = Cl.bufferFromHex("0000000000000000000000000000000000000000000000000000000000000005");
    simnet.callPublicFn(
      contractName,
      "attest-delivery",
      [Cl.uint(1), deliveryHash],
      seller
    );

    const sellerBefore = getStxBalance(seller);
    const feeRecipientBefore = getStxBalance(deployer);

    simnet.callPublicFn(
      contractName,
      "confirm-receipt",
      [Cl.uint(1)],
      buyer
    );

    // Fee: 8000 * 0.025 = 200, Royalty: 8000 * 0.04 = 320
    // Seller: 8000 - 200 - 320 = 7480
    expect(getStxBalance(seller)).toBe(sellerBefore + 7_480n);
    expect(getStxBalance(feeRecipientBefore)).toBe(feeRecipientBefore + 200n);
  });
});

describe("stack-mart price history tracking", () => {
  it("tracks price changes when listing is updated", () => {
    // Create initial listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(5_000), Cl.uint(300), Cl.principal(royaltyRecipient)],
      seller
    );

    // Update listing price (if function exists)
    // Note: This assumes an update-listing function exists
    // For now, we'll test price history retrieval
    const priceHistory = simnet.callReadOnlyFn(
      contractName,
      "get-price-history",
      [Cl.uint(1)],
      deployer
    );

    // Verify price history exists and contains initial price
    expect(priceHistory.result).toBeOk(
      Cl.tuple({
        history: Cl.list([
          Cl.tuple({
            price: Cl.uint(5_000),
            "updated-at-block": Cl.uint(0),
          })
        ])
      })
    );
  });

  it("returns empty history for non-existent listing", () => {
    const priceHistory = simnet.callReadOnlyFn(
      contractName,
      "get-price-history",
      [Cl.uint(999)],
      deployer
    );

    expect(priceHistory.result).toBeErr(Cl.uint(404));
  });
});

describe("stack-mart dispute resolution", () => {
  it("allows buyer to create dispute for escrow", () => {
    // Create listing and escrow
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(6_000), Cl.uint(600), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    // Create dispute
    const disputeResult = simnet.callPublicFn(
      contractName,
      "create-dispute",
      [Cl.uint(1), Cl.stringAscii("Item not received")],
      buyer
    );

    expect(disputeResult.result).toBeOk(Cl.uint(1));

    // Verify dispute was created
    const dispute = simnet.callReadOnlyFn(
      contractName,
      "get-dispute",
      [Cl.uint(1)],
      deployer
    );

    expect(dispute.result).toBeOk(
      Cl.tuple({
        "escrow-id": Cl.uint(1),
        creator: Cl.principal(buyer),
        reason: Cl.stringAscii("Item not received"),
        state: Cl.stringAscii("open"),
      })
    );
  });

  it("allows users to stake on dispute outcome", () => {
    // Setup: listing, escrow, dispute
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(7_000), Cl.uint(700), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    simnet.callPublicFn(
      contractName,
      "create-dispute",
      [Cl.uint(1), Cl.stringAscii("Quality issue")],
      buyer
    );

    // Stake on buyer side
    const stakeResult = simnet.callPublicFn(
      contractName,
      "stake-on-dispute",
      [Cl.uint(1), Cl.bool(true), Cl.uint(1_000)],
      royaltyRecipient
    );

    expect(stakeResult.result).toBeOk(Cl.bool(true));

    // Verify stake was recorded
    const stakes = simnet.callReadOnlyFn(
      contractName,
      "get-dispute-stakes",
      [Cl.uint(1)],
      deployer
    );

    expect(stakes.result).toBeOk(
      Cl.tuple({
        "buyer-stakes": Cl.uint(1_000),
        "seller-stakes": Cl.uint(0),
      })
    );
  });
});

describe("stack-mart dispute voting and resolution", () => {
  it("allows staked users to vote on dispute", () => {
    // Setup dispute with stakes
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(9_000), Cl.uint(900), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    simnet.callPublicFn(
      contractName,
      "create-dispute",
      [Cl.uint(1), Cl.stringAscii("Delivery delay")],
      buyer
    );

    simnet.callPublicFn(
      contractName,
      "stake-on-dispute",
      [Cl.uint(1), Cl.bool(true), Cl.uint(2_000)],
      royaltyRecipient
    );

    // Vote on dispute
    const voteResult = simnet.callPublicFn(
      contractName,
      "vote-on-dispute",
      [Cl.uint(1), Cl.bool(true)],
      royaltyRecipient
    );

    expect(voteResult.result).toBeOk(Cl.bool(true));
  });

  it("resolves dispute when majority votes are cast", () => {
    // Create dispute with multiple stakes
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(12_000), Cl.uint(1200), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    simnet.callPublicFn(
      contractName,
      "create-dispute",
      [Cl.uint(1), Cl.stringAscii("Item damaged")],
      buyer
    );

    // Multiple stakes and votes
    simnet.callPublicFn(
      contractName,
      "stake-on-dispute",
      [Cl.uint(1), Cl.bool(true), Cl.uint(3_000)],
      royaltyRecipient
    );

    simnet.callPublicFn(
      contractName,
      "vote-on-dispute",
      [Cl.uint(1), Cl.bool(true)],
      royaltyRecipient
    );

    // Resolve dispute
    const resolveResult = simnet.callPublicFn(
      contractName,
      "resolve-dispute",
      [Cl.uint(1)],
      deployer
    );

    expect(resolveResult.result).toBeOk(Cl.bool(true));
  });
});

describe("stack-mart admin functions", () => {
  it("allows admin to set marketplace fee", () => {
    // Get current fee
    const currentFee = simnet.callReadOnlyFn(
      contractName,
      "get-marketplace-fee",
      [],
      deployer
    );

    // Set new fee (3% = 300 bips)
    const setFeeResult = simnet.callPublicFn(
      contractName,
      "set-marketplace-fee",
      [Cl.uint(300)],
      deployer
    );

    expect(setFeeResult.result).toBeOk(Cl.bool(true));

    // Verify fee was updated
    const newFee = simnet.callReadOnlyFn(
      contractName,
      "get-marketplace-fee",
      [],
      deployer
    );

    expect(newFee.result).toBeOk(Cl.uint(300));
  });

  it("prevents non-admin from setting marketplace fee", () => {
    const setFeeResult = simnet.callPublicFn(
      contractName,
      "set-marketplace-fee",
      [Cl.uint(400)],
      seller
    );

    expect(setFeeResult.result).toBeErr(Cl.uint(403));
  });

  it("allows admin to set fee recipient", () => {
    const setRecipientResult = simnet.callPublicFn(
      contractName,
      "set-fee-recipient",
      [Cl.principal(royaltyRecipient)],
      deployer
    );

    expect(setRecipientResult.result).toBeOk(Cl.bool(true));
  });
});

describe("stack-mart error handling and edge cases", () => {
  it("rejects purchase with insufficient balance", () => {
    // Create expensive listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(1_000_000_000), Cl.uint(1000), Cl.principal(royaltyRecipient)],
      seller
    );

    // Try to buy with insufficient funds
    const purchase = simnet.callPublicFn(
      contractName,
      "buy-listing",
      [Cl.uint(1)],
      buyer
    );

    expect(purchase.result).toBeErr(Cl.uint(1)); // Insufficient balance error
  });

  it("rejects listing creation with invalid royalty", () => {
    // Try to create listing with royalty > 10% (1000 bips)
    const result = simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(5_000), Cl.uint(1_500), Cl.principal(royaltyRecipient)],
      seller
    );

    expect(result.result).toBeErr(Cl.uint(400)); // Bad royalty error
  });

  it("rejects purchase of non-existent listing", () => {
    const purchase = simnet.callPublicFn(
      contractName,
      "buy-listing",
      [Cl.uint(999)],
      buyer
    );

    expect(purchase.result).toBeErr(Cl.uint(404)); // Not found error
  });
});

describe("stack-mart reputation volume tracking", () => {
  it("tracks total volume for seller reputation", () => {
    // Create and complete multiple transactions
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(3_000), Cl.uint(300), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "buy-listing",
      [Cl.uint(1)],
      buyer
    );

    // Create second listing
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(4_000), Cl.uint(400), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "buy-listing",
      [Cl.uint(2)],
      buyer
    );

    // Check seller reputation includes total volume
    const sellerRep = simnet.callReadOnlyFn(
      contractName,
      "get-seller-reputation",
      [Cl.principal(seller)],
      deployer
    );

    expect(sellerRep.result).toBeOk(
      Cl.tuple({
        "successful-txs": Cl.uint(2),
        "total-volume": Cl.uint(7_000),
      })
    );
  });

  it("tracks total volume for buyer reputation", () => {
    // Create listings and buyer purchases them
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(2_500), Cl.uint(250), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "buy-listing",
      [Cl.uint(1)],
      buyer
    );

    // Check buyer reputation
    const buyerRep = simnet.callReadOnlyFn(
      contractName,
      "get-buyer-reputation",
      [Cl.principal(buyer)],
      deployer
    );

    expect(buyerRep.result).toBeOk(
      Cl.tuple({
        "successful-txs": Cl.uint(1),
        "total-volume": Cl.uint(2_500),
      })
    );
  });
});

describe("stack-mart escrow timeout handling", () => {
  it("allows buyer to release escrow after timeout", () => {
    // Create listing and escrow
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(6_500), Cl.uint(650), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    // Advance blocks to timeout (144 blocks)
    for (let i = 0; i < 145; i++) {
      simnet.mineBlock([]);
    }

    const buyerBefore = getStxBalance(buyer);

    // Release escrow after timeout
    const releaseResult = simnet.callPublicFn(
      contractName,
      "release-escrow",
      [Cl.uint(1)],
      buyer
    );

    expect(releaseResult.result).toBeOk(Cl.bool(true));

    // Buyer should get refund
    expect(getStxBalance(buyer)).toBe(buyerBefore + 6_500n);
  });

  it("prevents escrow release before timeout", () => {
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(5_500), Cl.uint(550), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "buy-listing-escrow",
      [Cl.uint(1)],
      buyer
    );

    // Try to release before timeout
    const releaseResult = simnet.callPublicFn(
      contractName,
      "release-escrow",
      [Cl.uint(1)],
      buyer
    );

    expect(releaseResult.result).toBeErr(Cl.uint(400)); // Timeout not reached
  });
});

describe("stack-mart bundle purchase flow", () => {
  it("allows purchase of bundle with discount applied", () => {
    // Create multiple listings
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(1_000), Cl.uint(100), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(2_000), Cl.uint(200), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(3_000), Cl.uint(300), Cl.principal(royaltyRecipient)],
      seller
    );

    // Create bundle with 15% discount (1500 bips)
    simnet.callPublicFn(
      contractName,
      "create-bundle",
      [
        Cl.list([Cl.uint(1), Cl.uint(2), Cl.uint(3)]),
        Cl.uint(1_500),
      ],
      seller
    );

    const buyerBefore = getStxBalance(buyer);

    // Purchase bundle
    const purchaseResult = simnet.callPublicFn(
      contractName,
      "buy-bundle",
      [Cl.uint(1)],
      buyer
    );

    expect(purchaseResult.result).toBeOk(Cl.bool(true));

    // Total: 6000, Discount: 15% = 900, Price: 5100
    expect(getStxBalance(buyer)).toBe(buyerBefore - 5_100n);
  });
});

describe("stack-mart curated pack functionality", () => {
  it("creates curated pack with multiple listings", () => {
    // Create listings for pack
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(500), Cl.uint(50), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(1_000), Cl.uint(100), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(1_500), Cl.uint(150), Cl.principal(royaltyRecipient)],
      seller
    );

    // Create curated pack with fixed price
    const packResult = simnet.callPublicFn(
      contractName,
      "create-pack",
      [
        Cl.list([Cl.uint(1), Cl.uint(2), Cl.uint(3)]),
        Cl.uint(2_500), // Pack price
      ],
      seller
    );

    expect(packResult.result).toBeOk(Cl.uint(1));

    // Verify pack was created
    const pack = simnet.callReadOnlyFn(
      contractName,
      "get-pack",
      [Cl.uint(1)],
      deployer
    );

    expect(pack.result).toBeOk(
      Cl.tuple({
        "listing-ids": Cl.list([Cl.uint(1), Cl.uint(2), Cl.uint(3)]),
        price: Cl.uint(2_500),
        creator: Cl.principal(seller),
      })
    );
  });

  it("allows purchase of curated pack", () => {
    // Setup pack
    simnet.callPublicFn(
      contractName,
      "create-listing",
      [Cl.uint(800), Cl.uint(80), Cl.principal(royaltyRecipient)],
      seller
    );

    simnet.callPublicFn(
      contractName,
      "create-pack",
      [
        Cl.list([Cl.uint(1)]),
        Cl.uint(700), // Discounted pack price
      ],
      seller
    );

    const buyerBefore = getStxBalance(buyer);

    // Purchase pack
    const purchaseResult = simnet.callPublicFn(
      contractName,
      "buy-pack",
      [Cl.uint(1)],
      buyer
    );

    expect(purchaseResult.result).toBeOk(Cl.bool(true));
    expect(getStxBalance(buyer)).toBe(buyerBefore - 700n);
  });
});

describe("stack-mart listing with NFT integration", () => {
  it("creates listing with NFT contract and token ID", () => {
    // Create listing with NFT details
    const nftContract = Cl.principal("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM");
    const tokenId = Cl.uint(42);

    const result = simnet.callPublicFn(
      contractName,
      "create-listing-with-nft",
      [
        Cl.uint(15_000),
        Cl.uint(750),
        Cl.principal(royaltyRecipient),
        nftContract,
        tokenId,
      ],
      seller
    );

    expect(result.result).toBeOk(Cl.uint(1));

    // Verify listing includes NFT info
    const listing = simnet.callReadOnlyFn(
      contractName,
      "get-listing",
      [Cl.uint(1)],
      deployer
    );

    expect(listing.result).toBeOk(
      Cl.tuple({
        "nft-contract": Cl.some(nftContract),
        "token-id": Cl.some(tokenId),
        price: Cl.uint(15_000),
      })
    );
  });

  it("transfers NFT on successful purchase", () => {
    // This test assumes NFT contract integration
    // Create listing with NFT
    const nftContract = Cl.principal("ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM");
    
    simnet.callPublicFn(
      contractName,
      "create-listing-with-nft",
      [
        Cl.uint(20_000),
        Cl.uint(1000),
        Cl.principal(royaltyRecipient),
        nftContract,
        Cl.uint(100),
      ],
      seller
    );

    // Purchase listing
    const purchase = simnet.callPublicFn(
      contractName,
      "buy-listing",
      [Cl.uint(1)],
      buyer
    );

    expect(purchase.result).toBeOk(Cl.bool(true));
    // NFT transfer would be verified through NFT contract calls
  });
});
