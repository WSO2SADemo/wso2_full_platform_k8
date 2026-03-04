import React from 'react';
import { useAsgardeo } from '@asgardeo/react'; // Removed SignInButton import

export default function Navbar() {
  // ✅ 1. Get 'signIn' directly from the hook
  const { state, signOut, signIn, isSignedIn } = useAsgardeo();

  const authenticated = isSignedIn || state?.isAuthenticated;
  const displayUsername = state?.username || state?.email || "Customer";

  return (
    <nav style={styles.nav}>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <img 
          src="https://cdn.statically.io/gh/ramindu90/imagerepo/main/bank_logo.png" 
          alt="City Bank" 
          style={{ height: '40px' }} 
        />
      </div>

      <div>
        {authenticated ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
            <span style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
              {displayUsername}
            </span>
            <button onClick={() => signOut()} className="btn-secondary">
              Sign Out
            </button>
          </div>
        ) : (
          // ✅ 2. Use a standard button with the signIn function
          // No more <SignInButton> wrapper!
          <button onClick={() => signIn()} className="btn-primary">
            Online Banking Login
          </button>
        )}
      </div>
    </nav>
  );
}

const styles = {
  nav: {
    display: 'flex',
    justifyContent: 'space-between',
    padding: '1.5rem 3rem',
    background: 'var(--color-surface)',
    boxShadow: '0 2px 10px rgba(0,0,0,0.05)',
    position: 'sticky',
    top: 0,
    zIndex: 100
  }
};