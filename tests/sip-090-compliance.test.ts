import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const contractName = "sip-090-nft";

describe("SIP-090 Standard Compliance Tests", () => {
  beforeEach(() => {
    simnet.setEpoch("3.0");
  });

  describe("Required SIP-090 Functions", () => {
    it("should implement get-last-token-id function", () => {
      const lastTokenId = simnet.callReadOnlyFn(
        contractName,
        "get-last-token-id",
        [],
        deployer
      );

      expect(lastTokenId.result).toBeOk(Cl.uint(0)); // Initial state
    });

    it("should implement get-token-uri function", () => {
      // Test with non-existent token
      const tokenUri = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(1)],
        deployer
      );

      expect(tokenUri.result).toBeErr(Cl.uint(404)); // ERR-NOT-FOUND

      // Mint token and test again
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const tokenUri2 = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(1)],
        deployer
      );

      expect(tokenUri2.result).toBeOk(
        Cl.some(Cl.stringAscii("https://api.stackmart.io/nft/1"))
      );
    });

    it("should implement get-owner function", () => {
      // Test with non-existent token
      const owner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );

      expect(owner.result).toBeErr(Cl.uint(404)); // ERR-NOT-FOUND

      // Mint token and test again
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const owner2 = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );

      expect(owner2.result).toBeOk(Cl.some(Cl.principal(wallet1)));
    });

    it("should implement transfer function", () => {
      // Mint token first
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      // Test transfer
      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );

      expect(transferResult.result).toBeOk(Cl.bool(true));

      // Verify ownership changed
      const newOwner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );
      expect(newOwner.result).toBeOk(Cl.some(Cl.principal(wallet2)));
    });
  });

  describe("Standard Error Codes", () => {
    it("should return correct error codes for SIP-090 compliance", () => {
      // ERR-NOT-FOUND (404) for non-existent tokens
      const owner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(999)],
        deployer
      );
      expect(owner.result).toBeErr(Cl.uint(404));

      // ERR-NOT-AUTHORIZED (401) for unauthorized operations
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        wallet1 // Non-owner
      );
      expect(mintResult.result).toBeErr(Cl.uint(401));

      // ERR-INVALID-OWNER (403) for wrong ownership claims
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet2), Cl.principal(wallet1)], // Wrong sender
        wallet1
      );
      expect(transferResult.result).toBeErr(Cl.uint(403));
    });
  });

  describe("Metadata Compliance", () => {
    it("should provide contract metadata", () => {
      const contractInfo = simnet.callReadOnlyFn(
        contractName,
        "get-contract-info",
        [],
        deployer
      );

      expect(contractInfo.result).toBeOk(
        Cl.tuple({
          name: Cl.stringAscii("StackMart NFT"),
          symbol: Cl.stringAscii("SMNFT"),
          "base-uri": Cl.stringAscii("https://api.stackmart.io/nft/"),
          "total-supply": Cl.uint(0),
          "max-supply": Cl.uint(10000)
        })
      );
    });

    it("should handle optional metadata URIs correctly", () => {
      // Mint without custom URI
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const tokenUri1 = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(1)],
        deployer
      );
      expect(tokenUri1.result).toBeOk(
        Cl.some(Cl.stringAscii("https://api.stackmart.io/nft/1"))
      );

      // Mint with custom URI
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.some(Cl.stringAscii("https://custom.uri/2"))],
        deployer
      );

      const tokenUri2 = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(2)],
        deployer
      );
      expect(tokenUri2.result).toBeOk(
        Cl.some(Cl.stringAscii("https://custom.uri/2"))
      );
    });
  });

  describe("Supply Tracking Compliance", () => {
    it("should track total supply correctly", () => {
      // Initial supply should be 0
      const initialSupply = simnet.callReadOnlyFn(
        contractName,
        "get-total-supply",
        [],
        deployer
      );
      expect(initialSupply.result).toBeOk(Cl.uint(0));

      // Mint tokens and verify supply increases
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const supply1 = simnet.callReadOnlyFn(
        contractName,
        "get-total-supply",
        [],
        deployer
      );
      expect(supply1.result).toBeOk(Cl.uint(1));

      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet2), Cl.none()],
        deployer
      );

      const supply2 = simnet.callReadOnlyFn(
        contractName,
        "get-total-supply",
        [],
        deployer
      );
      expect(supply2.result).toBeOk(Cl.uint(2));
    });

    it("should track last token ID correctly", () => {
      // Initial last token ID should be 0
      const initialLastId = simnet.callReadOnlyFn(
        contractName,
        "get-last-token-id",
        [],
        deployer
      );
      expect(initialLastId.result).toBeOk(Cl.uint(0));

      // Mint token and verify last ID updates
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const lastId1 = simnet.callReadOnlyFn(
        contractName,
        "get-last-token-id",
        [],
        deployer
      );
      expect(lastId1.result).toBeOk(Cl.uint(1));

      // Mint another token
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet2), Cl.none()],
        deployer
      );

      const lastId2 = simnet.callReadOnlyFn(
        contractName,
        "get-last-token-id",
        [],
        deployer
      );
      expect(lastId2.result).toBeOk(Cl.uint(2));
    });
  });

  describe("Transfer Compliance", () => {
    beforeEach(() => {
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );
    });

    it("should maintain ownership integrity during transfers", () => {
      // Initial owner
      const initialOwner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );
      expect(initialOwner.result).toBeOk(Cl.some(Cl.principal(wallet1)));

      // Transfer
      simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );

      // New owner
      const newOwner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );
      expect(newOwner.result).toBeOk(Cl.some(Cl.principal(wallet2)));

      // Total supply should remain unchanged
      const totalSupply = simnet.callReadOnlyFn(
        contractName,
        "get-total-supply",
        [],
        deployer
      );
      expect(totalSupply.result).toBeOk(Cl.uint(1));
    });
  });
});