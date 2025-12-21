# StackMart Chainhook Server

Express.js server that receives and processes chainhook events from Hiro Chainhooks, providing real-time marketplace event data to the frontend.

## Features

- Receives webhook events from Hiro Chainhooks
- Verifies webhook signatures for security
- Stores events in memory (can be extended to use a database)
- Provides REST API for frontend to query events
- Health check endpoint for monitoring

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment Variables

Create a `.env` file or set environment variables:

```bash
PORT=3001
CHAINHOOK_SECRET=your-shared-secret-here
```

The `CHAINHOOK_SECRET` should match the secret configured in your chainhook YAML file.

### 3. Start the Server

```bash
# Development
npm start

# With auto-reload (if using nodemon)
npm run dev
```

The server will start on port 3001 (or the port specified in `PORT`).

## API Endpoints

### POST `/api/chainhooks/stack-mart`
Webhook endpoint for Hiro Chainhooks to send events.

**Headers:**
- `x-chainhook-signature`: HMAC signature for verification (optional if secret not set)

**Response:**
```json
{
  "success": true,
  "message": "Event processed",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### GET `/api/events`
Get recent chainhook events.

**Query Parameters:**
- `limit` (optional): Maximum number of events to return (default: 50)
- `contract` (optional): Filter by contract identifier
- `function` (optional): Filter by function name

**Example:**
```bash
curl "http://localhost:3001/api/events?limit=10&function=create-listing"
```

**Response:**
```json
{
  "events": [
    {
      "txid": "0x...",
      "contract": "SPATASA6SYGCVB67NJ1XQ72BB0Q3EHGNGE9JQBQT.stack-mart",
      "function": "create-listing",
      "args": [...],
      "timestamp": "2024-01-01T00:00:00.000Z"
    }
  ],
  "total": 1
}
```

### GET `/api/events/tx/:txid`
Get event for a specific transaction.

**Example:**
```bash
curl "http://localhost:3001/api/events/tx/0x123..."
```

### GET `/health`
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "events_count": 42,
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Deployment

### Local Development

```bash
npm start
```

### Production Deployment

For production, consider:

1. **Use a process manager** (PM2, systemd, etc.)
2. **Add database storage** instead of in-memory storage
3. **Enable HTTPS** for webhook endpoint
4. **Set up monitoring** and logging
5. **Use environment variables** for configuration

Example with PM2:
```bash
pm2 start server.js --name stackmart-chainhooks
```

### Docker Deployment

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY server.js ./
EXPOSE 3001
CMD ["node", "server.js"]
```

## Security

- Webhook signature verification using HMAC-SHA256
- CORS enabled for frontend access
- Request size limit (10MB) to prevent DoS

## Monitoring

The server logs all received events to the console. In production, consider:

- Using a logging service (Winston, Pino, etc.)
- Setting up alerts for errors
- Monitoring event processing latency
- Tracking event volume

## Extending

### Add Database Storage

Replace the in-memory `events` array with a database:

```javascript
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

// Store event
await prisma.event.create({
  data: eventData
});
```

### Add WebSocket Support

For real-time updates to connected clients:

```javascript
import { WebSocketServer } from 'ws';

const wss = new WebSocketServer({ port: 3002 });

function broadcastEvent(eventData) {
  wss.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(eventData));
    }
  });
}
```

## Troubleshooting

### Events not being received

1. Check that the webhook URL in chainhook config is correct
2. Verify the server is accessible from the internet
3. Check that `CHAINHOOK_SECRET` matches the config
4. Review server logs for errors

### Signature verification failing

- Ensure `CHAINHOOK_SECRET` is set correctly
- Verify the secret in chainhook config matches
- Check that the signature header is being sent

### High memory usage

- Consider implementing event retention limits
- Add database storage instead of in-memory
- Implement event archiving for old events
