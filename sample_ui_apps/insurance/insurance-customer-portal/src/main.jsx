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
                clientId="ULyXO3hl_sBIJmv4kkfzqrc4uDga"
                clientSecret="Bt72nzcni5gwtqYKAEtElJXoxB1UIFePIpTsxYVvffAa"
                baseUrl="https://is.wso2.com"
                scopes="openid profile email phone address ext_privileged int_ordinary"
                enablePKCE={false}
                syncSession={true}
            >
                <App />
            </AsgardeoProvider>
        </BrowserRouter>
    </React.StrictMode>
);
