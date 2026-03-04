import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { SignedIn, SignedOut } from '@asgardeo/react';
import Navbar from './components/Navbar';
import GuestHome from './pages/GuestHome';
import CustomerDashboard from './pages/CustomerDashboard';

function App() {
  return (
    <div className="insurance-app">
      <Navbar />
      <div className="container" style={{ maxWidth: '1200px', margin: '0 auto', padding: '20px' }}>
        <Routes>
          <Route path="/" element={
            <>
              <SignedOut><GuestHome /></SignedOut>
              <SignedIn><CustomerDashboard /></SignedIn>
            </>
          } />
        </Routes>
      </div>
    </div>
  );
}

export default App;
