import React from 'react';
import { useAsgardeo } from '@asgardeo/react';

export default function Navbar() {
  const { signIn, signOut, isSignedIn, state } = useAsgardeo();
  const authenticated = isSignedIn || state?.isAuthenticated;
  const username = state?.username || state?.email || 'User';

  return (
    <nav className="topnav">
      <div className="nav-logo">
        <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
          <rect width="28" height="28" rx="8" fill="#0f172a"/>
          <path d="M7 14h14M14 7v14" stroke="#fff" strokeWidth="2.5" strokeLinecap="round"/>
        </svg>
        Medical API Demo
        <span className="pill">K8 Gateway</span>
      </div>

      <div>
        {authenticated ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
            <span style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--color-text-sub)' }}>
              {username}
            </span>
            <button className="btn-secondary" onClick={() => signOut()}>Sign Out</button>
          </div>
        ) : (
          <button className="btn-primary" onClick={() => signIn()}>
            Sign In with WSO2 IS
          </button>
        )}
      </div>
    </nav>
  );
}
