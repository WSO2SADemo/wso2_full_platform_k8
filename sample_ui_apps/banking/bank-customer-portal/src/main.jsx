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
                clientId="FtKsoWz0cw88j3E5c0vhLMS1Y8sa"
                clientSecret="Ofum4SUGt8gTRmxEHREfCo8FCW0V5F1dISUcfTtTCtUa"
                baseUrl="https://localhost:9444"
                scopes="openid profile ordinary view_premier_facilities address phone email"
                syncSession={true}
                >
                <App />
            </AsgardeoProvider>
        </BrowserRouter>
    </React.StrictMode>
);
