import React, { useState } from 'react';
import { callAI } from '../api.js';
import { FeatureHeader, InfoBox, pageStyle, warnStyle, sendBtn } from './PromptTemplate.jsx';

const PROMPTS = [
  'What does my annual deductible reset to each year?',
  'Is dental covered in the basic health plan?',
  'How long does claim processing take?',
  'Can I add a dependent to my policy mid-year?',
  'What is the out-of-pocket maximum for emergency care?',
  'Does my plan cover prescription medication?',
  'How do I find an in-network specialist?',
  'What is the co-pay for urgent care visits?',
  'Can I get reimbursed for out-of-network doctors?',
  'Is mental health therapy covered?',
];

export default function RateLimiting({ config }) {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(false);
  const [burstCount, setBurstCount] = useState(5);

  const color = '#f59e0b';

  const addResult = (r, prompt) =>
    setRequests(prev => [...prev, { ...r, prompt, ts: Date.now() }]);

  const sendSingle = async () => {
    if (loading || !config.apiKey) return;
    setLoading(true);
    const prompt = PROMPTS[requests.length % PROMPTS.length];
    const res = await callAI(config.endpoints.rateLimiting, config.apiKey, {
      model: config.model,
      messages: [{ role: 'user', content: prompt }],
    });
    addResult(res, prompt);
    setLoading(false);
  };

  const sendBurst = async () => {
    if (loading || !config.apiKey) return;
    setLoading(true);
    const start = requests.length;
    const calls = Array.from({ length: burstCount }, (_, i) =>
      callAI(config.endpoints.rateLimiting, config.apiKey, {
        model: config.model,
        messages: [{ role: 'user', content: PROMPTS[(start + i) % PROMPTS.length] }],
      }).then(res => ({ ...res, prompt: PROMPTS[(start + i) % PROMPTS.length] }))
    );
    const results = await Promise.all(calls);
    setRequests(prev => [...prev, ...results.map(r => ({ ...r, ts: Date.now() }))]);
    setLoading(false);
  };

  const totalTokens = requests.reduce((acc, r) => acc + (r.data?.usage?.total_tokens || 0), 0);
  const limitHits = requests.filter(r => r.status === 429).length;
  const successCount = requests.filter(r => r.ok).length;

  return (
    <div style={pageStyle}>
      <FeatureHeader
        icon="⚡" badge="RATE LIMIT" color={color}
        title="AI Rate Limiting"
        desc="APIM enforces token-based and request-based quotas on AI APIs. Subscription tiers control how many requests or tokens a consumer can use. When limits are exceeded, APIM returns 429 — protecting AI backends from cost overruns."
      />

      <InfoBox color={color} title="Gateway Policy: AI Subscription Rate Limit" items={[
        ['Policy Type', 'Subscription-Level AI Rate Limiting'],
        ['Quota Types', 'Request Count · Total Tokens · Prompt Tokens · Completion Tokens'],
        ['Example Tier', '"AI Bronze" — 100 requests/min, 50,000 total tokens/day'],
        ['Response on Limit', 'HTTP 429 Too Many Requests'],
        ['Config Location', 'APIM Admin Portal → Rate Limiting → AI Subscription Policies'],
      ]} />

      {/* Controls */}
      <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 20, flexWrap: 'wrap' }}>
        <button onClick={sendSingle} disabled={loading || !config.apiKey} style={sendBtn(loading || !config.apiKey, color)}>
          ▶ Send 1 Request
        </button>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <button onClick={sendBurst} disabled={loading || !config.apiKey} style={{
            ...sendBtn(loading || !config.apiKey, '#dc2626'),
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            ⚡ Burst: Send {burstCount} Requests
          </button>
          <select value={burstCount} onChange={e => setBurstCount(+e.target.value)} style={{
            padding: '6px 10px', border: '1px solid #e2e8f0', borderRadius: 8, fontSize: '0.82rem',
          }}>
            {[3,5,8,10].map(n => <option key={n} value={n}>{n}</option>)}
          </select>
        </div>
        {requests.length > 0 && (
          <button onClick={() => setRequests([])} style={{
            padding: '10px 16px', border: '1px solid #e2e8f0', borderRadius: 8, background: '#fff',
            cursor: 'pointer', fontSize: '0.82rem', color: '#64748b',
          }}>Clear</button>
        )}
      </div>
      {!config.apiKey && <div style={warnStyle}>Configure your API key in ⚙️ Settings first</div>}

      {/* Stats */}
      {requests.length > 0 && (
        <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' }}>
          {[
            ['Total Requests', requests.length, '#0f172a'],
            ['✅ Successful', successCount, '#10b981'],
            ['🚫 Rate Limited', limitHits, '#ef4444'],
            ['🪙 Total Tokens', totalTokens, '#8b5cf6'],
          ].map(([label, val, c]) => (
            <div key={label} style={{
              background: '#fff', border: '1px solid #e2e8f0', borderRadius: 10,
              padding: '12px 20px', textAlign: 'center', minWidth: 110,
            }}>
              <div style={{ fontSize: '1.5rem', fontWeight: 800, color: c }}>{val}</div>
              <div style={{ fontSize: '0.72rem', color: '#94a3b8', marginTop: 2 }}>{label}</div>
            </div>
          ))}
        </div>
      )}

      {/* Request log */}
      {requests.length > 0 && (
        <div style={{ border: '1px solid #e2e8f0', borderRadius: 10, overflow: 'hidden' }}>
          <div style={{ background: '#f8fafc', padding: '8px 14px', borderBottom: '1px solid #e2e8f0', fontSize: '0.72rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
            Request Log
          </div>
          <div style={{ maxHeight: 380, overflowY: 'auto' }}>
            {[...requests].reverse().map((r, i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 12, padding: '10px 14px',
                borderBottom: '1px solid #f1f5f9', background: r.status === 429 ? '#fffbeb' : '#fff',
              }}>
                <span style={{
                  padding: '2px 10px', borderRadius: 20, fontSize: '0.72rem', fontWeight: 700, flexShrink: 0,
                  background: r.ok ? '#dcfce7' : r.status === 429 ? '#fef9c3' : '#fee2e2',
                  color: r.ok ? '#166534' : r.status === 429 ? '#92400e' : '#991b1b',
                }}>
                  {r.status === 429 ? '429 LIMITED' : r.ok ? `${r.status} OK` : `${r.status} ERR`}
                </span>
                <span style={{ fontSize: '0.75rem', color: '#64748b', flexShrink: 0 }}>⏱ {r.elapsed}ms</span>
                {r.data?.usage?.total_tokens && (
                  <span style={{ fontSize: '0.72rem', color: '#8b5cf6', flexShrink: 0 }}>🪙 {r.data.usage.total_tokens} tok</span>
                )}
                <span style={{ fontSize: '0.78rem', color: '#475569', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {r.prompt}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
