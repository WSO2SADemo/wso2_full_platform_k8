import React, { useState } from 'react';
import { pageStyle } from './PromptTemplate.jsx';

const DEFAULT_URL = 'https://gw.wso2.com/samplemistralaiapi/0.0.2/v1/chat/completions';
const DEFAULT_API_KEY = 'eyJ4NXQjUzI1NiI6Ik4yTmlZVFkxT1RWaE9UTmhPVEV6T1dKbU1qaGlPVEUwTm1ZMFl6RTJOVFUzTUdJeE9EZ3lPRFU0WlRCaVpHRXdNalZoT0RFNE1qaGpObVl4TVdJbFpRPT0iLCJraWQiOiJnYXRld2F5X2NlcnRpZmljYXRlX2FsaWFzIiwidHlwIjoiSldUIiwiYWxnIjoiUlMyNTYifQ==.eyJzdWIiOiJhZG1pbkBjYXJib24uc3VwZXIiLCJhcHBsaWNhdGlvbiI6eyJpZCI6NiwidXVpZCI6IjE4ODg4ZWJmLWVmMGYtNDVjNy1hYmQxLWZkMmU0N2ZiNzdiYiJ9LCJpc3MiOiJodHRwczpcL1wvY3Aud3NvMi5jb206NDQzXC9vYXV0aDJcL3Rva2VuIiwia2V5dHlwZSI6IlBST0RVQ1RJT04iLCJwZXJtaXR0ZWRSZWZlcmVyIjoiIiwidG9rZW5fdHlwZSI6ImFwaUtleSIsInBlcm1pdHRlZElQIjoiIiwiaWF0IjoxNzc1MDIzMzMwLCJqdGkiOiIwNWMzMjlhNC1jY2RmLTQyNWUtYTk5OC1kNDM2NjhjOGRlZWQifQ==.Do21QoXx4fsT5F7gskmskia-8L9dg5llB1UtNubjFhlE0tVLSCtrJJmWkYiAxw1s-IuNOtiR4wV78tmr0nBcMUCoCUjf_xOW9qDYL1LuePlCXu_70fie4D5kDOv-1P3gowLgOQxI1E8ybuYhNsicombyc5zVP7VbtvovKabS4MLYNEPezf5mMlL_H6hFOpNbhpBK9b8sR3Of6ToeImq0C1ycNANhB5Pq_4Tr3HbBV-VxL97WNLtBfMwt2Tnl84iGzdQuHu7h_QeQhp_BIOGhaqKs5luiiGkGkAuZjkCiXA-MPqj6ifAEJH-xA3eNfI-um6GHRnLKUAjsqdmgM_CHjA==';
const DEFAULT_BODY = JSON.stringify({
  model: 'mistral-small-latest',
  messages: [
    {
      role: 'user',
      content: 'template://claim-intake-template?claim_type=Medical&claim_description=I%20had%20surgery',
    },
  ],
}, null, 2);

function statusColor(s) {
  if (!s) return '#64748b';
  if (s === 446) return '#f97316';
  if (s === 429) return '#f59e0b';
  if (s >= 200 && s < 300) return '#10b981';
  return '#ef4444';
}

