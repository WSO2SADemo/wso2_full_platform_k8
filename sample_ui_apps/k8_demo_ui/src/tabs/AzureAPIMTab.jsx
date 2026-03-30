import React, { useState } from 'react';
import { TokenPanel, ResponsePanel } from '../components/TokenPanel';
import config from '../config';

const MODES = [
  { value: 'all',  label: 'List All Appointments' },
  { value: 'byId', label: 'Get by Appointment ID' },
];

const COLOR = '#0078d4';

export default function AzureAPIMTab() {
  const [authMode, setAuthMode] = useState('subscriptionKey'); // 'bearer' | 'subscriptionKey'

  // Bearer token state
  const [azureToken, setAzureToken]     = useState(null);
  const [tokenLoading, setTokenLoading] = useState(false);
  const [tokenError, setTokenError]     = useState(null);

  // Subscription key state
  const [subscriptionKey, setSubscriptionKey] = useState(config.azureSubscriptionKey || '');

  // API call state
  const [mode, setMode]                   = useState('all');
  const [appointmentId, setAppointmentId] = useState('APT001');
  const [response, setResponse]           = useState(null);
  const [status, setStatus]               = useState(null);
  const [apiLoading, setApiLoading]       = useState(false);
  const [apiError, setApiError]           = useState(null);

  const fetchToken = async () => {
    setTokenLoading(true); setTokenError(null); setAzureToken(null);
    try {
      const body = new URLSearchParams({
        grant_type:    'client_credentials',
        client_id:     config.azureClientId,
        client_secret: config.azureClientSecret,
        scope:         config.azureScope,
      });
      const res = await fetch(
        `https://login.microsoftonline.com/${config.azureTenantId}/oauth2/v2.0/token`,
        { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body }
      );
      const data = await res.json();
      if (!res.ok) throw new Error(data.error_description || data.error || `HTTP ${res.status}`);
      setAzureToken(data.access_token);
    } catch (e) {
      setTokenError(e.message);
    } finally {
      setTokenLoading(false);
    }
  };

  const AZURE_REAL_BASE = 'https://apimserviceramindus.azure-api.net/appointments';

  const getUrl = () => {
    const base = `${config.azureBase}/appointments`;
    if (mode === 'byId') return `${base}/${appointmentId}`;
    return base;
  };

  const getDisplayUrl = () => {
    if (mode === 'byId') return `${AZURE_REAL_BASE}/${appointmentId}`;
    return AZURE_REAL_BASE;
  };

  const isReadyToCall = authMode === 'subscriptionKey' ? !!subscriptionKey : !!azureToken;

  const callApi = async () => {
    if (!isReadyToCall) return;
    setApiLoading(true); setResponse(null); setStatus(null); setApiError(null);
    try {
      const headers = { 'accept': 'application/json' };
      if (authMode === 'subscriptionKey') {
        headers['Ocp-Apim-Subscription-Key'] = subscriptionKey;
      } else {
        headers['Authorization'] = `Bearer ${azureToken}`;
      }
      const res = await fetch(getUrl(), { headers });
      setStatus(res.status);
      const text = await res.text();
      try { setResponse(JSON.parse(text)); } catch { setResponse(text); }
    } catch (e) {
      setApiError('Request failed: ' + e.message);
    } finally {
      setApiLoading(false);
    }
  };

  const bearerFlowSteps = [
    { label: '1. App Credentials', done: true },
    { label: '2. POST /token',     done: !!azureToken || tokenLoading },
    { label: '3. Bearer Token',    done: !!azureToken },
    { label: '4. APIM Call',       done: !!response },
    { label: '5. Response',        done: status >= 200 && status < 300 },
  ];

  const subKeyFlowSteps = [
    { label: '1. Subscription Key', done: !!subscriptionKey },
    { label: '2. APIM Call',        done: !!response || apiLoading },
    { label: '3. Response',         done: status >= 200 && status < 300 },
  ];

  const flowSteps = authMode === 'subscriptionKey' ? subKeyFlowSteps : bearerFlowSteps;

  return (
    <div>
      <div className="gateway-header" style={{ background: `linear-gradient(135deg, ${COLOR}, #005a9e)` }}>
        <div style={{ fontSize: '2rem' }}>☁️</div>
        <div>
          <h2>Azure APIM — Appointments API</h2>
          <p>https://apimserviceramindus.azure-api.net/appointments</p>
        </div>
      </div>

      <div className="flow-steps">
        {flowSteps.map((s, i) => (
          <React.Fragment key={i}>
            {i > 0 && <span className="flow-step arrow">→</span>}
            <span className={`flow-step ${s.done ? 'done' : ''}`}>{s.done ? '✓ ' : ''}{s.label}</span>
          </React.Fragment>
        ))}
      </div>

      {/* Auth mode selector */}
      <div className="card" style={{ marginBottom: '1rem' }}>
        <p className="section-title">Authentication Method</p>
        <div style={{ display: 'flex', gap: '12px' }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
            <input
              type="radio" name="authMode" value="subscriptionKey"
              checked={authMode === 'subscriptionKey'}
              onChange={() => setAuthMode('subscriptionKey')}
            />
            <span>Subscription Key</span>
          </label>
          <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
            <input
              type="radio" name="authMode" value="bearer"
              checked={authMode === 'bearer'}
              onChange={() => setAuthMode('bearer')}
            />
            <span>Bearer Token (OAuth2 Client Credentials)</span>
          </label>
        </div>
      </div>

      {/* Subscription Key auth */}
      {authMode === 'subscriptionKey' && (
        <div className="card" style={{ marginBottom: '1rem' }}>
          <p className="section-title">Subscription Key</p>
          <div className="code-block" style={{ fontSize: '0.78rem', padding: '0.75rem 1rem', marginBottom: '1rem' }}>
            <span style={{ color: '#94a3b8' }}>Ocp-Apim-Subscription-Key: </span>
            <span style={{ color: '#fbbf24' }}>{subscriptionKey || '<enter key below>'}</span>
          </div>
          <div className="input-row">
            <input
              type="text"
              value={subscriptionKey}
              onChange={e => setSubscriptionKey(e.target.value)}
              placeholder="Enter subscription key"
              style={{ flex: 1, fontFamily: 'monospace' }}
            />
            {subscriptionKey && <span className="badge success">✓ Key ready</span>}
          </div>
        </div>
      )}

      {/* Bearer token auth */}
      {authMode === 'bearer' && (
        <div className="card" style={{ marginBottom: '1rem' }}>
          <p className="section-title">Step 1 — Get Azure Token (Client Credentials)</p>
          <div className="code-block" style={{ fontSize: '0.78rem', padding: '0.75rem 1rem', marginBottom: '1rem' }}>
            <span style={{ color: '#94a3b8' }}>POST </span>
            <span style={{ color: '#86efac' }}>https://login.microsoftonline.com/{config.azureTenantId || '<tenant-id>'}/oauth2/v2.0/token</span>{'\n'}
            <span style={{ color: '#94a3b8' }}>grant_type=</span><span style={{ color: '#fbbf24' }}>client_credentials</span>{'\n'}
            <span style={{ color: '#94a3b8' }}>scope=</span><span style={{ color: '#86efac' }}>{config.azureScope || '<scope>'}</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <button className="btn-primary" style={{ background: COLOR }} onClick={fetchToken} disabled={tokenLoading}>
              {tokenLoading ? <span className="spinner" /> : 'Get Token'}
            </button>
            {azureToken && <span className="badge success">✓ Token acquired</span>}
            {tokenError && <span className="badge error">✗ {tokenError}</span>}
          </div>
        </div>
      )}

      {/* Call API */}
      <div className="card">
        <p className="section-title">{authMode === 'bearer' ? 'Step 2 — ' : ''}Call Appointments API via Azure APIM</p>
        <div className="input-row">
          <select value={mode} onChange={e => setMode(e.target.value)}>
            {MODES.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
          </select>
          {mode === 'byId' && (
            <input
              type="text"
              value={appointmentId}
              onChange={e => setAppointmentId(e.target.value)}
              placeholder="APT001"
            />
          )}
          <button
            className="btn-primary"
            style={{ background: COLOR, minWidth: '120px' }}
            onClick={callApi}
            disabled={!isReadyToCall || apiLoading}
          >
            {apiLoading ? <span className="spinner" /> : 'Call API'}
          </button>
        </div>
        <div className="code-block" style={{ fontSize: '0.78rem', padding: '0.75rem 1rem' }}>
          <span style={{ color: '#94a3b8' }}>GET </span><span style={{ color: '#86efac' }}>{getDisplayUrl()}</span>{'\n'}
          {authMode === 'subscriptionKey' ? (
            <>
              <span style={{ color: '#94a3b8' }}>Ocp-Apim-Subscription-Key: </span>
              <span style={{ color: '#fbbf24' }}>{subscriptionKey ? subscriptionKey.slice(0, 8) + '…' : '<enter key above>'}</span>
            </>
          ) : (
            <>
              <span style={{ color: '#94a3b8' }}>Authorization: </span><span style={{ color: '#fbbf24' }}>Bearer </span>
              <span style={{ color: '#e2e8f0' }}>{azureToken ? azureToken.slice(0, 40) + '…' : '<fetch token first>'}</span>
            </>
          )}
        </div>
        {apiError && <span className="badge error" style={{ marginTop: '0.75rem', display: 'inline-flex' }}>✗ {apiError}</span>}
      </div>

      {authMode === 'bearer' && (
        <TokenPanel token={azureToken} label="Azure Token (Client Credentials — no user context)" />
      )}
      <ResponsePanel response={response} status={status} label="Appointments API Response (Azure APIM)" />
    </div>
  );
}
