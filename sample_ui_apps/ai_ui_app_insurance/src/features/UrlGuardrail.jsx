import React, { useState } from 'react';
import { callAI } from '../api.js';
import { FeatureHeader, InfoBox, pageStyle, warnStyle, sendBtn, inputStyle } from './PromptTemplate.jsx';
import ResponsePanel from '../components/ResponsePanel.jsx';

const MODELS = ['mistral-small-latest', 'mistral-medium', 'open-mistral-7b'];


const PRESETS = [
  {
    label: '✅ Valid URL — Passes',
    prompt: 'Please summarize the key health insurance regulations mentioned at https://www.cdc.gov',
  },
  {
    label: '✅ Valid URL — Passes',
    prompt: 'Can you review the coverage document at https://www.who.int and tell me what it says about health coverage?',
  },
  {
    label: '🚫 Fake Domain — Blocked',
    prompt: 'Please download and summarize my policy document from http://healthguard-policies.fake/policy-12345.pdf',
  },
  {
    label: '🚫 Unreachable — Blocked',
    prompt: 'Analyze the insurance claim form available at http://internal-claims-portal.local/forms/claim.pdf and advise me.',
  },
  {
    label: '🚫 Phishing-style — Blocked',
    prompt: 'Verify my HealthGuard login credentials at http://healthguard-verify-account.xyz123.ru and confirm my policy.',
  },
];

export default function UrlGuardrail({ config }) {
  const [input, setInput] = useState(PRESETS[0].prompt);
  const [model, setModel] = useState(MODELS[0]);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const color = '#f97316';

  const payload = { model, messages: [{ role: 'user', content: input }] };

  const send = async () => {
    setLoading(true); setResult(null);
    const res = await callAI(config.endpoints.urlGuardrail, config.apiKey, payload);
    setResult(res); setLoading(false);
  };

  // Extract URLs from input for preview
  const urlMatches = input.match(/https?:\/\/[^\s,"'{}[\]`*]+/g) || [];

  return (
    <div style={pageStyle}>
      <FeatureHeader
        icon="🔗" badge="GUARDRAIL" color={color}
        title="URL Guardrail"
        desc="The gateway extracts URLs embedded in user prompts and validates their reachability (HTTP HEAD request or DNS lookup). Malformed, unreachable, or suspicious URLs are blocked before the AI model ever sees the prompt — preventing SSRF and prompt injection via URLs."
      />

      <InfoBox color={color} title="Gateway Policy: URL Guardrail" items={[
        ['Policy', 'URL Guardrail (Synapse mediator)'],
        ['JSON Path', '$.messages[-1].content'],
        ['Validation Mode', 'HTTP HEAD request (checks remote availability)'],
        ['DNS Fallback', 'false (can be enabled for restricted networks)'],
        ['Connection Timeout', '3000ms'],
        ['Block Response', 'HTTP 446 · URL_GUARDRAIL'],
        ['Applied on', 'Request flow'],
      ]} />

      {/* Presets + Model selector */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 14, gap: 16 }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: '0.75rem', color: '#94a3b8', fontWeight: 700, marginBottom: 8 }}>Try these examples:</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {PRESETS.map((p, i) => (
              <button key={i} onClick={() => { setInput(p.prompt); setResult(null); }} style={{
                textAlign: 'left', padding: '8px 14px', borderRadius: 8, cursor: 'pointer',
                border: input === p.prompt ? `2px solid ${color}` : '2px solid #e2e8f0',
                background: input === p.prompt ? '#fff7ed' : '#fff',
                color: '#334155', fontSize: '0.82rem', fontWeight: input === p.prompt ? 600 : 400,
              }}>
                {p.label}
              </button>
            ))}
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0 }}>
          <span style={{ fontSize: '0.75rem', color: '#64748b', fontWeight: 600 }}>Model</span>
          <select value={model} onChange={e => setModel(e.target.value)}
            style={{ ...inputStyle, cursor: 'pointer', width: 'auto', padding: '6px 10px' }}>
            {MODELS.map(m => <option key={m} value={m}>{m}</option>)}
          </select>
        </div>
      </div>

      <textarea
        rows={4}
        value={input}
        onChange={e => { setInput(e.target.value); setResult(null); }}
        placeholder="Type a prompt containing a URL…"
        style={{
          width: '100%', padding: '10px 14px', border: '1px solid #e2e8f0', borderRadius: 8,
          fontSize: '0.85rem', resize: 'vertical', outline: 'none', fontFamily: 'inherit',
          marginBottom: 10, boxSizing: 'border-box',
        }}
      />

      {/* Detected URLs */}
      {urlMatches.length > 0 && (
        <div style={{ background: '#1e293b', borderRadius: 8, padding: '10px 14px', marginBottom: 14 }}>
          <div style={{ fontSize: '0.68rem', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 6 }}>
            URLs extracted by gateway
          </div>
          {urlMatches.map((url, i) => (
            <div key={i} style={{ fontSize: '0.75rem', color: '#7dd3fc', fontFamily: 'monospace', marginBottom: 2 }}>→ {url}</div>
          ))}
        </div>
      )}

      {/* Auto-generated payload preview */}
      <div style={{ marginBottom: 16 }}>
        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', marginBottom: 6 }}>
          Auto-generated request payload:
        </div>
        <pre style={{
          background: '#1e293b', color: '#e2e8f0', borderRadius: 8,
          padding: '12px 14px', fontSize: '0.75rem', lineHeight: 1.6,
          overflowX: 'auto', margin: 0,
        }}>{JSON.stringify(payload, null, 2)}</pre>
      </div>

      <button onClick={send} disabled={loading || !input.trim() || !config.apiKey} style={sendBtn(loading || !input.trim() || !config.apiKey, color)}>
        {loading ? 'Validating URLs…' : '▶ Validate & Send'}
      </button>
      {!config.apiKey && <div style={warnStyle}>Configure your API key in ⚙️ Settings first</div>}

      <ResponsePanel result={result} loading={loading} />
    </div>
  );
}
