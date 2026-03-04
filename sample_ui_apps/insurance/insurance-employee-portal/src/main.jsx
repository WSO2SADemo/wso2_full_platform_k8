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
                clientId="Sv2JLfGWmHtrRunNOVFyFIty7qIa"
                clientSecret="0X7uAHEwJ86BRIAkAzlrzvyJrrqe9LRgGD6CHSUDtboa"
                baseUrl="https://is.wso2.com"
                scopes="openid profile ordinary privileged"
                enablePKCE={false}
                syncSession={true}
                >
                <App />
            </AsgardeoProvider>
        </BrowserRouter>
    </React.StrictMode>
);
