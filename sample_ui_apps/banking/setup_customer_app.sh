#!/bin/bash

# 1. Create Directory Structure
echo "Creating Bank Customer Portal..."
mkdir -p bank-customer-portal/src/components
mkdir -p bank-customer-portal/src/pages
cd bank-customer-portal

# 2. Create package.json
cat > package.json << 'EOF'
{
  "name": "bank-customer-portal",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@asgardeo/react": "^3.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.22.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.64",
    "@types/react-dom": "^18.2.21",
    "@vitejs/plugin-react": "^4.2.1",
    "vite": "^5.1.6"
  }
}
EOF

# 3. Create vite.config.js
cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: { port: 3000 }
})
EOF

# 4. Create index.html
cat > index.html << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>City Bank - Customer Portal</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# 5. Create src/main.jsx
cat > src/main.jsx << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { AsgardeoProvider } from '@asgardeo/react';
import App from './App';
import './index.css';

const config = {
    clientID: "YOUR_CUSTOMER_CLIENT_ID",
    baseUrl: "https://api.asgardeo.io/t/YOUR_ORG_NAME",
    signInRedirectURL: "http://localhost:3000",
    signOutRedirectURL: "http://localhost:3000",
    scope: [ "openid", "profile" ]
};

ReactDOM.createRoot(document.getElementById('root')).render(
    <React.StrictMode>
        <BrowserRouter>
            <AsgardeoProvider {...config}>
                <App />
            </AsgardeoProvider>
        </BrowserRouter>
    </React.StrictMode>
);
EOF

# 6. Create src/App.jsx
cat > src/App.jsx << 'EOF'
import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { SignedIn, SignedOut } from '@asgardeo/react';
import Navbar from './components/Navbar';
import GuestHome from './pages/GuestHome';
import CustomerDashboard from './pages/CustomerDashboard';

function App() {
  return (
    <div className="bank-app">
      <Navbar />
      <div className="container" style={{maxWidth: '1200px', margin: '0 auto', padding: '20px'}}>
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
EOF

# 7. Create src/components/Navbar.jsx
cat > src/components/Navbar.jsx << 'EOF'
import React from 'react';
import { useAsgardeo, SignInButton } from '@asgardeo/react';

export default function Navbar() {
  const { state, signOut } = useAsgardeo();
  const styles = {
    nav: { display: 'flex', justifyContent: 'space-between', padding: '15px 30px', background: '#004d40', color: 'white', alignItems: 'center' },
    btnLogin: { padding: '8px 16px', background: '#ffca28', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }
  };

  return (
    <nav style={styles.nav}>
      <h3>City Bank</h3>
      <div>
        {state.isAuthenticated ? (
          <div style={{display: 'flex', alignItems: 'center', gap: '15px'}}>
            <span>{state.username}</span>
            <button onClick={() => signOut()}>Sign Out</button>
          </div>
        ) : (
          <SignInButton><button style={styles.btnLogin}>Login</button></SignInButton>
        )}
      </div>
    </nav>
  );
}
EOF

# 8. Create src/pages/GuestHome.jsx
cat > src/pages/GuestHome.jsx << 'EOF'
import React from 'react';
export default function GuestHome() {
  const products = [
    { title: "Home Loans", rate: "12%" },
    { title: "Fixed Deposits", rate: "8.5%" },
    { title: "Vehicle Leasing", rate: "14%" }
  ];
  return (
    <div style={{padding: '2rem'}}>
      <h1>Welcome to City Bank</h1>
      <div style={{display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '20px'}}>
        {products.map((p, i) => (
          <div key={i} style={{border: '1px solid #ddd', padding: '20px', borderRadius: '8px'}}>
            <h3>{p.title}</h3>
            <p>Interest: {p.rate}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
EOF

# 9. Create src/pages/CustomerDashboard.jsx
cat > src/pages/CustomerDashboard.jsx << 'EOF'
import React from 'react';
export default function CustomerDashboard() {
  return (
    <div style={{padding: '2rem'}}>
      <h2>My Accounts</h2>
      <div style={{background: '#00695c', color: 'white', padding: '20px', borderRadius: '10px', width: '300px'}}>
        <h4>Savings Account</h4>
        <h1>$12,450.00</h1>
      </div>
    </div>
  );
}
EOF

# 10. Create basic CSS
cat > src/index.css << 'EOF'
body { margin: 0; font-family: sans-serif; background: #f5f5f5; }
EOF

echo "Bank Customer Portal Created! Run 'npm install' then 'npm run dev' to start."