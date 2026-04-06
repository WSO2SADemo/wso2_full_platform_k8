import React, { useState, useEffect } from 'react';
import { callAI } from '../api.js';
import ResponsePanel from '../components/ResponsePanel.jsx';

// ─── Shared helpers (exported for other features) ─────────────────────────────

export function FeatureHeader({ icon, badge, color, title, desc }) {
  return (
    <div style={{ marginBottom: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
        <span style={{ fontSize: '1.5rem' }}>{icon}</span>
        <span style={{ background: color + '22', color, padding: '2px 10px', borderRadius: 20, fontSize: '0.7rem', fontWeight: 700, letterSpacing: '0.06em' }}>{badge}</span>
      </div>
      <h2 style={{ margin: '0 0 8px', color: '#0f172a', fontWeight: 800, fontSize: '1.4rem' }}>{title}</h2>
      <p style={{ margin: 0, color: '#64748b', lineHeight: 1.7, fontSize: '0.9rem' }}>{desc}</p>
    </div>
  );
}

export function InfoBox({ color, title, items }) {
  return (
    <div style={{ background: color + '0d', border: `1px solid ${color}33`, borderRadius: 10, padding: '14px 16px', marginBottom: 24 }}>
      <div style={{ fontSize: '0.75rem', fontWeight: 700, color, textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 10 }}>
        🔧 {title}
      </div>
      {items.map(([k, v]) => (
        <div key={k} style={{ display: 'flex', gap: 8, marginBottom: 5 }}>
          <span style={{ fontSize: '0.72rem', color: '#94a3b8', minWidth: 120, paddingTop: 1 }}>{k}</span>
          <span style={{ fontSize: '0.78rem', color: '#334155', wordBreak: 'break-all' }}>{v}</span>
        </div>
      ))}
    </div>
  );
}

export const pageStyle = { padding: '32px 36px', maxWidth: 820, margin: '0 auto' };
export const labelStyle = { display: 'block', fontSize: '0.78rem', color: '#475569', fontWeight: 600, marginBottom: 5 };
export const inputStyle = {
  width: '100%', padding: '9px 12px', border: '1px solid #e2e8f0',
  borderRadius: 8, fontSize: '0.85rem', color: '#0f172a', outline: 'none', boxSizing: 'border-box',
};
export const warnStyle = { marginTop: 8, fontSize: '0.75rem', color: '#f59e0b' };
export const sendBtn = (disabled, color) => ({
  background: disabled ? '#cbd5e1' : color,
  color: '#fff', border: 'none', borderRadius: 8,
  padding: '11px 24px', cursor: disabled ? 'not-allowed' : 'pointer',
  fontSize: '0.9rem', fontWeight: 700,
});

// ─── Gateway templates config ─────────────────────────────────────────────────

const TEMPLATES = [
  {
    id: 'claim-intake-template',
    name: 'Claim Intake',
    icon: '📋',
    gatewayPrompt: 'You are a HealthGuard claims specialist. A customer is submitting a [[claim_type]] claim. Details: [[claim_description]]. Acknowledge professionally, list required documents, give estimated timeline.',
    fields: [
      {
        key: 'claim_type',
        label: 'Claim Type',
        type: 'select',
        options: ['Medical', 'Dental', 'Vision', 'Mental Health', 'Emergency'],
        defaultValue: 'Medical',
      },
      {
        key: 'claim_description',
        label: 'Claim Description',
        type: 'textarea',
        placeholder: 'e.g. I had emergency surgery last week for appendicitis',
        defaultValue: 'I had surgery last week',
      },
    ],
  },
  {
    id: 'policy-advisor-template',
    name: 'Policy Advisor',
    icon: '🛡️',
    gatewayPrompt: 'You are a HealthGuard policy advisor. A customer asks: [[customer_question]]. Answer clearly covering coverage, exclusions, and next steps.',
    fields: [
      {
        key: 'customer_question',
        label: 'Customer Question',
        type: 'textarea',
        placeholder: 'e.g. Does my plan cover physiotherapy after surgery?',
        defaultValue: 'Does my plan cover physiotherapy after surgery?',
      },
    ],
  },
];

// ─── Component ────────────────────────────────────────────────────────────────

function defaultFields(tmpl) {
  return Object.fromEntries(tmpl.fields.map(f => [f.key, f.defaultValue || '']));
}

function buildTemplateUri(tmpl, fields) {
  const params = new URLSearchParams();
  tmpl.fields.forEach(f => { if (fields[f.key]) params.set(f.key, fields[f.key]); });
  return `template://${tmpl.id}?${params.toString()}`;
}

const MODELS = ['mistral-small-latest', 'mistral-medium', 'open-mistral-7b'];

function buildPayload(model, templateUri) {
  return {
    model,
    messages: [{ role: 'user', content: templateUri }],
  };
}

export default function PromptTemplate({ config }) {
  const [activeIdx, setActiveIdx] = useState(0);
  const [fields, setFields] = useState(defaultFields(TEMPLATES[0]));
  const [model, setModel] = useState(MODELS[0]);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);

  const tmpl = TEMPLATES[activeIdx];
  const templateUri = buildTemplateUri(tmpl, fields);
  const payload = buildPayload(model, templateUri);
  const payloadStr = JSON.stringify(payload, null, 2);

  useEffect(() => {
    setFields(defaultFields(TEMPLATES[activeIdx]));
    setResult(null);
  }, [activeIdx]);

  const setField = (k, v) => setFields(f => ({ ...f, [k]: v }));

  const send = async () => {
    setLoading(true); setResult(null);
    const apiKey = config?.apiKey;
    const res = await callAI(config.endpoints.promptTemplate, apiKey, payload);
    setResult(res);
    setLoading(false);
  };

  const color = '#0ea5e9';

  return (
    <div style={pageStyle}>
      <FeatureHeader
        icon="📋" badge="POLICY" color={color}
        title="Prompt Template"
        desc="The gateway intercepts requests using a template:// URI and replaces it with a full, structured prompt before forwarding to the AI model. Templates are managed centrally in APIM — consumers only send a template name and parameter values."
      />

      <InfoBox color={color} title="Gateway Policy: Prompt Template" items={[
        ['Endpoint', config?.endpoints?.promptTemplate],
        ['Policy', 'Prompt Template (Synapse mediator)'],
        ['Trigger', 'content starts with template://'],
        ['Substitution', '[[placeholder]] → query param value'],
        ['Applied on', 'Request flow'],
      ]} />

      {/* Gateway templates config display */}
      <div style={{ marginBottom: 24 }}>
        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', marginBottom: 6 }}>
          Templates configured in APIM gateway:
        </div>
        <pre style={{
          background: '#1e293b', color: '#7dd3fc', borderRadius: 8,
          padding: '12px 14px', fontSize: '0.72rem', lineHeight: 1.6,
          overflowX: 'auto', margin: 0,
        }}>{JSON.stringify(TEMPLATES.map(t => ({ name: t.id, prompt: t.gatewayPrompt })), null, 2)}</pre>
      </div>

      {/* Template selector */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 20 }}>
        {TEMPLATES.map((t, i) => (
          <button key={t.id} onClick={() => setActiveIdx(i)} style={{
            padding: '9px 20px', borderRadius: 8, cursor: 'pointer', fontWeight: 600, fontSize: '0.85rem',
            border: i === activeIdx ? `2px solid ${color}` : '2px solid #e2e8f0',
            background: i === activeIdx ? '#f0f9ff' : '#fff',
            color: i === activeIdx ? color : '#64748b',
          }}>
            {t.icon} {t.name}
          </button>
        ))}
      </div>

      {/* Fields */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginBottom: 20 }}>
        {/* First row: Model + first field side by side */}
        <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
          <div style={{ minWidth: 180 }}>
            <label style={labelStyle}>Model</label>
            <select value={model} onChange={e => setModel(e.target.value)}
              style={{ ...inputStyle, cursor: 'pointer' }}>
              {MODELS.map(m => <option key={m} value={m}>{m}</option>)}
            </select>
          </div>
          {tmpl.fields[0] && (
            <div style={{ flex: 1 }}>
              <label style={labelStyle}>{tmpl.fields[0].label}</label>
              {tmpl.fields[0].type === 'select' ? (
                <select value={fields[tmpl.fields[0].key] || ''} onChange={e => setField(tmpl.fields[0].key, e.target.value)}
                  style={{ ...inputStyle, cursor: 'pointer' }}>
                  {tmpl.fields[0].options.map(o => <option key={o} value={o}>{o}</option>)}
                </select>
              ) : (
                <textarea rows={3} value={fields[tmpl.fields[0].key] || ''}
                  onChange={e => setField(tmpl.fields[0].key, e.target.value)}
                  placeholder={tmpl.fields[0].placeholder}
                  style={{ ...inputStyle, resize: 'vertical', fontFamily: 'inherit' }} />
              )}
            </div>
          )}
        </div>
        {/* Remaining fields */}
        {tmpl.fields.slice(1).map(f => (
          <div key={f.key}>
            <label style={labelStyle}>{f.label}</label>
            {f.type === 'select' ? (
              <select value={fields[f.key] || ''} onChange={e => setField(f.key, e.target.value)}
                style={{ ...inputStyle, cursor: 'pointer' }}>
                {f.options.map(o => <option key={o} value={o}>{o}</option>)}
              </select>
            ) : (
              <textarea
                rows={3}
                value={fields[f.key] || ''}
                onChange={e => setField(f.key, e.target.value)}
                placeholder={f.placeholder}
                style={{ ...inputStyle, resize: 'vertical', fontFamily: 'inherit' }}
              />
            )}
          </div>
        ))}
      </div>

      {/* Auto-generated payload preview */}
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', marginBottom: 6 }}>
          Auto-generated request payload:
        </div>
        <pre style={{
          background: '#1e293b', color: '#e2e8f0', borderRadius: 8,
          padding: '12px 14px', fontSize: '0.75rem', lineHeight: 1.6,
          overflowX: 'auto', margin: 0,
        }}>
          {payloadStr}
        </pre>
        <div style={{ marginTop: 6, fontSize: '0.7rem', color: '#94a3b8' }}>
          ↑ The gateway replaces <code style={{ color: '#7dd3fc' }}>template://{tmpl.id}?…</code> with the full prompt before forwarding to the AI model
        </div>
      </div>

      <button onClick={send} disabled={loading || !config?.apiKey} style={sendBtn(loading || !config?.apiKey, color)}>
        {loading ? 'Sending…' : '▶ Send to Gateway'}
      </button>

      <ResponsePanel result={result} loading={loading} />
    </div>
  );
}
