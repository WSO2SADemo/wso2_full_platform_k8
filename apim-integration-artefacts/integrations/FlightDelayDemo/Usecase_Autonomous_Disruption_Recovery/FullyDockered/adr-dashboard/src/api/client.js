// Gateway URL from runtime config injected by create_apis.sh, or fallback to env/default
const GATEWAY_URL = (window.__AUTH_CONFIG__ && window.__AUTH_CONFIG__.gatewayUrl)
  || import.meta.env.VITE_API_GATEWAY_URL
  || 'https://localhost:8246';

// AI Agent URL — use relative path (nginx proxies /ai/* to orchestrator:9095)
// This avoids CORS issues by making same-origin requests through the dashboard proxy
const AI_AGENT_URL = '';

// A global reference to the getAccessToken function from auth context.
// Set by the AuthTokenProvider component at app init.
let _getAccessToken = null;

// A callback that clears the auth session AND updates React state.
// Set by AuthTokenProvider so that 401 handling flows through React
// instead of doing hard page reloads (which cause infinite loops when
// the IS has an active session).
let _onSessionExpired = null;

export function setAccessTokenGetter(fn) {
  _getAccessToken = fn;
}

export function setOnSessionExpired(fn) {
  _onSessionExpired = fn;
}

// Read token directly from sessionStorage as fallback.
// This handles the race condition where Dashboard's useEffect fires
// API calls BEFORE AuthTokenProvider's useEffect wires up _getAccessToken.
function getTokenFromStorage() {
  try {
    const raw = sessionStorage.getItem('oidc_session');
    if (raw) {
      const session = JSON.parse(raw);
      return session?.access_token || null;
    }
  } catch { /* ignore */ }
  return null;
}

// Handle 401 — session expired.
// Clear session data and update React auth state (which triggers
// ProtectedRoute to navigate to /login via React Router).
// NEVER do window.location.href here — that causes infinite loops
// when IS has an active session.
function handleUnauthorized() {
  sessionStorage.removeItem('oidc_session');
  if (_onSessionExpired) {
    _onSessionExpired();
  }
}

async function request(url, options = {}) {
  const headers = { 'Content-Type': 'application/json', ...options.headers };

  // Attach Bearer token — try the wired-up getter first, then fall back
  // to reading sessionStorage directly (covers the race condition where
  // Dashboard mounts and fires API calls before AuthTokenProvider's
  // useEffect has wired up _getAccessToken).
  let token = null;
  if (_getAccessToken) {
    try {
      token = await _getAccessToken();
    } catch (e) {
      // getAccessToken failed — session may be gone
      handleUnauthorized();
      throw new Error('Session expired');
    }
  } else {
    token = getTokenFromStorage();
  }
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const res = await fetch(GATEWAY_URL + url, {
    headers,
    ...options,
  });
  if (res.status === 401) {
    handleUnauthorized();
    throw new Error('Session expired');
  }
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new Error(`${res.status}: ${text}`);
  }
  return res.json();
}

// Direct AI Agent request (bypasses APIM, agent validates JWT internally)
async function aiAgentRequest(url, options = {}) {
  const headers = { 'Content-Type': 'application/json', ...options.headers };

  // Attach Bearer token — same fallback logic as request()
  let token = null;
  if (_getAccessToken) {
    try {
      token = await _getAccessToken();
    } catch (e) {
      handleUnauthorized();
      throw new Error('Session expired');
    }
  } else {
    token = getTokenFromStorage();
  }
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const res = await fetch(AI_AGENT_URL + url, {
    headers,
    ...options,
  });
  if (res.status === 401) {
    handleUnauthorized();
    throw new Error('Session expired');
  }
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new Error(`${res.status}: ${text}`);
  }
  return res.json();
}

// ── Disruption Detection API (APIM context: /disruption/1.0.0) ───────────
export const disruption = {
  getFlights:       ()        => request('/disruption/1.0.0/flights'),
  getFlight:        (id)      => request(`/disruption/1.0.0/flights/${id}`),
  createFlight:     (data)    => request('/disruption/1.0.0/flights', { method: 'POST', body: JSON.stringify(data) }),
  reportDelay:      (id, data)=> request(`/disruption/1.0.0/flights/${id}/delay`, { method: 'PUT', body: JSON.stringify(data) }),
  getDelays:        ()        => request('/disruption/1.0.0/delays'),
  getDisruption:    (id)      => request(`/disruption/1.0.0/${id}`),
  resolveDisruption:(id)      => request(`/disruption/1.0.0/${id}/resolve`, { method: 'PUT' }),
  getFlightSeats:   (id)      => request(`/disruption/1.0.0/flights/${id}/seats`),
  getFlightCrewReqs:(id)      => request(`/disruption/1.0.0/flights/${id}/crew-requirements`),
  changeStatus:     (id, data)=> request(`/disruption/1.0.0/flights/${id}/status`, { method: 'PUT', body: JSON.stringify(data) }),
  assessFlight:     (id)      => request(`/disruption/1.0.0/flights/${id}/assess`),
};

