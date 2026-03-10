import { useState } from 'react';
import { startLogin } from '../auth';

export function LoginScreen() {
  const [scopes, setScopes] = useState('email openid privilege');

  return (
    <div className="login-screen">
      <div className="login-card">
        <div className="login-logo">
          <svg width="56" height="56" viewBox="0 0 56 56" fill="none">
            <rect width="56" height="56" rx="12" fill="#FF7300"/>
            <path d="M12 28C12 19.16 19.16 12 28 12C36.84 12 44 19.16 44 28" stroke="white" strokeWidth="4" strokeLinecap="round"/>
            <path d="M20 28C20 23.58 23.58 20 28 20C32.42 20 36 23.58 36 28" stroke="white" strokeWidth="4" strokeLinecap="round"/>
            <circle cx="28" cy="28" r="4" fill="white"/>
            <path d="M28 32V44" stroke="white" strokeWidth="4" strokeLinecap="round"/>
          </svg>
        </div>
        <h1>Integration Demo</h1>
        <p>Customer Use Cases — Powered by WSO2 APIM</p>

        <label htmlFor="scopes">OAuth2 Scopes</label>
        <input
          id="scopes"
          type="text"
          value={scopes}
          onChange={(e) => setScopes(e.target.value)}
          placeholder="e.g. openid email"
        />
        <p className="hint">Space-separated scopes to request from the authorization server</p>

        <button className="btn btn-primary" onClick={() => startLogin(scopes.trim() || 'openid')}>
          Sign in with WSO2
        </button>
      </div>
    </div>
  );
}
