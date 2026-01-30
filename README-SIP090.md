# SIP-090 NFT Contract

A fully compliant SIP-090 Non-Fungible Token implementation for the Stacks blockchain, designed for the StackMart ecosystem.

## Features

- ✅ **SIP-090 Compliance**: Full compatibility with the Stacks NFT standard
- 🚀 **Batch Operations**: Efficient batch minting for large collections
- ⏸️ **Pause/Unpause**: Emergency controls for contract management
- 📊 **Event Logging**: Comprehensive event emission for analytics
- ⛽ **Gas Optimized**: Efficient storage patterns and operations
- 🔐 **Access Control**: Proper authorization and ownership management
- 🌐 **Flexible Metadata**: Support for both individual and base URI patterns

## Contract Information

- **Name**: StackMart NFT
- **Symbol**: SMNFT
- **Max Supply**: 10,000 NFTs
- **Base URI**: https://api.stackmart.io/nft/
- **Standard**: SIP-090

## Core Functions

### Read-Only Functions

#### `get-last-token-id()`
Returns the highest token ID that has been minted.

```clarity
(get-last-token-id)
;; Returns: (ok u42) if 42 tokens have been minted
```

#### `get-total-supply()`
Returns the current total number of minted NFTs.

```clarity
(get-total-supply)
;; Returns: (ok u100) if 100 NFTs exist
```

#### `get-token-uri(token-id)`
Returns the metadata URI for a specific token.

```clarity
(get-token-uri u1)
;; Returns: (ok (some "https://api.stackmart.io/nft/1"))
```

#### `get-owner(token-id)`
Returns the owner of a specific token.

```clarity
(get-owner u1)
;; Returns: (ok (some 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM))
```

### Public Functions

#### `mint(recipient, metadata-uri)`
Mints a new NFT to the specified recipient (owner only).

```clarity
(mint 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 (some "custom-uri"))
;; Returns: (ok u1) with the new token ID
```

#### `transfer(token-id, sender, recipient)`
Transfers an NFT from sender to recipient (SIP-090 standard).

```clarity
(transfer u1 'ST1SENDER... 'ST1RECIPIENT...)
;; Returns: (ok true) on success
```

#### `batch-mint(recipients, metadata-uris)`
Mints multiple NFTs in a single transaction (owner only).

```clarity
(batch-mint 
  (list 'ST1ADDR1... 'ST1ADDR2...)
  (list (some "uri1") (some "uri2")))
```

### Administrative Functions

#### `pause-contract()` / `unpause-contract()`
Emergency pause controls (owner only).

```clarity
(pause-contract)   ;; Pauses all operations
(unpause-contract) ;; Resumes operations
```

#### `set-base-uri(new-uri)`
Updates the base URI for metadata (owner only).

```clarity
(set-base-uri "https://new-api.stackmart.io/nft/")
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 400 | ERR-INVALID-PARAMETERS | Invalid function parameters |
| 401 | ERR-NOT-AUTHORIZED | Unauthorized access attempt |
| 403 | ERR-INVALID-OWNER | Invalid ownership claim |
| 404 | ERR-NOT-FOUND | Token or resource not found |
| 409 | ERR-ALREADY-EXISTS | Token already exists |
| 422 | ERR-INVALID-RECIPIENT | Invalid recipient address |
| 429 | ERR-MAX-SUPPLY-REACHED | Maximum supply limit reached |
| 503 | ERR-CONTRACT-PAUSED | Contract is paused |

## Events

The contract emits comprehensive events for all major operations:

### Mint Event
```json
{
  "type": "nft_mint_event",
  "token-contract": "ST1...contract-address",
  "token-id": 1,
  "recipient": "ST1...recipient-address",
  "metadata-uri": "optional-uri",
  "block-height": 12345,
  "total-supply": 1
}
```

### Transfer Event
```json
{
  "type": "nft_transfer_event",
  "token-contract": "ST1...contract-address", 
  "token-id": 1,
  "sender": "ST1...sender-address",
  "recipient": "ST1...recipient-address",
  "block-height": 12346
}
```

## Deployment

### Prerequisites
- Node.js 16+
- Stacks CLI
- Private key for deployment

### Deploy to Testnet
```bash
export PRIVATE_KEY="your-private-key"
export NETWORK="testnet"
node scripts/deploy-sip-090.js
```

### Deploy to Mainnet
```bash
export PRIVATE_KEY="your-private-key"
export NETWORK="mainnet"
node scripts/deploy-sip-090.js
```

## Usage Examples

### Minting NFTs
```javascript
import { makeContractCall } from '@stacks/transactions';

const mintTx = await makeContractCall({
  contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
  contractName: 'sip-090-nft',
  functionName: 'mint',
  functionArgs: [
    principalCV('ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5'),
    someCV(stringAsciiCV('https://metadata.example.com/1'))
  ],
  senderKey: privateKey,
  network
});
```

### Transferring NFTs
```javascript
const transferTx = await makeContractCall({
  contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
  contractName: 'sip-090-nft',
  functionName: 'transfer',
  functionArgs: [
    uintCV(1),
    principalCV('ST1SENDER...'),
    principalCV('ST1RECIPIENT...')
  ],
  senderKey: privateKey,
  network
});
```

## Security Considerations

- **Access Control**: Only contract owner can mint and perform administrative functions
- **Pause Mechanism**: Emergency pause functionality for security incidents
- **Input Validation**: Comprehensive parameter validation on all functions
- **Reentrancy Protection**: Safe state updates and external call patterns
- **Supply Limits**: Hard cap on maximum supply to prevent inflation

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

For questions and support, please open an issue on GitHub or contact the StackMart development team.