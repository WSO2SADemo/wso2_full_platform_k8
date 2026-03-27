import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from './auth/AuthContext';
import App from './App';
import './index.css';

// Auth config can be set at build time via env vars, or at runtime via
// window.__AUTH_CONFIG__ (injected by create_apis.sh after deployment).
const runtimeConfig = window.__AUTH_CONFIG__ || {};

const authConfig = {
  signInRedirectURL: runtimeConfig.signInRedirectURL
    || import.meta.env.VITE_AUTH_SIGN_IN_REDIRECT_URL
    || 'http://localhost:3000',
  signOutRedirectURL: runtimeConfig.signOutRedirectURL
    || import.meta.env.VITE_AUTH_SIGN_OUT_REDIRECT_URL
    || 'http://localhost:3000',
  clientID: runtimeConfig.clientID
    || import.meta.env.VITE_AUTH_CLIENT_ID
    || '',
  baseUrl: runtimeConfig.baseUrl
    || import.meta.env.VITE_AUTH_BASE_URL
    || 'https://localhost:9444',
  scope: runtimeConfig.scope
    || (import.meta.env.VITE_AUTH_SCOPE?.split(' '))
    || ['openid', 'email', 'profile', 'roles', 'groups'],
  // Endpoint overrides (injected by create_apis.sh) route fetch-based OIDC
  // calls through the dashboard's nginx proxy to avoid self-signed-cert and
  // CORS issues.  The authorize endpoint stays on the real IS URL because
  // that is a full-page browser redirect, not a fetch.
  ...(runtimeConfig.endpoints && { endpoints: runtimeConfig.endpoints }),
};

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider config={authConfig}>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </React.StrictMode>
);
