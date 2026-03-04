import React, { useEffect, useState } from 'react';
import { useAsgardeo, User, SignOutButton } from '@asgardeo/react';

export default function EmployeeDashboard() {
  const { state, getAccessToken, getIDToken, getDecodedIdToken, isSignedIn, isLoading } = useAsgardeo();

  const [searchTerm, setSearchTerm] = useState("");
  const [customers, setCustomers] = useState([]); 
  
  const [hasDeletePermission, setDeletePermission] = useState(false);
  const [hasViewPermission, setViewPermission] = useState(false);
  const [isCheckingPermissions, setIsCheckingPermissions] = useState(true);
  
  const [accessToken, setAccessToken] = useState(null);
  const [username, setUsername] = useState(null);

  // 🆕 STATE FOR CONFIRMATION MODAL
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [userToDelete, setUserToDelete] = useState(null);

  // 🆕 STATE FOR SUCCESS MODAL
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [successMessage, setSuccessMessage] = useState("");

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

  const formatMoney = (amount) => {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount);
  };

  // --- 1. AUTH & PERMISSION LOGIC ---
  useEffect(() => {
      if (!isSignedIn || isLoading) return;
  
      (async () => {
        try {
          const token = await getAccessToken();
          const idToken = await getDecodedIdToken();
          const parsedAccess = parseJwt(token);
          const scopeString = parsedAccess?.scope || ""; 
          const scopeArray = scopeString.split(" ");
          console.log("🛂 Access Token:", token);
          // Logic determines if it shows username or email
          setUsername(idToken.username || idToken.email || "Unknown User");
          setAccessToken(token); 
          console.log("👉 Employee Scopes:", scopeArray);

          if (scopeArray.includes("ordinary_priviledges")) setViewPermission(true);
          else setViewPermission(false);

          if (scopeArray.includes("restricted_priviladges")) setDeletePermission(true);
          else setDeletePermission(false);
  
        } catch (error) {
          console.error('Error fetching permissions:', error);
          setViewPermission(false);
          setDeletePermission(false);
        } finally {
          setIsCheckingPermissions(false);
        }
      })();
  }, [getAccessToken, isSignedIn, isLoading, getDecodedIdToken]);


  // --- 2. API CALL: Fetch Accounts ---
  useEffect(() => {
    if (accessToken && hasViewPermission) {
      const fetchAccounts = async () => {
        try {
          console.log("🚀 Fetching customer accounts...");
          const response = await fetch('https://localhost:8245/bankapi/1.0.0/accounts', {
            method: 'GET',
            headers: {
              'accept': '*/*',
              'Authorization': `Bearer ${accessToken}`
            }
          });

          if (!response.ok) throw new Error(`API Error: ${response.status}`);
          const data = await response.json();
          setCustomers(data);
        } catch (error) {
          console.error("🔴 Failed to fetch accounts:", error);
        }
      };
      fetchAccounts();
    }
  }, [accessToken, hasViewPermission]);


  // --- 3. DELETE LOGIC ---
  
  const initiateDelete = (targetUsername) => {
    setUserToDelete(targetUsername);
    setShowDeleteModal(true);
  };

  const confirmDelete = async () => {
    if (!userToDelete) return;

    try {
      console.log(`🗑️ Deleting user: ${userToDelete}...`);
      
      const response = await fetch('https://localhost:8245/bankapi/1.0.0/account/delete', {
        method: 'POST',
        headers: {
          'accept': '*/*',
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        body: JSON.stringify({ 
          username: userToDelete 
        })
      });

      if (!response.ok) throw new Error(`Delete Failed: ${response.status}`);

      const result = await response.json();
      console.log("✅ Delete Result:", result);
      
      // Update UI
      setCustomers(customers.filter(c => c.username !== userToDelete));
      
      // Close Confirmation Modal
      closeDeleteModal();

      // ✅ OPEN SUCCESS MODAL
      setSuccessMessage(result.message || `Successfully deleted account for ${userToDelete}`);
      setShowSuccessModal(true);

    } catch (error) {
      console.error("🔴 Delete API Error:", error);
      alert("Failed to delete account. Check console for details."); 
      closeDeleteModal();
    }
  };

  const closeDeleteModal = () => {
    setShowDeleteModal(false);
    setUserToDelete(null);
  };
  
  const closeSuccessModal = () => {
    setShowSuccessModal(false);
    setSuccessMessage("");
  };


  return (
    <div style={{display: 'flex', height: '100vh', background: '#f5f5f5', position: 'relative'}}>
      {/* Sidebar */}
      <div style={{width: '260px', background: '#0a192f', color: 'white', padding: '30px 20px', display: 'flex', flexDirection: 'column'}}>
        <h3 style={{marginBottom: '40px', color: '#fbbf24'}}>🛡️ Admin Portal</h3>
        <div style={{flex: 1}}>
            <p style={{padding: '12px', background: 'rgba(255,255,255,0.1)', borderRadius: '12px'}}>Dashboard</p>
        </div>
        
        <User>
            {(user) => (
                <div style={{ marginBottom: '20px', fontSize: '0.9rem', opacity: 0.8, lineHeight: '1.6' }}>
                    <div style={{color: '#94a3b8', fontSize: '0.75rem'}}>LOGGED IN AS</div>
                    <div style={{fontWeight: 'bold', fontSize: '1rem', color: 'white'}}>
                        {user.given_name || user.username} {user.family_name}
                    </div>
                    
                    {/* ✅ DISPLAY THE LOGGED IN USERNAME FROM STATE */}
                    <div style={{fontSize: '0.8rem', fontStyle: 'italic', color: '#cbd5e1', marginTop: '4px'}}>
                        {username}
                    </div>
                    
                    <div style={{marginTop: '10px'}}>
                        <span style={{
                            background: hasDeletePermission ? '#fbbf24' : '#64748b',
                            color: hasDeletePermission ? '#0a192f' : 'white',
                            padding: '2px 8px', borderRadius: '4px', fontSize: '0.75rem', fontWeight: 'bold'
                        }}>
                            {hasDeletePermission ? "MANAGER" : (hasViewPermission ? "CASHIER" : "RESTRICTED")}
                        </span>
                    </div>
                </div>
            )}
        </User>
        <SignOutButton 
            className="btn-secondary" 
            style={{border: '1px solid #ef5350', color: '#ef5350', width: '100%', backgroundColor: 'transparent'}}
        >
            Log Out
        </SignOutButton>        
      </div>

      {/* Main Content */}
      <div style={{flex: 1, padding: '40px', overflowY: 'auto'}}>
        
        {isCheckingPermissions ? (
             <div style={{textAlign: 'center', marginTop: '100px', color: '#64748b'}}>Checking permissions...</div>
        ) : hasViewPermission ? (
            <>
                <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px'}}>
                    <h2 style={{margin: 0, color: '#0a192f'}}>Customer Overview</h2>
                    <input 
                        type="text" 
                        placeholder="🔍 Search accounts..." 
                        onChange={(e) => setSearchTerm(e.target.value)}
                        style={{width: '300px'}}
                    />
                </div>

                <div className="card" style={{padding: '0', overflow: 'hidden'}}>
                    <table style={{width: '100%', borderCollapse: 'collapse'}}>
                        <thead style={{background: '#f1f5f9'}}>
                            <tr style={{textAlign: 'left', color: '#64748b', fontSize: '0.9rem'}}>
                                <th style={{padding: '20px'}}>Username</th>
                                <th style={{padding: '20px'}}>Account No</th>
                                <th style={{padding: '20px'}}>Savings</th>
                                <th style={{padding: '20px'}}>Current</th>
                                <th style={{padding: '20px'}}>Status</th>
                                {hasDeletePermission && <th style={{textAlign: 'right', paddingRight: '20px'}}>Actions</th>}
                            </tr>
                        </thead>
                        <tbody>
                            {customers
                                .filter(c => c.username?.toLowerCase().includes(searchTerm.toLowerCase()))
                                .map(c => (
                                <tr key={c.accountNumber} style={{borderBottom: '1px solid #e2e8f0'}}>
                                    <td style={{padding: '20px', fontWeight: '600'}}>{c.username}</td>
                                    <td style={{padding: '20px', color: '#64748b', fontFamily: 'monospace'}}>{c.accountNumber}</td>
                                    <td style={{padding: '20px', fontWeight: 'bold'}}>{formatMoney(c.savingsBalance)}</td>
                                    <td style={{padding: '20px', color: '#b45309'}}>{formatMoney(c.currentAccountBalance)}</td>
                                    <td style={{padding: '20px'}}>
                                        <span style={{
                                            padding: '5px 12px', borderRadius: '20px', fontSize: '0.8rem', fontWeight: 'bold',
                                            background: c.status === 'ACTIVE' ? '#dcfce7' : '#fee2e2',
                                            color: c.status === 'ACTIVE' ? '#166534' : '#991b1b'
                                        }}>{c.status}</span>
                                    </td>
                                    {hasDeletePermission && (
                                        <td style={{textAlign: 'right', paddingRight: '20px'}}>
                                            <button 
                                                onClick={() => initiateDelete(c.username)}
                                                style={{
                                                    background: '#fee2e2', color: '#dc2626', border: 'none', 
                                                    padding: '8px 16px', borderRadius: '8px', cursor: 'pointer', fontWeight: '600'
                                                }}
                                            >
                                                Delete
                                            </button>
                                        </td>
                                    )}
                                </tr>
                            ))}
                        </tbody>
                    </table>
                    {customers.length === 0 && (
                        <div style={{padding: '40px', textAlign: 'center', color: '#64748b'}}>No accounts found.</div>
                    )}
                </div>
            </>
        ) : (
            <div style={{textAlign: 'center', marginTop: '100px', padding: '40px', background: '#fff1f2', borderRadius: '12px', border: '1px solid #fda4af'}}>
                <div style={{fontSize: '3rem', marginBottom: '10px'}}>🚫</div>
                <h2 style={{color: '#9f1239', margin: 0}}>Access Denied</h2>
            </div>
        )}
      </div>

      {/* ⚠️ MODAL 1: DELETE CONFIRMATION */}
      {showDeleteModal && (
        <div style={{
            position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.5)', zIndex: 1000,
            display: 'flex', justifyContent: 'center', alignItems: 'center', backdropFilter: 'blur(4px)'
        }}>
            <div style={{
                backgroundColor: 'white', padding: '30px', borderRadius: '16px', width: '400px',
                textAlign: 'center', boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1)'
            }}>
                <div style={{fontSize: '3rem', marginBottom: '10px'}}>⚠️</div>
                <h3 style={{color: '#1f2937', marginTop: 0}}>Confirm Deletion</h3>
                <p style={{color: '#6b7280'}}>
                    Permanently delete account for <strong style={{color: '#111827'}}>{userToDelete}</strong>?
                </p>
                <div style={{marginTop: '30px', display: 'flex', gap: '15px', justifyContent: 'center'}}>
                    <button onClick={closeDeleteModal} style={{
                        padding: '10px 20px', borderRadius: '8px', border: '1px solid #d1d5db',
                        background: 'white', color: '#374151', cursor: 'pointer', fontWeight: '600'
                    }}>Cancel</button>
                    <button onClick={confirmDelete} style={{
                        padding: '10px 20px', borderRadius: '8px', border: 'none',
                        background: '#dc2626', color: 'white', cursor: 'pointer', fontWeight: '600'
                    }}>Confirm Delete</button>
                </div>
            </div>
        </div>
      )}

      {/* ✅ MODAL 2: SUCCESS MESSAGE */}
      {showSuccessModal && (
        <div style={{
            position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.5)', zIndex: 1000,
            display: 'flex', justifyContent: 'center', alignItems: 'center', backdropFilter: 'blur(4px)'
        }}>
            <div style={{
                backgroundColor: 'white', padding: '30px', borderRadius: '16px', width: '400px',
                textAlign: 'center', boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1)',
                borderTop: '6px solid #16a34a' // Green Top Border
            }}>
                <div style={{fontSize: '3rem', marginBottom: '10px'}}>✅</div>
                <h3 style={{color: '#16a34a', marginTop: 0}}>Deletion Successful</h3>
                <p style={{color: '#4b5563', lineHeight: '1.5'}}>
                    {successMessage}
                </p>
                <div style={{marginTop: '30px'}}>
                    <button 
                        onClick={closeSuccessModal}
                        style={{
                            padding: '10px 25px', borderRadius: '8px', border: 'none',
                            background: '#16a34a', color: 'white', cursor: 'pointer', fontWeight: '600',
                            width: '100%', fontSize: '1rem'
                        }}
                    >
                        Done
                    </button>
                </div>
            </div>
        </div>
      )}

    </div>
  );
}