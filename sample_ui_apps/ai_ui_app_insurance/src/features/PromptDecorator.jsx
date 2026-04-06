import React, { useState, useRef, useEffect } from 'react';
import { callAI } from '../api.js';
import { FeatureHeader, InfoBox, pageStyle, warnStyle } from './PromptTemplate.jsx';

const QUICK_PROMPTS = [
  'What does my deductible mean?',
  'How do I file a claim for emergency surgery?',
  'Is physiotherapy covered under my Basic Health plan?',
  'What documents do I need to renew my policy?',
  'Explain the difference between co-pay and co-insurance.',
];

const DECORATOR_CONFIG = `{
  "decoration": [{
    "role": "system",
    "content": "You are a professional HealthGuard Insurance virtual assistant. Help customers with policy questions, claim submissions, benefit inquiries, and coverage details. Be empathetic, clear, and professional. Always end with an offer to help further."
  }]
}`;

export default function PromptDecorator({ config }) {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [lastElapsed, setLastElapsed] = useState(null);
  const bottomRef = useRef(null);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);

  const send = async (text) => {
    const userMsg = text || input.trim();
    if (!userMsg || loading || !config.apiKey) return;
    setInput('');
    const newMessages = [...messages, { role: 'user', content: userMsg }];
    setMessages(newMessages);
    setLoading(true);

    const res = await callAI(config.endpoints.promptDecorator, config.apiKey, {
      model: config.model,
      messages: newMessages,
    });

    setLastElapsed(res.elapsed);
    const aiContent = res.data?.choices?.[0]?.message?.content
      || (res.status === 446 ? `🛡 Guardrail intervened: ${res.data?.message?.actionReason}` : `Error ${res.status}: ${JSON.stringify(res.data)}`)
    setMessages(prev => [...prev, { role: 'assistant', content: aiContent, elapsed: res.elapsed, status: res.status }]);
    setLoading(false);
  };

  const color = '#0ea5e9';

  return (
    <div style={pageStyle}>
      <FeatureHeader
        icon="🎨" badge="POLICY" color={color}
        title="Prompt Decorator"
        desc="The gateway injects a HealthGuard Insurance assistant persona (system message) before every request. The consumer sends plain user messages — the decorator is applied centrally at the API level, invisible to the caller."
      />

      <InfoBox color={color} title="Gateway Policy: Prompt Decorator" items={[
        ['Policy', 'Prompt Decorator (Synapse mediator)'],
        ['JSON Path', '$.messages (chat-level decoration)'],
        ['Mode', 'Prepend system message'],
        ['Applied on', 'Request flow'],
        ['Effect', 'Injects HealthGuard Insurance persona for all consumers'],
      ]} />

      {/* Decorator content preview */}
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', marginBottom: 6 }}>
          Gateway injects this system message (not sent by the client):
        </div>
        <pre style={{
          background: '#1e293b', color: '#7dd3fc', borderRadius: 8,
          padding: '12px 14px', fontSize: '0.72rem', lineHeight: 1.6,
          overflowX: 'auto', margin: 0,
        }}>{DECORATOR_CONFIG}</pre>
      </div>

      {/* Quick prompts */}
      <div style={{ marginBottom: 16 }}>
        <div style={{ fontSize: '0.75rem', color: '#94a3b8', marginBottom: 8, fontWeight: 600 }}>Quick prompts:</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {QUICK_PROMPTS.map(p => (
            <button key={p} onClick={() => send(p)} disabled={loading}
              style={{
                background: '#f0f9ff', border: '1px solid #bae6fd', borderRadius: 20,
                padding: '5px 14px', cursor: 'pointer', fontSize: '0.78rem', color: '#0ea5e9', fontWeight: 500,
              }}
            >{p}</button>
          ))}
        </div>
      </div>

      {/* Chat history */}
      {messages.length > 0 && (
        <div style={{
          border: '1px solid #e2e8f0', borderRadius: 12, overflow: 'hidden', marginBottom: 16,
          maxHeight: 380, display: 'flex', flexDirection: 'column',
        }}>
          <div style={{ background: '#f8fafc', padding: '8px 14px', borderBottom: '1px solid #e2e8f0', fontSize: '0.7rem', color: '#94a3b8', fontWeight: 700 }}>
            CONVERSATION
          </div>
          <div style={{ overflowY: 'auto', padding: 14, display: 'flex', flexDirection: 'column', gap: 10, background: '#fafafa', flex: 1 }}>
            {messages.map((m, i) => (
              <div key={i} style={{ display: 'flex', justifyContent: m.role === 'user' ? 'flex-end' : 'flex-start' }}>
                <div style={{
                  maxWidth: '82%', padding: '10px 14px',
                  borderRadius: m.role === 'user' ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                  background: m.role === 'user' ? color : '#fff',
                  color: m.role === 'user' ? '#fff' : '#1e293b',
                  fontSize: '0.85rem', lineHeight: 1.6, boxShadow: '0 1px 4px rgba(0,0,0,0.07)',
                  border: m.role === 'assistant' ? '1px solid #e2e8f0' : 'none',
                  whiteSpace: 'pre-wrap',
                }}>
                  {m.content}
                  {m.elapsed && (
                    <div style={{ fontSize: '0.65rem', opacity: 0.6, marginTop: 4, textAlign: 'right' }}>⏱ {m.elapsed}ms</div>
                  )}
                </div>
              </div>
            ))}
            {loading && (
              <div style={{ display: 'flex' }}>
                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: '18px 18px 18px 4px', padding: '10px 16px', boxShadow: '0 1px 4px rgba(0,0,0,0.07)' }}>
                  <span style={{ display: 'flex', gap: 4 }}>
                    {[0,1,2].map(n => <span key={n} style={{ width:6, height:6, borderRadius:'50%', background: color, animation:`bounce 1.1s ${n*0.2}s infinite` }}/>)}
                  </span>
                </div>
              </div>
            )}
            <div ref={bottomRef}/>
          </div>
        </div>
      )}

      {/* Input */}
      <div style={{ display: 'flex', gap: 10, alignItems: 'flex-end' }}>
        <textarea
          rows={2}
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } }}
          placeholder="Ask anything — the gateway adds the HealthGuard persona for you…"
          disabled={loading || !config.apiKey}
          style={{
            flex: 1, padding: '10px 14px', border: '1px solid #e2e8f0', borderRadius: 10,
            fontSize: '0.85rem', resize: 'none', outline: 'none', fontFamily: 'inherit',
            background: loading ? '#f8fafc' : '#fff',
          }}
        />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <button onClick={() => send()} disabled={loading || !input.trim() || !config.apiKey} style={{
            background: color, color: '#fff', border: 'none', borderRadius: 10,
            padding: '10px 18px', cursor: loading || !input.trim() ? 'not-allowed' : 'pointer',
            fontSize: '0.85rem', fontWeight: 700, opacity: loading || !input.trim() ? 0.5 : 1,
          }}>Send</button>
          {messages.length > 0 && (
            <button onClick={() => { setMessages([]); setLastElapsed(null); }} style={{
              background: '#f1f5f9', color: '#64748b', border: 'none', borderRadius: 10,
              padding: '6px 14px', cursor: 'pointer', fontSize: '0.75rem',
            }}>Clear</button>
          )}
        </div>
      </div>
      {!config.apiKey && <div style={warnStyle}>Configure your API key in ⚙️ Settings first</div>}
      <style>{`@keyframes bounce{0%,80%,100%{transform:translateY(0)}40%{transform:translateY(-7px)}}`}</style>
    </div>
  );
}
