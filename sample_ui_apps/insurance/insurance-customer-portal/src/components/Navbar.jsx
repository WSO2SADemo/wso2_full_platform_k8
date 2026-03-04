import React from 'react';
import { useAsgardeo } from '@asgardeo/react';

export default function Navbar() {
  const { state, signOut, signIn, isSignedIn } = useAsgardeo();

  const authenticated = isSignedIn || state?.isAuthenticated;
  const displayUsername = state?.username || state?.email || "Customer";

  return (
    <nav style={styles.nav}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
        <span style={{ fontSize: '1.5rem' }}>🛡️</span>
        <span style={{ fontWeight: 700, fontSize: '1.3rem', color: 'var(--color-primary)' }}>
          InsureMe
        </span>
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
          <button onClick={() => signIn()} className="btn-primary">
            Customer Login
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
    alignItems: 'center',
    padding: '1.5rem 3rem',
    background: 'var(--color-surface)',
    boxShadow: '0 2px 10px rgba(13, 110, 110, 0.08)',
    position: 'sticky',
    top: 0,
    zIndex: 100
  }
};