// ── Crew Agent API (APIM context: /crew/1.0.0) ──────────────────────────
export const crew = {
  getMembers:       ()        => request('/crew/1.0.0/members'),
  getMember:        (id)      => request(`/crew/1.0.0/members/${id}`),
  createMember:     (data)    => request('/crew/1.0.0/members', { method: 'POST', body: JSON.stringify(data) }),
  getAssignments:   (flightId)=> request(`/crew/1.0.0/assignments/${flightId}`),
  checkCompliance:  (data)    => request('/crew/1.0.0/check-compliance', { method: 'POST', body: JSON.stringify(data) }),
  reassign:         (data)    => request('/crew/1.0.0/reassign', { method: 'POST', body: JSON.stringify(data) }),
  getRequirements:  (flightId)=> request(`/crew/1.0.0/requirements/${flightId}`),
  evaluateCrew:     (flightId)=> request(`/crew/1.0.0/evaluate/${flightId}`),
  assignCrew:       (data)    => request('/crew/1.0.0/assign', { method: 'POST', body: JSON.stringify(data) }),
  getAvailable:     (airport, role) => {
    const params = new URLSearchParams();
    if (airport) params.set('airport', airport);
    if (role)    params.set('role', role);
    return request(`/crew/1.0.0/available?${params}`);
  },
};

// ── Passenger Service API (APIM context: /passenger/1.0.0) ──────────────────
export const passenger = {
  getBookings:      (flightId)=> request(`/passenger/1.0.0/bookings/${flightId}`),
  getAllBookings:    ()        => request('/passenger/1.0.0/all-bookings'),
  getPassenger:     (id)      => request(`/passenger/1.0.0/${id}`),
  rebook:           (data)    => request('/passenger/1.0.0/rebook', { method: 'POST', body: JSON.stringify(data) }),
  notify:           (data)    => request('/passenger/1.0.0/notify', { method: 'POST', body: JSON.stringify(data) }),
  compensation:     (data)    => request('/passenger/1.0.0/compensation', { method: 'POST', body: JSON.stringify(data) }),
  getAlternatives:  (flightId)=> request(`/passenger/1.0.0/alternatives/${flightId}`),
  getHistory:       (passengerId) => request(`/passenger/1.0.0/history/${passengerId}`),
  getDetailedAlternatives: (flightId) => request(`/passenger/1.0.0/alternatives-detailed/${flightId}`),
  evaluateRebook:   (passengerId, flightId) => request(`/passenger/1.0.0/evaluate-rebook/${passengerId}/${flightId}`),
};

// ── Logistics Service API (APIM context: /logistics/1.0.0) ──────────────────
export const logistics = {
  getAvailableGates:(airport, gateType) => {
    const params = gateType ? `?gate_type=${gateType}` : '';
    return request(`/logistics/1.0.0/gates/available/${airport}${params}`);
  },
  assignGate:       (data)    => request('/logistics/1.0.0/gates/assign', { method: 'POST', body: JSON.stringify(data) }),
  redirectCatering: (data)    => request('/logistics/1.0.0/catering/redirect', { method: 'POST', body: JSON.stringify(data) }),
  notifyGroundHandling: (data)=> request('/logistics/1.0.0/ground-handling/notify', { method: 'POST', body: JSON.stringify(data) }),
  getResources:     (airport) => request(`/logistics/1.0.0/resources/${airport}`),
  getCatering:      (flightId)=> request(`/logistics/1.0.0/catering/${flightId}`),
  getGroundTasks:   (flightId)=> request(`/logistics/1.0.0/ground-tasks/${flightId}`),
};

// ── ADR Orchestrator API (APIM context: /adr/1.0.0) ─────────────────────
export const adr = {
  triggerRecovery:  (data)    => request('/adr/1.0.0/recover', { method: 'POST', body: JSON.stringify(data) }),
  getRecoveryPlans: ()        => request('/adr/1.0.0/recovery-plans'),
  getRecoveryPlan:  (id)      => request(`/adr/1.0.0/recovery-plans/${id}`),
};

// ── AI Agent API (Direct invocation with in-agent JWT validation) ────────────────────────
export const aiAgent = {
  chat:   (message, sessionId)  => aiAgentRequest('/ai/chat', { method: 'POST', body: JSON.stringify({ message, session_id: sessionId || undefined }) }),
  health: ()         => aiAgentRequest('/ai/health'),
};

// ── CS Agent API (Direct invocation with in-agent JWT validation) ────────
// Same pattern as AI Agent — bypasses APIM, nginx proxies /cs/* to cs-agent:9097
export const csAgent = {
  chat:   (message, sessionId)  => aiAgentRequest('/cs/chat', { method: 'POST', body: JSON.stringify({ message, session_id: sessionId || undefined }) }),
  health: ()         => aiAgentRequest('/cs/health'),
};
