import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { SignedIn, SignedOut } from '@asgardeo/react';
import Navbar from './components/Navbar';
import GuestHome from './pages/GuestHome';
import CustomerPortal from './pages/CustomerPortal';

function App() {
  return (
    <div className="insurance-app">
      <Navbar />
      <div className="container" style={{ maxWidth: '1400px', margin: '0 auto', padding: '20px' }}>
        <Routes>
          <Route path="/" element={
            <>
              <SignedOut><GuestHome /></SignedOut>
              <SignedIn><CustomerPortal /></SignedIn>
            </>
          } />
        </Routes>
      </div>
    </div>
  );
}

export default App;
