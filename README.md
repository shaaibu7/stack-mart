# StackMart

StackMart is a decentralized marketplace on Stacks where creators list digital goods (templates, code snippets, game assets, music loops) as NFTs with built-in licensing. Buyers pay in STX, and smart contracts handle escrow, automatic royalty splits, and on-chain delivery signals to prevent fraud.

- **Auction System** – Complete bidding lifecycle with secure NFT custody and auto-refunds.
- **Bundle Logic** – Buy multiple items at a discount with batched escrow creation.
- **Secure Escrow** – Hardened logic ensuring funds are securely held and released by the contract.
- **Dispute Resolution** – Community-based dispute resolution with staking mechanics.
- **Marketplace Fees** – Configurable fee system with automatic distribution.
- **Wishlist System** – Users can favorite listings for quick access.
- **Price History** – On-chain tracking and visualization of listing price changes.
- **Reputation Volume** – Enhanced reputation metrics including total transaction volume.
- **Multi-wallet support** via Reown AppKit and WalletKit SDK for seamless user experience.

## Repo Structure
- `Clarinet.toml` – Clarinet project manifest.
- `contracts/` – Clarity smart contracts (add your contracts here and register in `Clarinet.toml`).
- `tests/` – Vitest + clarinet simnet tests.
- `settings/` – Network-specific Clarinet settings.
- `vitest.config.ts` / `tsconfig.json` – Test runner and TS config for the clarinet environment.

## Getting Started
1) Install prerequisites
   - Node.js 18+ and npm
   - Clarinet (`npm install -g @hirosystems/clarinet` or see docs)
2) Install dependencies
   - `npm install`
3) Add a contract
   - Create a `.clar` file under `contracts/` and register it in `Clarinet.toml`.
4) Write tests
   - Add simnet tests in `tests/` (Vitest + `vitest-environment-clarinet` are preconfigured).

## Testing
- Run tests: `npm test`
- Run tests with coverage and cost reports: `npm run test:report`
- Watch mode (tests rerun on contract/test changes): `npm run test:watch`

## Development Workflow
- Use `clarinet check` to lint/check contracts as you build.
- Keep contract interfaces and tests in sync; simnet state resets between tests.
- Capture any protocol decisions (e.g., royalty splits, dispute parameters) in this README as the design evolves.

## Wallet Integration

StackMart supports multiple wallet connection options for maximum flexibility and user experience:

### Reown AppKit Integration

[Reown AppKit](https://reown.com/appkit) (formerly WalletConnect AppKit) provides seamless wallet connections with support for 100+ wallets including MetaMask, Coinbase Wallet, WalletConnect, and more.

**Features:**
- 🔌 Multi-wallet support via WalletConnect protocol
- 📧 Email and social login options
- 🌐 Multi-chain support (Ethereum, Base, Polygon, etc.)
- 🎨 Modern, customizable UI components
- 📱 Mobile wallet support

**Usage:**
```tsx
import { AppKitConnectButton } from './components/AppKitConnectButton';

function App() {
  return <AppKitConnectButton />;
}
```

**Configuration:**
1. Get your Project ID from [Reown Cloud](https://cloud.reown.com)
2. Add to `.env`: `VITE_REOWN_PROJECT_ID=your_project_id`

### WalletKit SDK Integration

[WalletKit SDK](https://walletkit.com) enables gasless transactions and smart wallet features, removing friction for users.

**Features:**
- ⚡ **Gasless transactions** - Zero gas fees for users
- 🔐 **Smart wallets** - Pre-built smart wallet infrastructure
- 📧 Email and social login
- 🔄 Recoverable wallets with key splitting
- 🌐 Multi-chain support (Ethereum, Base, Solana, Polkadot)

**Usage:**
```tsx
import { WalletKitButton } from './components/WalletKitButton';

function App() {
  return <WalletKitButton />;
}
```

**Configuration:**
1. Get your Project ID from [WalletKit Dashboard](https://walletkit.com)
2. Add to `.env`: `VITE_WALLETKIT_PROJECT_ID=your_project_id`

### Unified Wallet Selector

For the best user experience, use the unified wallet selector that supports all wallet types:

```tsx
import { UnifiedWalletSelector } from './components/UnifiedWalletSelector';

function App() {
  return <UnifiedWalletSelector />;
}
```

This component allows users to choose between:
- **Stacks Connect** - Native Stacks blockchain wallets
- **Reown AppKit** - 100+ EVM wallets via WalletConnect
- **WalletKit SDK** - Gasless smart wallets

### Available Hooks

```tsx
// Unified wallet state
import { useAllWallets } from './hooks/useAllWallets';
const { isAnyConnected, connectedWallets, getPrimaryAddress } = useAllWallets();

// Individual wallet hooks
import { useAppKitIntegration } from './hooks/useAppKitIntegration';
import { useWalletKitHook } from './hooks/useWalletKit';
import { useStacks } from './hooks/useStacks';
```

### Documentation

For detailed integration guides and examples, see:
- [Complete Wallet Integration Guide](./frontend/WALLET_INTEGRATION_GUIDE.md)
- [AppKit Integration Guide](./frontend/APPKIT_INTEGRATION.md)
- [WalletKit Integration Guide](./frontend/WALLETKIT_INTEGRATION.md)
- [Wallet Usage Examples](./WALLET_USAGE_EXAMPLES.md) - Comprehensive code examples
- [Example Components](./frontend/src/examples/WalletIntegrationExamples.tsx) - Ready-to-use component examples

## Frontend Setup

The frontend is a React + TypeScript application using Vite.

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your Project IDs
   ```

4. Start development server:
   ```bash
   npm run dev
   ```

5. Build for production:
   ```bash
   npm run build
   ```
## Recent Enhancements (Jan 2026)
- **Advanced Auctions**: Implemented English auctions with reserve prices and duration.
- **Bundle Purchases**: Added logic to purchase multiple listings in one transaction with discounts.
- **Security Hardening**: Fixed escrow fund handling to prevent locked assets.
- **Testing**: Added comprehensive test suite for all new features.
