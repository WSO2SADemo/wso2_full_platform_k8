import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { SignedIn, SignedOut, SignInButton } from '@asgardeo/react';
import EmployeeDashboard from './pages/EmployeeDashboard';

function App() {
  return (
    <Routes>
      <Route path="/" element={
        <>
          <SignedOut>
            <div className="login-page-wrapper">
              <div className="card login-card">
                <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>🛡️</div>
                <h1 style={{ color: 'var(--color-primary)', margin: '0 0 10px 0' }}>Employee Portal</h1>
                <p style={{ color: 'var(--color-text-sub)', marginBottom: '2rem' }}>Secure Access for Staff Only</p>

                <SignInButton>
                  <button className="btn-primary" style={{ width: '100%' }}>Log In to Workspace</button>
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
