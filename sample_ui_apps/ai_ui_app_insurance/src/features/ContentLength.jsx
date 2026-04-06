import React, { useState } from 'react';
import { callAI } from '../api.js';
import { FeatureHeader, InfoBox, pageStyle, warnStyle, sendBtn, labelStyle, inputStyle } from './PromptTemplate.jsx';
import ResponsePanel from '../components/ResponsePanel.jsx';

const MODELS = ['mistral-small-latest', 'mistral-medium', 'open-mistral-7b'];

const MIN_BYTES = 20;
const MAX_BYTES = 500;

const PRESETS = [
  { label: '🚫 Too Short (<20 bytes)', prompt: 'Hi' },
  { label: '✅ Valid Length', prompt: 'I recently visited an emergency room after a car accident. My HealthGuard policy is #HG-2024-55231. What documents do I need to submit my claim?' },
  { label: '🚫 Too Long (>500 bytes)', prompt: 'I am writing to inquire about the status of my insurance claim that I submitted three weeks ago. The claim number is HG-CLAIM-2024-98765 and it relates to an emergency hospitalization I underwent in February. During that time, I was admitted for five days due to severe pneumonia. The total hospital bill came to $24,500 which includes ICU charges, medication, physician fees, and diagnostic tests. I have already submitted all the required documents including my discharge summary, itemized bills, prescriptions, and lab reports. However, I have not received any update from HealthGuard yet. Could you please investigate this matter urgently and let me know the current status of my claim, the expected timeline for resolution, and whether any additional documents are required from my end? I would greatly appreciate a prompt response.' },
];

function byteLength(str) { return new TextEncoder().encode(str).length; }

function meterColor(bytes) {
  if (bytes < MIN_BYTES || bytes > MAX_BYTES) return '#ef4444';
  return '#10b981';
}

function meterLabel(bytes) {
  if (bytes < MIN_BYTES) return `Too short — ${bytes}/${MIN_BYTES} bytes minimum`;
  if (bytes > MAX_BYTES) return `Too long — ${bytes}/${MAX_BYTES} bytes maximum`;
  return `✅ Valid — ${bytes} bytes`;
}

