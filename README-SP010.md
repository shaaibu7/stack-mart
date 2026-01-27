# SP-010 Token Contract

A fully compliant SIP-010 fungible token implementation on the Stacks blockchain.

## Features

- ✅ Complete SIP-010 standard compliance
- ✅ Safe arithmetic operations with overflow protection
- ✅ Comprehensive input validation
- ✅ Event emission for transfers and mints
- ✅ Gas-optimized storage operations
- ✅ Initial token distribution to deployer

## Token Details

- **Name**: SP-010
- **Symbol**: SP010
- **Decimals**: 6
- **Initial Supply**: 1,000,000 tokens
- **Total Supply**: 1,000,000,000,000 (with 6 decimals)

## Contract Functions

### Read-Only Functions

- `get-name()` - Returns token name
- `get-symbol()` - Returns token symbol
- `get-decimals()` - Returns decimal places
- `get-token-uri()` - Returns metadata URI
- `get-balance(principal)` - Returns balance for a principal
- `get-total-supply()` - Returns total token supply

### Public Functions

- `transfer(amount, sender, recipient, memo)` - Transfer tokens between principals

## Security Features

- Authorization checks ensure only token owners can transfer
- Input validation prevents invalid operations
- Safe arithmetic prevents overflow/underflow
- Principal validation ensures valid addresses
- Zero-amount and self-transfer protection

## Deployment

Use the provided deployment configuration in `deployments/sp-010-deployment.yaml`.

## Testing

The contract includes comprehensive test coverage with both unit tests and property-based tests validating all correctness properties defined in the specification.