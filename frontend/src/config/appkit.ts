import { createAppKit } from '@reown/appkit/react'
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi'
import { mainnet, sepolia } from 'viem/chains'

// Get project ID from environment or use a default
// You should get your own Project ID from https://cloud.reown.com
const projectId = import.meta.env.VITE_REOWN_PROJECT_ID || '037216c37e770337c0cbfa970a4a2797'

// Create Wagmi adapter for EVM chains
const wagmiAdapter = new WagmiAdapter({
  networks: [mainnet, sepolia],
  projectId,
  ssr: false,
})

// Create AppKit instance for modern wallet connection UI
// Note: This is for EVM chains. Stacks transactions still use @stacks/connect
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
  themeMode: 'light',
  themeVariables: {
    '--w3m-accent': '#6366f1',
    '--w3m-border-radius-master': '8px',
  },
})

// Export wagmi config for provider
export const wagmiConfig = wagmiAdapter.wagmiConfig

export default appKit

