import { describe, it, expect, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

const contractName = "sip-090-nft";

describe("SIP-090 NFT Event Emission Tests", () => {
  beforeEach(() => {
    simnet.setEpoch("3.0");
  });

  describe("Mint Events", () => {
    it("should emit proper mint events", () => {
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.some(Cl.stringAscii("https://example.com/1"))],
        deployer
      );

      expect(mintResult.result).toBeOk(Cl.uint(1));

      // Check that events were emitted (events are in the transaction receipt)
      expect(mintResult.events).toHaveLength(1);
      
      const printEvent = mintResult.events[0];
      expect(printEvent.event).toBe("print_event");
      
      // The print event should contain mint information
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("nft_mint_event"),
        "token-id": Cl.uint(1),
        recipient: Cl.principal(wallet1),
        "metadata-uri": Cl.some(Cl.stringAscii("https://example.com/1"))
      });
    });

    it("should emit mint events without metadata URI", () => {
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      expect(mintResult.result).toBeOk(Cl.uint(1));
      expect(mintResult.events).toHaveLength(1);
      
      const printEvent = mintResult.events[0];
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("nft_mint_event"),
        "token-id": Cl.uint(1),
        recipient: Cl.principal(wallet1),
        "metadata-uri": Cl.none()
      });
    });

    it("should emit events for optimized mint", () => {
      const mintResult = simnet.callPublicFn(
        contractName,
        "mint-optimized",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      expect(mintResult.result).toBeOk(Cl.uint(1));
      expect(mintResult.events).toHaveLength(1);
      
      const printEvent = mintResult.events[0];
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("mint"),
        "token-id": Cl.uint(1),
        recipient: Cl.principal(wallet1)
      });
    });
  });

  describe("Transfer Events", () => {
    beforeEach(() => {
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );
    });

    it("should emit proper transfer events", () => {
      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );

      expect(transferResult.result).toBeOk(Cl.bool(true));
      expect(transferResult.events).toHaveLength(1);
      
      const printEvent = transferResult.events[0];
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("nft_transfer_event"),
        "token-id": Cl.uint(1),
        sender: Cl.principal(wallet1),
        recipient: Cl.principal(wallet2)
      });
    });

    it("should emit enhanced transfer events", () => {
      const transferResult = simnet.callPublicFn(
        contractName,
        "transfer-enhanced",
        [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)],
        wallet1
      );

      expect(transferResult.result).toBeOk(Cl.bool(true));
      expect(transferResult.events).toHaveLength(1);
      
      const printEvent = transferResult.events[0];
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("nft_transfer_event"),
        "token-id": Cl.uint(1),
        sender: Cl.principal(wallet1),
        recipient: Cl.principal(wallet2)
      });
    });
  });

  describe("Administrative Events", () => {
    it("should emit pause events", () => {
      const pauseResult = simnet.callPublicFn(
        contractName,
        "pause-contract",
        [],
        deployer
      );

      expect(pauseResult.result).toBeOk(Cl.bool(true));
      expect(pauseResult.events).toHaveLength(1);
      
      const printEvent = pauseResult.events[0];
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("contract_paused"),
        "paused-by": Cl.principal(deployer)
      });
    });

    it("should emit unpause events", () => {
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
      expect(unpauseResult.events).toHaveLength(1);
      
      const printEvent = unpauseResult.events[0];
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("contract_unpaused"),
        "unpaused-by": Cl.principal(deployer)
      });
    });

    it("should emit base URI update events", () => {
      const newUri = "https://new.api.com/nft/";
      
      const setUriResult = simnet.callPublicFn(
        contractName,
        "set-base-uri",
        [Cl.stringAscii(newUri)],
        deployer
      );

      expect(setUriResult.result).toBeOk(Cl.bool(true));
      expect(setUriResult.events).toHaveLength(1);
      
      const printEvent = setUriResult.events[0];
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("base_uri_updated"),
        "new-uri": Cl.stringAscii(newUri)
      });
    });

    it("should emit token URI update events", () => {
      // First mint a token
      simnet.callPublicFn(
        contractName,
        "mint",
        [Cl.principal(wallet1), Cl.none()],
        deployer
      );

      const customUri = "https://custom.token.uri/1";
      
      const setTokenUriResult = simnet.callPublicFn(
        contractName,
        "set-token-uri",
        [Cl.uint(1), Cl.stringAscii(customUri)],
        deployer
      );

      expect(setTokenUriResult.result).toBeOk(Cl.bool(true));
      expect(setTokenUriResult.events).toHaveLength(1);
      
      const printEvent = setTokenUriResult.events[0];
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("token_uri_updated"),
        "token-id": Cl.uint(1),
        "new-uri": Cl.stringAscii(customUri)
      });
    });
  });

  describe("Emergency Events", () => {
    it("should emit emergency mode events", () => {
      const emergencyResult = simnet.callPublicFn(
        contractName,
        "enable-emergency-mode",
        [],
        deployer
      );

      expect(emergencyResult.result).toBeOk(Cl.bool(true));
      expect(emergencyResult.events).toHaveLength(2); // Emergency event + pause event
      
      // Check for admin event
      const adminEvent = emergencyResult.events.find(e => 
        e.data && e.data.type && e.data.type.data === "admin_event"
      );
      expect(adminEvent).toBeDefined();
    });

    it("should emit emergency disable events", () => {
      // First enable emergency mode
      simnet.callPublicFn(contractName, "enable-emergency-mode", [], deployer);

      const disableResult = simnet.callPublicFn(
        contractName,
        "disable-emergency-mode",
        [],
        deployer
      );

      expect(disableResult.result).toBeOk(Cl.bool(true));
      expect(disableResult.events).toHaveLength(1);
      
      const printEvent = disableResult.events[0];
      const eventData = printEvent.data;
      expect(eventData).toMatchObject({
        type: Cl.stringAscii("admin_event"),
        action: Cl.stringAscii("emergency_disabled"),
        admin: Cl.principal(deployer)
      });
    });
  });

  describe("Batch Operation Events", () => {
    it("should emit events for batch minting", () => {
      const recipients = [wallet1, wallet2];
      const metadataUris = [Cl.none(), Cl.none()];

      const batchMintResult = simnet.callPublicFn(
        contractName,
        "batch-mint",
        [
          Cl.list(recipients.map(w => Cl.principal(w))),
          Cl.list(metadataUris)
        ],
        deployer
      );

      expect(batchMintResult.result).toBeOk(Cl.list([Cl.uint(1), Cl.uint(2)]));
      
      // Should have 2 mint events (one for each token)
      expect(batchMintResult.events).toHaveLength(2);
      
      // Check first mint event
      const firstEvent = batchMintResult.events[0];
      expect(firstEvent.data).toMatchObject({
        type: Cl.stringAscii("nft_mint_event"),
        "token-id": Cl.uint(1),
        recipient: Cl.principal(wallet1)
      });

      // Check second mint event
      const secondEvent = batchMintResult.events[1];
      expect(secondEvent.data).toMatchObject({
        type: Cl.stringAscii("nft_mint_event"),
        "token-id": Cl.uint(2),
        recipient: Cl.principal(wallet2)
      });
    });
  });
});