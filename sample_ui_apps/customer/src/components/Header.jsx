import { signOut } from '../auth';

export function Header() {
  return (
    <header className="app-header">
      <div className="brand">
        <svg width="28" height="28" viewBox="0 0 56 56" fill="none">
          <rect width="56" height="56" rx="8" fill="#FF7300"/>
          <path d="M12 28C12 19.16 19.16 12 28 12C36.84 12 44 19.16 44 28" stroke="white" strokeWidth="4" strokeLinecap="round"/>
          <path d="M20 28C20 23.58 23.58 20 28 20C32.42 20 36 23.58 36 28" stroke="white" strokeWidth="4" strokeLinecap="round"/>
          <circle cx="28" cy="28" r="4" fill="white"/>
          <path d="M28 32V44" stroke="white" strokeWidth="4" strokeLinecap="round"/>
        </svg>
        WSO2 <span className="brand-accent">Integration Demo</span>
        &nbsp;·&nbsp; Customer Use Cases
      </div>
      <div className="header-actions">
        <span className="token-status">Authenticated</span>
        <button className="btn-signout" onClick={signOut}>Sign Out</button>
      </div>
    </header>
  );
}
