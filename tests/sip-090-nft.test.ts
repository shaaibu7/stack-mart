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
  describe("Administrative Functions", () => {
    it("should allow owner to pause contract", () => {
      const pauseResult = simnet.callPublicFn(
        contractName,
        "pause-contract",
        [],
        deployer
      );

      expect(pauseResult.result).toBeOk(Cl.bool(true));

      // Verify contract is paused
      const isPaused = simnet.callReadOnlyFn(
        contractName,
        "is-paused",
        [],
        deployer
      );
      expect(isPaused.result).toBeOk(Cl.bool(true));
    });

    it("should allow owner to unpause contract", () => {
      // First pause
      simnet.callPublicFn(contractName, "pause-contract", [], deployer);

      // Then unpause
      const unpauseResult = simnet.callPublicFn(
        contractName,
        "unpause-contract",
        [],
        deployer
      );

      expect(unpauseResult.result).toBeOk(Cl.bool(true));

      // Verify contract is not paused
      const isPaused = simnet.callReadOnlyFn(
        contractName,
        "is-paused",
        [],
        deployer
      );
      expect(isPaused.result).toBeOk(Cl.bool(false));
    });

    it("should reject pause from non-owner", () => {
      const pauseResult = simnet.callPublicFn(
        contractName,
        "pause-contract",
        [],
        wallet1
      );

      expect(pauseResult.result).toBeErr(Cl.uint(401)); // ERR-NOT-AUTHORIZED
    });

    it("should allow owner to set base URI", () => {
      const newBaseUri = "https://new.api.com/nft/";
      
      const setUriResult = simnet.callPublicFn(
        contractName,
        "set-base-uri",
        [Cl.stringAscii(newBaseUri)],
        deployer
      );

      expect(setUriResult.result).toBeOk(Cl.bool(true));

      // Verify new base URI is used
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
        Cl.some(Cl.stringAscii("https://new.api.com/nft/1"))
      );
    });

    it("should allow owner to set custom token URI", () => {
      // First mint a token
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const customUri = "https://custom.token.uri/special";
      
      const setTokenUriResult = simnet.callPublicFn(
        contractName,
        "set-token-uri",
        [Cl.uint(1), Cl.stringAscii(customUri)],
        deployer
      );

      expect(setTokenUriResult.result).toBeOk(Cl.bool(true));

      // Verify custom URI is returned
      const tokenUri = simnet.callReadOnlyFn(
        contractName,
        "get-token-uri",
        [Cl.uint(1)],
        deployer
      );

      expect(tokenUri.result).toBeOk(Cl.some(Cl.stringAscii(customUri)));
    });
  });
  describe("Query Functions", () => {
    beforeEach(() => {
      // Mint some tokens for testing
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet2), Cl.none()],
        deployer
      );
    });

    it("should return correct tokens by owner", () => {
      const wallet1Tokens = simnet.callReadOnlyFn(
        contractName,
        "get-tokens-by-owner",
        [Cl.principal(wallet1)],
        deployer
      );

      expect(wallet1Tokens.result).toBeOk(
        Cl.list([Cl.uint(1), Cl.uint(2)])
      );

      const wallet2Tokens = simnet.callReadOnlyFn(
        contractName,
        "get-tokens-by-owner",
        [Cl.principal(wallet2)],
        deployer
      );

      expect(wallet2Tokens.result).toBeOk(
        Cl.list([Cl.uint(3)])
      );
    });

    it("should return correct token count by owner", () => {
      const wallet1Count = simnet.callReadOnlyFn(
        contractName,
        "get-token-count-by-owner",
        [Cl.principal(wallet1)],
        deployer
      );

      expect(wallet1Count.result).toBeOk(Cl.uint(2));

      const wallet2Count = simnet.callReadOnlyFn(
        contractName,
        "get-token-count-by-owner",
        [Cl.principal(wallet2)],
        deployer
      );

      expect(wallet2Count.result).toBeOk(Cl.uint(1));
    });

    it("should correctly identify token ownership", () => {
      const isOwner1 = simnet.callReadOnlyFn(
        contractName,
        "is-token-owner",
        [Cl.uint(1), Cl.principal(wallet1)],
        deployer
      );

      expect(isOwner1.result).toBeOk(Cl.bool(true));

      const isOwner2 = simnet.callReadOnlyFn(
        contractName,
        "is-token-owner",
        [Cl.uint(1), Cl.principal(wallet2)],
        deployer
      );

      expect(isOwner2.result).toBeOk(Cl.bool(false));
    });

    it("should check token existence correctly", () => {
      const exists1 = simnet.callReadOnlyFn(
        contractName,
        "token-exists",
        [Cl.uint(1)],
        deployer
      );

      expect(exists1.result).toBeOk(Cl.bool(true));

      const exists999 = simnet.callReadOnlyFn(
        contractName,
        "token-exists",
        [Cl.uint(999)],
        deployer
      );

      expect(exists999.result).toBeOk(Cl.bool(false));
    });

    it("should return complete token info", () => {
      const tokenInfo = simnet.callReadOnlyFn(
        contractName,
        "get-token-info",
        [Cl.uint(1)],
        deployer
      );

      expect(tokenInfo.result).toBeOk(
        Cl.tuple({
          "token-id": Cl.uint(1),
          owner: Cl.principal(wallet1),
          "metadata-uri": Cl.some(Cl.stringAscii("https://api.stackmart.io/nft/1"))
        })
      );
    });
  });
  describe("Batch Operations", () => {
    it("should batch mint multiple NFTs", () => {
      const recipients = [wallet1, wallet2, wallet3];
      const metadataUris = [
        Cl.some(Cl.stringAscii("uri1")),
        Cl.some(Cl.stringAscii("uri2")),
        Cl.none()
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

      expect(batchMintResult.result).toBeOk(
        Cl.list([Cl.uint(1), Cl.uint(2), Cl.uint(3)])
      );

      // Verify total supply
      const totalSupply = simnet.callReadOnlyFn(
        contractName,
        "get-total-supply",
        [],
        deployer
      );
      expect(totalSupply.result).toBeOk(Cl.uint(3));
    });

    it("should reject batch mint with mismatched arrays", () => {
      const recipients = [wallet1, wallet2];
      const metadataUris = [Cl.some(Cl.stringAscii("uri1"))]; // Different length

      const batchMintResult = simnet.callPublicFn(
        contractName,
        "batch-mint",
        [
          Cl.list(recipients.map(w => Cl.principal(w))),
          Cl.list(metadataUris)
        ],
        deployer
      );

      expect(batchMintResult.result).toBeErr(Cl.uint(400)); // ERR-INVALID-PARAMETERS
    });

    it("should reject batch mint from non-owner", () => {
      const recipients = [wallet1];
      const metadataUris = [Cl.none()];

      const batchMintResult = simnet.callPublicFn(
        contractName,
        "batch-mint",
        [
          Cl.list(recipients.map(w => Cl.principal(w))),
          Cl.list(metadataUris)
        ],
        wallet1
      );

      expect(batchMintResult.result).toBeErr(Cl.uint(401)); // ERR-NOT-AUTHORIZED
    });
  });