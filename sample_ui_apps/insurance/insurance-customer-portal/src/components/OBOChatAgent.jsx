import React, { useState, useEffect, useRef } from 'react';
import config from '../config';

const BASE = import.meta.env.DEV ? '/api/obo_chat' : config.oboChatApiBase;
const OBO_CHAT_URL = `${BASE}/obo_chat`;

// Stable session ID per page load — shared across consent round-trips
const OBO_SESSION_ID = `obo-session-${Date.now()}`;

function decodeJwt(token) {
  try {
    const payload = token.split('.')[1];
    const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(decodeURIComponent(
      json.split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join('')
    ));
  } catch { return null; }
}

export default function OBOChatAgent({ accessToken, username, onOboToken, onAgentToken }) {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [pendingMessage, setPendingMessage] = useState(null);
  const messagesEndRef = useRef(null);

  useEffect(() => {
    if (open) messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, open]);

  useEffect(() => {
    if (open && messages.length === 0) {
      setMessages([{
        role: 'agent',
        text: "Hello! I'm your OBO-enabled insurance assistant. For read-only queries (policy, claims) I'll respond directly. For submitting a claim I'll ask for your explicit authorization first — that's the OBO flow in action."
      }]);
    }
  }, [open]);

  // Listen for consent popup callback
  useEffect(() => {
    const handleMessage = (event) => {
      if (event.data?.type === 'obo_authorized') {
        console.log('[OBO Agent] Popup callback event.data:', event.data);
        if (event.data.obo_token) {
          const decoded = decodeJwt(event.data.obo_token);
          console.log('[OBO Agent] OBO token from popup:', event.data.obo_token);
          console.log('[OBO Agent] Decoded OBO claims:', decoded);
          if (onOboToken) onOboToken(event.data.obo_token);
        }
        setMessages(prev => [...prev, {
          role: 'agent',
          text: '✅ Authorization successful! Retrying your request with delegated access...'
        }]);
        if (pendingMessage) {
          const msg = pendingMessage;
          setPendingMessage(null);
          doSend(msg);
        }
      }
    };
    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [pendingMessage]);

  const doSend = async (text) => {
    setLoading(true);
    try {
      const res = await fetch(OBO_CHAT_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        body: JSON.stringify({ message: username ? `[Logged in user: ${username}]\n${text}` : text, sessionId: OBO_SESSION_ID })
      });

      if (res.ok) {
        const data = await res.json();
        console.log('[OBO Agent] Response data:', data);
        if (data.agent_token) {
          const decodedAgent = decodeJwt(data.agent_token);
          console.log('[OBO Agent] Agent token:', data.agent_token);
          console.log('[OBO Agent] Agent token decoded:', decodedAgent);
          if (onAgentToken) onAgentToken(data.agent_token);
        }
        if (data.obo_token) {
          const decoded = decodeJwt(data.obo_token);
          console.log('[OBO Agent] Delegated token:', data.obo_token);
          console.log('[OBO Agent] Decoded claims:', decoded);
          if (onOboToken) onOboToken(data.obo_token);
        }
        if (data.consent_url) {
          // Agent tried submitClaim but needs OBO token — show consent button
          setPendingMessage(text);
          setMessages(prev => [...prev, {
            role: 'consent',
            text: data.message,
            consentUrl: data.consent_url
          }]);
        } else {
          setMessages(prev => [...prev, { role: 'agent', text: data.message }]);
        }
      } else {
        setMessages(prev => [...prev, { role: 'agent', text: `Error: ${res.status} — ${res.statusText}` }]);
      }
    } catch (err) {
      setMessages(prev => [...prev, { role: 'agent', text: 'Connection error. Please try again.' }]);
    } finally {
      setLoading(false);
    }
  };

  const sendMessage = () => {
    const text = input.trim();
    if (!text || loading || !accessToken) return;
    setMessages(prev => [...prev, { role: 'user', text }]);
    setInput('');
    doSend(text);
  };

  const openConsentPopup = (url) => {
    window.open(url, 'obo_consent', 'width=600,height=700,scrollbars=yes,resizable=yes');
  };

  const onKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  };

  const color = '#7c3aed';

  return (
    <>
      {open && (
        <div style={{
          position: 'fixed', bottom: '90px', right: '90px',
          width: '420px', height: '580px',
          background: '#fff', borderRadius: '16px',
          boxShadow: '0 20px 60px rgba(124,58,237,0.2)',
          display: 'flex', flexDirection: 'column',
          zIndex: 1000, border: '1px solid #ddd6fe', overflow: 'hidden'
        }}>
          {/* Header */}
          <div style={{
            background: 'linear-gradient(135deg, #7c3aed 0%, #a78bfa 100%)',
            padding: '16px 20px', color: '#fff',
            display: 'flex', justifyContent: 'space-between', alignItems: 'center'
          }}>
            <div>
              <div style={{ fontWeight: 700, fontSize: '1rem' }}>🔐 OBO Insurance Agent</div>
              <div style={{ fontSize: '0.75rem', opacity: 0.85, marginTop: '2px' }}>
                On-Behalf-Of · HealthGuard
              </div>
            </div>
            <button onClick={() => setOpen(false)} style={{
              background: 'rgba(255,255,255,0.2)', border: 'none', borderRadius: '50%',
              width: '30px', height: '30px', color: '#fff', cursor: 'pointer', fontSize: '1rem',
              display: 'flex', alignItems: 'center', justifyContent: 'center'
            }}>✕</button>
          </div>

          {/* Messages */}
          <div style={{
            flex: 1, overflowY: 'auto', padding: '16px',
            display: 'flex', flexDirection: 'column', gap: '12px',
            background: '#faf5ff'
          }}>
            {messages.map((msg, i) => {
              if (msg.role === 'consent') {
                return (
                  <div key={i} style={{ display: 'flex', justifyContent: 'flex-start' }}>
                    <div style={{
                      maxWidth: '92%', padding: '12px 14px',
                      borderRadius: '18px 18px 18px 4px',
                      background: '#fffbeb', border: '2px solid #f59e0b',
                      fontSize: '0.875rem', lineHeight: '1.5'
                    }}>
                      <div style={{ color: '#92400e', marginBottom: '10px' }}>{msg.text}</div>
                      <button
                        onClick={() => openConsentPopup(msg.consentUrl)}
                        style={{
                          background: color, color: '#fff', border: 'none',
                          padding: '8px 16px', borderRadius: '8px', cursor: 'pointer',
                          fontWeight: 600, fontSize: '0.85rem', width: '100%'
                        }}
                      >
                        🔐 Authorize Agent to Act on My Behalf
                      </button>
                    </div>
                  </div>
                );
              }
              return (
                <div key={i} style={{ display: 'flex', justifyContent: msg.role === 'user' ? 'flex-end' : 'flex-start' }}>
                  <div style={{
                    maxWidth: '80%', padding: '10px 14px',
                    borderRadius: msg.role === 'user' ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                    background: msg.role === 'user' ? color : '#fff',
                    color: msg.role === 'user' ? '#fff' : '#1a2e2e',
                    fontSize: '0.875rem', lineHeight: '1.5',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.08)',
                    whiteSpace: 'pre-wrap', wordBreak: 'break-word',
                    border: msg.role === 'agent' ? '1px solid #ede9fe' : 'none'
                  }}>
                    {msg.text}
                  </div>
                </div>
              );
            })}
            {loading && (
              <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
                <div style={{
                  padding: '10px 16px', borderRadius: '18px 18px 18px 4px',
                  background: '#fff', border: '1px solid #ede9fe',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.08)'
                }}>
                  <span style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
                    {[0, 1, 2].map(n => (
                      <span key={n} style={{
                        width: '6px', height: '6px', borderRadius: '50%',
                        background: color, opacity: 0.6,
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
            padding: '12px 16px', borderTop: '1px solid #ede9fe',
            background: '#fff', display: 'flex', gap: '8px', alignItems: 'flex-end'
          }}>
            <textarea
              value={input}
              onChange={e => setInput(e.target.value)}
              onKeyDown={onKeyDown}
              placeholder="Ask about your policy, claims, or try: submit a claim…"
              rows={1}
              disabled={loading || !accessToken}
              style={{
                flex: 1, border: '2px solid #ddd6fe', borderRadius: '12px',
                padding: '10px 14px', fontSize: '0.875rem', fontFamily: 'inherit',
                resize: 'none', outline: 'none', lineHeight: '1.5',
                maxHeight: '100px', overflowY: 'auto',
                transition: 'border-color 0.2s',
                background: loading ? '#f8fafc' : '#fff'
              }}
              onFocus={e => e.target.style.borderColor = color}
              onBlur={e => e.target.style.borderColor = '#ddd6fe'}
            />
            <button
              onClick={sendMessage}
              disabled={loading || !input.trim() || !accessToken}
              style={{
                width: '40px', height: '40px', borderRadius: '50%',
                border: 'none', background: color,
                color: '#fff', cursor: loading || !input.trim() ? 'not-allowed' : 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: '1rem', flexShrink: 0,
                opacity: loading || !input.trim() ? 0.5 : 1,
                transition: 'opacity 0.2s'
              }}
            >➤</button>
          </div>
        </div>
      )}

      {/* Floating toggle */}
      <button
        onClick={() => setOpen(o => !o)}
        title="Open OBO Insurance Agent"
        style={{
          position: 'fixed', bottom: '24px', right: '90px',
          width: '56px', height: '56px', borderRadius: '50%',
          background: 'linear-gradient(135deg, #7c3aed 0%, #a78bfa 100%)',
          border: 'none', color: '#fff', fontSize: '1.5rem',
          cursor: 'pointer', zIndex: 1001,
          boxShadow: '0 6px 20px rgba(124,58,237,0.4)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          transition: 'transform 0.2s, box-shadow 0.2s'
        }}
        onMouseEnter={e => { e.currentTarget.style.transform = 'scale(1.1)'; e.currentTarget.style.boxShadow = '0 8px 25px rgba(124,58,237,0.5)'; }}
        onMouseLeave={e => { e.currentTarget.style.transform = 'scale(1)'; e.currentTarget.style.boxShadow = '0 6px 20px rgba(124,58,237,0.4)'; }}
      >
        {open ? '✕' : '🔐'}
      </button>

      <style>{`
        @keyframes bounce {
          0%, 60%, 100% { transform: translateY(0); }
          30% { transform: translateY(-6px); }
        }
      `}</style>
    </>
  );
}
