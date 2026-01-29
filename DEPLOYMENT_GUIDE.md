# StackMart Deployment Guide

## Prerequisites

Before deploying, you need to:

1. **Install Dependencies**:
   ```bash
   npm install
   ```

2. **Create `.env` File**:
   Create a `.env` file in the project root with the following:
   ```env
   PRIVATE_KEY=your_hex_private_key_here
   STACKS_NETWORK=testnet  # or mainnet
   STACKS_API_URL=https://api.testnet.hiro.so  # or https://api.hiro.so for mainnet
   FEE=150000
   ```

## Current Issues

⚠️ The contract currently has compilation errors that need to be fixed before deployment:

1. **Clarity Version Compatibility**: The contract uses `as-contract` which was deprecated in Clarity 3+
2. **Trait References**: The SIP-009 NFT trait needs to be properly imported or the functions need to be restructured
3. **Syntax Errors**: There are unclosed parentheses that need to be resolved

## Recommended Next Steps

### Option 1: Simplify for Deployment (Recommended)
Remove the auction functionality temporarily and deploy the core marketplace:
- Keep: listings, escrow, bundles, reputation
- Remove: auctions (which require trait parameters)

### Option 2: Fix Clarity 4 Compatibility
Update the contract to be Clarity 4 compatible by:
- Replacing `as-contract` with proper authorization patterns
- Using `use-trait` to import the SIP-009 NFT trait
- Fixing parenthesis mismatches

### Option 3: Use Clarity 2
Change the `epoch` in `Clarinet.toml` to use Clarity 2:
```toml
[contracts.stack-mart]
path = "contracts/stack-mart.clar"
epoch = "2.5"
```

## Once Fixed

Run the deployment script:
```bash
node deploy.js
```

This will deploy the contract to the network specified in your `.env` file.
