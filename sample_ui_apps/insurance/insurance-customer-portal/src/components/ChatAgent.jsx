import React, { useState, useEffect, useRef } from 'react';
import config from '../config';

const BASE = import.meta.env.DEV
  ? '/api/chat'
  : config.chatApiBase;
const CHAT_URL = `${BASE}/chat`;

// Stable session ID per page load
const SESSION_ID = `session-${Date.now()}`;

export default function ChatAgent({ accessToken, hasPremiumCoverage, username }) {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const messagesEndRef = useRef(null);

  const endpoint = CHAT_URL;
  const modeLabel = hasPremiumCoverage ? 'Privileged Agent' : 'Agent';
  const modeColor = hasPremiumCoverage ? '#7c3aed' : '#0d6e6e';
  const placeholder = hasPremiumCoverage
    ? 'Submit a claim, request a policy update…'
    : 'Ask about your coverage, claims, policy details…';

  // Scroll to bottom on new messages
  useEffect(() => {
    if (open) messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, open]);

  // Greeting on first open
  useEffect(() => {
    if (open && messages.length === 0) {
      setMessages([{
        role: 'agent',
        text: hasPremiumCoverage
          ? "Hello! I'm your privileged insurance assistant. I can submit claims, update your policy, and answer any questions about your HealthGuard coverage."
          : "Hello! I'm your insurance assistant. I can answer questions about your policy, coverage details, and claim status. How can I help you today?"
      }]);
    }
  }, [open]);

  const sendMessage = async () => {
    const text = input.trim();
    if (!text || loading || !accessToken) return;

    setMessages(prev => [...prev, { role: 'user', text }]);
    setInput('');
    setLoading(true);

    try {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        body: JSON.stringify({ message: username ? `[Logged in user: ${username}]\n${text}` : text, sessionId: SESSION_ID })
      });

      if (res.ok) {
        const data = await res.json();
        setMessages(prev => [...prev, { role: 'agent', text: data.message }]);
      } else {
        setMessages(prev => [...prev, { role: 'agent', text: `Error: ${res.status} — ${res.statusText}` }]);
      }
    } catch (err) {
      setMessages(prev => [...prev, { role: 'agent', text: 'Connection error. Please try again.' }]);
    } finally {
      setLoading(false);
    }
  };

  const onKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  return (
    <>
      {/* Chat Panel */}
      {open && (
        <div style={{
          position: 'fixed', bottom: '90px', right: '24px',
          width: '380px', height: '560px',
          background: '#fff', borderRadius: '16px',
          boxShadow: '0 20px 60px rgba(13,110,110,0.2)',
          display: 'flex', flexDirection: 'column',
          zIndex: 1000, border: '1px solid #c8e0e0',
          overflow: 'hidden'
        }}>
          {/* Header */}
          <div style={{
            background: `linear-gradient(135deg, ${modeColor} 0%, #17a589 100%)`,
            padding: '16px 20px', color: '#fff',
            display: 'flex', justifyContent: 'space-between', alignItems: 'center'
          }}>
            <div>
              <div style={{ fontWeight: 700, fontSize: '1rem' }}>
                🤖 AI Insurance Assistant
              </div>
              <div style={{ fontSize: '0.75rem', opacity: 0.85, marginTop: '2px' }}>
                {modeLabel} · HealthGuard
              </div>
            </div>
            <button
              onClick={() => setOpen(false)}
              style={{
                background: 'rgba(255,255,255,0.2)', border: 'none',
                borderRadius: '50%', width: '30px', height: '30px',
                color: '#fff', cursor: 'pointer', fontSize: '1rem',
                display: 'flex', alignItems: 'center', justifyContent: 'center'
              }}
            >✕</button>
          </div>

          {/* Messages */}
          <div style={{
            flex: 1, overflowY: 'auto', padding: '16px',
            display: 'flex', flexDirection: 'column', gap: '12px',
            background: '#f8fbfb'
          }}>
            {messages.map((msg, i) => (
              <div key={i} style={{
                display: 'flex',
                justifyContent: msg.role === 'user' ? 'flex-end' : 'flex-start'
              }}>
                <div style={{
                  maxWidth: '80%', padding: '10px 14px',
                  borderRadius: msg.role === 'user' ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                  background: msg.role === 'user' ? modeColor : '#fff',
                  color: msg.role === 'user' ? '#fff' : '#1a2e2e',
                  fontSize: '0.875rem', lineHeight: '1.5',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.08)',
                  whiteSpace: 'pre-wrap', wordBreak: 'break-word',
                  border: msg.role === 'agent' ? '1px solid #e2e8f0' : 'none'
                }}>
                  {msg.text}
                </div>
              </div>
            ))}

            {loading && (
              <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
                <div style={{
                  padding: '10px 16px', borderRadius: '18px 18px 18px 4px',
                  background: '#fff', border: '1px solid #e2e8f0',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.08)'
                }}>
                  <span style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
                    {[0, 1, 2].map(n => (
                      <span key={n} style={{
                        width: '6px', height: '6px', borderRadius: '50%',
                        background: '#0d6e6e', opacity: 0.6,
                        animation: `bounce 1.2s ${n * 0.2}s infinite`
                      }} />
                    ))}
                  </span>
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          {/* Input */}
          <div style={{
            padding: '12px 16px', borderTop: '1px solid #e2e8f0',
            background: '#fff', display: 'flex', gap: '8px', alignItems: 'flex-end'
          }}>
            <textarea
              value={input}
              onChange={e => setInput(e.target.value)}
              onKeyDown={onKeyDown}
              placeholder={placeholder}
              rows={1}
              disabled={loading || !accessToken}
              style={{
                flex: 1, border: '2px solid #c8e0e0', borderRadius: '12px',
                padding: '10px 14px', fontSize: '0.875rem', fontFamily: 'inherit',
                resize: 'none', outline: 'none', lineHeight: '1.5',
                maxHeight: '100px', overflowY: 'auto',
                transition: 'border-color 0.2s',
                background: loading ? '#f8fafc' : '#fff'
              }}
              onFocus={e => e.target.style.borderColor = modeColor}
              onBlur={e => e.target.style.borderColor = '#c8e0e0'}
            />
            <button
              onClick={sendMessage}
              disabled={loading || !input.trim() || !accessToken}
              style={{
                width: '40px', height: '40px', borderRadius: '50%',
                border: 'none', background: modeColor,
                color: '#fff', cursor: loading || !input.trim() ? 'not-allowed' : 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: '1rem', flexShrink: 0,
                opacity: loading || !input.trim() ? 0.5 : 1,
                transition: 'opacity 0.2s'
              }}
            >
              ➤
            </button>
          </div>
        </div>
      )}

      {/* Floating Toggle Button */}
      <button
        onClick={() => setOpen(o => !o)}
        title="Open AI Insurance Assistant"
        style={{
          position: 'fixed', bottom: '24px', right: '24px',
          width: '56px', height: '56px', borderRadius: '50%',
          background: `linear-gradient(135deg, ${modeColor} 0%, #17a589 100%)`,
          border: 'none', color: '#fff', fontSize: '1.5rem',
          cursor: 'pointer', zIndex: 1001,
          boxShadow: '0 6px 20px rgba(13,110,110,0.4)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          transition: 'transform 0.2s, box-shadow 0.2s'
        }}
        onMouseEnter={e => { e.currentTarget.style.transform = 'scale(1.1)'; e.currentTarget.style.boxShadow = '0 8px 25px rgba(13,110,110,0.5)'; }}
        onMouseLeave={e => { e.currentTarget.style.transform = 'scale(1)'; e.currentTarget.style.boxShadow = '0 6px 20px rgba(13,110,110,0.4)'; }}
      >
        {open ? '✕' : '💬'}
      </button>

      {/* Bounce animation for typing dots */}
      <style>{`
        @keyframes bounce {
          0%, 60%, 100% { transform: translateY(0); }
          30% { transform: translateY(-6px); }
        }
      `}</style>
    </>
  );
}
