import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;

const contractName = "sip-090-nft";

describe("SIP-090 NFT Integration Tests", () => {
  beforeEach(() => {
    simnet.setEpoch("3.0");
  });

  describe("Complete Workflow Integration", () => {
    it("should handle complete mint-transfer-query workflow", () => {
      // Step 1: Mint token
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.some(Cl.stringAscii("https://example.com/1"))],
        deployer
      );
      expect(mintResult.result).toBeOk(Cl.uint(1));

      // Step 2: Verify initial ownership
      const initialOwner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );
      expect(initialOwner.result).toBeOk(Cl.some(Cl.principal(wallet1)));

      // Step 3: Transfer token
      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );
      expect(transferResult.result).toBeOk(Cl.bool(true));

      // Step 4: Verify new ownership
      const newOwner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );
      expect(newOwner.result).toBeOk(Cl.some(Cl.principal(wallet2)));

      // Step 5: Verify token lists updated
      const wallet1Tokens = simnet.callReadOnlyFn(
        contractName,
        "get-tokens-by-owner",
        [Cl.principal(wallet1)],
        deployer
      );
      expect(wallet1Tokens.result).toBeOk(Cl.list([]));

      const wallet2Tokens = simnet.callReadOnlyFn(
        contractName,
        "get-tokens-by-owner",
        [Cl.principal(wallet2)],
        deployer
      );
      expect(wallet2Tokens.result).toBeOk(Cl.list([Cl.uint(1)]));
    });

    it("should handle multiple transfers correctly", () => {
      // Mint token
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      // Transfer chain: wallet1 -> wallet2 -> wallet3
      simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );

      simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet2), Cl.principal(wallet3)],
        wallet2
      );

      // Verify final ownership
      const finalOwner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );
      expect(finalOwner.result).toBeOk(Cl.some(Cl.principal(wallet3)));

      // Verify token lists
      const wallet3Tokens = simnet.callReadOnlyFn(
        contractName,
        "get-tokens-by-owner",
        [Cl.principal(wallet3)],
        deployer
      );
      expect(wallet3Tokens.result).toBeOk(Cl.list([Cl.uint(1)]));
    });
  });

  describe("Batch Operations Integration", () => {
    it("should handle batch mint and individual transfers", () => {
      // Batch mint 3 tokens
      const recipients = [wallet1, wallet2, wallet3];
      const metadataUris = [
        Cl.some(Cl.stringAscii("uri1")),
        Cl.some(Cl.stringAscii("uri2")),
        Cl.some(Cl.stringAscii("uri3"))
      ];

      const batchMintResult = simnet.callPublicFn(
        contractName,
        "batch-mint",
        [
          Cl.list(recipients.map(w => Cl.principal(w))),
          Cl.list(metadataUris)
        ],
        deployer
      );
      expect(batchMintResult.result).toBeOk(Cl.list([Cl.uint(1), Cl.uint(2), Cl.uint(3)]));

      // Transfer token 2 from wallet2 to wallet1
      simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(2), Cl.principal(wallet2), Cl.principal(wallet1)],
        wallet2
      );

      // Verify final token distribution
      const wallet1Tokens = simnet.callReadOnlyFn(
        contractName,
        "get-tokens-by-owner",
        [Cl.principal(wallet1)],
        deployer
      );
      expect(wallet1Tokens.result).toBeOk(Cl.list([Cl.uint(1), Cl.uint(2)]));

      const wallet2Tokens = simnet.callReadOnlyFn(
        contractName,
        "get-tokens-by-owner",
        [Cl.principal(wallet2)],
        deployer
      );
      expect(wallet2Tokens.result).toBeOk(Cl.list([]));

      const wallet3Tokens = simnet.callReadOnlyFn(
        contractName,
        "get-tokens-by-owner",
        [Cl.principal(wallet3)],
        deployer
      );
      expect(wallet3Tokens.result).toBeOk(Cl.list([Cl.uint(3)]));
    });
  });

  describe("Administrative Integration", () => {
    it("should handle pause/unpause with operations", () => {
      // Mint a token first
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      // Pause contract
      simnet.callPublicFn(contractName, "pause-contract", [], deployer);

      // Try to transfer (should fail)
      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );
      expect(transferResult.result).toBeErr(Cl.uint(503)); // ERR-CONTRACT-PAUSED

      // Try to mint (should fail)
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet2), Cl.none()],
        deployer
      );
      expect(mintResult.result).toBeErr(Cl.uint(503)); // ERR-CONTRACT-PAUSED

      // Unpause contract
      simnet.callPublicFn(contractName, "unpause-contract", [], deployer);

      // Now transfer should work
      const transferResult2 = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );
      expect(transferResult2.result).toBeOk(Cl.bool(true));
    });
  });
});