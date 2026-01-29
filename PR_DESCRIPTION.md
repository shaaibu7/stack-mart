# Refactor StackMart: Auctions, Bundles, and Secure Escrow

## Description
This PR implements major feature enhancements and critical security fixes for the StackMart smart contract. It expands the marketplace capabilities to support English auctions and bundle purchases while significantly hardening the escrow and dispute resolution mechanisms.

## Key Changes

### 🔨 New Features
- **Auction System**: Implemented a complete on-chain auction lifecycle:
    - `create-auction`: custodies the NFT and initializes auction parameters.
    - `place-bid`: handles outbid logic by automatically refunding the previous bidder.
    - `end-auction`: securely transfers the NFT to the winner and funds to the seller (or returns NFT if reserve not met).
- **Bundle Purchases**: Added `buy-bundle` functionality that creates individual escrows for multiple listings in a single transaction, supporting batch discounts.

### 🛡️ Security & Fixes
- **Escrow Hardening**: Refactored `buy-listing-escrow`, `confirm-receipt`, `release-escrow`, and `resolve-dispute` to use `as-contract stx-transfer?`. This fixes a critical issue where the contract could not previously release held funds.
- **Unified Reputation**: Merged separate buyer/seller reputation maps into a single, robust `reputation` map tracking total volume and success rates.
- **Syntax Fixes**: Resolved map definition errors and duplicate admin variable declarations.

### 🧪 Testing
- Added `tests/stack-mart-v2.spec.ts` with comprehensive coverage:
    - valid auction with successful bid and end.
    - bundle purchase creating correct escrows.
    - mock NFT integration for testing transfers.
- Verified all tests pass with `npm test`.

## Checklist
- [x] Smart Contract compilation checks passed.
- [x] New unit tests added and passing.
- [x] Granular commit history generated.
