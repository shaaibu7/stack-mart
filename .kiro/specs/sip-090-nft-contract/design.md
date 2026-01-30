# SIP-090 NFT Contract Design

## Overview

This design document outlines the implementation of a SIP-090 compliant Non-Fungible Token contract for the StackMart ecosystem. The contract will provide a secure, efficient, and standards-compliant NFT implementation with administrative controls and comprehensive metadata support.

## Architecture

The contract follows a modular architecture with clear separation of concerns:

- **Core NFT Logic**: Standard SIP-090 interface implementation
- **Administrative Layer**: Owner-only functions for contract management
- **Security Layer**: Input validation and access control
- **Event System**: Comprehensive logging for all operations
- **Metadata Management**: Flexible URI handling for NFT metadata

## Components and Interfaces

### Core Components

1. **NFT Storage Maps**
   - `token-owners`: Maps token ID to owner principal
   - `token-uris`: Maps token ID to metadata URI
   - `owner-tokens`: Maps owner to list of owned token IDs

2. **Contract State Variables**
   - `total-supply`: Current number of minted NFTs
   - `next-token-id`: Counter for generating unique token IDs
   - `contract-owner`: Principal with administrative privileges
   - `base-uri`: Base URI for metadata
   - `contract-paused`: Pause state for emergency stops

3. **SIP-090 Interface Functions**
   - `get-last-token-id()`: Returns the highest minted token ID
   - `get-token-uri(token-id)`: Returns metadata URI for token
   - `get-owner(token-id)`: Returns owner of specific token
   - `transfer(token-id, sender, recipient)`: Transfers NFT ownership

### Administrative Interface

1. **Minting Functions**
   - `mint(recipient, metadata-uri)`: Creates new NFT
   - `batch-mint(recipients, metadata-uris)`: Creates multiple NFTs

2. **Contract Management**
   - `set-base-uri(new-uri)`: Updates base metadata URI
   - `pause-contract()`: Pauses all operations
   - `unpause-contract()`: Resumes operations
   - `transfer-ownership(new-owner)`: Changes contract owner

## Data Models

### Token Structure
```clarity
{
  token-id: uint,
  owner: principal,
  metadata-uri: (string-ascii 256)
}
```

### Contract Configuration
```clarity
{
  name: "StackMart NFT",
  symbol: "SMNFT", 
  base-uri: "https://api.stackmart.io/nft/",
  max-supply: u10000,
  paused: false
}
```

## Error Handling

The contract implements comprehensive error handling with specific error codes:

- `ERR-NOT-AUTHORIZED (u401)`: Unauthorized access attempt
- `ERR-NOT-FOUND (u404)`: Token does not exist
- `ERR-INVALID-OWNER (u403)`: Invalid ownership claim
- `ERR-CONTRACT-PAUSED (u503)`: Operations blocked due to pause
- `ERR-INVALID-PARAMETERS (u400)`: Invalid function parameters
- `ERR-MAX-SUPPLY-REACHED (u429)`: Cannot mint beyond maximum supply

## Testing Strategy

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Unique Token ID Generation
*For any* successful mint operation, the generated token ID should be unique and never previously used
**Validates: Requirements 1.1**

### Property 2: Ownership Assignment on Mint
*For any* valid minting operation with a specified recipient, that recipient should become the owner of the newly minted token
**Validates: Requirements 1.2**

### Property 3: Supply Increment on Mint
*For any* successful mint operation, the total supply should increase by exactly one
**Validates: Requirements 1.3**

### Property 4: Transfer Ownership Update
*For any* valid transfer from owner to recipient, the recipient should become the new owner and the previous owner should no longer own the token
**Validates: Requirements 2.1**

### Property 5: Transfer Authorization
*For any* transfer attempt by a non-owner, the operation should be rejected with appropriate error
**Validates: Requirements 2.2**

### Property 6: Owner Query Accuracy
*For any* existing token, querying its owner should return the principal who currently owns it
**Validates: Requirements 3.1**

### Property 7: Metadata URI Consistency
*For any* token with assigned metadata URI, querying should return the correct URI
**Validates: Requirements 3.2**

### Property 8: Supply Tracking Accuracy
*For any* point in time, the total supply should equal the number of successfully minted tokens
**Validates: Requirements 3.3**

### Property 9: Administrative Access Control
*For any* administrative function call by a non-owner, the operation should be rejected
**Validates: Requirements 4.2**

### Property 10: Pause State Enforcement
*For any* state-changing operation when contract is paused, the operation should be blocked
**Validates: Requirements 4.3**

### Property 11: Base URI Update Effect
*For any* base URI update by the owner, subsequent metadata queries should reflect the new base URI
**Validates: Requirements 4.1**

### Property 12: Supply Limit Enforcement
*For any* mint attempt when at maximum supply, the operation should be rejected
**Validates: Requirements 4.5**

### Dual Testing Approach

**Unit Testing**: 
- Specific examples of minting, transferring, and querying operations
- Edge cases like minting to contract addresses, transferring non-existent tokens
- Error condition testing for invalid parameters
- Integration testing between different contract functions

**Property-Based Testing**:
- Using Clarinet's property testing framework with minimum 100 iterations per property
- Each property test tagged with format: **Feature: sip-090-nft-contract, Property {number}: {property_text}**
- Random generation of valid principals, token IDs, and metadata URIs
- Comprehensive input space coverage for all contract functions

## Implementation Notes

### Gas Optimization
- Use efficient map structures for token storage
- Batch operations where possible to reduce transaction costs
- Optimize storage patterns to minimize read/write operations

### Security Considerations
- Input validation for all public functions
- Reentrancy protection for transfer operations
- Safe arithmetic operations to prevent overflow/underflow
- Access control enforcement for administrative functions

### Metadata Standards
- Support for standard NFT metadata JSON schema
- Flexible URI patterns supporting both individual and base URI approaches
- IPFS compatibility for decentralized metadata storage