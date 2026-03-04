import React, { useEffect, useState } from 'react';
import { Routes, Route } from 'react-router-dom';
import { SignedIn, SignedOut, SignInButton, useAsgardeo } from '@asgardeo/react';
import EmployeeDashboard from './pages/EmployeeDashboard';

function App() {
//   const {signInSilently} = useAsgardeo();
//   useEffect(() => {
//     (async () => {
//       try {
//         const response = await signInSilently();

//         if (!response) {
//           console.warn('User is not authenticated');
//         }
//       } catch (error) {
//         console.error('Error during silent sign-in:', error);
//       }
//     })();
//   }, []);

  return (
    <Routes>
      <Route path="/" element={
        <>
          <SignedOut>
            {/* ✅ FIXED: Uses CSS class 'login-page-wrapper' instead of inline blue style */}
            <div className="login-page-wrapper">
              <div className="card login-card">
                <img 
                  src="https://cdn.statically.io/gh/ramindu90/imagerepo/main/bank_logo.png" 
                  alt="City Bank" 
                  style={{ height: '60px', marginBottom: '1.5rem' }} 
                />
                <h1 style={{ color: 'var(--color-primary)', margin: '0 0 10px 0' }}>Employee Portal</h1>
                <p style={{ color: 'var(--color-text-sub)', marginBottom: '2rem' }}>Secure Access for Staff Only</p>
                
                <SignInButton>
                  <button className="btn-primary" style={{width: '100%'}}>Log In to Workspace</button>
                </SignInButton>
              </div>
            </div>
          </SignedOut>
          <SignedIn><EmployeeDashboard /></SignedIn>
        </>
      } />
    </Routes>
  );
}

export default App;