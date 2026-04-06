import React, { useState, useRef, useEffect } from 'react';
import { callAI } from '../api.js';
import { FeatureHeader, InfoBox, pageStyle, inputStyle } from './PromptTemplate.jsx';

const MODELS = ['mistral-small-latest', 'mistral-medium', 'open-mistral-7b'];

const TOKEN_QUOTA = 20;

const QUICK_PROMPTS = [
  'I was recently involved in a car accident and sustained injuries requiring emergency surgery, a 5-day hospital stay, and ongoing physical therapy. My HealthGuard Premium policy number is HG-2024-55231. The total medical bill is $24,500 which includes emergency room charges of $8,000, surgical fees of $10,000, hospitalization costs of $5,000, and physical therapy sessions totaling $1,500. I have already met my annual deductible of $1,500. My co-insurance is 80/20 after deductible. Please explain what HealthGuard will cover, what my out-of-pocket responsibility will be, what documents I need to submit my claim, and the expected timeline for claim processing and reimbursement.',
];

const DECORATOR_CONFIG = `{
  "decoration": [{
    "role": "system",
    "content": "You are a professional HealthGuard Insurance virtual assistant. Help customers with policy questions, claim submissions, benefit inquiries, and coverage details. Be empathetic, clear, and professional. Always end with an offer to help further."
  }]
}`;

