import { CFG } from './config';

export function redirectUri() {
  return CFG.callbackUrl;
}

export function startLogin(scopes) {
  sessionStorage.setItem('requested_scopes', scopes);
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: CFG.clientId,
    scope: scopes,
    redirect_uri: redirectUri(),
  });
  window.location.href = CFG.authUrl + '?' + params.toString();
}

// In dev, route through Vite's proxy to avoid CORS on the token endpoint.
// In production, call the token endpoint directly.
function tokenUrl() {
  return import.meta.env.DEV ? '/token-proxy/oauth2/token' : CFG.tokenUrl;
}

export async function exchangeCode(code) {
  const basic = btoa(`${CFG.clientId}:${CFG.clientSecret}`);
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: redirectUri(),
  });
  const res = await fetch(tokenUrl(), {
    method: 'POST',
    headers: {
      Authorization: 'Basic ' + basic,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: body.toString(),
  });
  const text = await res.text();
  console.log('[token exchange] status:', res.status, 'body:', text);
  if (!res.ok) {
    throw new Error(`Token exchange failed (${res.status}): ${text || '(empty body)'}`);
  }
  return JSON.parse(text);
}

export function getToken() {
  return sessionStorage.getItem('access_token');
}

export function saveToken(token) {
  sessionStorage.setItem('access_token', token);
}

export function signOut() {
  sessionStorage.clear();
  window.location.href = redirectUri();
}

export function authHeaders(extra = {}) {
  return { Authorization: `Bearer ${getToken()}`, ...extra };
}
