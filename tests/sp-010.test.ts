import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;

/**
 * SIP-010 Token Contract Test Suite
 * 
 * Comprehensive tests for SIP-010 compliant fungible token
 * covering all functionality and edge cases.
 */
describe("SIP-010 Token Contract", () => {
  beforeEach(() => {
    // Contract is automatically deployed with initial supply to deployer
  });

  describe("Metadata Functions", () => {
    it("should return correct token name", () => {
      const response = simnet.callReadOnlyFn("sip-010-token", "get-name", [], deployer);
      expect(response.result).toBeOk(Cl.stringAscii("StackMart Token"));
    });

    it("should return correct token symbol", () => {
      const response = simnet.callReadOnlyFn("sip-010-token", "get-symbol", [], deployer);
      expect(response.result).toBeOk(Cl.stringAscii("SMT"));
    });

    it("should return correct decimals", () => {
      const response = simnet.callReadOnlyFn("sip-010-token", "get-decimals", [], deployer);
      expect(response.result).toBeOk(Cl.uint(6));
    });

    it("should return token URI", () => {
      const response = simnet.callReadOnlyFn("sip-010-token", "get-token-uri", [], deployer);
      expect(response.result).toBeOk(Cl.some(Cl.uint("https://stackmart.io/token-metadata.json")));
    });
  });

  describe("Balance and Supply", () => {
    it("should return deployer initial balance", () => {
      const response = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(deployer)], deployer);
      expect(response.result).toBeOk(Cl.uint(1000000000000000));
    });

    it("should return zero balance for new principal", () => {
      const response = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(wallet1)], deployer);
      expect(response.result).toBeOk(Cl.uint(0));
    });

    it("should return correct total supply", () => {
      const response = simnet.callReadOnlyFn("sip-010-token", "get-total-supply", [], deployer);
      expect(response.result).toBeOk(Cl.uint(1000000000000000));
    });
  });

  describe("Transfer Function", () => {
    it("should transfer tokens successfully", () => {
      const transferAmount = 1000000; // 1 token with 6 decimals
      
      const response = simnet.callPublicFn(
        "sip-010-token",
        "transfer",
        [
          Cl.uint(transferAmount),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check balances after transfer
      const senderBalance = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(deployer)], deployer);
      const recipientBalance = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(wallet1)], deployer);
      
      expect(senderBalance.result).toBeOk(Cl.uint(1000000000000000 - transferAmount));
      expect(recipientBalance.result).toBeOk(Cl.uint(transferAmount));
    });

    it("should reject transfer with insufficient balance", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "transfer",
        [
          Cl.uint(2000000000000000), // More than total supply
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });

    it("should reject zero amount transfer", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "transfer",
        [
          Cl.uint(0),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(103)); // ERR-INVALID-AMOUNT
    });

    it("should reject unauthorized transfer", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "transfer",
        [
          Cl.uint(1000000),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        wallet2 // Wrong sender
      );
      
      expect(response.result).toBeErr(Cl.uint(101)); // ERR-NOT-TOKEN-OWNER
    });
  });
  describe("Mint Function", () => {
    it("should mint tokens successfully by owner", () => {
      const mintAmount = 5000000; // 5 tokens
      
      const response = simnet.callPublicFn(
        "sip-010-token",
        "mint",
        [
          Cl.uint(mintAmount),
          Cl.principal(wallet1)
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check recipient balance
      const balance = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(wallet1)], deployer);
      expect(balance.result).toBeOk(Cl.uint(mintAmount));
    });

    it("should reject mint by non-owner", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "mint",
        [
          Cl.uint(1000000),
          Cl.principal(wallet1)
        ],
        wallet2 // Non-owner
      );
      
      expect(response.result).toBeErr(Cl.uint(100)); // ERR-OWNER-ONLY
    });

    it("should reject zero amount mint", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "mint",
        [
          Cl.uint(0),
          Cl.principal(wallet1)
        ],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(103)); // ERR-INVALID-AMOUNT
    });
  });

  describe("Burn Function", () => {
    beforeEach(() => {
      // Transfer some tokens to wallet1 for burning tests
      simnet.callPublicFn(
        "sip-010-token",
        "transfer",
        [
          Cl.uint(10000000),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
    });

    it("should burn tokens successfully", () => {
      const burnAmount = 2000000;
      
      const response = simnet.callPublicFn(
        "sip-010-token",
        "burn",
        [
          Cl.uint(burnAmount),
          Cl.principal(wallet1)
        ],
        wallet1
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check balance after burn
      const balance = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(wallet1)], deployer);
      expect(balance.result).toBeOk(Cl.uint(10000000 - burnAmount));
    });

    it("should reject unauthorized burn", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "burn",
        [
          Cl.uint(1000000),
          Cl.principal(wallet1)
        ],
        wallet2 // Wrong sender
      );
      
      expect(response.result).toBeErr(Cl.uint(101)); // ERR-NOT-TOKEN-OWNER
    });

    it("should reject zero amount burn", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "burn",
        [
          Cl.uint(0),
          Cl.principal(wallet1)
        ],
        wallet1
      );
      
      expect(response.result).toBeErr(Cl.uint(103)); // ERR-INVALID-AMOUNT
    });
  });
  describe("Allowance Functions", () => {
    it("should approve allowance successfully", () => {
      const allowanceAmount = 3000000;
      
      const response = simnet.callPublicFn(
        "sip-010-token",
        "approve",
        [
          Cl.principal(wallet1),
          Cl.uint(allowanceAmount)
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check allowance
      const allowance = simnet.callReadOnlyFn(
        "sip-010-token",
        "get-allowance",
        [Cl.principal(deployer), Cl.principal(wallet1)],
        deployer
      );
      expect(allowance.result).toBeOk(Cl.uint(allowanceAmount));
    });

    it("should reject zero allowance approval", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "approve",
        [
          Cl.principal(wallet1),
          Cl.uint(0)
        ],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(103)); // ERR-INVALID-AMOUNT
    });

    it("should increase allowance successfully", () => {
      // First approve some amount
      simnet.callPublicFn(
        "sip-010-token",
        "approve",
        [Cl.principal(wallet1), Cl.uint(1000000)],
        deployer
      );
      
      // Then increase
      const increaseAmount = 500000;
      const response = simnet.callPublicFn(
        "sip-010-token",
        "increase-allowance",
        [
          Cl.principal(wallet1),
          Cl.uint(increaseAmount)
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check new allowance
      const allowance = simnet.callReadOnlyFn(
        "sip-010-token",
        "get-allowance",
        [Cl.principal(deployer), Cl.principal(wallet1)],
        deployer
      );
      expect(allowance.result).toBeOk(Cl.uint(1500000));
    });

    it("should decrease allowance successfully", () => {
      // First approve some amount
      simnet.callPublicFn(
        "sip-010-token",
        "approve",
        [Cl.principal(wallet1), Cl.uint(2000000)],
        deployer
      );
      
      // Then decrease
      const decreaseAmount = 500000;
      const response = simnet.callPublicFn(
        "sip-010-token",
        "decrease-allowance",
        [
          Cl.principal(wallet1),
          Cl.uint(decreaseAmount)
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check new allowance
      const allowance = simnet.callReadOnlyFn(
        "sip-010-token",
        "get-allowance",
        [Cl.principal(deployer), Cl.principal(wallet1)],
        deployer
      );
      expect(allowance.result).toBeOk(Cl.uint(1500000));
    });

    it("should revoke allowance successfully", () => {
      // First approve some amount
      simnet.callPublicFn(
        "sip-010-token",
        "approve",
        [Cl.principal(wallet1), Cl.uint(1000000)],
        deployer
      );
      
      // Then revoke
      const response = simnet.callPublicFn(
        "sip-010-token",
        "revoke-allowance",
        [Cl.principal(wallet1)],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check allowance is zero
      const allowance = simnet.callReadOnlyFn(
        "sip-010-token",
        "get-allowance",
        [Cl.principal(deployer), Cl.principal(wallet1)],
        deployer
      );
      expect(allowance.result).toBeOk(Cl.uint(0));
    });
  });
  describe("Transfer From Function", () => {
    beforeEach(() => {
      // Approve wallet1 to spend from deployer
      simnet.callPublicFn(
        "sip-010-token",
        "approve",
        [Cl.principal(wallet1), Cl.uint(5000000)],
        deployer
      );
    });

    it("should transfer from approved account successfully", () => {
      const transferAmount = 2000000;
      
      const response = simnet.callPublicFn(
        "sip-010-token",
        "transfer-from",
        [
          Cl.uint(transferAmount),
          Cl.principal(deployer),
          Cl.principal(wallet2),
          Cl.none()
        ],
        wallet1 // Approved spender
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check balances
      const ownerBalance = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(deployer)], deployer);
      const recipientBalance = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(wallet2)], deployer);
      
      expect(recipientBalance.result).toBeOk(Cl.uint(transferAmount));
      
      // Check remaining allowance
      const allowance = simnet.callReadOnlyFn(
        "sip-010-token",
        "get-allowance",
        [Cl.principal(deployer), Cl.principal(wallet1)],
        deployer
      );
      expect(allowance.result).toBeOk(Cl.uint(3000000)); // 5M - 2M
    });

    it("should reject transfer from with insufficient allowance", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "transfer-from",
        [
          Cl.uint(6000000), // More than approved
          Cl.principal(deployer),
          Cl.principal(wallet2),
          Cl.none()
        ],
        wallet1
      );
      
      expect(response.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });

    it("should reject transfer from without approval", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "transfer-from",
        [
          Cl.uint(1000000),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        wallet2 // Not approved
      );
      
      expect(response.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });
  });
  describe("Batch Transfer Function", () => {
    it("should execute batch transfers successfully", () => {
      const transfers = [
        { recipient: wallet1, amount: 1000000, memo: Cl.none() },
        { recipient: wallet2, amount: 2000000, memo: Cl.none() },
        { recipient: wallet3, amount: 1500000, memo: Cl.none() }
      ];
      
      const transfersList = Cl.list(transfers.map(t => 
        Cl.tuple({
          recipient: Cl.principal(t.recipient),
          amount: Cl.uint(t.amount),
          memo: t.memo
        })
      ));
      
      const response = simnet.callPublicFn(
        "sip-010-token",
        "batch-transfer",
        [transfersList],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check all recipient balances
      const balance1 = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(wallet1)], deployer);
      const balance2 = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(wallet2)], deployer);
      const balance3 = simnet.callReadOnlyFn("sip-010-token", "get-balance", [Cl.principal(wallet3)], deployer);
      
      expect(balance1.result).toBeOk(Cl.uint(1000000));
      expect(balance2.result).toBeOk(Cl.uint(2000000));
      expect(balance3.result).toBeOk(Cl.uint(1500000));
    });

    it("should reject empty batch transfer", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "batch-transfer",
        [Cl.list([])],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(103)); // ERR-INVALID-AMOUNT
    });
  });

  describe("Pause/Unpause Functions", () => {
    it("should pause contract successfully by owner", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "pause-contract",
        [],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check pause status
      const isPaused = simnet.callReadOnlyFn("sip-010-token", "is-paused", [], deployer);
      expect(isPaused.result).toBe(Cl.bool(true));
    });

    it("should unpause contract successfully by owner", () => {
      // First pause
      simnet.callPublicFn("sip-010-token", "pause-contract", [], deployer);
      
      // Then unpause
      const response = simnet.callPublicFn(
        "sip-010-token",
        "unpause-contract",
        [],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check pause status
      const isPaused = simnet.callReadOnlyFn("sip-010-token", "is-paused", [], deployer);
      expect(isPaused.result).toBe(Cl.bool(false));
    });

    it("should reject pause by non-owner", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "pause-contract",
        [],
        wallet1
      );
      
      expect(response.result).toBeErr(Cl.uint(100)); // ERR-OWNER-ONLY
    });
  });