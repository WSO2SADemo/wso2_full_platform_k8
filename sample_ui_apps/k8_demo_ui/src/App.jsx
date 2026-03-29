import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { SignedIn, SignedOut } from '@asgardeo/react';
import Navbar from './components/Navbar';
import GuestHome from './pages/GuestHome';
import Dashboard from './pages/Dashboard';

function App() {
  return (
    <div className="app">
      <Navbar />
      <div className="page-content">
        <Routes>
          <Route path="/" element={
            <>
              <SignedOut><GuestHome /></SignedOut>
              <SignedIn><Dashboard /></SignedIn>
            </>
          } />
        </Routes>
      </div>
    </div>
  );
}

export default App;
