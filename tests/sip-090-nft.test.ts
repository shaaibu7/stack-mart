import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;

const contractName = "sip-090-nft";

describe("SIP-090 NFT Contract", () => {
  beforeEach(() => {
    // Reset simnet state before each test
    simnet.setEpoch("3.0");
  });

  describe("Contract Initialization", () => {
    it("should have correct initial contract info", () => {
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

    it("should have zero initial supply", () => {
      const totalSupply = simnet.callReadOnlyFn(
        contractName,
        "get-total-supply",
        [],
        deployer
      );

      expect(totalSupply.result).toBeOk(Cl.uint(0));
    });

    it("should have correct initial last token ID", () => {
      const lastTokenId = simnet.callReadOnlyFn(
        contractName,
        "get-last-token-id",
        [],
        deployer
      );

      expect(lastTokenId.result).toBeOk(Cl.uint(0));
    });

    it("should not be paused initially", () => {
      const isPaused = simnet.callReadOnlyFn(
        contractName,
        "is-paused",
        [],
        deployer
      );

      expect(isPaused.result).toBeOk(Cl.bool(false));
    });
  });

  describe("Minting Functionality", () => {
    it("should allow owner to mint NFT", () => {
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      expect(mintResult.result).toBeOk(Cl.uint(1));
      
      // Check total supply increased
      const totalSupply = simnet.callReadOnlyFn(
        contractName,
        "get-total-supply",
        [],
        deployer
      );
      expect(totalSupply.result).toBeOk(Cl.uint(1));
    });

    it("should set correct owner after minting", () => {
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const owner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );

      expect(owner.result).toBeOk(Cl.some(Cl.principal(wallet1)));
    });

    it("should mint with custom metadata URI", () => {
      const customUri = "https://custom.uri/token/1";
      
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.some(Cl.stringAscii(customUri))],
        deployer
      );

      const tokenUri = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(1)],
        deployer
      );

      expect(tokenUri.result).toBeOk(Cl.some(Cl.stringAscii(customUri)));
    });

    it("should use base URI when no custom URI provided", () => {
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const tokenUri = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(1)],
        deployer
      );

      expect(tokenUri.result).toBeOk(
        Cl.some(Cl.stringAscii("https://api.stackmart.io/nft/1"))
      );
    });

    it("should reject minting from non-owner", () => {
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet2), Cl.none()],
        wallet1
      );

      expect(mintResult.result).toBeErr(Cl.uint(401)); // ERR-NOT-AUTHORIZED
    });

    it("should reject minting when contract is paused", () => {
      // Pause contract first
      simnet.callPublicFn(contractName, "pause-contract", [], deployer);

      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      expect(mintResult.result).toBeErr(Cl.uint(503)); // ERR-CONTRACT-PAUSED
    });
  });
  describe("Transfer Functionality", () => {
    beforeEach(() => {
      // Mint a token for testing transfers
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );
    });

    it("should allow owner to transfer NFT", () => {
      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );

      expect(transferResult.result).toBeOk(Cl.bool(true));

      // Verify new owner
      const newOwner = simnet.callReadOnlyFn(
        contractName,
        "get-owner",
        [Cl.uint(1)],
        deployer
      );
      expect(newOwner.result).toBeOk(Cl.some(Cl.principal(wallet2)));
    });

    it("should reject transfer from non-owner", () => {
      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet2
      );

      expect(transferResult.result).toBeErr(Cl.uint(401)); // ERR-NOT-AUTHORIZED
    });

    it("should reject transfer of non-existent token", () => {
      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(999), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );

      expect(transferResult.result).toBeErr(Cl.uint(404)); // ERR-NOT-FOUND
    });

    it("should reject transfer to same address", () => {
      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet1)],
        wallet1
      );

      expect(transferResult.result).toBeErr(Cl.uint(400)); // ERR-INVALID-PARAMETERS
    });

    it("should reject transfer when contract is paused", () => {
      // Pause contract
      simnet.callPublicFn(contractName, "pause-contract", [], deployer);

      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );

      expect(transferResult.result).toBeErr(Cl.uint(503)); // ERR-CONTRACT-PAUSED
    });
  });