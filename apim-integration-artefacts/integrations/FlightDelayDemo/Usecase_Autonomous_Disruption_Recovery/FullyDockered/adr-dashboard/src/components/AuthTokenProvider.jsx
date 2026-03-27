import { useEffect, useCallback } from 'react';
import { useAuthContext } from '../auth/AuthContext';
import { setAccessTokenGetter, setOnSessionExpired } from '../api/client';

/**
 * Invisible component that wires up the auth context's getAccessToken
 * to the API client, and provides a session-expired callback that
 * updates React state (so ProtectedRoute navigates to /login via
 * React Router instead of hard page reloads).
 */
export default function AuthTokenProvider({ children }) {
  const { getAccessToken, clearAuthSession } = useAuthContext();

  const onSessionExpired = useCallback(() => {
    clearAuthSession();
  }, [clearAuthSession]);

  useEffect(() => {
    setAccessTokenGetter(getAccessToken);
    setOnSessionExpired(onSessionExpired);
    return () => {
      setAccessTokenGetter(null);
      setOnSessionExpired(null);
    };
  }, [getAccessToken, onSessionExpired]);

  return children;
}
