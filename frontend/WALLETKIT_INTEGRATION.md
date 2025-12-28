# WalletKit SDK Integration

This project integrates WalletKit SDK for gasless wallet transactions and smart wallet features.

## Features

- **Gasless Transactions**: Eliminate gas fees for users on supported chains
- **Email & Social Logins**: Users can create wallets using email or social accounts
- **Recoverable Wallets**: Secure wallet recovery using key splitting
- **Multi-Chain Support**: Supports Ethereum, Base, Solana, Polkadot, and more
- **Smart Wallets**: Pre-built smart wallet infrastructure

## Configuration

The WalletKit configuration is in `src/config/walletkit.ts`. You need to:

1. Get a Project ID from [WalletKit Dashboard](https://walletkit.com)
2. Set it in your `.env` file:
   ```
   VITE_WALLETKIT_PROJECT_ID=your_walletkit_project_id_here
   ```

## Usage

### Basic Hook Usage

```typescript
import { useWalletKitHook } from '../hooks/useWalletKit';

const { walletKit, isConnected, address, chain } = useWalletKitHook();
```

### Direct WalletKit Hook

```typescript
import { useWalletKit } from '@walletkit/react-link';

const walletKit = useWalletKit();

// Connect wallet
await walletKit?.connect();

// Disconnect wallet
await walletKit?.disconnect();

// Send gasless transaction
await walletKit?.sendTransaction({
  to: '0x...',
  value: '0x0',
  data: '0x...',
});
```

### Components

- `WalletKitButton`: Pre-built button component for WalletKit connection

## Comparison: WalletKit vs AppKit

### WalletKit SDK
- **Best for**: Gasless transactions, smart wallets, simplified onboarding
- **Key Feature**: Zero gas fees for users
- **Use Case**: Applications wanting to remove gas friction

### Reown AppKit
- **Best for**: Multi-wallet support, WalletConnect integration
- **Key Feature**: Connect to 100+ wallets
- **Use Case**: Applications needing broad wallet compatibility

Both can be used together in this project for maximum flexibility!