export default function DecoratorAndRateLimit({ config }) {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [model, setModel] = useState(MODELS[0]);
  const [chatLoading, setChatLoading] = useState(false);
  const [promptTokensUsed, setPromptTokensUsed] = useState(0);
  const [rateLimited, setRateLimited] = useState(false);
  const bottomRef = useRef(null);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);

  const tokensRemaining = Math.max(0, TOKEN_QUOTA - promptTokensUsed);
  const tokenPct = Math.min((promptTokensUsed / TOKEN_QUOTA) * 100, 100);
  const tokenColor = tokenPct >= 100 ? '#ef4444' : tokenPct >= 75 ? '#f59e0b' : '#10b981';

  const sendChat = async (text) => {
    const userMsg = text || input.trim();
    if (!userMsg || chatLoading) return;
    setInput('');
    const next = [...messages, { role: 'user', content: userMsg }];
    setMessages(next);
    setChatLoading(true);

    const res = await callAI(config.endpoints.promptDecorator, config.apiKey, { model, messages: next });

    if (res.status === 429) {
      setRateLimited(true);
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: '⚡ Rate limit reached — prompt token quota exceeded. Reset the counter to continue.',
        errorJson: res.data,
        elapsed: res.elapsed, status: 429,
      }]);
    } else if (!res.ok) {
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: null,
        errorJson: res.data,
        elapsed: res.elapsed, status: res.status,
      }]);
    } else {
      const promptTokens = res.data?.usage?.prompt_tokens || 0;
      setPromptTokensUsed(prev => prev + promptTokens);
      const reply = res.status === 446
        ? `🛡 Guardrail blocked: ${res.data?.message?.actionReason || 'content policy violation'}`
        : res.data?.choices?.[0]?.message?.content || `Error ${res.status}`;
      setMessages(prev => [...prev, { role: 'assistant', content: reply, elapsed: res.elapsed, status: res.status, promptTokens }]);
    }
    setChatLoading(false);
  };

  const resetSession = () => {
    setMessages([]);
    setPromptTokensUsed(0);
    setRateLimited(false);
  };

  const color = '#0ea5e9';
  const rColor = '#f59e0b';

  return (
    <div style={pageStyle}>
      <FeatureHeader
        icon="🎨⚡" badge="COMBINED POLICY" color={color}
        title="Prompt Decorator + Rate Limiting"
        desc="The gateway injects the HealthGuard persona on every request via Prompt Decorator, and enforces a prompt token quota via AI Rate Limiting. When the quota is exhausted, requests are blocked with HTTP 429."
      />

      {/* Policy info row */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 28 }}>
        <InfoBox color={color} title="Prompt Decorator" items={[
          ['Endpoint', config.endpoints.promptDecorator],
          ['Policy', 'Prompt Decorator'],
          ['JSON Path', '$.messages (chat-level)'],
          ['Mode', 'Prepend system message'],
          ['Applied on', 'Request flow'],
        ]} />
        <InfoBox color={rColor} title="Rate Limiting" items={[
          ['Policy', 'AI Subscription Tier'],
          ['Prompt Token Quota', `${TOKEN_QUOTA} tokens / session`],
          ['On Limit', 'HTTP 429'],
          ['Config', 'Admin Portal → AI Rate Limiting'],
        ]} />
      </div>

      {/* ── Decorated Chat ── */}
      <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 12, marginBottom: 24, overflow: 'hidden' }}>
        <div style={{ background: '#f0f9ff', padding: '12px 18px', borderBottom: '1px solid #bae6fd', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <span style={{ fontWeight: 700, color: color, fontSize: '0.9rem' }}>🎨 Decorated Chat</span>
            <span style={{ fontSize: '0.72rem', color: '#64748b', marginLeft: 10 }}>Gateway injects HealthGuard persona — you send plain messages</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ fontSize: '0.72rem', color: '#64748b', fontWeight: 600 }}>Model</span>
              <select value={model} onChange={e => setModel(e.target.value)}
                style={{ ...inputStyle, cursor: 'pointer', width: 'auto', padding: '4px 8px', fontSize: '0.75rem' }}>
                {MODELS.map(m => <option key={m} value={m}>{m}</option>)}
              </select>
            </div>
          </div>
        </div>

        {/* Decorator config preview */}
        <div style={{ padding: '10px 18px', borderBottom: '1px solid #e2e8f0', background: '#fafafa' }}>
          <div style={{ fontSize: '0.68rem', color: '#94a3b8', marginBottom: 4, fontWeight: 700 }}>Injected by gateway (not sent by client):</div>
          <pre style={{ margin: 0, background: '#1e293b', color: '#7dd3fc', borderRadius: 6, padding: '8px 12px', fontSize: '0.68rem', lineHeight: 1.5, overflowX: 'auto' }}>{DECORATOR_CONFIG}</pre>
        </div>

        {/* Quick prompts */}
        <div style={{ padding: '10px 18px', borderBottom: '1px solid #e2e8f0', display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {QUICK_PROMPTS.map(p => (
            <button key={p} onClick={() => setInput(p)} disabled={chatLoading || rateLimited} style={{
              background: '#f0f9ff', border: '1px solid #bae6fd', borderRadius: 20,
              padding: '4px 12px', cursor: chatLoading || rateLimited ? 'not-allowed' : 'pointer',
              fontSize: '0.75rem', color: color, opacity: rateLimited ? 0.4 : 1,
            }}>{p}</button>
          ))}
        </div>

        {/* Messages */}
        <div style={{ minHeight: 80, maxHeight: 280, overflowY: 'auto', padding: 14, display: 'flex', flexDirection: 'column', gap: 10, background: '#fafafa' }}>
          {messages.length === 0 && (
            <div style={{ textAlign: 'center', color: '#cbd5e1', fontSize: '0.82rem', padding: '20px 0' }}>
              Pick a quick prompt or type below to start
            </div>
          )}
          {messages.map((m, i) => {
            const isError = m.role === 'assistant' && !m.content && m.errorJson;
            const is429 = m.status === 429;
            const bgColor = is429 ? '#fef9c3' : isError ? '#fff1f2' : m.role === 'user' ? color : '#fff';
            const textColor = is429 ? '#92400e' : isError ? '#881337' : m.role === 'user' ? '#fff' : '#1e293b';
            const borderColor = is429 ? '#fde68a' : isError ? '#fda4af' : '#e2e8f0';
            return (
              <div key={i} style={{ display: 'flex', justifyContent: m.role === 'user' ? 'flex-end' : 'flex-start' }}>
                <div style={{
                  maxWidth: '82%', padding: '10px 14px',
                  borderRadius: m.role === 'user' ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                  background: bgColor, color: textColor,
                  fontSize: '0.85rem', lineHeight: 1.6,
                  border: m.role === 'assistant' ? `1px solid ${borderColor}` : 'none',
                  boxShadow: '0 1px 4px rgba(0,0,0,0.06)', whiteSpace: 'pre-wrap',
                }}>
                  {m.content}
                  {(isError || is429) && m.errorJson && (
                    <pre style={{
                      margin: m.content ? '8px 0 0' : 0,
                      background: '#1e293b', color: '#fda4af', borderRadius: 6,
                      padding: '8px 12px', fontSize: '0.72rem', lineHeight: 1.5,
                      overflowX: 'auto', whiteSpace: 'pre',
                    }}>{JSON.stringify(m.errorJson, null, 2)}</pre>
                  )}
                  <div style={{ display: 'flex', gap: 8, marginTop: 4, justifyContent: 'flex-end' }}>
                    {m.elapsed && <span style={{ fontSize: '0.65rem', opacity: 0.5 }}>⏱ {m.elapsed}ms</span>}
                    {m.promptTokens > 0 && <span style={{ fontSize: '0.65rem', color: rColor, opacity: 0.8 }}>🪙 {m.promptTokens} prompt tokens</span>}
                  </div>
                </div>
              </div>
            );
          })}
          {chatLoading && (
            <div style={{ display: 'flex' }}>
              <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: '18px 18px 18px 4px', padding: '10px 16px' }}>
                <span style={{ display: 'flex', gap: 4 }}>
                  {[0,1,2].map(n => <span key={n} style={{ width:6, height:6, borderRadius:'50%', background: color, animation:`bounce 1.1s ${n*0.2}s infinite` }}/>)}
                </span>
              </div>
            </div>
          )}
          <div ref={bottomRef}/>
        </div>

        {/* Input */}
        <div style={{ padding: '10px 14px', borderTop: '1px solid #e2e8f0', display: 'flex', gap: 8, alignItems: 'flex-end', background: '#fff' }}>
          <textarea
            rows={2}
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendChat(); } }}
            placeholder={rateLimited ? '⚡ Quota exhausted — click ↺ Reset to continue' : 'Ask about your coverage, claims, or policy…'}
            disabled={chatLoading || rateLimited}
            style={{
              flex: 1, padding: '9px 12px', border: `1px solid ${rateLimited ? '#fca5a5' : '#e2e8f0'}`, borderRadius: 10,
              fontSize: '0.85rem', resize: 'none', outline: 'none', fontFamily: 'inherit',
              background: rateLimited ? '#fff5f5' : '#fff',
            }}
          />
          <button onClick={() => sendChat()} disabled={chatLoading || !input.trim() || rateLimited} style={{
            background: color, color: '#fff', border: 'none', borderRadius: 10,
            padding: '10px 18px', cursor: chatLoading || !input.trim() || rateLimited ? 'not-allowed' : 'pointer',
            fontWeight: 700, opacity: chatLoading || !input.trim() || rateLimited ? 0.5 : 1, fontSize: '0.85rem',
          }}>Send</button>
        </div>

        {/* Payload preview */}
        <div style={{ padding: '10px 18px', borderTop: '1px solid #e2e8f0', background: '#fafafa' }}>
          <div style={{ fontSize: '0.68rem', color: '#94a3b8', fontWeight: 700, marginBottom: 4 }}>Auto-generated request payload:</div>
          <pre style={{ margin: 0, background: '#1e293b', color: '#e2e8f0', borderRadius: 6, padding: '8px 12px', fontSize: '0.68rem', lineHeight: 1.5, overflowX: 'auto' }}>
            {JSON.stringify({ model, messages: [{ role: 'user', content: input.trim() || '…' }] }, null, 2)}
          </pre>
        </div>
      </div>

      <style>{`@keyframes bounce{0%,80%,100%{transform:translateY(0)}40%{transform:translateY(-7px)}}`}</style>
    </div>
  );
}
