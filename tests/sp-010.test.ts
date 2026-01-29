import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

// Import simnet for proper typing
declare const simnet: any;

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;

/**
 * SIP-010 Token Contract Test Suite
 * 
 * Comprehensive tests for SIP-010 compliant fungible token
 * covering all functionality, edge cases, security validations,
 * event emissions, and performance characteristics.
 * 
 * Test Coverage:
 * - Metadata functions (name, symbol, decimals, URI)
 * - Balance and supply queries
 * - Transfer functionality with all validation
 * - Error handling and edge cases
 * - Event emission verification
 * - Gas optimization and performance
 * - Security boundary testing
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
      const transferAmount = ONE_TOKEN;
      
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

    it("should handle multiple sequential transfers", () => {
      // First transfer
      simnet.callPublicFn(
        "sp-010",
        "transfer",
        [Cl.uint(ONE_TOKEN), Cl.principal(deployer), Cl.principal(wallet1), Cl.none()],
        deployer
      );
      
      // Second transfer
      simnet.callPublicFn(
        "sp-010",
        "transfer",
        [Cl.uint(HALF_TOKEN), Cl.principal(deployer), Cl.principal(wallet2), Cl.none()],
        deployer
      );
      
      // Verify final balances
      const deployerBalance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(deployer)], deployer);
      const wallet1Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet1)], deployer);
      const wallet2Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet2)], deployer);
      
      expect(deployerBalance.result).toBeOk(Cl.uint(INITIAL_SUPPLY - ONE_TOKEN - HALF_TOKEN));
      expect(wallet1Balance.result).toBeOk(Cl.uint(ONE_TOKEN));
      expect(wallet2Balance.result).toBeOk(Cl.uint(HALF_TOKEN));
    });

    it("should allow wallet-to-wallet transfers", () => {
      // First, give wallet1 some tokens
      simnet.callPublicFn(
        "sp-010",
        "transfer",
        [Cl.uint(ONE_TOKEN * 2), Cl.principal(deployer), Cl.principal(wallet1), Cl.none()],
        deployer
      );
      
      // Then wallet1 transfers to wallet2
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [Cl.uint(ONE_TOKEN), Cl.principal(wallet1), Cl.principal(wallet2), Cl.none()],
        wallet1
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Verify balances
      const wallet1Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet1)], deployer);
      const wallet2Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet2)], deployer);
      
      expect(wallet1Balance.result).toBeOk(Cl.uint(ONE_TOKEN));
      expect(wallet2Balance.result).toBeOk(Cl.uint(ONE_TOKEN));
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

    it("should reject transfer from empty wallet", () => {
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [
          Cl.uint(ONE_TOKEN),
          Cl.principal(wallet1), // wallet1 has no tokens
          Cl.principal(wallet2),
          Cl.none()
        ],
        wallet1
      );
      
      expect(response.result).toBeErr(Cl.uint(1)); // ERR-INSUFFICIENT-BALANCE
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
          Cl.uint(ONE_TOKEN),
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
  describe("Blacklist Functions", () => {
    it("should blacklist address successfully by owner", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "blacklist-address",
        [Cl.principal(wallet1)],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check blacklist status
      const isBlacklisted = simnet.callReadOnlyFn(
        "sip-010-token",
        "is-blacklisted",
        [Cl.principal(wallet1)],
        deployer
      );
      expect(isBlacklisted.result).toBe(Cl.bool(true));
    });

    it("should unblacklist address successfully by owner", () => {
      // First blacklist
      simnet.callPublicFn(
        "sip-010-token",
        "blacklist-address",
        [Cl.principal(wallet1)],
        deployer
      );
      
      // Then unblacklist
      const response = simnet.callPublicFn(
        "sip-010-token",
        "unblacklist-address",
        [Cl.principal(wallet1)],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check blacklist status
      const isBlacklisted = simnet.callReadOnlyFn(
        "sip-010-token",
        "is-blacklisted",
        [Cl.principal(wallet1)],
        deployer
      );
      expect(isBlacklisted.result).toBe(Cl.bool(false));
    });

    it("should reject blacklist by non-owner", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "blacklist-address",
        [Cl.principal(wallet2)],
        wallet1
      );
      
      expect(response.result).toBeErr(Cl.uint(100)); // ERR-OWNER-ONLY
    });
  });

  describe("Fee Management Functions", () => {
    it("should set transfer fee rate successfully by owner", () => {
      const newRate = 250; // 2.5%
      
      const response = simnet.callPublicFn(
        "sip-010-token",
        "set-transfer-fee-rate",
        [Cl.uint(newRate)],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check fee rate
      const feeRate = simnet.callReadOnlyFn("sip-010-token", "get-transfer-fee-rate", [], deployer);
      expect(feeRate.result).toBe(Cl.uint(newRate));
    });

    it("should reject excessive fee rate", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "set-transfer-fee-rate",
        [Cl.uint(1500)], // 15% - too high
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(103)); // ERR-INVALID-AMOUNT
    });

    it("should set fee recipient successfully by owner", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "set-fee-recipient",
        [Cl.principal(wallet1)],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
    });

    it("should calculate fee correctly", () => {
      const amount = 1000000; // 1 token
      const feeRate = 100; // 1%
      
      // Set fee rate first
      simnet.callPublicFn(
        "sip-010-token",
        "set-transfer-fee-rate",
        [Cl.uint(feeRate)],
        deployer
      );
      
      const calculatedFee = simnet.callReadOnlyFn(
        "sip-010-token",
        "calculate-fee",
        [Cl.uint(amount)],
        deployer
      );
      
      expect(calculatedFee.result).toBe(Cl.uint(10000)); // 1% of 1M = 10K
    });
  });
  describe("Staking Functions", () => {
    beforeEach(() => {
      // Transfer some tokens to wallet1 for staking tests
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

    it("should stake tokens successfully", () => {
      const stakeAmount = 5000000;
      
      const response = simnet.callPublicFn(
        "sip-010-token",
        "stake-tokens",
        [Cl.uint(stakeAmount)],
        wallet1
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check staked balance
      const stakedBalance = simnet.callReadOnlyFn(
        "sip-010-token",
        "get-staked-balance",
        [Cl.principal(wallet1)],
        deployer
      );
      expect(stakedBalance.result).toBe(Cl.uint(stakeAmount));
    });

    it("should unstake tokens successfully", () => {
      const stakeAmount = 5000000;
      const unstakeAmount = 2000000;
      
      // First stake
      simnet.callPublicFn(
        "sip-010-token",
        "stake-tokens",
        [Cl.uint(stakeAmount)],
        wallet1
      );
      
      // Then unstake
      const response = simnet.callPublicFn(
        "sip-010-token",
        "unstake-tokens",
        [Cl.uint(unstakeAmount)],
        wallet1
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check remaining staked balance
      const stakedBalance = simnet.callReadOnlyFn(
        "sip-010-token",
        "get-staked-balance",
        [Cl.principal(wallet1)],
        deployer
      );
      expect(stakedBalance.result).toBe(Cl.uint(stakeAmount - unstakeAmount));
    });

    it("should reject staking with insufficient balance", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "stake-tokens",
        [Cl.uint(20000000)], // More than wallet1 has
        wallet1
      );
      
      expect(response.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });

    it("should reject unstaking more than staked", () => {
      // Stake some amount first
      simnet.callPublicFn(
        "sip-010-token",
        "stake-tokens",
        [Cl.uint(3000000)],
        wallet1
      );
      
      // Try to unstake more
      const response = simnet.callPublicFn(
        "sip-010-token",
        "unstake-tokens",
        [Cl.uint(5000000)],
        wallet1
      );
      
      expect(response.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });
  });
  describe("Governance Functions", () => {
    beforeEach(() => {
      // Mint enough tokens to deployer for proposal threshold
      simnet.callPublicFn(
        "sip-010-token",
        "mint",
        [Cl.uint(2000000000), Cl.principal(deployer)],
        deployer
      );
      
      // Transfer some tokens to wallet1 for voting
      simnet.callPublicFn(
        "sip-010-token",
        "transfer",
        [
          Cl.uint(5000000),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
    });

    it("should create proposal successfully", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "create-proposal",
        [
          Cl.stringAscii("Test Proposal"),
          Cl.stringAscii("This is a test proposal for governance"),
          Cl.uint(100) // 100 blocks voting period
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.uint(1)); // First proposal ID
      
      // Check proposal details
      const proposal = simnet.callReadOnlyFn(
        "sip-010-token",
        "get-proposal",
        [Cl.uint(1)],
        deployer
      );
      
      expect(proposal.result).toBeSome();
    });

    it("should reject proposal creation with insufficient balance", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "create-proposal",
        [
          Cl.stringAscii("Test Proposal"),
          Cl.stringAscii("This should fail"),
          Cl.uint(100)
        ],
        wallet2 // Doesn't have enough tokens
      );
      
      expect(response.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });

    it("should vote on proposal successfully", () => {
      // Create proposal first
      simnet.callPublicFn(
        "sip-010-token",
        "create-proposal",
        [
          Cl.stringAscii("Test Proposal"),
          Cl.stringAscii("Test proposal description"),
          Cl.uint(100)
        ],
        deployer
      );
      
      // Vote on proposal
      const response = simnet.callPublicFn(
        "sip-010-token",
        "vote-on-proposal",
        [
          Cl.uint(1), // Proposal ID
          Cl.bool(true) // Vote for
        ],
        wallet1
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
    });

    it("should reject double voting", () => {
      // Create proposal
      simnet.callPublicFn(
        "sip-010-token",
        "create-proposal",
        [
          Cl.stringAscii("Test Proposal"),
          Cl.stringAscii("Test proposal description"),
          Cl.uint(100)
        ],
        deployer
      );
      
      // First vote
      simnet.callPublicFn(
        "sip-010-token",
        "vote-on-proposal",
        [Cl.uint(1), Cl.bool(true)],
        wallet1
      );
      
      // Second vote should fail
      const response = simnet.callPublicFn(
        "sip-010-token",
        "vote-on-proposal",
        [Cl.uint(1), Cl.bool(false)],
        wallet1
      );
      
      expect(response.result).toBeErr(Cl.uint(105)); // Already voted
    });
  });
  describe("Emergency Functions", () => {
    it("should enable emergency mode successfully by owner", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "enable-emergency-mode",
        [],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
    });

    it("should disable emergency mode successfully by owner", () => {
      // First enable
      simnet.callPublicFn("sip-010-token", "enable-emergency-mode", [], deployer);
      
      // Then disable
      const response = simnet.callPublicFn(
        "sip-010-token",
        "disable-emergency-mode",
        [],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
    });

    it("should reject emergency mode toggle by non-owner", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "enable-emergency-mode",
        [],
        wallet1
      );
      
      expect(response.result).toBeErr(Cl.uint(100)); // ERR-OWNER-ONLY
    });

    it("should perform emergency withdraw in emergency mode", () => {
      // Enable emergency mode
      simnet.callPublicFn("sip-010-token", "enable-emergency-mode", [], deployer);
      
      // Perform emergency withdraw
      const withdrawAmount = 1000000;
      const response = simnet.callPublicFn(
        "sip-010-token",
        "emergency-withdraw",
        [
          Cl.uint(withdrawAmount),
          Cl.principal(wallet1)
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
    });

    it("should reject emergency withdraw when not in emergency mode", () => {
      const response = simnet.callPublicFn(
        "sip-010-token",
        "emergency-withdraw",
        [
          Cl.uint(1000000),
          Cl.principal(wallet1)
        ],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(200)); // ERR-EMERGENCY-ONLY
    });
  });

  describe("Edge Cases and Error Handling", () => {
    it("should handle maximum uint values correctly", () => {
      const maxUint = "340282366920938463463374607431768211455"; // 2^128 - 1
      
      const response = simnet.callPublicFn(
        "sip-010-token",
        "transfer",
        [
          Cl.uint(maxUint),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });

    it("should handle zero balance operations correctly", () => {
      // Try to transfer from account with zero balance
      const response = simnet.callPublicFn(
        "sip-010-token",
        "transfer",
        [
          Cl.uint(1),
          Cl.principal(wallet3),
          Cl.principal(wallet1),
          Cl.none()
        ],
        wallet3
      );
      
      expect(response.result).toBeErr(Cl.uint(102)); // ERR-INSUFFICIENT-BALANCE
    });

    it("should maintain total supply invariant after operations", () => {
      const initialSupply = simnet.callReadOnlyFn("sip-010-token", "get-total-supply", [], deployer);
      
      // Perform various operations
      simnet.callPublicFn(
        "sip-010-token",
        "transfer",
        [Cl.uint(1000000), Cl.principal(deployer), Cl.principal(wallet1), Cl.none()],
        deployer
      );
      
      simnet.callPublicFn(
        "sip-010-token",
        "mint",
        [Cl.uint(500000), Cl.principal(wallet2)],
        deployer
      );
      
      simnet.callPublicFn(
        "sip-010-token",
        "burn",
        [Cl.uint(250000), Cl.principal(wallet2)],
        wallet2
      );
      
      // Check final supply
      const finalSupply = simnet.callReadOnlyFn("sip-010-token", "get-total-supply", [], deployer);
      const expectedSupply = 1000000000000000 + 500000 - 250000; // initial + mint - burn
      
      expect(finalSupply.result).toBeOk(Cl.uint(expectedSupply));
    });

    it("should handle memo parameter correctly", () => {
      const memo = Cl.bufferFromAscii("test transfer");
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [
          Cl.uint(ONE_TOKEN),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.some(memo)
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
    });
  });

  describe("Edge Cases and Boundary Testing", () => {
    it("should handle maximum possible transfer amount", () => {
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [
          Cl.uint(INITIAL_SUPPLY), // Transfer entire supply
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Verify deployer has zero balance
      const deployerBalance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(deployer)], deployer);
      expect(deployerBalance.result).toBeOk(Cl.uint(0));
      
      // Verify wallet1 has entire supply
      const wallet1Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet1)], deployer);
      expect(wallet1Balance.result).toBeOk(Cl.uint(INITIAL_SUPPLY));
    });

    it("should handle minimum transfer amount (1 micro-token)", () => {
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [
          Cl.uint(1), // Smallest possible amount
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      const wallet1Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet1)], deployer);
      expect(wallet1Balance.result).toBeOk(Cl.uint(1));
    });

    it("should maintain total supply invariant after transfers", () => {
      // Perform multiple transfers
      simnet.callPublicFn("sp-010", "transfer", [Cl.uint(ONE_TOKEN), Cl.principal(deployer), Cl.principal(wallet1), Cl.none()], deployer);
      simnet.callPublicFn("sp-010", "transfer", [Cl.uint(HALF_TOKEN), Cl.principal(deployer), Cl.principal(wallet2), Cl.none()], deployer);
      simnet.callPublicFn("sp-010", "transfer", [Cl.uint(ONE_TOKEN), Cl.principal(deployer), Cl.principal(wallet3), Cl.none()], deployer);
      
      // Check total supply remains unchanged
      const totalSupply = simnet.callReadOnlyFn("sp-010", "get-total-supply", [], deployer);
      expect(totalSupply.result).toBeOk(Cl.uint(INITIAL_SUPPLY));
      
      // Verify sum of all balances equals total supply
      const deployerBalance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(deployer)], deployer);
      const wallet1Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet1)], deployer);
      const wallet2Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet2)], deployer);
      const wallet3Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet3)], deployer);
      
      const totalBalances = 
        Number(deployerBalance.result.value.value) +
        Number(wallet1Balance.result.value.value) +
        Number(wallet2Balance.result.value.value) +
        Number(wallet3Balance.result.value.value);
      
      expect(totalBalances).toBe(INITIAL_SUPPLY);
    });
  });

  describe("Event Emission Testing", () => {
    it("should emit transfer events", () => {
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [
          Cl.uint(ONE_TOKEN),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeOk(Cl.bool(true));
      
      // Check that events were emitted (simnet captures print events)
      expect(response.events).toBeDefined();
      expect(response.events.length).toBeGreaterThan(0);
    });

    it("should emit events for multiple transfers", () => {
      const response1 = simnet.callPublicFn("sp-010", "transfer", [Cl.uint(ONE_TOKEN), Cl.principal(deployer), Cl.principal(wallet1), Cl.none()], deployer);
      const response2 = simnet.callPublicFn("sp-010", "transfer", [Cl.uint(HALF_TOKEN), Cl.principal(deployer), Cl.principal(wallet2), Cl.none()], deployer);
      
      expect(response1.events).toBeDefined();
      expect(response2.events).toBeDefined();
      expect(response1.events.length).toBeGreaterThan(0);
      expect(response2.events.length).toBeGreaterThan(0);
    });
  });

  describe("Gas Optimization and Performance", () => {
    it("should handle batch transfers efficiently", () => {
      const transfers = [
        { amount: ONE_TOKEN, recipient: wallet1 },
        { amount: HALF_TOKEN, recipient: wallet2 },
        { amount: ONE_TOKEN * 2, recipient: wallet3 }
      ];
      
      transfers.forEach(({ amount, recipient }) => {
        const response = simnet.callPublicFn(
          "sp-010",
          "transfer",
          [Cl.uint(amount), Cl.principal(deployer), Cl.principal(recipient), Cl.none()],
          deployer
        );
        expect(response.result).toBeOk(Cl.bool(true));
      });
      
      // Verify all transfers completed successfully
      const wallet1Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet1)], deployer);
      const wallet2Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet2)], deployer);
      const wallet3Balance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet3)], deployer);
      
      expect(wallet1Balance.result).toBeOk(Cl.uint(ONE_TOKEN));
      expect(wallet2Balance.result).toBeOk(Cl.uint(HALF_TOKEN));
      expect(wallet3Balance.result).toBeOk(Cl.uint(ONE_TOKEN * 2));
    });
  });
});