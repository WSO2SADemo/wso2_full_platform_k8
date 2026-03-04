#!/bin/bash

# 1. Create Directory Structure
echo "Creating Bank Employee Portal..."
mkdir -p bank-employee-portal/src/pages
cd bank-employee-portal

# 2. Create package.json
cat > package.json << 'EOF'
{
  "name": "bank-employee-portal",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "dependencies": {
    "@asgardeo/react": "^3.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.22.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.1",
    "vite": "^5.1.6"
  }
}
EOF

# 3. Create vite.config.js (Port 3001)
cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: { port: 3001 }
})
EOF

# 4. Create index.html
cat > index.html << 'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>City Bank - Employee Portal</title>
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
    clientID: "YOUR_EMPLOYEE_CLIENT_ID",
    baseUrl: "https://api.asgardeo.io/t/YOUR_ORG_NAME",
    signInRedirectURL: "http://localhost:3001",
    signOutRedirectURL: "http://localhost:3001",
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
import { SignedIn, SignedOut, SignInButton } from '@asgardeo/react';
import EmployeeDashboard from './pages/EmployeeDashboard';

function App() {
  return (
    <Routes>
      <Route path="/" element={
        <>
          <SignedOut>
            <div style={{height: '100vh', display: 'flex', justifyContent: 'center', alignItems: 'center', background: '#e8eaf6'}}>
                <h1>Employee Login</h1>
                <SignInButton><button>Login to Portal</button></SignInButton>
            </div>
          </SignedOut>
          <SignedIn><EmployeeDashboard /></SignedIn>
        </>
      } />
    </Routes>
  );
}
export default App;
EOF

# 7. Create src/pages/EmployeeDashboard.jsx
cat > src/pages/EmployeeDashboard.jsx << 'EOF'
import React, { useState } from 'react';
import { useAsgardeo } from '@asgardeo/react';

const allCustomers = [
    { id: 1, name: "Alice Johnson", account: "SAV-001", balance: "$5,200", status: "Active" },
    { id: 2, name: "Bob Smith", account: "LN-889", balance: "$150,000", status: "Pending" }
];

export default function EmployeeDashboard() {
  const { signOut, state } = useAsgardeo();
  const [searchTerm, setSearchTerm] = useState("");

  return (
    <div style={{display: 'flex', height: '100vh'}}>
      <div style={{width: '250px', background: '#1a237e', color: 'white', padding: '20px'}}>
        <h3>Admin Portal</h3>
        <button onClick={() => signOut()} style={{marginTop: '20px'}}>Log Out</button>
      </div>
      <div style={{flex: 1, padding: '40px'}}>
        <h2>Customer Accounts</h2>
        <input 
            type="text" 
            placeholder="Search..." 
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{padding: '10px', marginBottom: '20px'}}
        />
        <table style={{width: '100%', border: '1px solid #ddd'}}>
            <thead><tr><th>Name</th><th>Balance</th><th>Status</th></tr></thead>
            <tbody>
                {allCustomers.filter(c => c.name.toLowerCase().includes(searchTerm.toLowerCase())).map(c => (
                    <tr key={c.id}>
                        <td>{c.name}</td>
                        <td>{c.balance}</td>
                        <td>{c.status}</td>
                    </tr>
                ))}
            </tbody>
        </table>
      </div>
    </div>
  );
}
EOF

# 8. Create CSS
cat > src/index.css << 'EOF'
body { margin: 0; font-family: sans-serif; }
table { border-collapse: collapse; }
td, th { padding: 10px; border: 1px solid #ccc; }
EOF

echo "Bank Employee Portal Created! Run 'npm install' then 'npm run dev' to start."