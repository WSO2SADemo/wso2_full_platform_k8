import React, { useState } from 'react';
import { TokenPanel, ResponsePanel } from '../components/TokenPanel';
import config from '../config';

const MODES = [
  { value: 'all',       label: 'List All Appointments' },
  { value: 'byId',      label: 'Get by Appointment ID' },
  { value: 'byPatient', label: 'Get by Patient ID' },
];

const COLOR = '#0078d4';

export default function AzureAPIMTab() {
  const [azureToken, setAzureToken]     = useState(null);
  const [tokenLoading, setTokenLoading] = useState(false);
  const [tokenError, setTokenError]     = useState(null);

  const [mode, setMode]                     = useState('all');
  const [appointmentId, setAppointmentId]   = useState('APT001');
  const [patientId, setPatientId]           = useState('P001');
  const [response, setResponse]             = useState(null);
  const [status, setStatus]                 = useState(null);
  const [apiLoading, setApiLoading]         = useState(false);
  const [apiError, setApiError]             = useState(null);

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

  const getUrl = () => {
    const base = `${config.azureBase}/appointments/appointments`;
    if (mode === 'byId')      return `${base}/${appointmentId}`;
    if (mode === 'byPatient') return `${base}/patient/${patientId}`;
    return base;
  };

  const callApi = async () => {
    if (!azureToken) return;
    setApiLoading(true); setResponse(null); setStatus(null); setApiError(null);
    try {
      const res = await fetch(getUrl(), {
        headers: { 'accept': 'application/json', 'Authorization': `Bearer ${azureToken}` },
      });
      setStatus(res.status);
      const text = await res.text();
      try { setResponse(JSON.parse(text)); } catch { setResponse(text); }
    } catch (e) {
      setApiError('Request failed: ' + e.message);
    } finally {
      setApiLoading(false);
    }
  };

  const tokenFlowSteps = [
    { label: '1. App Credentials', done: true },
    { label: '2. POST /token',     done: !!azureToken || tokenLoading },
    { label: '3. Bearer Token',    done: !!azureToken },
    { label: '4. APIM Call',       done: !!response },
    { label: '5. Response',        done: status >= 200 && status < 300 },
  ];

  return (
    <div>
      <div className="gateway-header" style={{ background: `linear-gradient(135deg, ${COLOR}, #005a9e)` }}>
        <div style={{ fontSize: '2rem' }}>☁️</div>
        <div>
          <h2>Azure APIM — Appointments API</h2>
          <p>Client Credentials Grant · Azure Entra ID · apimserviceramindus.azure-api.net</p>
        </div>
      </div>

      <div className="flow-steps">
        {tokenFlowSteps.map((s, i) => (
          <React.Fragment key={i}>
            {i > 0 && <span className="flow-step arrow">→</span>}
            <span className={`flow-step ${s.done ? 'done' : ''}`}>{s.done ? '✓ ' : ''}{s.label}</span>
          </React.Fragment>
        ))}
      </div>

      {/* Step 1: Get token */}
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
          {azureToken  && <span className="badge success">✓ Token acquired</span>}
          {tokenError  && <span className="badge error">✗ {tokenError}</span>}
        </div>
      </div>

      {/* Step 2: Call API */}
      <div className="card">
        <p className="section-title">Step 2 — Call Appointments API via Azure APIM</p>
        <div className="input-row">
          <select value={mode} onChange={e => setMode(e.target.value)}>
            {MODES.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
          </select>
          {mode === 'byId' && (
            <input type="text" value={appointmentId} onChange={e => setAppointmentId(e.target.value)} placeholder="APT001" />
          )}
          {mode === 'byPatient' && (
            <input type="text" value={patientId} onChange={e => setPatientId(e.target.value)} placeholder="P001" />
          )}
          <button className="btn-primary" style={{ background: COLOR, minWidth: '120px' }} onClick={callApi} disabled={!azureToken || apiLoading}>
            {apiLoading ? <span className="spinner" /> : 'Call API'}
          </button>
        </div>
        <div className="code-block" style={{ fontSize: '0.78rem', padding: '0.75rem 1rem' }}>
          <span style={{ color: '#94a3b8' }}>GET </span><span style={{ color: '#86efac' }}>{getUrl()}</span>{'\n'}
          <span style={{ color: '#94a3b8' }}>Authorization: </span><span style={{ color: '#fbbf24' }}>Bearer </span>
          <span style={{ color: '#e2e8f0' }}>{azureToken ? azureToken.slice(0, 40) + '…' : '<fetch token first>'}</span>
        </div>
        {apiError && <span className="badge error" style={{ marginTop: '0.75rem', display: 'inline-flex' }}>✗ {apiError}</span>}
      </div>

      <TokenPanel token={azureToken} label="Azure Token (Client Credentials — no user context)" />
      <ResponsePanel response={response} status={status} label="Appointments API Response (Azure APIM)" />
    </div>
  );
}
