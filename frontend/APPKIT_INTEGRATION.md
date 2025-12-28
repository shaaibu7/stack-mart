# Reown AppKit Integration

This project uses Reown AppKit (formerly WalletConnect AppKit) for modern wallet connection UI alongside Stacks Connect for Stacks-specific transactions.

## Features

- **Modern Wallet UI**: AppKit provides a beautiful, modern wallet connection interface
- **Multi-Wallet Support**: Supports multiple EVM wallets through WalletConnect
- **Email & Social Login**: Users can connect via email or social accounts
- **Hybrid Approach**: Stacks transactions still use @stacks/connect for native Stacks support

## Configuration

The AppKit configuration is in `src/config/appkit.ts`. You need to:

1. Get a Project ID from [Reown Cloud](https://cloud.reown.com)
2. Set it in your `.env` file:
   ```
   VITE_REOWN_PROJECT_ID=your_project_id_here
   ```

## Usage

The `useStacks` hook has been enhanced to support both AppKit and Stacks Connect:

```typescript
const { isConnected, connectWallet, appKitAddress, isAppKitConnected } = useStacks();
```

The `WalletButton` component automatically uses AppKit's UI when available.

## Network Support

Currently configured for:
- Ethereum Mainnet
- Sepolia Testnet

For Stacks blockchain transactions, the app continues to use `@stacks/connect`.

