import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { AsgardeoProvider } from '@asgardeo/react';
import App from './App';
import config from './config';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <AsgardeoProvider
        clientId={config.isClientId}
        clientSecret={config.isClientSecret}
        baseUrl={config.isBaseUrl}
        scopes="openid profile email"
        enablePKCE={false}
        syncSession={true}
      >
        <App />
      </AsgardeoProvider>
    </BrowserRouter>
  </React.StrictMode>
);
