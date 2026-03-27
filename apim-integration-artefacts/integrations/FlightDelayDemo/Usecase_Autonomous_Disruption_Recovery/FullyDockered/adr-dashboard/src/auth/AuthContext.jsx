/**
 * Lightweight OIDC PKCE authentication context.
 *
 * Replaces the @asgardeo/auth-react SDK, which has complex internal
 * session-management behaviours (iframe checks, token-refresh listeners,
 * auto-logout on token-refresh errors, silent sign-in) that are
 * incompatible with a self-signed-cert, no-refresh-token, proxied
 * WSO2 IS environment and caused infinite redirect / refresh loops.
 *
 * This implementation provides the same public API surface the rest of
 * the dashboard relies on:
 *   - state.isAuthenticated, state.isLoading, state.displayName, etc.
 *   - signIn(), signOut(), getAccessToken(), getDecodedIDToken()
 */
import { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';

// ─── helpers ────────────────────────────────────────────────────────────────

function base64urlEncode(buffer) {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function generatePKCE() {
  const verifier = base64urlEncode(crypto.getRandomValues(new Uint8Array(32)));
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  const challenge = base64urlEncode(digest);
  return { verifier, challenge };
}

function decodeJWT(token) {
  try {
    const payload = token.split('.')[1];
    return JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/')));
  } catch {
    return null;
  }
}

const STORAGE_KEY = 'oidc_session';

function loadSession() {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function saveSession(data) {
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify(data));
}

function clearSession() {
  sessionStorage.removeItem(STORAGE_KEY);
  // Also clean up any Asgardeo SDK leftovers from previous sessions
  const keysToRemove = [];
  for (let i = 0; i < sessionStorage.length; i++) {
    const key = sessionStorage.key(i);
    if (key && (key.startsWith('session_data-instance_') ||
                key.startsWith('session_active-instance_') ||
                key.startsWith('op_config-instance_') ||
                key.startsWith('temp_data-instance_') ||
                key.startsWith('config_data-instance_'))) {
      keysToRemove.push(key);
    }
  }
  keysToRemove.forEach(k => sessionStorage.removeItem(k));
}

// ─── context ────────────────────────────────────────────────────────────────

const AuthContext = createContext(null);

const DEFAULT_STATE = {
  isAuthenticated: false,
  isLoading: true,
  displayName: '',
  email: '',
  username: '',
  sub: '',
  allowedScopes: '',
};

export function AuthProvider({ config, children }) {
  const [state, setState] = useState(() => {
    // Restore from session if available
    const saved = loadSession();
    if (saved?.access_token) {
      const decoded = decodeJWT(saved.id_token || saved.access_token);
      return {
        isAuthenticated: true,
        isLoading: false,
        displayName: decoded?.given_name || decoded?.sub || '',
        email: decoded?.email || '',
        username: decoded?.username || decoded?.sub || '',
        sub: decoded?.sub || '',
        allowedScopes: saved.scope || '',
      };
    }
    return DEFAULT_STATE;
  });

  const initDone = useRef(false);

  // ── Resolve endpoints from config ─────────────────────────────────────
  const cfg = config || {};
  const baseUrl = cfg.baseUrl || 'https://localhost:9444';
  const clientID = cfg.clientID || '';
  const scope = Array.isArray(cfg.scope) ? cfg.scope.join(' ') : (cfg.scope || 'openid profile email');
  const signInRedirectURL = cfg.signInRedirectURL || window.location.origin;
  const signOutRedirectURL = cfg.signOutRedirectURL || window.location.origin;

  // Use explicit endpoint overrides when provided (nginx proxied),
  // otherwise fall back to constructing from baseUrl.
  const endpoints = cfg.endpoints || {};
  const authorizationEndpoint = endpoints.authorizationEndpoint || `${baseUrl}/oauth2/authorize`;
  const tokenEndpoint = endpoints.tokenEndpoint || `${baseUrl}/oauth2/token`;
  const endSessionEndpoint = endpoints.endSessionEndpoint || `${baseUrl}/oidc/logout`;

  // ── Exchange authorization code for tokens ────────────────────────────
  const exchangeCode = useCallback(async (code, codeVerifier) => {
    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: signInRedirectURL,
      client_id: clientID,
      code_verifier: codeVerifier,
    });

    const res = await fetch(tokenEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });

    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new Error(`Token exchange failed: ${res.status} ${text}`);
    }

    return res.json();
  }, [tokenEndpoint, signInRedirectURL, clientID]);

  // ── Handle OAuth callback on mount ────────────────────────────────────
  useEffect(() => {
    if (initDone.current) return;
    initDone.current = true;

    const url = new URL(window.location.href);
    const code = url.searchParams.get('code');
    const returnedState = url.searchParams.get('state');
    const storedVerifier = sessionStorage.getItem('pkce_verifier');

    // Clean URL params regardless — we don't want code/state lingering
    if (code || url.searchParams.has('state') || url.searchParams.has('session_state')) {
      url.searchParams.delete('code');
      url.searchParams.delete('state');
      url.searchParams.delete('session_state');
      window.history.replaceState({}, document.title, url.pathname + url.search);
    }

    if (code && storedVerifier && returnedState) {
      // We have an authorization code — exchange it
      sessionStorage.removeItem('pkce_verifier');
      exchangeCode(code, storedVerifier)
        .then((tokens) => {
          const session = {
            access_token: tokens.access_token,
            id_token: tokens.id_token,
            scope: tokens.scope || '',
            token_type: tokens.token_type || 'Bearer',
          };
          saveSession(session);
          const decoded = decodeJWT(tokens.id_token || tokens.access_token);
          setState({
            isAuthenticated: true,
            isLoading: false,
            displayName: decoded?.given_name || decoded?.sub || '',
            email: decoded?.email || '',
            username: decoded?.username || decoded?.sub || '',
            sub: decoded?.sub || '',
            allowedScopes: tokens.scope || '',
          });
        })
        .catch((err) => {
          console.error('[Auth] Token exchange failed:', err);
          clearSession();
          setState({ ...DEFAULT_STATE, isLoading: false });
        });
    } else if (loadSession()?.access_token) {
      // Already have a session — keep it (state was initialized from storage)
      setState((prev) => ({ ...prev, isLoading: false }));
    } else {
      // No code, no session — not authenticated
      setState({ ...DEFAULT_STATE, isLoading: false });
    }
  }, [exchangeCode]);

  // ── signIn: redirect to IS authorization endpoint ─────────────────────
  const signIn = useCallback(async () => {
    const { verifier, challenge } = await generatePKCE();
    sessionStorage.setItem('pkce_verifier', verifier);

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: clientID,
      redirect_uri: signInRedirectURL,
      scope,
      code_challenge: challenge,
      code_challenge_method: 'S256',
      state: 'login',
    });

    window.location.href = `${authorizationEndpoint}?${params}`;
  }, [authorizationEndpoint, clientID, signInRedirectURL, scope]);

  // ── signOut: clear session + redirect to IS logout ────────────────────
  const signOut = useCallback(() => {
    clearSession();
    setState({ ...DEFAULT_STATE, isLoading: false });

    const params = new URLSearchParams({
      post_logout_redirect_uri: signOutRedirectURL,
      client_id: clientID,
      state: 'sign_out_success',
    });

    window.location.href = `${endSessionEndpoint}?${params}`;
  }, [endSessionEndpoint, signOutRedirectURL, clientID]);

  // ── clearAuthSession: clear storage + update React state ────────────
  // Called by the API client on 401 so that ProtectedRoute detects
  // isAuthenticated=false and navigates to /login via React Router
  // (no hard page reload needed).
  const clearAuthSession = useCallback(() => {
    clearSession();
    setState({ ...DEFAULT_STATE, isLoading: false });
  }, []);

  // ── getAccessToken: return stored access token ────────────────────────
  const getAccessToken = useCallback(async () => {
    const session = loadSession();
    if (!session?.access_token) {
      throw new Error('No access token available');
    }
    return session.access_token;
  }, []);

  // ── getDecodedIDToken: decode and return ID token claims ──────────────
  const getDecodedIDToken = useCallback(async () => {
    const session = loadSession();
    const token = session?.id_token || session?.access_token;
    if (!token) throw new Error('No ID token available');
    const decoded = decodeJWT(token);
    if (!decoded) throw new Error('Failed to decode ID token');
    return decoded;
  }, []);

  const value = {
    state,
    signIn,
    signOut,
    clearAuthSession,
    getAccessToken,
    getDecodedIDToken,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuthContext() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuthContext must be used within an AuthProvider');
  }
  return ctx;
}
