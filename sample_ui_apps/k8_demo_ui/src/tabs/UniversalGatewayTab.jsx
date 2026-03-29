import React, { useEffect, useState } from 'react';
import { useAsgardeo } from '@asgardeo/react';
import { TokenPanel, ResponsePanel } from '../components/TokenPanel';
import config from '../config';

const MODES = [
  { value: 'all',           label: 'List All Prescriptions' },
  { value: 'byId',          label: 'Get by Prescription ID' },
  { value: 'byPatient',     label: 'By Patient ID' },
  { value: 'activePatient', label: 'Active — By Patient ID' },
];

const COLOR = '#6366f1';

export default function UniversalGatewayTab() {
  const { getAccessToken, isSignedIn, isLoading } = useAsgardeo();

  const [accessToken, setAccessToken]       = useState(null);
  const [mode, setMode]                     = useState('all');
  const [prescriptionId, setPrescriptionId] = useState('RX001');
  const [patientId, setPatientId]           = useState('P001');
  const [response, setResponse]             = useState(null);
  const [status, setStatus]                 = useState(null);
  const [loading, setLoading]               = useState(false);
  const [error, setError]                   = useState(null);

  useEffect(() => {
    if (!isSignedIn || isLoading) return;
    (async () => {
      try { setAccessToken(await getAccessToken()); }
      catch (e) { setError('Token error: ' + e.message); }
    })();
  }, [isSignedIn, isLoading, getAccessToken]);

  const realBase = import.meta.env.VITE_UNIVERSAL_BASE || 'https://gw.wso2.com';

  const apiPath = (base) => {
    const root = `${base}/medicalprescriptionsapi/1.0.0`;
    if (mode === 'byId')          return `${root}/prescriptions/${prescriptionId}`;
    if (mode === 'byPatient')     return `${root}/prescriptions/patient/${patientId}`;
    if (mode === 'activePatient') return `${root}/prescriptions/patient/${patientId}/active`;
    return `${root}/prescriptions`;
  };

  const getUrl     = () => apiPath(config.universalBase);
  const displayUrl = () => apiPath(realBase);

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

  return (
    <div>
      <div className="gateway-header" style={{ background: `linear-gradient(135deg, ${COLOR}, #4338ca)` }}>
        <div style={{ fontSize: '2rem' }}>🟣</div>
        <div>
          <h2>WSO2 Universal Gateway — Prescriptions API</h2>
          <p>Auth Code Grant via is.wso2.com · Bearer token forwarded to {realBase}</p>
        </div>
      </div>

      <div className="card">
        <p className="section-title">Invoke Prescriptions Service</p>
        <div className="input-row">
          <select value={mode} onChange={e => setMode(e.target.value)}>
            {MODES.map(m => <option key={m.value} value={m.value}>{m.label}</option>)}
          </select>
          {mode === 'byId' && (
            <input type="text" value={prescriptionId} onChange={e => setPrescriptionId(e.target.value)} placeholder="Prescription ID (e.g. RX001)" />
          )}
          {(mode === 'byPatient' || mode === 'activePatient') && (
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

      <ResponsePanel response={response} status={status} label="Prescriptions API Response (Universal Gateway)" />
      <TokenPanel token={accessToken} label="Access Token (Auth Code Grant — is.wso2.com)" />
    </div>
  );
}