export default function Playground() {
  const [url, setUrl] = useState(DEFAULT_URL);
  const [apiKey, setApiKey] = useState(DEFAULT_API_KEY);
  const [body, setBody] = useState(DEFAULT_BODY);
  const [bodyError, setBodyError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);

  const validateBody = (val) => {
    setBody(val);
    try { JSON.parse(val); setBodyError(null); }
    catch (e) { setBodyError(e.message); }
  };

  const send = async () => {
    if (bodyError || !url || loading) return;
    setLoading(true); setResult(null);
    const start = performance.now();
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'ApiKey': apiKey },
        body,
      });
      const elapsed = Math.round(performance.now() - start);
      let data;
      try { data = await res.json(); } catch { data = null; }
      setResult({ status: res.status, elapsed, data, ok: res.ok });
    } catch (err) {
      setResult({ status: 0, elapsed: Math.round(performance.now() - start), data: { error: err.message }, ok: false });
    }
    setLoading(false);
  };

  const aiText = result?.data?.choices?.[0]?.message?.content;
  const isGuardrail = result?.status === 446;
  const guardInfo = result?.data?.message;

  // Build equivalent curl for display
  const curlCmd = `curl -k -X POST "${url}" \\
  -H "Content-Type: application/json" \\
  -H "ApiKey: ${apiKey.substring(0, 40)}…" \\
  -d '${body}'`;

  return (
    <div style={pageStyle}>
      {/* Header */}
      <div style={{ marginBottom: 24 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
          <span style={{ fontSize: '1.5rem' }}>🧪</span>
          <span style={{ background: '#8b5cf622', color: '#8b5cf6', padding: '2px 10px', borderRadius: 20, fontSize: '0.7rem', fontWeight: 700, letterSpacing: '0.06em' }}>PLAYGROUND</span>
        </div>
        <h2 style={{ margin: '0 0 8px', color: '#0f172a', fontWeight: 800, fontSize: '1.4rem' }}>Direct API Playground</h2>
        <p style={{ margin: 0, color: '#64748b', lineHeight: 1.7, fontSize: '0.9rem' }}>
          Fire raw requests directly against any APIM Gateway endpoint. Pre-filled with the Mistral AI API using a Prompt Template trigger.
        </p>
      </div>

      {/* URL */}
      <div style={{ marginBottom: 14 }}>
        <label style={labelStyle}>Endpoint URL</label>
        <input
          type="text"
          value={url}
          onChange={e => setUrl(e.target.value)}
          style={{ ...inputStyle, fontFamily: 'monospace' }}
        />
      </div>

      {/* ApiKey */}
      <div style={{ marginBottom: 14 }}>
        <label style={labelStyle}>ApiKey Header Value</label>
        <textarea
          rows={3}
          value={apiKey}
          onChange={e => setApiKey(e.target.value)}
          style={{ ...inputStyle, fontFamily: 'monospace', fontSize: '0.72rem', resize: 'vertical', lineHeight: 1.5 }}
        />
      </div>

      {/* Body */}
      <div style={{ marginBottom: 6 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 5 }}>
          <label style={labelStyle}>Request Body (JSON)</label>
          <button onClick={() => setBody(DEFAULT_BODY)} style={{
            background: 'none', border: 'none', cursor: 'pointer',
            fontSize: '0.72rem', color: '#94a3b8', textDecoration: 'underline',
          }}>Reset to default</button>
        </div>
        <textarea
          rows={12}
          value={body}
          onChange={e => validateBody(e.target.value)}
          style={{
            ...inputStyle, fontFamily: 'monospace', fontSize: '0.8rem',
            resize: 'vertical', lineHeight: 1.6,
            borderColor: bodyError ? '#ef4444' : '#e2e8f0',
          }}
        />
        {bodyError && <div style={{ fontSize: '0.72rem', color: '#ef4444', marginTop: 4 }}>⚠ Invalid JSON: {bodyError}</div>}
      </div>

      {/* Send button */}
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginTop: 14, marginBottom: 20 }}>
        <button
          onClick={send}
          disabled={loading || !!bodyError || !url}
          style={{
            background: loading || bodyError || !url ? '#cbd5e1' : '#8b5cf6',
            color: '#fff', border: 'none', borderRadius: 8,
            padding: '11px 28px', cursor: loading || bodyError ? 'not-allowed' : 'pointer',
            fontSize: '0.9rem', fontWeight: 700,
          }}
        >
          {loading ? 'Sending…' : '▶ Send Request'}
        </button>
        {result && (
          <span style={{
            padding: '4px 14px', borderRadius: 20, fontSize: '0.78rem', fontWeight: 700,
            background: statusColor(result.status) + '22', color: statusColor(result.status),
            border: `1px solid ${statusColor(result.status)}55`,
          }}>
            {result.status === 0 ? 'CONNECTION ERROR' : `HTTP ${result.status}`} · ⏱ {result.elapsed}ms
          </span>
        )}
      </div>

      {/* Result */}
      {result && (
        <>
          {/* Guardrail block */}
          {isGuardrail && guardInfo && (
            <div style={{ background: '#fff7ed', border: '2px solid #f97316', borderRadius: 10, padding: '14px 16px', marginBottom: 16 }}>
              <div style={{ fontWeight: 700, color: '#9a3412', marginBottom: 8, fontSize: '0.85rem' }}>🛡 Guardrail Intervened</div>
              {[
                ['Type', result.data?.type],
                ['Guardrail', guardInfo.interveningGuardrail],
                ['Reason', guardInfo.actionReason],
                ['Direction', guardInfo.direction],
              ].map(([k, v]) => v ? (
                <div key={k} style={{ display: 'flex', gap: 8, marginBottom: 4 }}>
                  <span style={{ fontSize: '0.72rem', color: '#9a3412', minWidth: 80, fontWeight: 600 }}>{k}</span>
                  <span style={{ fontSize: '0.75rem', color: '#7c2d12' }}>{String(v)}</span>
                </div>
              ) : null)}
            </div>
          )}

          {/* AI text */}
          {aiText && (
            <div style={{ background: '#f0f7f7', border: '1px solid #c8e0e0', borderRadius: 10, padding: '14px 16px', marginBottom: 16 }}>
              <div style={{ fontSize: '0.7rem', color: '#0d6e6e', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 8 }}>AI Response</div>
              <div style={{ fontSize: '0.88rem', color: '#1e293b', lineHeight: 1.7, whiteSpace: 'pre-wrap' }}>{aiText}</div>
              {result.data?.usage && (
                <div style={{ marginTop: 10, display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                  {[
                    ['Prompt tokens', result.data.usage.prompt_tokens],
                    ['Completion tokens', result.data.usage.completion_tokens],
                    ['Total tokens', result.data.usage.total_tokens],
                  ].map(([k, v]) => v != null ? (
                    <span key={k} style={{ fontSize: '0.72rem', color: '#8b5cf6', background: '#ede9fe', padding: '2px 10px', borderRadius: 20 }}>
                      {k}: {v}
                    </span>
                  ) : null)}
                </div>
              )}
            </div>
          )}

          {/* Raw JSON */}
          <div style={{ fontSize: '0.72rem', color: '#94a3b8', fontWeight: 700, marginBottom: 4 }}>Raw Response</div>
          <pre style={{
            background: '#1e293b', color: '#e2e8f0', borderRadius: 8,
            padding: '12px 14px', fontSize: '0.72rem', lineHeight: 1.6,
            overflowX: 'auto', whiteSpace: 'pre-wrap', wordBreak: 'break-all', margin: 0,
          }}>
            {JSON.stringify(result.data, null, 2)}
          </pre>
        </>
      )}
    </div>
  );
}

const labelStyle = { display: 'block', fontSize: '0.78rem', color: '#475569', fontWeight: 600, marginBottom: 5 };
const inputStyle = {
  width: '100%', padding: '9px 12px', border: '1px solid #e2e8f0',
  borderRadius: 8, fontSize: '0.85rem', color: '#0f172a', outline: 'none', boxSizing: 'border-box',
};
