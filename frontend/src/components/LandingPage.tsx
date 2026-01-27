import { useEffect, useRef } from 'react';
import { WalletButton } from './WalletButton';
import { useStacks } from '../hooks/useStacks';
import { useAppKit } from '@reown/appkit/react';
import { useAccount } from 'wagmi';

interface LandingPageProps {
  onEnter: () => void;
}

export const LandingPage = ({ onEnter }: LandingPageProps) => {
  const { isConnected, isAppKitConnected } = useStacks();
  const { address, isConnected: isAppKitAccountConnected } = useAccount();

  // Auto-navigate to marketplace when wallet is connected (only once per session)
  useEffect(() => {
    const walletConnected = isConnected || isAppKitConnected || isAppKitAccountConnected;
    
    // Check if we've already auto-navigated in this session
    const hasAutoNavigated = sessionStorage.getItem('landingPageAutoNavigated') === 'true';
    
    // Only auto-navigate if:
    // 1. Wallet is connected
    // 2. We haven't already auto-navigated in this session
    if (walletConnected && !hasAutoNavigated) {
      sessionStorage.setItem('landingPageAutoNavigated', 'true');
      // Small delay to ensure connection is fully established
      const timer = setTimeout(() => {
        onEnter();
      }, 500);
      return () => clearTimeout(timer);
    }
    
    // Reset the flag if wallet disconnects (so it can auto-navigate again if they reconnect)
    if (!walletConnected && hasAutoNavigated) {
      sessionStorage.removeItem('landingPageAutoNavigated');
    }
  }, [isConnected, isAppKitConnected, isAppKitAccountConnected, onEnter]);
  return (
    <div style={{
      minHeight: '100vh',
      backgroundColor: '#ffffff',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'stretch',
      paddingBottom: '3rem',
      position: 'relative',
      overflow: 'hidden'
    }}>
      <style>{`
        @keyframes float {
          0% { transform: translate(0, 0) rotate(0deg); }
          100% { transform: translate(-50px, -50px) rotate(360deg); }
        }
        @keyframes fadeInUp {
          from {
            opacity: 0;
            transform: translateY(30px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
        .fade-in-up {
          animation: fadeInUp 0.8s ease-out;
        }
      `}</style>

      {/* Navigation bar */}
      <header style={{ backgroundColor: '#ffffff', borderBottom: '1px solid #e0e0e0' }}>
        <div style={{
          maxWidth: '1200px',
          margin: '0 auto',
          padding: '1rem 1.5rem',
          display: 'flex',
          alignItems: 'center',
          gap: '1rem',
          flexWrap: 'wrap'
        }}>
          {/* Logo */}
          <div 
            onClick={() => window.location.reload()}
            style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '0.5rem', 
              marginRight: 'auto',
              cursor: 'pointer',
              transition: 'opacity 0.2s'
            }}
            onMouseEnter={(e) => e.currentTarget.style.opacity = '0.7'}
            onMouseLeave={(e) => e.currentTarget.style.opacity = '1'}
            title="Click to refresh"
          >
            <div style={{
              width: '32px',
              height: '32px',
              borderRadius: '8px',
              border: '2px solid #333333',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#333333',
              fontSize: '1.1rem'
            }}>
              🛍️
            </div>
            <span style={{
              fontSize: '1.4rem',
              fontWeight: 700,
              color: '#333333'
            }}>
              StackMart
            </span>
          </div>

          {/* Marketplace Link */}
          <button
            onClick={onEnter}
            style={{
              background: 'none',
              border: 'none',
              color: '#333333',
              fontSize: '0.95rem',
              fontWeight: 600,
              cursor: 'pointer',
              padding: '0.5rem 1rem',
              borderRadius: '4px',
              transition: 'background-color 0.2s'
            }}
            onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#f5f5f5'}
            onMouseLeave={(e) => e.currentTarget.style.backgroundColor = 'transparent'}
          >
            Marketplace
          </button>

          {/* Category */}
          <select
            style={{
              borderRadius: '4px',
              border: '1px solid #e0e0e0',
              padding: '0.75rem 1rem',
              fontSize: '0.95rem',
              appearance: 'none',
              backgroundColor: '#ffffff',
              cursor: 'pointer',
              minWidth: '150px'
            }}
            defaultValue=""
          >
            <option value="" disabled>Category</option>
            <option value="nfts">NFTs</option>
            <option value="music">Music Rights</option>
            <option value="art">Digital Art</option>
            <option value="templates">Code & Templates</option>
          </select>

          {/* Search */}
          <div style={{ display: 'flex', alignItems: 'center', flex: '1', minWidth: '200px', maxWidth: '400px' }}>
            <input
              placeholder="Search..."
              style={{
                borderRadius: '4px',
                border: '1px solid #e0e0e0',
                padding: '0.75rem 1rem',
                fontSize: '0.95rem',
                width: '100%'
              }}
            />
          </div>

          {/* Connect Wallet - Rightmost */}
          <div style={{ display: 'flex', alignItems: 'center', marginLeft: 'auto' }}>
            <WalletButton />
          </div>
        </div>
      </header>

      <div style={{
        maxWidth: '1200px',
        width: '100%',
        zIndex: 1,
        textAlign: 'center',
        margin: '4rem auto 0',
        padding: '0 1.5rem'
      }}>
        {/* Logo/Title */}
        <div className="fade-in-up" style={{
          marginBottom: '3rem'
        }}>
          <h1 style={{
            fontSize: 'clamp(3rem, 8vw, 5rem)',
            fontWeight: 'bold',
            color: '#333333',
            marginBottom: '1.5rem',
            letterSpacing: '-0.02em'
          }}>
            🛍️ StackMart
          </h1>
          <p style={{
            fontSize: 'clamp(1.2rem, 3vw, 1.8rem)',
            color: '#666666',
            marginBottom: '1rem',
            fontWeight: 300
          }}>
            Decentralized Marketplace on Stacks
          </p>
          <p style={{
            fontSize: 'clamp(1rem, 2vw, 1.2rem)',
            color: '#666666',
            maxWidth: '600px',
            margin: '0 auto',
            lineHeight: '1.7',
            padding: '0 1rem'
          }}>
            Buy and sell digital goods as NFTs with built-in licensing, escrow, and automatic royalty splits
          </p>
        </div>

        {/* Features Grid */}
        <div className="fade-in-up" style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
          gap: '1.5rem',
          marginBottom: '4rem',
          marginTop: '2rem'
        }}>
          {[
            { icon: '🔐', title: 'Secure Escrow', desc: 'Smart contracts handle payments safely' },
            { icon: '💰', title: 'Auto Royalties', desc: 'Automatic splits to collaborators' },
            { icon: '⭐', title: 'Reputation System', desc: 'On-chain seller/buyer ratings' },
            { icon: '⚖️', title: 'Dispute Resolution', desc: 'Community-powered arbitration' },
            { icon: '📦', title: 'Bundles & Packs', desc: 'Curated collections with discounts' },
            { icon: '🌐', title: 'Multi-Wallet', desc: 'Support for all major wallets' }
          ].map((feature, idx) => (
            <div key={idx} style={{
              background: '#ffffff',
              borderRadius: '16px',
              padding: '2rem 1.5rem',
              border: '1px solid #e0e0e0',
              transition: 'transform 0.3s, box-shadow 0.3s',
              cursor: 'pointer'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-8px)';
              e.currentTarget.style.boxShadow = '0 12px 40px rgba(0, 102, 255, 0.15)';
              e.currentTarget.style.borderColor = 'var(--primary-light)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 1px 3px rgba(0, 0, 0, 0.05)';
              e.currentTarget.style.borderColor = 'var(--gray-200)';
            }}
            >
              <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>
                {feature.icon}
              </div>
              <h3 style={{
                color: '#333333',
                fontSize: '1.2rem',
                fontWeight: '600',
                marginBottom: '0.75rem'
              }}>
                {feature.title}
              </h3>
              <p style={{
                color: '#666666',
                fontSize: '0.9rem',
                lineHeight: '1.6'
              }}>
                {feature.desc}
              </p>
            </div>
          ))}
        </div>

        {/* CTA Section */}
        <div className="fade-in-up" style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: '1.5rem',
          marginTop: '3rem'
        }}>
          <div style={{
            display: 'flex',
            gap: '1rem',
            flexWrap: 'wrap',
            justifyContent: 'center',
            alignItems: 'center'
          }}>
            <button
              onClick={onEnter}
              style={{
                padding: '1rem 2.5rem',
                fontSize: '1.2rem',
                fontWeight: '600',
                color: '#ffffff',
                background: '#26a626',
                border: 'none',
                borderRadius: '12px',
                cursor: 'pointer',
                boxShadow: '0 4px 20px rgba(0, 102, 255, 0.3)',
                transition: 'all 0.2s ease',
                minWidth: '200px'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.transform = 'translateY(-2px) scale(1.02)';
                e.currentTarget.style.boxShadow = '0 8px 30px rgba(0, 102, 255, 0.4)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.transform = 'translateY(0) scale(1)';
                e.currentTarget.style.boxShadow = '0 4px 20px rgba(0, 102, 255, 0.3)';
              }}
            >
              🚀 Enter Marketplace
            </button>
            
            <div style={{
              background: '#ffffff',
              borderRadius: '12px',
              padding: '0.75rem 1.25rem',
              border: '1px solid #e0e0e0'
            }}>
              <WalletButton />
            </div>
          </div>

          <p style={{
            color: '#666666',
            fontSize: '0.9rem',
            marginTop: '0.5rem'
          }}>
            Connect your wallet to start buying and selling digital goods
          </p>
        </div>

        {/* Stats */}
        <div className="fade-in-up" style={{
          display: 'flex',
          justifyContent: 'center',
          gap: '4rem',
          marginTop: '5rem',
          marginBottom: '3rem',
          flexWrap: 'wrap'
        }}>
          {[
            { label: 'Blockchain', value: 'Stacks' },
            { label: 'Payments', value: 'STX' },
            { label: 'Smart Contracts', value: 'Clarity' }
          ].map((stat, idx) => (
            <div key={idx} style={{
              textAlign: 'center',
              padding: '0 1rem'
            }}>
              <div style={{
                fontSize: '2rem',
                fontWeight: 'bold',
                color: '#333333',
                marginBottom: '0.5rem'
              }}>
                {stat.value}
              </div>
              <div style={{
                fontSize: '0.9rem',
                color: '#666666'
              }}>
                {stat.label}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

