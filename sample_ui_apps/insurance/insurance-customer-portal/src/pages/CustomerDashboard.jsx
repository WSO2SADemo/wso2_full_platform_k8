import React, { useEffect, useState } from 'react';
import { useAsgardeo, SignedIn, User } from '@asgardeo/react';
import ChatAgent from '../components/ChatAgent';
import OBOChatAgent from '../components/OBOChatAgent';
import TokenInfoPanel from '../components/TokenInfoPanel';
import config from '../config';

export default function CustomerDashboard() {
  const { state, getAccessToken, getDecodedIdToken, isSignedIn, isLoading } = useAsgardeo();

  const [hasPremiumCoverage, setHasPremiumCoverage] = useState(false);
  const [accessToken, setAccessToken] = useState(null);
  const [username, setUsername] = useState(null);
  const [policyData, setPolicyData] = useState(null);
  const [claimsData, setClaimsData] = useState(null);

  // --- 1. AUTH & TOKEN LOGIC ---
  useEffect(() => {
    if (!isSignedIn || isLoading) return;

    (async () => {
      try {
        const token = await getAccessToken();
        const idToken = await getDecodedIdToken();

        const parsedAccess = parseJwt(token);
        const scopeString = parsedAccess?.scope || "";
        const scopeArray = scopeString.split(" ").filter(s => s);

        console.log('ID Token claims:', idToken);
        console.log('Access Token claims:', parseJwt(token));

        // Fetch user profile claims from userinfo endpoint
        const userInfoRes = await fetch(`${config.isBaseUrl}/oauth2/userinfo`, {
          headers: { 'Authorization': `Bearer ${token}` }
        });
        const userInfo = await userInfoRes.json();
        console.log('Userinfo claims:', userInfo);

        const resolvedUsername = userInfo.username || userInfo.preferred_username || userInfo.sub || idToken.username || idToken.sub || idToken.email || userInfo.email || "Unknown User";
        sessionStorage.setItem('insurance_username', resolvedUsername);
        setAccessToken(token);
        setUsername(resolvedUsername);
        setHasPremiumCoverage(scopeArray.some(s => s === "ext_privileged" || s === "ext_privileged_api_scope" || s === "privilege_external_api_scope"));
      } catch (error) {
        console.error('Error fetching token:', error);
      }
    })();
  }, [getAccessToken, isSignedIn, isLoading, getDecodedIdToken]);

  // --- 2. API CALLS ---
  useEffect(() => {
    if (!accessToken || !username) return;

    const fetchInsuranceData = async () => {
      try {
        const [policyRes, claimsRes] = await Promise.all([
          fetch(`${config.customerApiBase}/insurance/customer/policy`, {
            method: 'POST',
            headers: {
              'accept': '*/*',
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({ username })
          }),
          fetch(`${config.customerApiBase}/insurance/customer/claims`, {
            method: 'POST',
            headers: {
              'accept': '*/*',
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({ username })
          })
        ]);

        if (policyRes.ok) setPolicyData(await policyRes.json());
        if (claimsRes.ok) setClaimsData(await claimsRes.json());
      } catch (error) {
        console.error('Failed to fetch insurance data:', error);
      }
    };

    fetchInsuranceData();
  }, [accessToken, username]);

  const parseJwt = (token) => {
    try {
      const base64Url = token.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(atob(base64).split('').map(c =>
        '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)
      ).join(''));
      return JSON.parse(jsonPayload);
    } catch (e) { return {}; }
  };

  const formatMoney = (amount) =>
    new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);

  const statusColor = (status) => ({
    ACTIVE: { bg: '#dcfce7', color: '#166534' },
    EXPIRED: { bg: '#fee2e2', color: '#991b1b' },
    PENDING: { bg: '#fef9c3', color: '#92400e' },
    APPROVED: { bg: '#dcfce7', color: '#166534' },
    REJECTED: { bg: '#fee2e2', color: '#991b1b' },
  }[status] || { bg: '#f1f5f9', color: '#475569' });

  return (
    <div style={{ display: 'flex', gap: '24px', alignItems: 'flex-start', padding: '2rem' }}>
      <TokenInfoPanel accessToken={accessToken} />
      <div style={{ flex: 1, minWidth: 0 }}>

      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '3rem' }}>
        <div>
          <h1 style={{ margin: 0, color: 'var(--color-primary)' }}>My Insurance</h1>
          <SignedIn>
            <User>
              {(user) => (
                <p style={{ color: 'var(--color-text-sub)', marginTop: '5px' }}>
                  Welcome back, <strong>{user.name?.givenName || username}</strong>
                </p>
              )}
            </User>
          </SignedIn>
        </div>

        {hasPremiumCoverage && (
          <div style={{
            background: 'linear-gradient(135deg, #0d6e6e 0%, #17a589 100%)',
            color: 'white', padding: '8px 16px', borderRadius: '50px', fontWeight: 'bold',
            boxShadow: '0 4px 12px rgba(13, 110, 110, 0.35)'
          }}>
            ⭐ Premium Member
          </div>
        )}
      </div>

      {/* Policy Card */}
      {policyData ? (
        <div className="card" style={{ marginBottom: '2rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ marginTop: 0, color: 'var(--color-primary)' }}>Active Policy</h3>
            <span style={{
              background: statusColor(policyData.status).bg,
              color: statusColor(policyData.status).color,
              padding: '4px 12px', borderRadius: '20px', fontSize: '0.8rem', fontWeight: 'bold'
            }}>
              {policyData.status}
            </span>
          </div>

          <p style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '20px' }}>
            Policy No: <span style={{ fontFamily: 'monospace', fontWeight: 'bold' }}>{policyData.policyNumber}</span>
            &nbsp;|&nbsp; Type: <strong>{policyData.policyType}</strong>
          </p>

          <div style={{ display: 'flex', gap: '1.5rem', flexWrap: 'wrap' }}>
            <div style={{ flex: 1, padding: '1.5rem', background: '#f0f7f7', borderRadius: '12px', border: '1px solid #c8e0e0' }}>
              <div style={{ color: 'var(--color-text-sub)', fontSize: '0.9rem', marginBottom: '5px' }}>Coverage Amount</div>
              <div style={{ fontSize: '2rem', fontWeight: 'bold', color: 'var(--color-primary)' }}>
                {formatMoney(policyData.coverageAmount)}
              </div>
            </div>
            <div style={{ flex: 1, padding: '1.5rem', background: '#fafff9', borderRadius: '12px', border: '1px solid #bbf7d0' }}>
              <div style={{ color: '#065f46', fontSize: '0.9rem', marginBottom: '5px' }}>Monthly Premium</div>
              <div style={{ fontSize: '2rem', fontWeight: 'bold', color: '#065f46' }}>
                {formatMoney(policyData.premiumAmount)}
              </div>
            </div>
            <div style={{ flex: 1, padding: '1.5rem', background: '#f8fafc', borderRadius: '12px', border: '1px solid #e2e8f0' }}>
              <div style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '5px' }}>Valid Until</div>
              <div style={{ fontSize: '1.3rem', fontWeight: 'bold', color: '#0f172a' }}>
                {policyData.endDate}
              </div>
            </div>
          </div>
        </div>
      ) : (
        <div className="card" style={{ marginBottom: '2rem', textAlign: 'center', padding: '3rem' }}>
          <p style={{ color: '#94a3b8' }}>Loading policy details...</p>
        </div>
      )}

      {/* Claims History */}
      <div className="card" style={{ marginBottom: '2rem' }}>
        <h3 style={{ marginTop: 0, color: 'var(--color-primary)' }}>Claims History</h3>
        {claimsData && claimsData.length > 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {claimsData.map((claim, i) => (
              <div key={i} style={{
                display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                padding: '1rem 1.25rem', background: '#f8fafc', borderRadius: '10px',
                border: '1px solid #e2e8f0'
              }}>
                <div>
                  <div style={{ fontWeight: 600, color: '#0f172a' }}>{claim.claimType}</div>
                  <div style={{ fontSize: '0.85rem', color: '#64748b', marginTop: '2px' }}>
                    {claim.claimId} &nbsp;·&nbsp; {claim.submittedDate}
                  </div>
                  <div style={{ fontSize: '0.85rem', color: '#94a3b8', marginTop: '2px' }}>{claim.description}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontWeight: 700, fontSize: '1.1rem', color: 'var(--color-primary)' }}>
                    {formatMoney(claim.amount)}
                  </div>
                  <span style={{
                    background: statusColor(claim.status).bg,
                    color: statusColor(claim.status).color,
                    padding: '2px 10px', borderRadius: '20px', fontSize: '0.75rem', fontWeight: 'bold'
                  }}>
                    {claim.status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p style={{ color: '#94a3b8', textAlign: 'center', padding: '1rem 0' }}>
            {claimsData ? 'No claims on record.' : 'Loading claims...'}
          </p>
        )}
      </div>

      {/* AI Chat Agent */}
      <ChatAgent accessToken={accessToken} hasPremiumCoverage={hasPremiumCoverage} username={username} />
      <OBOChatAgent accessToken={accessToken} username={username} />

      {/* Premium Section */}
      {hasPremiumCoverage ? (
        <div className="card" style={{ background: '#0d6e6e', color: 'white', border: '1px solid #0a5555' }}>
          <h3 style={{ margin: '0 0 1.5rem', color: '#5eead4' }}>Premium Member Benefits</h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem' }}>
            {[
              { icon: '👨‍⚕️', label: 'Dedicated Health Advisor' },
              { icon: '🏨', label: 'Private Hospital Cover' },
              { icon: '🌍', label: 'International Coverage' },
              { icon: '💊', label: 'Extended Pharmacy Benefits' },
            ].map((b, i) => (
              <div key={i} style={{ padding: '1rem', background: 'rgba(255,255,255,0.1)', borderRadius: '10px' }}>
                <div style={{ fontSize: '1.5rem', marginBottom: '0.4rem' }}>{b.icon}</div>
                <strong>{b.label}</strong>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="card" style={{ textAlign: 'center', border: '1px dashed #c8e0e0' }}>
          <h3 style={{ color: 'var(--color-primary)' }}>Upgrade to Premium</h3>
          <p style={{ color: '#64748b' }}>Unlock international coverage, a dedicated health advisor, and extended benefits.</p>
          <button className="btn-secondary">View Eligibility</button>
        </div>
      )}
      </div>
    </div>
  );
}
