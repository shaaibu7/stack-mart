import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const contractName = "sip-090-nft";

describe("SIP-090 NFT Edge Cases", () => {
  beforeEach(() => {
    simnet.setEpoch("3.0");
  });

  describe("URI Edge Cases", () => {
    it("should handle very long URIs", () => {
      const longUri = "a".repeat(255); // Maximum length
      
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.some(Cl.stringAscii(longUri))],
        deployer
      );

      expect(mintResult.result).toBeOk(Cl.uint(1));

      const tokenUri = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(1)],
        deployer
      );

      expect(tokenUri.result).toBeOk(Cl.some(Cl.stringAscii(longUri)));
    });

    it("should handle empty string URIs", () => {
      const emptyUri = "";
      
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.some(Cl.stringAscii(emptyUri))],
        deployer
      );

      expect(mintResult.result).toBeOk(Cl.uint(1));
    });

    it("should handle special characters in URIs", () => {
      const specialUri = "https://api.test.com/nft/special-chars_123?param=value";
      
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.some(Cl.stringAscii(specialUri))],
        deployer
      );

      expect(mintResult.result).toBeOk(Cl.uint(1));

      const tokenUri = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(1)],
        deployer
      );

      expect(tokenUri.result).toBeOk(Cl.some(Cl.stringAscii(specialUri)));
    });
  });

  describe("Large Token ID Edge Cases", () => {
    it("should handle queries for very large token IDs", () => {
      const largeTokenId = 999999999;
      
      const owner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(largeTokenId)],
        deployer
      );

      expect(owner.result).toBeErr(Cl.uint(404)); // ERR-NOT-FOUND

      const tokenUri = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(largeTokenId)],
        deployer
      );

      expect(tokenUri.result).toBeErr(Cl.uint(404)); // ERR-NOT-FOUND
    });

    it("should handle zero token ID", () => {
      const owner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(0)],
        deployer
      );

      expect(owner.result).toBeErr(Cl.uint(404)); // ERR-NOT-FOUND
    });
  });

  describe("Ownership Edge Cases", () => {
    it("should handle empty token lists correctly", () => {
      const emptyTokens = simnet.callReadOnlyFn(
        contractName,
        "get-tokens-by-owner",
        [Cl.principal(wallet1)],
        deployer
      );

      expect(emptyTokens.result).toBeOk(Cl.list([]));

      const tokenCount = simnet.callReadOnlyFn(
        contractName,
        "get-token-count-by-owner",
        [Cl.principal(wallet1)],
        deployer
      );

      expect(tokenCount.result).toBeOk(Cl.uint(0));
    });

    it("should handle ownership checks for non-existent tokens", () => {
      const isOwner = simnet.callReadOnlyFn(
        contractName,
        "is-token-owner",
        [Cl.uint(999), Cl.principal(wallet1)],
        deployer
      );

      expect(isOwner.result).toBeOk(Cl.bool(false));
    });
  });
});