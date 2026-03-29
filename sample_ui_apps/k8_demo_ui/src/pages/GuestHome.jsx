import React from 'react';
import { useAsgardeo } from '@asgardeo/react';
import config from '../config';

const GATEWAYS = {
  wso2K8:    { color: '#FF7300' },
  envoy:     { color: '#00adef' },
  universal: { color: '#6366f1' },
  azure:     { color: '#0078d4' },
};

export default function GuestHome() {
  const { signIn } = useAsgardeo();

  return (
    <div className="guest-page">
      <div style={{ fontSize: '3rem' }}>🏥</div>
      <h1>Medical API Gateway Demo</h1>
      <p>
        A live demonstration of medical backend services exposed through four
        different API gateways. Sign in with your WSO2 IS account to explore
        each integration.
      </p>

      <div className="gateway-pills">
        <span className="gateway-pill" style={{ background: GATEWAYS.wso2K8.color }}>
          WSO2 K8 Gateway
        </span>
        <span className="gateway-pill" style={{ background: GATEWAYS.envoy.color }}>
          Envoy Gateway
        </span>
        <span className="gateway-pill" style={{ background: GATEWAYS.azure.color }}>
          Azure APIM
        </span>
        <span className="gateway-pill" style={{ background: GATEWAYS.universal.color }}>
          Universal Gateway
        </span>
      </div>

      <div style={{ display: 'flex', gap: '1.5rem', marginTop: '1.5rem', flexWrap: 'wrap', justifyContent: 'center', maxWidth: '680px' }}>
        {[
          { icon: '👤', label: 'Patients',       desc: 'WSO2 K8 + Envoy Gateway · Auth Code' },
          { icon: '💊', label: 'Prescriptions',  desc: 'WSO2 Universal Gateway · Auth Code' },
          { icon: '📅', label: 'Appointments',   desc: 'Azure APIM · Client Credentials' },
        ].map(item => (
          <div key={item.label} className="card" style={{ flex: '1', minWidth: '180px', textAlign: 'center' }}>
            <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>{item.icon}</div>
            <strong>{item.label}</strong>
            <p style={{ fontSize: '0.8rem', color: 'var(--color-text-sub)', margin: '4px 0 0' }}>{item.desc}</p>
          </div>
        ))}
      </div>

      <button className="btn-primary" style={{ marginTop: '2rem', fontSize: '1rem' }} onClick={() => signIn()}>
        Sign In with WSO2 IS →
      </button>
    </div>
  );
}
