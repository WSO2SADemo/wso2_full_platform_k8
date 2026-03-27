import React, { useEffect, useState } from 'react';
import { useAsgardeo, User, SignOutButton } from '@asgardeo/react';
import ChatAgent from '../components/ChatAgent';
import config from '../config';

export default function EmployeeDashboard() {
  const { getAccessToken, getDecodedIdToken, isSignedIn, isLoading } = useAsgardeo();

  const [searchTerm, setSearchTerm] = useState("");
  const [policies, setPolicies] = useState([]);

  const [hasPrivilegedAccess, setHasPrivilegedAccess] = useState(false);
  const [hasOrdinaryAccess, setHasOrdinaryAccess] = useState(false);
  const [isCheckingPermissions, setIsCheckingPermissions] = useState(true);

  const [accessToken, setAccessToken] = useState(null);
  const [username, setUsername] = useState(null);

  // Modal state for policy update
  const [showUpdateModal, setShowUpdateModal] = useState(false);
  const [policyToUpdate, setPolicyToUpdate] = useState(null);
  const [newStatus, setNewStatus] = useState("ACTIVE");

  // Result modal (success or error)
  const [showResultModal, setShowResultModal] = useState(false);
  const [resultIsError, setResultIsError] = useState(false);
  const [resultMessage, setResultMessage] = useState("");

  const parseJwt = (token) => {
    try {
      if (!token) return {};
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(atob(base64).split('').map(c =>
        '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)
      ).join(''));
      return JSON.parse(jsonPayload);
    } catch (e) { return {}; }
  };

  const formatCurrency = (amount) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);

  // --- 1. AUTH & PERMISSION LOGIC ---
  useEffect(() => {
    if (!isSignedIn || isLoading) return;

    (async () => {
      try {
        const token = await getAccessToken();
        const idToken = await getDecodedIdToken();
        const parsedAccess = parseJwt(token);
        const scopeArray = (parsedAccess?.scope || "").split(" ");

        console.log('ID Token claims:', idToken);
        console.log('Access Token claims:', parsedAccess);
        console.log("Employee Scopes:", scopeArray);

        const userInfoRes = await fetch(`${config.isBaseUrl}/oauth2/userinfo`, {
          headers: { 'Authorization': `Bearer ${token}` }
        });
        const userInfo = await userInfoRes.json();
        console.log('Userinfo claims:', userInfo);

        const resolvedUsername = userInfo.username || userInfo.preferred_username || userInfo.email || idToken.username || idToken.email || "Unknown User";
        sessionStorage.setItem('insurance_username', resolvedUsername);
        setUsername(resolvedUsername);
        setAccessToken(token);
        const hasPrivileged = scopeArray.some(s => s === "privileged" || s === "privileged_api_scope");
        const hasOrdinary = scopeArray.some(s => s === "ordinary" || s === "ordinary_api_scope");
        setHasOrdinaryAccess(hasOrdinary || hasPrivileged);
        setHasPrivilegedAccess(hasPrivileged);

      } catch (error) {
        console.error('Error fetching permissions:', error);
        setHasOrdinaryAccess(false);
        setHasPrivilegedAccess(false);
      } finally {
        setIsCheckingPermissions(false);
      }
    })();
  }, [getAccessToken, isSignedIn, isLoading, getDecodedIdToken]);

  // --- 2. API CALL: Fetch Policies ---
  useEffect(() => {
    if (!accessToken || !hasOrdinaryAccess) return;

    const fetchPolicies = async () => {
      try {
        console.log("Fetching policies...");
        const response = await fetch(`${config.agentApiBase}/insurance/agent/policies`, {
          method: 'GET',
          headers: { 'accept': '*/*', 'Authorization': `Bearer ${accessToken}` }
        });

        if (!response.ok) throw new Error(`API Error: ${response.status}`);
        const data = await response.json();
        setPolicies(data);
      } catch (error) {
        console.error("Failed to fetch policies:", error);
      }
    };
    fetchPolicies();
  }, [accessToken, hasOrdinaryAccess]);

  // --- 3. POLICY UPDATE LOGIC ---
  const initiateUpdate = (policy) => {
    setPolicyToUpdate(policy);
    setNewStatus(policy.status);
    setShowUpdateModal(true);
  };

  const confirmUpdate = async () => {
    if (!policyToUpdate) return;

    try {
      const response = await fetch(`${config.agentApiBase}/insurance/agent/policy/update`, {
        method: 'POST',
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        body: JSON.stringify({ policyNumber: policyToUpdate.policyNumber, status: newStatus })
      });

      const result = await response.json();
      setShowUpdateModal(false);

      if (response.ok) {
        setPolicies(policies.map(p =>
          p.policyNumber === policyToUpdate.policyNumber ? { ...p, status: newStatus } : p
        ));
        setResultIsError(false);
        setResultMessage(result.message || `Policy ${policyToUpdate.policyNumber} updated to ${newStatus}.`);
      } else {
        setResultIsError(true);
        setResultMessage(result.message || result.description || `Error ${response.status}: Failed to update policy.`);
      }
      setShowResultModal(true);

    } catch (error) {
      console.error("Policy update error:", error);
      setShowUpdateModal(false);
      setResultIsError(true);
      setResultMessage("Network error: Could not reach the gateway.");
      setShowResultModal(true);
    }
  };

  const getStatusStyle = (status) => ({
    ACTIVE:    { background: '#dcfce7', color: '#166534' },
    EXPIRED:   { background: '#fee2e2', color: '#991b1b' },
    SUSPENDED: { background: '#fef9c3', color: '#854d0e' },
    PENDING:   { background: '#e0f2fe', color: '#075985' },
  }[status] || { background: '#f1f5f9', color: '#475569' });

  return (
    <div style={{ display: 'flex', height: '100vh', background: '#f0fdf4', position: 'relative' }}>

      {/* Sidebar */}
      <div style={{ width: '260px', background: '#064e3b', color: 'white', padding: '30px 20px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ marginBottom: '40px' }}>
          <div style={{ fontSize: '1.5rem', marginBottom: '4px' }}>🛡️</div>
          <h3 style={{ margin: 0, color: '#10b981' }}>SafeGuard Insurance</h3>
          <p style={{ margin: '4px 0 0 0', fontSize: '0.8rem', opacity: 0.7 }}>Employee Portal</p>
        </div>

        <div style={{ flex: 1 }}>
          <p style={{ padding: '12px', background: 'rgba(255,255,255,0.1)', borderRadius: '12px' }}>
            📋 Policies Dashboard
          </p>
        </div>

        <User>
          {(user) => (
            <div style={{ marginBottom: '20px', fontSize: '0.9rem', opacity: 0.8, lineHeight: '1.6' }}>
              <div style={{ color: '#6ee7b7', fontSize: '0.75rem' }}>LOGGED IN AS</div>
              <div style={{ fontWeight: 'bold', fontSize: '1rem', color: 'white' }}>
                {user.given_name || user.username} {user.family_name}
              </div>
              <div style={{ fontSize: '0.8rem', fontStyle: 'italic', color: '#a7f3d0', marginTop: '4px' }}>
                {username}
              </div>
              <div style={{ marginTop: '10px' }}>
                <span style={{
                  background: hasPrivilegedAccess ? '#10b981' : '#64748b',
                  color: hasPrivilegedAccess ? '#064e3b' : 'white',
                  padding: '2px 8px', borderRadius: '4px', fontSize: '0.75rem', fontWeight: 'bold'
                }}>
                  {hasPrivilegedAccess ? "MANAGER" : (hasOrdinaryAccess ? "OFFICER" : "RESTRICTED")}
                </span>
              </div>
            </div>
          )}
        </User>

        <SignOutButton
          className="btn-secondary"
          style={{ border: '1px solid #ef5350', color: '#ef5350', width: '100%', backgroundColor: 'transparent' }}
        >
          Log Out
        </SignOutButton>
      </div>

      {/* Main Content */}
      <div style={{ flex: 1, padding: '40px', overflowY: 'auto' }}>

        {isCheckingPermissions ? (
          <div style={{ textAlign: 'center', marginTop: '100px', color: '#64748b' }}>Checking permissions...</div>
        ) : hasOrdinaryAccess ? (
          <>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
              <div>
                <h2 style={{ margin: 0, color: '#064e3b' }}>Policies Overview</h2>
                <p style={{ margin: '4px 0 0 0', color: '#64748b', fontSize: '0.9rem' }}>
                  {hasPrivilegedAccess
                    ? 'You can view and update policy statuses.'
                    : 'You can view and update policy statuses.'}
                </p>
              </div>
              <input
                type="text"
                placeholder="🔍 Search policies..."
                onChange={(e) => setSearchTerm(e.target.value)}
                style={{ width: '300px' }}
              />
            </div>

            <div className="card" style={{ padding: '0', overflow: 'hidden' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead style={{ background: '#f0fdf4' }}>
                  <tr style={{ textAlign: 'left', color: '#064e3b', fontSize: '0.9rem' }}>
                    <th style={{ padding: '16px 20px' }}>Policy Number</th>
                    <th style={{ padding: '16px 20px' }}>Policyholder</th>
                    <th style={{ padding: '16px 20px' }}>Type</th>
                    <th style={{ padding: '16px 20px' }}>Coverage</th>
                    <th style={{ padding: '16px 20px' }}>Premium</th>
                    <th style={{ padding: '16px 20px' }}>Valid Until</th>
                    <th style={{ padding: '16px 20px' }}>Status</th>
                    <th style={{ padding: '16px 20px', textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {policies
                    .filter(p =>
                      p.username?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                      p.policyNumber?.toLowerCase().includes(searchTerm.toLowerCase())
                    )
                    .map(p => (
                      <tr key={p.policyNumber} style={{ borderBottom: '1px solid #d1fae5' }}>
                        <td style={{ padding: '16px 20px', fontFamily: 'monospace', color: '#064e3b', fontWeight: '600' }}>{p.policyNumber}</td>
                        <td style={{ padding: '16px 20px', fontWeight: '600' }}>{p.username}</td>
                        <td style={{ padding: '16px 20px', color: '#64748b' }}>{p.policyType}</td>
                        <td style={{ padding: '16px 20px', fontWeight: 'bold' }}>{formatCurrency(p.coverageAmount)}</td>
                        <td style={{ padding: '16px 20px' }}>{formatCurrency(p.premiumAmount)}/mo</td>
                        <td style={{ padding: '16px 20px', color: '#64748b' }}>{p.endDate}</td>
                        <td style={{ padding: '16px 20px' }}>
                          <span style={{
                            padding: '4px 12px', borderRadius: '20px', fontSize: '0.8rem', fontWeight: 'bold',
                            ...getStatusStyle(p.status)
                          }}>{p.status}</span>
                        </td>
                        <td style={{ padding: '16px 20px', textAlign: 'right' }}>
                          <button
                            onClick={() => initiateUpdate(p)}
                            style={{
                              background: '#064e3b', color: 'white', border: 'none',
                              padding: '7px 14px', borderRadius: '8px', cursor: 'pointer', fontWeight: '600', fontSize: '0.85rem'
                            }}
                          >
                            Update
                          </button>
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
              {policies.length === 0 && (
                <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>No policies found.</div>
              )}
            </div>
          </>
        ) : (
          <div style={{ textAlign: 'center', marginTop: '100px', padding: '40px', background: '#fff1f2', borderRadius: '12px', border: '1px solid #fda4af' }}>
            <div style={{ fontSize: '3rem', marginBottom: '10px' }}>🚫</div>
            <h2 style={{ color: '#9f1239', margin: 0 }}>Access Denied</h2>
            <p style={{ color: '#64748b', marginTop: '10px' }}>You do not have the required permissions to view this portal.</p>
          </div>
        )}
      </div>

      {/* AI Chat Agent */}
      <ChatAgent accessToken={accessToken} hasPremiumCoverage={hasPrivilegedAccess} username={username} />

      {/* MODAL: Update Policy Status */}
      {showUpdateModal && policyToUpdate && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', justifyContent: 'center', alignItems: 'center', backdropFilter: 'blur(4px)'
        }}>
          <div style={{
            backgroundColor: 'white', padding: '30px', borderRadius: '16px', width: '420px',
            boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)'
          }}>
            <h3 style={{ color: '#1f2937', marginTop: 0 }}>Update Policy Status</h3>
            <p style={{ color: '#6b7280', marginBottom: '20px' }}>
              Policy <strong style={{ color: '#064e3b', fontFamily: 'monospace' }}>{policyToUpdate.policyNumber}</strong>
              {' '}— Policyholder: <strong>{policyToUpdate.username}</strong>
            </p>
            <label style={{ display: 'block', fontSize: '0.9rem', color: '#374151', marginBottom: '8px', fontWeight: '600' }}>
              New Status
            </label>
            <select
              value={newStatus}
              onChange={(e) => setNewStatus(e.target.value)}
              style={{
                width: '100%', padding: '10px 12px', borderRadius: '8px',
                border: '1px solid #d1d5db', fontSize: '0.95rem', marginBottom: '24px'
              }}
            >
              <option value="ACTIVE">ACTIVE</option>
              <option value="SUSPENDED">SUSPENDED</option>
              <option value="EXPIRED">EXPIRED</option>
              <option value="PENDING">PENDING</option>
            </select>
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
              <button onClick={() => setShowUpdateModal(false)} style={{
                padding: '10px 20px', borderRadius: '8px', border: '1px solid #d1d5db',
                background: 'white', color: '#374151', cursor: 'pointer', fontWeight: '600'
              }}>Cancel</button>
              <button onClick={confirmUpdate} style={{
                padding: '10px 20px', borderRadius: '8px', border: 'none',
                background: '#064e3b', color: 'white', cursor: 'pointer', fontWeight: '600'
              }}>Confirm Update</button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: Result (Success or Error) */}
      {showResultModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', justifyContent: 'center', alignItems: 'center', backdropFilter: 'blur(4px)'
        }}>
          <div style={{
            backgroundColor: 'white', padding: '30px', borderRadius: '16px', width: '420px',
            textAlign: 'center', boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)',
            borderTop: `6px solid ${resultIsError ? '#dc2626' : '#16a34a'}`
          }}>
            <div style={{ fontSize: '3rem', marginBottom: '10px' }}>{resultIsError ? '❌' : '✅'}</div>
            <h3 style={{ color: resultIsError ? '#dc2626' : '#16a34a', marginTop: 0 }}>
              {resultIsError ? 'Update Failed' : 'Update Successful'}
            </h3>
            <p style={{ color: '#4b5563', lineHeight: '1.5' }}>{resultMessage}</p>
            <button
              onClick={() => setShowResultModal(false)}
              style={{
                marginTop: '20px', padding: '10px 25px', borderRadius: '8px', border: 'none',
                background: resultIsError ? '#dc2626' : '#16a34a',
                color: 'white', cursor: 'pointer', fontWeight: '600', width: '100%', fontSize: '1rem'
              }}
            >
              Close
            </button>
          </div>
        </div>
      )}

    </div>
  );
}
