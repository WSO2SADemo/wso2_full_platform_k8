import { useState, useEffect } from 'react';
import { useAuthContext } from '../auth/AuthContext';

/**
 * Hook to get the current user's groups from the decoded ID token.
 * Returns { groups: string[], loading: boolean }.
 *
 * Groups are populated from the `groups` claim in the ID token,
 * which is configured in the IS OIDC application claim settings.
 */
export function useUserGroups() {
  const { getDecodedIDToken, state } = useAuthContext();
  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!state.isAuthenticated) {
      setLoading(false);
      return;
    }
    getDecodedIDToken()
      .then((decoded) => {
        const g = decoded?.groups || [];
        setGroups(Array.isArray(g) ? g : [g]);
      })
      .catch(() => setGroups([]))
      .finally(() => setLoading(false));
  }, [state.isAuthenticated, getDecodedIDToken]);

  return { groups, loading };
}

/** Check whether the user belongs to a specific group */
export function hasGroup(groups, groupName) {
  return groups.some((g) => g === groupName);
}
