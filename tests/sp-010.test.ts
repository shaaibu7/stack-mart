import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

/**
 * SP-010 Token Contract Test Suite
 * 
 * Comprehensive tests for SIP-010 compliant fungible token
 * covering all functionality and edge cases.
 */
describe("SP-010 Token Contract", () => {
  beforeEach(() => {
    // Contract is automatically deployed with initial supply to deployer
  });

  describe("Metadata Functions", () => {
    it("should return correct token name", () => {
      const response = simnet.callReadOnlyFn("sp-010", "get-name", [], deployer);
      expect(response.result).toBeOk(Cl.stringAscii("SP-010"));
    });

    it("should return correct token symbol", () => {
      const response = simnet.callReadOnlyFn("sp-010", "get-symbol", [], deployer);
      expect(response.result).toBeOk(Cl.stringAscii("SP010"));
    });

    it("should return correct decimals", () => {
      const response = simnet.callReadOnlyFn("sp-010", "get-decimals", [], deployer);
      expect(response.result).toBeOk(Cl.uint(6));
    });

    it("should return token URI", () => {
      const response = simnet.callReadOnlyFn("sp-010", "get-token-uri", [], deployer);
      expect(response.result).toBeOk(Cl.some(Cl.stringAscii("https://example.com/sp010-metadata.json")));
    });
  });

  describe("Balance and Supply", () => {
    it("should return deployer initial balance", () => {
      const response = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(deployer)], deployer);
      expect(response.result).toBeOk(Cl.uint(1000000000000));
    });

    it("should return zero balance for new principal", () => {
      const response = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet1)], deployer);
      expect(response.result).toBeOk(Cl.uint(0));
    });

    it("should return correct total supply", () => {
      const response = simnet.callReadOnlyFn("sp-010", "get-total-supply", [], deployer);
      expect(response.result).toBeOk(Cl.uint(1000000000000));
    });
  });

  describe("Transfer Function", () => {
    it("should transfer tokens successfully", () => {
      const transferAmount = 1000000; // 1 token with 6 decimals
      
      const response = simnet.callPublicFn(
        "sp-010",
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
      const senderBalance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(deployer)], deployer);
      const recipientBalance = simnet.callReadOnlyFn("sp-010", "get-balance", [Cl.principal(wallet1)], deployer);
      
      expect(senderBalance.result).toBeOk(Cl.uint(1000000000000 - transferAmount));
      expect(recipientBalance.result).toBeOk(Cl.uint(transferAmount));
    });

    it("should reject transfer with insufficient balance", () => {
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [
          Cl.uint(2000000000000), // More than total supply
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(1)); // ERR-INSUFFICIENT-BALANCE
    });

    it("should reject zero amount transfer", () => {
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [
          Cl.uint(0),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(4)); // ERR-INVALID-AMOUNT
    });

    it("should reject self-transfer", () => {
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [
          Cl.uint(1000000),
          Cl.principal(deployer),
          Cl.principal(deployer),
          Cl.none()
        ],
        deployer
      );
      
      expect(response.result).toBeErr(Cl.uint(5)); // ERR-SELF-TRANSFER
    });

    it("should reject unauthorized transfer", () => {
      const response = simnet.callPublicFn(
        "sp-010",
        "transfer",
        [
          Cl.uint(1000000),
          Cl.principal(deployer),
          Cl.principal(wallet1),
          Cl.none()
        ],
        wallet2 // Wrong sender
      );
      
      expect(response.result).toBeErr(Cl.uint(3)); // ERR-UNAUTHORIZED
    });
  });
});