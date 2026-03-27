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
                clientSecret="qHJy4bqtYkaw0R4K36oGm3z1CTwaJ5TsxMyLJZK49MIa"
                baseUrl={config.isBaseUrl}
                scopes="openid profile privileged_api_scope ordinary_api_scope"
                enablePKCE={false}
                syncSession={true}
                >
                <App />
            </AsgardeoProvider>
        </BrowserRouter>
    </React.StrictMode>
);
