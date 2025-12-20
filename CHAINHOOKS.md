# Hiro Chainhooks Integration

StackMart uses Hiro Chainhooks to monitor blockchain events in real-time, providing instant updates to the frontend when marketplace activities occur.

## Architecture

1. **Chainhook Configurations** (`ops/chainhooks/`)
   - YAML files defining which contract events to monitor
   - Separate configs for mainnet and testnet

2. **Chainhook Server** (`hooks-server/`)
   - Express.js server receiving webhook events
   - Processes and stores events
   - Provides API endpoints for frontend

3. **Frontend Integration** (`frontend/src/hooks/useChainhooks.ts`)
   - React hook for fetching chainhook events
   - Real-time updates via polling
   - Event filtering and categorization

## Setup Instructions

### 1. Deploy Chainhook Server

```bash
cd hooks-server
npm install
npm start
```

Set environment variables:
```bash
export PORT=3001
export CHAINHOOK_SECRET=your-secret-key
```

### 2. Update Chainhook Configurations

Edit `ops/chainhooks/stack-mart-mainnet.yaml`:
- Update `delivery.url` with your deployed server URL
- Set `delivery.secret` for webhook verification
- Optionally set `start_block` to begin from specific block

### 3. Register Chainhooks

Use Hiro Chainhooks service to register your chainhook:
```bash
# Install chainhook CLI if needed
# Register the chainhook
chainhook register ops/chainhooks/stack-mart-mainnet.yaml
```

### 4. Configure Frontend

Set environment variable in `frontend/.env`:
```
VITE_CHAINHOOK_API_URL=https://your-chainhook-server.com
```

## Monitored Events

The chainhooks monitor these StackMart contract functions:

- **Listing Events**: `create-listing`, `create-listing-with-nft`
- **Purchase Events**: `buy-listing`, `buy-listing-escrow`
- **Escrow Events**: `attest-delivery`, `confirm-receipt`, `release-escrow`
- **Dispute Events**: `create-dispute`, `resolve-dispute`

## API Endpoints

- `POST /api/chainhooks/stack-mart` - Webhook endpoint (used by Hiro)
- `GET /api/events` - Get recent events (query params: limit, contract, function)
- `GET /api/events/tx/:txid` - Get event for specific transaction
- `GET /health` - Health check

## Frontend Usage

```typescript
import { useChainhooks } from './hooks/useChainhooks';

const { 
  events, 
  getLatestListings, 
  getLatestPurchases,
  getEscrowUpdates 
} = useChainhooks();
```

## Benefits

- **Real-time Updates**: Frontend automatically updates when events occur
- **No Polling Overhead**: Efficient event-driven architecture
- **Reliable**: Chainhooks ensure no events are missed
- **Scalable**: Server can handle high event volumes

