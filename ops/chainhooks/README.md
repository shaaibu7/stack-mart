# Hiro Chainhooks Configuration

This directory contains chainhook configurations for monitoring StackMart contract events on Stacks blockchain.

## Files

- `stack-mart-mainnet.yaml` - Configuration for mainnet
- `stack-mart-testnet.yaml` - Configuration for testnet
- `setup.sh` - Interactive setup script

## Quick Start

### 1. Install Chainhook CLI

```bash
cargo install --git https://github.com/hirosystems/chainhook.git chainhook-cli
```

### 2. Run Setup Script

```bash
cd ops/chainhooks
./setup.sh
```

The script will:
- Check if chainhook CLI is installed
- Let you choose network (mainnet/testnet)
- Help configure webhook URL
- Generate shared secret
- Register the chainhook

### 3. Manual Setup

If you prefer to set up manually:

1. **Update webhook URL** in the YAML file:
   ```yaml
   delivery:
     url: https://your-server.com/api/chainhooks/stack-mart
   ```

2. **Set shared secret** (optional but recommended):
   ```yaml
   delivery:
     secret: "your-generated-secret-here"
   ```
   
   Generate a secret:
   ```bash
   openssl rand -hex 32
   ```

3. **Register the chainhook**:
   ```bash
   chainhook register stack-mart-mainnet.yaml
   ```

## Configuration Details

### Monitored Events

The chainhooks monitor these StackMart contract functions:

**Listing Events:**
- `create-listing` - New listing created
- `create-listing-with-nft` - New NFT listing created

**Purchase Events:**
- `buy-listing` - Immediate purchase
- `buy-listing-escrow` - Purchase with escrow

**Escrow Events:**
- `attest-delivery` - Seller attests delivery
- `confirm-receipt` - Buyer confirms receipt
- `release-escrow` - Escrow released

**Dispute Events:**
- `create-dispute` - Dispute created
- `resolve-dispute` - Dispute resolved

### Contract Address

Update the `contract_identifier` in the YAML files with your deployed contract address:

```yaml
contract_identifier: "SPATASA6SYGCVB67NJ1XQ72BB0Q3EHGNGE9JQBQT.stack-mart"
```

### Webhook Delivery

The chainhook service will POST events to your webhook endpoint:

```json
{
  "apply": [
    {
      "transaction_identifier": {
        "hash": "0x..."
      },
      "operations": [
        {
          "operation": "contract_call",
          "contract_identifier": "SPATASA6SYGCVB67NJ1XQ72BB0Q3EHGNGE9JQBQT.stack-mart",
          "function_name": "create-listing",
          "function_args": [...]
        }
      ]
    }
  ],
  "rollback": []
}
```

## Managing Chainhooks

### List Registered Chainhooks

```bash
chainhook list
```

### Unregister a Chainhook

```bash
chainhook unregister <chainhook-id>
```

### Update a Chainhook

1. Edit the YAML file
2. Re-register:
   ```bash
   chainhook register stack-mart-mainnet.yaml
   ```

## Testing

### Test Webhook Locally

Use a tool like [ngrok](https://ngrok.com/) to expose your local server:

```bash
# Terminal 1: Start your webhook server
cd hooks-server
npm start

# Terminal 2: Expose local server
ngrok http 3001

# Use the ngrok URL in your chainhook config
```

### Verify Events

Check that events are being received:

```bash
curl http://localhost:3001/api/events
```

## Security Best Practices

1. **Use HTTPS** for webhook endpoints in production
2. **Set a strong shared secret** and verify signatures
3. **Rate limit** webhook endpoints to prevent abuse
4. **Monitor** for unusual activity
5. **Keep chainhook CLI updated**

## Troubleshooting

### Chainhook not receiving events

- Verify contract address is correct
- Check that contract is deployed and active
- Ensure webhook URL is accessible
- Review chainhook service status

### Events not being processed

- Check webhook server logs
- Verify signature verification (if enabled)
- Ensure server is handling POST requests correctly
- Test webhook endpoint manually

### High latency

- Consider using a database instead of in-memory storage
- Optimize event processing logic
- Use a CDN or edge function for webhook endpoint
- Monitor server performance

## Resources

- [Hiro Chainhooks Documentation](https://docs.hiro.so/chainhooks)
- [Chainhook GitHub Repository](https://github.com/hirosystems/chainhook)
- [Stacks Blockchain](https://www.stacks.co/)

