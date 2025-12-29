# WalletKit SDK & Reown AppKit Usage Examples

This document demonstrates how WalletKit SDK and Reown AppKit are integrated and used throughout the StackMart application.

## Table of Contents
- [Overview](#overview)
- [Reown AppKit Usage](#reown-appkit-usage)
- [WalletKit SDK Usage](#walletkit-sdk-usage)
- [Unified Implementation](#unified-implementation)
- [Real-World Examples](#real-world-examples)

## Overview

StackMart uses both **Reown AppKit** and **WalletKit SDK** to provide users with multiple wallet connection options:

- **Reown AppKit**: For connecting to 100+ wallets via WalletConnect
- **WalletKit SDK**: For gasless transactions and smart wallet features
- **Stacks Connect**: For native Stacks blockchain interactions

## Reown AppKit Usage

### 1. Provider Setup

**File:** `frontend/src/main.tsx`

```tsx
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { wagmiConfig } from './config/appkit'

const queryClient = new QueryClient()

createRoot(document.getElementById('root')!).render(
  <WagmiProvider config={wagmiConfig}>
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  </WagmiProvider>
)
```

### 2. Configuration

**File:** `frontend/src/config/appkit.ts`

```tsx
import { createAppKit } from '@reown/appkit/react'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { mainnet, sepolia } from 'viem/chains'

const projectId = import.meta.env.VITE_REOWN_PROJECT_ID

const wagmiAdapter = new WagmiAdapter({
  networks: [mainnet, sepolia],
  projectId,
})

export const appKit = createAppKit({
  adapters: [wagmiAdapter],
  networks: [mainnet, sepolia],
  projectId,
  metadata: {
    name: 'StackMart Marketplace',
    description: 'Decentralized marketplace on Stacks blockchain',
    url: window.location.origin,
    icons: [`${window.location.origin}/vite.svg`],
  },
  features: {
    analytics: true,
    email: true,
    socials: ['github', 'google', 'x', 'discord'],
    emailShowWallets: true,
  },
})
```

### 3. Using AppKit Hook

**File:** `frontend/src/hooks/useAppKitIntegration.ts`

```tsx
import { useAppKit } from '@reown/appkit/react'
import { useAccount } from 'wagmi'

export const useAppKitIntegration = () => {
  const { open, close } = useAppKit()
  const { address, isConnected, chain } = useAccount()

  return {
    open,
    close,
    address,
    isConnected,
    chain,
  }
}
```

### 4. AppKit Connect Button Component

**File:** `frontend/src/components/AppKitConnectButton.tsx`

```tsx
import { useAppKit } from '@reown/appkit/react'
import { useAccount } from 'wagmi'

export const AppKitConnectButton = () => {
  const { open } = useAppKit()
  const { address, isConnected } = useAccount()

  if (isConnected && address) {
    return <w3m-button /> // Built-in AppKit button
  }

  return (
    <button onClick={() => open()}>
      🔗 Connect Wallet (AppKit)
    </button>
  )
}
```

## WalletKit SDK Usage

### 1. Provider Setup

**File:** `frontend/src/main.tsx`

```tsx
import { WalletKitLinkProvider } from '@walletkit/react-link'
import { walletKitLink } from './config/walletkit'

createRoot(document.getElementById('root')!).render(
  <WalletKitLinkProvider link={walletKitLink}>
    <App />
  </WalletKitLinkProvider>
)
```

### 2. Configuration

**File:** `frontend/src/config/walletkit.ts`

```tsx
import { WalletKitLink } from '@walletkit/react-link'

const projectId = import.meta.env.VITE_WALLETKIT_PROJECT_ID

export const walletKitLink = new WalletKitLink({
  projectId,
})
```

### 3. Using WalletKit Hook

**File:** `frontend/src/hooks/useWalletKit.ts`

```tsx
import { useWalletKit } from '@walletkit/react-link'

export const useWalletKitHook = () => {
  const walletKit = useWalletKit()

  return {
    walletKit,
    isConnected: walletKit?.isConnected || false,
    address: walletKit?.address || null,
    chain: walletKit?.chain || null,
  }
}
```

### 4. WalletKit Connect Button Component

**File:** `frontend/src/components/WalletKitButton.tsx`

```tsx
import { useWalletKit } from '@walletkit/react-link'

export const WalletKitButton = () => {
  const walletKit = useWalletKit()

  const handleConnect = async () => {
    await walletKit?.connect()
  }

  const handleDisconnect = async () => {
    await walletKit?.disconnect()
  }

  if (walletKit?.isConnected && walletKit?.address) {
    return (
      <div>
        <span>{formatAddress(walletKit.address)}</span>
        <button onClick={handleDisconnect}>Disconnect</button>
      </div>
    )
  }

  return (
    <button onClick={handleConnect}>
      🔗 Connect WalletKit (Gasless)
    </button>
  )
}
```

## Unified Implementation

### Unified Wallet Selector

**File:** `frontend/src/components/UnifiedWalletSelector.tsx`

This component allows users to choose between all wallet options:

```tsx
import { WalletButton } from './WalletButton'
import { AppKitConnectButton } from './AppKitConnectButton'
import { WalletKitButton } from './WalletKitButton'

export const UnifiedWalletSelector = () => {
  const [selectedOption, setSelectedOption] = useState<'stacks' | 'appkit' | 'walletkit'>('stacks')

  return (
    <div>
      {/* Wallet selection UI */}
      {selectedOption === 'stacks' && <WalletButton />}
      {selectedOption === 'appkit' && <AppKitConnectButton />}
      {selectedOption === 'walletkit' && <WalletKitButton />}
    </div>
  )
}
```

### Unified Wallet State Hook

**File:** `frontend/src/hooks/useAllWallets.ts`

Aggregates all wallet connection states:

```tsx
import { useStacks } from './useStacks'
import { useAppKitIntegration } from './useAppKitIntegration'
import { useWalletKitHook } from './useWalletKit'

export const useAllWallets = () => {
  const stacks = useStacks()
  const appKit = useAppKitIntegration()
  const walletKit = useWalletKitHook()

  const isAnyConnected = stacks.isConnected || appKit.isConnected || walletKit.isConnected

  return {
    stacks,
    appKit,
    walletKit,
    isAnyConnected,
    getPrimaryAddress: () => {
      // Priority: Stacks > AppKit > WalletKit
      return stacks.userData?.profile?.stxAddress?.mainnet 
        || appKit.address 
        || walletKit.address
    },
  }
}
```

## Real-World Examples

### Example 1: Using in Main App Component

**File:** `frontend/src/App.tsx`

```tsx
import { UnifiedWalletSelector } from './components/UnifiedWalletSelector'

function App() {
  return (
    <div className="App">
      <header>
        <h1>StackMart Marketplace</h1>
        <UnifiedWalletSelector />
      </header>
      {/* Rest of app */}
    </div>
  )
}
```

### Example 2: Checking Wallet Connection

```tsx
import { useAllWallets } from './hooks/useAllWallets'

function MyComponent() {
  const { isAnyConnected, getPrimaryAddress, appKit, walletKit } = useAllWallets()

  if (!isAnyConnected) {
    return <div>Please connect a wallet</div>
  }

  const address = getPrimaryAddress()

  return (
    <div>
      <p>Connected: {address}</p>
      {appKit.isConnected && <p>AppKit: {appKit.address}</p>}
      {walletKit.isConnected && <p>WalletKit: {walletKit.address}</p>}
    </div>
  )
}
```

### Example 3: Sending Transactions

#### Using AppKit (EVM Chains)

```tsx
import { useAccount, useWriteContract } from 'wagmi'

function SendTransaction() {
  const { address, isConnected } = useAccount()
  const { writeContract } = useWriteContract()

  const handleSend = async () => {
    if (!isConnected) return

    writeContract({
      address: '0x...',
      abi: [...],
      functionName: 'transfer',
      args: ['0x...', '1000000000000000000'],
    })
  }

  return <button onClick={handleSend}>Send Transaction</button>
}
```

#### Using WalletKit (Gasless)

```tsx
import { useWalletKit } from '@walletkit/react-link'

function SendGaslessTransaction() {
  const walletKit = useWalletKit()

  const handleSend = async () => {
    if (!walletKit?.isConnected) return

    await walletKit.sendTransaction({
      to: '0x...',
      value: '0x0',
      data: '0x...',
    })
  }

  return <button onClick={handleSend}>Send Gasless Transaction</button>
}
```

### Example 4: Wallet Status Display

**File:** `frontend/src/components/WalletStatus.tsx`

```tsx
import { useAllWallets } from '../hooks/useAllWallets'

export const WalletStatus = () => {
  const { stacks, appKit, walletKit, isAnyConnected } = useAllWallets()

  return (
    <div>
      {stacks.isConnected && <div>Stacks: Connected</div>}
      {appKit.isConnected && <div>AppKit: {appKit.address}</div>}
      {walletKit.isConnected && <div>WalletKit: {walletKit.address}</div>}
    </div>
  )
}
```

## Key Benefits

### Reown AppKit Benefits:
- ✅ Connect to 100+ wallets (MetaMask, Coinbase, WalletConnect, etc.)
- ✅ Email and social login options
- ✅ Multi-chain support (Ethereum, Base, Polygon, etc.)
- ✅ Modern, customizable UI
- ✅ Mobile wallet support

### WalletKit SDK Benefits:
- ✅ **Zero gas fees** for users
- ✅ Smart wallet infrastructure
- ✅ Email and social login
- ✅ Recoverable wallets
- ✅ Multi-chain support

## Environment Variables

Create a `.env` file in the `frontend` directory:

```bash
# Reown AppKit Project ID
VITE_REOWN_PROJECT_ID=your_reown_project_id_here

# WalletKit Project ID
VITE_WALLETKIT_PROJECT_ID=your_walletkit_project_id_here

# Stacks Network
VITE_STACKS_NETWORK=mainnet
```

## Getting Project IDs

1. **Reown AppKit**: 
   - Visit [Reown Cloud](https://cloud.reown.com)
   - Create a new project
   - Copy your Project ID

2. **WalletKit SDK**:
   - Visit [WalletKit Dashboard](https://walletkit.com)
   - Create a new project
   - Copy your Project ID

## Additional Resources

- [Complete Wallet Integration Guide](./frontend/WALLET_INTEGRATION_GUIDE.md)
- [AppKit Integration Guide](./frontend/APPKIT_INTEGRATION.md)
- [WalletKit Integration Guide](./frontend/WALLETKIT_INTEGRATION.md)
- [Reown AppKit Documentation](https://docs.reown.com/appkit)
- [WalletKit Documentation](https://docs.walletkit.com)

