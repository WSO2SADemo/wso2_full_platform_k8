import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { AsgardeoProvider } from '@asgardeo/react';
import App from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')).render(
    <React.StrictMode>
        <BrowserRouter>
            <AsgardeoProvider
                clientId="3J2QFbVULKqpg4FephPNlFEqCgIa"
                clientSecret="HVyVkfRPdvGfMS5UWJ0aNODAKluZ5OdrDTMj30PFEKIa"
                baseUrl="https://is.wso2.com"
                scopes="openid profile ordinary_priviledges restricted_priviladges"
                syncSession={true}
                disableTrySignInSilently={false}
                >
                <App />
            </AsgardeoProvider>
        </BrowserRouter>
    </React.StrictMode>
);
