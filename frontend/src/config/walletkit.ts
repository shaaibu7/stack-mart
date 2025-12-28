import { WalletKitLink } from '@walletkit/react-link';

// Get project ID from environment or use a default
// You should get your own Project ID from https://walletkit.com
const projectId = import.meta.env.VITE_WALLETKIT_PROJECT_ID || 'YOUR_WALLETKIT_PROJECT_ID';

// Initialize WalletKit Link
// WalletKit provides gasless transactions, email/social logins, and recoverable wallets
export const walletKitLink = new WalletKitLink({
  projectId,
  // Optional: Configure default network
  // network: 'ethereum-mainnet', // or 'base-mainnet', 'solana-mainnet', etc.
});

export default walletKitLink;

