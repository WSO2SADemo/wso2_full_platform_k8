import React, { useEffect, useState } from 'react';
import { useAsgardeo, SignedIn, User } from '@asgardeo/react';

export default function CustomerDashboard() {
  const { state, getAccessToken, getDecodedIdToken, isSignedIn, isLoading } = useAsgardeo();
  
  // State
  const [isPremier, setIsPremier] = useState(false);
  const [roles, setRoles] = useState([]);
  const [country, setCountry] = useState(null);
  const [mobile, setMobile] = useState(null);
  const [accessToken, setAccessToken] = useState(null);
  const [username, setUsername] = useState(null);
  const [accountData, setAccountData] = useState(null);


  // --- 1. AUTH & TOKEN LOGIC (Unchanged) ---
  useEffect(() => {
    if (!isSignedIn || isLoading) {
      setRoles([]);
      return;
    }

    (async () => {
      try {
        const token = await getAccessToken();
        const idToken = await getDecodedIdToken();
        
        console.log("=== 👤 DECODED ID TOKEN ===", idToken);
        
        const parsedAccess = parseJwt(token);
        const scopeString = parsedAccess?.scope || ""; 
        const scopeArray = scopeString.split(" ").filter(s => s); 
        
        setRoles(scopeArray);
        setAccessToken(token);
        setCountry(idToken.address?.country || "Not Provided");
        setMobile(idToken.Mobile || "Not Provided");
        setUsername(idToken.username || idToken.email || "Unknown User");

        if (scopeArray.includes("view_premier_facilities")) {
          setIsPremier(true);
        } else {
          setIsPremier(false);
        }

      } catch (error) {
        console.error('Error fetching roles:', error);
        setRoles([]);
      }
    })();
  }, [getAccessToken, isSignedIn, isLoading, getDecodedIdToken]);


  // --- 2. API CALL LOGIC (Unchanged) ---
  useEffect(() => {
    if (accessToken && username && username !== "Unknown User") {
      const fetchAccountDetails = async () => {
        try {
          console.log("🚀 Calling Banking API...");
          
          const response = await fetch('https://localhost:8245/bank/1.0.0/account', {
            method: 'POST',
            headers: {
              'accept': '*/*',
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({ username: username })
          });

          if (!response.ok) throw new Error(`API Error: ${response.status}`);

          const data = await response.json();
          console.log("🏦 API Response:", data);
          setAccountData(data);

        } catch (error) {
          console.error("🔴 Failed to fetch account details:", error);
        }
      };
      fetchAccountDetails();
    }
  }, [accessToken, username]);


  // Helper: Decode JWT
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

  // Helper: Format Currency
  const formatMoney = (amount) => {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);
  };

  return (
    <div style={{ maxWidth: '1000px', margin: '0 auto', padding: '2rem' }}>
      
      {/* Header Section */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '3rem' }}>
        <div>
          <h1 style={{ margin: 0, color: 'var(--color-primary)' }}>My Dashboard</h1>
          <div style={{ color: 'var(--color-text-sub)', fontSize: '1.1rem', marginTop: '5px' }}>
            <SignedIn>
              <User>
                {(user) => (
                  <div>
                    <p>Welcome back, <strong>{user.name?.givenName || username}</strong></p>
                    <div style={{fontSize: '0.9rem', opacity: 0.8}}>
                        <span>📍 {country}</span> | <span>📱 {mobile}</span>
                    </div>
                  </div>
                )}
              </User>
            </SignedIn>
          </div>
        </div>
        
        {isPremier && (
          <div style={{ 
            background: 'linear-gradient(135deg, #fbbf24 0%, #d97706 100%)', 
            color: 'white', padding: '8px 16px', borderRadius: '50px', fontWeight: 'bold',
            boxShadow: '0 4px 12px rgba(251, 191, 36, 0.4)'
          }}>
            👑 Premier Member
          </div>
        )}
      </div>

      {/* ✅ UPDATED: Accounts Grid using API Data */}
      {accountData ? (
        <div className="card" style={{ marginBottom: '2rem' }}>
            <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center'}}>
                <h3 style={{ marginTop: 0, color: '#0a192f' }}>Account Overview</h3>
                {/* Status Badge */}
                <span style={{
                    background: accountData.status === 'ACTIVE' ? '#dcfce7' : '#fee2e2',
                    color: accountData.status === 'ACTIVE' ? '#166534' : '#991b1b',
                    padding: '4px 12px', borderRadius: '20px', fontSize: '0.8rem', fontWeight: 'bold'
                }}>
                    {accountData.status}
                </span>
            </div>
            
            <p style={{color: '#64748b', fontSize: '0.9rem', marginBottom: '20px'}}>
                Account No: <span style={{fontFamily: 'monospace', fontWeight: 'bold'}}>{accountData.accountNumber}</span>
            </p>

            <div style={{ display: 'flex', gap: '2rem', flexWrap: 'wrap' }}>
                {/* 1. Savings Balance */}
                <div style={{ flex: 1, padding: '1.5rem', background: '#f8fafc', borderRadius: '12px', border: '1px solid #e2e8f0' }}>
                    <div style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '5px' }}>Savings Balance</div>
                    <div style={{ fontSize: '2rem', fontWeight: 'bold', color: '#0a192f' }}>
                        {formatMoney(accountData.savingsBalance)}
                    </div>
                </div>

                {/* 2. Current Account Balance */}
                <div style={{ flex: 1, padding: '1.5rem', background: '#fffbeb', borderRadius: '12px', border: '1px solid #fcd34d' }}>
                    <div style={{ color: '#92400e', fontSize: '0.9rem', marginBottom: '5px' }}>Current Account</div>
                    <div style={{ fontSize: '2rem', fontWeight: 'bold', color: '#b45309' }}>
                        {formatMoney(accountData.currentAccountBalance)}
                    </div>
                </div>
            </div>
        </div>
      ) : (
        /* Loading / Fallback State */
        <div className="card" style={{ marginBottom: '2rem', textAlign: 'center', padding: '3rem' }}>
            <div className="spinner"></div> {/* Ensure you have CSS for spinner or use text */}
            <p style={{color: '#94a3b8'}}>Loading account details...</p>
        </div>
      )}

      {/* Premier Section */}
      {isPremier ? (
        <div className="card" style={{ background: '#0a192f', color: 'white', border: '1px solid #1e293b' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
            <h3 style={{ margin: 0, color: '#fbbf24' }}>Premier Exclusive Benefits</h3>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '1.5rem' }}>
            <div style={{ padding: '1rem', background: 'rgba(255,255,255,0.1)', borderRadius: '12px' }}>
                <div style={{ fontSize: '1.5rem', marginBottom: '0.5rem' }}>🤵</div>
                <strong>Private Wealth Manager</strong>
            </div>
            <div style={{ padding: '1rem', background: 'rgba(255,255,255,0.1)', borderRadius: '12px' }}>
                <div style={{ fontSize: '1.5rem', marginBottom: '0.5rem' }}>✈️</div>
                <strong>Airport Lounge Access</strong>
            </div>
          </div>
        </div>
      ) : (
        <div className="card" style={{ textAlign: 'center', background: 'white', border: '1px dashed #cbd5e1' }}>
            <h3 style={{ color: '#0a192f' }}>Upgrade to Premier</h3>
            <p style={{ color: '#64748b' }}>Unlock exclusive rates, a private wealth manager, and global travel perks.</p>
            <button className="btn-secondary">View Eligibility</button>
        </div>
      )}
    </div>
  );
}