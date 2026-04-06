import React, { useState } from 'react';

const ENDPOINT_LABELS = {
  promptTemplate:    { label: 'Prompt Template API',       desc: 'API with Prompt Template policy' },
  promptDecorator:   { label: 'Prompt Decorator API',      desc: 'API with Prompt Decorator policy' },
  rateLimiting:      { label: 'Rate Limiting API',         desc: 'API with AI rate limit subscription tier' },
  semanticCache:     { label: 'Semantic Cache API',        desc: 'API with Semantic Cache policy (request+response)' },
  azureGuardrail:    { label: 'Azure Content Safety API',  desc: 'API with Azure Content Safety guardrail' },
  contentLength:     { label: 'Content Length API',        desc: 'API with Content Length guardrail' },
  semanticGuardrail: { label: 'Semantic Prompt API',       desc: 'API with Semantic Prompt guardrail' },
  urlGuardrail:      { label: 'URL Guardrail API',         desc: 'API with URL Guardrail policy' },
};

export default function SettingsModal({ config, onSave, onClose }) {
  const [form, setForm] = useState({ ...config, endpoints: { ...config.endpoints } });

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  const setEndpoint = (k, v) => setForm(f => ({ ...f, endpoints: { ...f.endpoints, [k]: v } }));

  return (
    <div style={{
      position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)',
      display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999,
    }}>
      <div style={{
        background: '#fff', borderRadius: 16, width: 680, maxHeight: '88vh',
        display: 'flex', flexDirection: 'column', boxShadow: '0 24px 60px rgba(0,0,0,0.25)',
      }}>
        {/* Header */}
        <div style={{ padding: '20px 24px 16px', borderBottom: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <div style={{ fontWeight: 700, fontSize: '1.05rem', color: '#0f172a' }}>⚙️ Configuration</div>
            <div style={{ fontSize: '0.78rem', color: '#64748b', marginTop: 2 }}>Set API Key, model, and per-feature endpoint URLs</div>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: '1.2rem', color: '#94a3b8' }}>✕</button>
        </div>

        {/* Body */}
        <div style={{ overflowY: 'auto', padding: '20px 24px', flex: 1 }}>
          {/* Global */}
          <div style={{ marginBottom: 24 }}>
            <div style={{ fontSize: '0.78rem', fontWeight: 700, color: '#0f172a', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 12 }}>
              Global Settings
            </div>
            <div style={{ display: 'flex', gap: 12 }}>
              <div style={{ flex: 2 }}>
                <label style={{ fontSize: '0.75rem', color: '#64748b', display: 'block', marginBottom: 4 }}>API Key</label>
                <input
                  type="password"
                  value={form.apiKey}
                  onChange={e => set('apiKey', e.target.value)}
                  placeholder="Enter APIM API key"
                  style={inputStyle}
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ fontSize: '0.75rem', color: '#64748b', display: 'block', marginBottom: 4 }}>Model</label>
                <input
                  type="text"
                  value={form.model}
                  onChange={e => set('model', e.target.value)}
                  placeholder="mistral-small-latest"
                  style={inputStyle}
                />
              </div>
            </div>
          </div>

          {/* Endpoints */}
          <div style={{ fontSize: '0.78rem', fontWeight: 700, color: '#0f172a', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 12 }}>
            API Endpoints (one per feature)
          </div>
          {Object.entries(ENDPOINT_LABELS).map(([key, { label, desc }]) => (
            <div key={key} style={{ marginBottom: 12 }}>
              <label style={{ fontSize: '0.75rem', color: '#0f172a', fontWeight: 600, display: 'block', marginBottom: 1 }}>{label}</label>
              <label style={{ fontSize: '0.7rem', color: '#94a3b8', display: 'block', marginBottom: 4 }}>{desc}</label>
              <input
                type="text"
                value={form.endpoints[key] || ''}
                onChange={e => setEndpoint(key, e.target.value)}
                style={inputStyle}
              />
            </div>
          ))}
        </div>

        {/* Footer */}
        <div style={{ padding: '16px 24px', borderTop: '1px solid #e2e8f0', display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
          <button onClick={onClose} style={{ padding: '9px 20px', borderRadius: 8, border: '1px solid #e2e8f0', background: '#fff', cursor: 'pointer', fontSize: '0.85rem', color: '#64748b' }}>
            Cancel
          </button>
          <button
            onClick={() => { onSave(form); onClose(); }}
            style={{ padding: '9px 20px', borderRadius: 8, border: 'none', background: '#0d6e6e', color: '#fff', cursor: 'pointer', fontSize: '0.85rem', fontWeight: 600 }}
          >
            Save Configuration
          </button>
        </div>
      </div>
    </div>
  );
}

const inputStyle = {
  width: '100%', padding: '8px 12px', border: '1px solid #e2e8f0',
  borderRadius: 8, fontSize: '0.82rem', color: '#0f172a',
  fontFamily: 'monospace', outline: 'none',
};