export default function ContentLength({ config }) {
  const [input, setInput] = useState(PRESETS[1].prompt);
  const [model, setModel] = useState(MODELS[0]);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const color = '#f97316';
  const bytes = byteLength(input);

  const payload = { model, messages: [{ role: 'user', content: input }] };

  const send = async () => {
    setLoading(true); setResult(null);
    const res = await callAI(config.endpoints.contentLength, config.apiKey, payload);
    setResult(res); setLoading(false);
  };

  const meterWidth = Math.min(Math.max(bytes / MAX_BYTES, 0), 1.2) * 100;

  return (
    <div style={pageStyle}>
      <FeatureHeader
        icon="📏" badge="GUARDRAIL" color={color}
        title="Content Length Guardrail"
        desc="The gateway enforces minimum and maximum byte-length constraints on AI prompts. This prevents trivially short inputs (bot probing) and excessively long prompts (token cost attacks). Violations are blocked with HTTP 446 before the AI model is invoked."
      />

      <InfoBox color={color} title="Gateway Policy: Content Length Guardrail" items={[
        ['Policy', 'Content Length Guardrail (Synapse mediator)'],
        ['Minimum Length', `${MIN_BYTES} bytes`],
        ['Maximum Length', `${MAX_BYTES} bytes`],
        ['JSON Path', '$.messages[0].content'],
        ['Invert Decision', 'false'],
        ['Block Response', 'HTTP 446 · CONTENT_LENGTH_GUARDRAIL'],
        ['Applied on', 'Request flow'],
      ]} />

      {/* Model + Presets row */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 14, gap: 16, flexWrap: 'wrap' }}>
        <div>
          <div style={{ fontSize: '0.75rem', color: '#94a3b8', fontWeight: 700, marginBottom: 8 }}>Try these examples:</div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {PRESETS.map((p, i) => (
              <button key={i} onClick={() => { setInput(p.prompt); setResult(null); }} style={{
                padding: '7px 14px', borderRadius: 8, cursor: 'pointer', fontSize: '0.78rem',
                border: input === p.prompt ? `2px solid ${color}` : '2px solid #e2e8f0',
                background: input === p.prompt ? '#fff7ed' : '#fff', color: '#334155',
                fontWeight: input === p.prompt ? 600 : 400,
              }}>
                {p.label}
              </button>
            ))}
          </div>
        </div>
        <div>
          <label style={labelStyle}>Model</label>
          <select value={model} onChange={e => setModel(e.target.value)}
            style={{ ...inputStyle, cursor: 'pointer', width: 'auto' }}>
            {MODELS.map(m => <option key={m} value={m}>{m}</option>)}
          </select>
        </div>
      </div>

      {/* Content textarea */}
      <div style={{ marginBottom: 10 }}>
        <label style={labelStyle}>
          Message content&nbsp;
          <span style={{ fontWeight: 400, color: '#94a3b8' }}>— checked via <code style={{ color: '#f97316' }}>$.messages[0].content</code></span>
        </label>
        <textarea
          rows={5}
          value={input}
          onChange={e => { setInput(e.target.value); setResult(null); }}
          placeholder="Enter your insurance query…"
          style={{
            width: '100%', padding: '10px 14px', border: `2px solid ${meterColor(bytes)}`,
            borderRadius: 8, fontSize: '0.85rem', resize: 'vertical', outline: 'none',
            fontFamily: 'inherit', boxSizing: 'border-box', transition: 'border-color 0.2s',
          }}
        />
      </div>

      {/* Byte meter */}
      <div style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
          <span style={{ fontSize: '0.75rem', fontWeight: 600, color: meterColor(bytes) }}>{meterLabel(bytes)}</span>
          <span style={{ fontSize: '0.72rem', color: '#94a3b8' }}>Min: {MIN_BYTES} · Max: {MAX_BYTES}</span>
        </div>
        <div style={{ background: '#e2e8f0', borderRadius: 6, height: 8, overflow: 'hidden' }}>
          <div style={{
            height: '100%', borderRadius: 6,
            width: `${Math.min(meterWidth, 100)}%`,
            background: meterColor(bytes),
            transition: 'width 0.2s, background 0.2s',
          }}/>
        </div>
        {bytes > MAX_BYTES && (
          <div style={{ marginTop: 4, background: '#fee2e2', border: '1px solid #fca5a5', borderRadius: 6, padding: '4px 10px' }}>
            <span style={{ fontSize: '0.72rem', color: '#991b1b' }}>⚠ {bytes - MAX_BYTES} bytes over limit</span>
          </div>
        )}
      </div>

      {/* Payload preview */}
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', marginBottom: 6 }}>
          Auto-generated request payload:
        </div>
        <pre style={{
          background: '#1e293b', color: '#e2e8f0', borderRadius: 8,
          padding: '12px 14px', fontSize: '0.75rem', lineHeight: 1.6,
          overflowX: 'auto', margin: 0,
        }}>{JSON.stringify(payload, null, 2)}</pre>
        <div style={{ marginTop: 6, fontSize: '0.7rem', color: '#94a3b8' }}>
          ↑ Gateway evaluates byte length of <code style={{ color: '#f97316' }}>$.messages[0].content</code>
        </div>
      </div>

      <button onClick={send} disabled={loading || !input.trim() || !config.apiKey} style={sendBtn(loading || !input.trim() || !config.apiKey, color)}>
        {loading ? 'Checking…' : '▶ Send to Gateway'}
      </button>
      {!config.apiKey && <div style={warnStyle}>Configure your API key in ⚙️ Settings first</div>}

      <ResponsePanel result={result} loading={loading} />
    </div>
  );
}
