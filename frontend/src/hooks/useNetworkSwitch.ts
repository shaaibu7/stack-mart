import { useAccount, useSwitchChain } from 'wagmi';
import { mainnet, sepolia, base, polygon } from 'viem/chains';

/**
 * Hook for switching networks with AppKit
 * Supports multiple EVM chains
 */
export const useNetworkSwitch = () => {
  const { chain } = useAccount();
  const { switchChain } = useSwitchChain();

  const supportedChains = [
    { id: mainnet.id, name: 'Ethereum Mainnet', icon: '🔷' },
    { id: sepolia.id, name: 'Sepolia Testnet', icon: '🧪' },
    { id: base.id, name: 'Base', icon: '🔵' },
    { id: polygon.id, name: 'Polygon', icon: '🟣' },
  ];

  const switchToChain = async (chainId: number) => {
    try {
      if (switchChain) {
        await switchChain({ chainId });
      }
    } catch (error) {
      console.error('Error switching chain:', error);
      throw error;
    }
  };

  return {
    currentChain: chain,
    supportedChains,
    switchToChain,
    isSwitching: false, // Could track switching state if needed
  };
};

