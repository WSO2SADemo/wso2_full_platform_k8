import React, { useEffect, useState } from 'react';
import { useAsgardeo } from '@asgardeo/react';
import { TokenPanel, ResponsePanel } from '../components/TokenPanel';
import config from '../config';

const MODES = [
  { value: 'all',  label: 'List All Patients' },
  { value: 'byId', label: 'Get by Patient ID' },
];

const COLOR = '#FF7300';

export default function WSO2GatewayTab() {
  const { getAccessToken, isSignedIn, isLoading } = useAsgardeo();

  const [accessToken, setAccessToken] = useState(null);
  const [mode, setMode]               = useState('all');
  const [patientId, setPatientId]     = useState('P001');
  const [response, setResponse]       = useState(null);
  const [status, setStatus]           = useState(null);
  const [loading, setLoading]         = useState(false);
  const [error, setError]             = useState(null);

  useEffect(() => {
    if (!isSignedIn || isLoading) return;
    (async () => {
      try { setAccessToken(await getAccessToken()); }
      catch (e) { setError('Failed to retrieve access token: ' + e.message); }
    })();
  }, [isSignedIn, isLoading, getAccessToken]);

  const apiPath = (base) =>
    mode === 'byId'
      ? `${base}/medicalpatientservicesapi/1.0.0/patients/${patientId}`
      : `${base}/medicalpatientservicesapi/1.0.0/patients`;

  const getUrl     = () => apiPath(config.wso2K8Base);
  const displayUrl = () => apiPath(import.meta.env.VITE_WSO2_K8_BASE || 'https://kgw.wso2.com:9095');

  const callApi = async () => {
    if (!accessToken) return;
    setLoading(true); setResponse(null); setStatus(null); setError(null);
    try {
      const res = await fetch(getUrl(), {
        headers: { 'accept': 'application/json', 'Authorization': `Bearer ${accessToken}` },
      });
      setStatus(res.status);
      const text = await res.text();
      try { setResponse(JSON.parse(text)); } catch { setResponse(text); }
    } catch (e) {
      setError('Request failed: ' + e.message);
    } finally {
      setLoading(false);
    }
  };

  const flowSteps = [
    { label: '1. User Login',   done: isSignedIn },
    { label: '2. Auth Code',    done: isSignedIn },
    { label: '3. Token Issued', done: !!accessToken },
    { label: '4. API Called',   done: !!response },
    { label: '5. Response',     done: status >= 200 && status < 300 },
  ];

  return (
    <div>
      <div className="gateway-header" style={{ background: `linear-gradient(135deg, ${COLOR}, #c05500)` }}>
        <div style={{ fontSize: '2rem' }}>🟠</div>
        <div>
          <h2>WSO2 K8 Gateway — Patients API</h2>
          <p>Auth Code Grant via is.wso2.com · Bearer token forwarded to {config.wso2K8Base}</p>
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

      <div className="card">
        <p className="section-title">Invoke Patient Lookup</p>
        <div className="input-row">
          <select value={mode} onChange={e => setMode(e.target.value)}>
            {MODES.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
          </select>
          {mode === 'byId' && (
            <input type="text" value={patientId} onChange={e => setPatientId(e.target.value)} placeholder="Patient ID (e.g. P001)" />
          )}
          <button className="btn-primary" style={{ background: COLOR, minWidth: '120px' }} onClick={callApi} disabled={!accessToken || loading}>
            {loading ? <span className="spinner" /> : 'Call API'}
          </button>
        </div>
        <div className="code-block" style={{ fontSize: '0.78rem', padding: '0.75rem 1rem' }}>
          <span style={{ color: '#94a3b8' }}>GET </span><span style={{ color: '#86efac' }}>{displayUrl()}</span>{'\n'}
          <span style={{ color: '#94a3b8' }}>Authorization: </span><span style={{ color: '#fbbf24' }}>Bearer </span>
          <span style={{ color: '#e2e8f0' }}>{accessToken ? accessToken.slice(0, 40) + '…' : '<token pending>'}</span>
        </div>
        {error && <span className="badge error" style={{ marginTop: '0.75rem', display: 'inline-flex' }}>✗ {error}</span>}
      </div>

      <ResponsePanel response={response} status={status} label="Patients API Response (WSO2 K8 Gateway)" />
      <TokenPanel token={accessToken} label="Access Token (Auth Code Grant — is.wso2.com)" />
    </div>
  );
}
