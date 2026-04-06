import React, { useState, useMemo } from 'react';
import config from '../config';

function decodeJwt(token) {
  try {
    const payload = token.split('.')[1];
    const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
    return JSON.parse(decodeURIComponent(
      json.split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join('')
    ));
  } catch {
    return null;
  }
}

function truncate(token, len = 48) {
  if (!token) return null;
  return token.length > len ? token.substring(0, len) + '…' : token;
}

function ClaimRow({ label, value }) {
  return (
    <div style={{ display: 'flex', gap: '8px', marginBottom: '5px', alignItems: 'flex-start' }}>
      <span style={{ fontSize: '0.72rem', color: '#94a3b8', fontFamily: 'monospace', flexShrink: 0, paddingTop: '1px', minWidth: '80px' }}>
        {label}
      </span>
      <span style={{
        fontSize: '0.75rem', color: '#e2e8f0', fontFamily: 'monospace',
        wordBreak: 'break-all', lineHeight: 1.5
      }}>
        {String(value)}
      </span>
    </div>
  );
}

const KEY_CLAIMS = ['sub', 'username', 'scope', 'iss', 'iat', 'exp', 'act', 'client_id'];

export default function TokenInfoPanel({ accessToken, oboToken, agentToken }) {
  const [copied, setCopied] = useState(null);
  const [decodedOpen, setDecodedOpen] = useState({});

  const decodedAccess = useMemo(() => accessToken ? decodeJwt(accessToken) : null, [accessToken]);
  const decodedAgent = useMemo(() => agentToken ? decodeJwt(agentToken) : null, [agentToken]);
  const decodedObo = useMemo(() => oboToken ? decodeJwt(oboToken) : null, [oboToken]);

  const copy = (text, key) => {
    navigator.clipboard.writeText(text);
    setCopied(key);
    setTimeout(() => setCopied(null), 1500);
  };

  const toggleDecoded = (key) => setDecodedOpen(o => ({ ...o, [key]: !o[key] }));

  const sections = [
    {
      key: 'direct',
      icon: '🔗',
      title: 'Direct API Calls',
      subtitle: 'Policy & Claims data',
      url: config.customerApiBase,
      tokenLabel: 'User Access Token',
      tokenValue: accessToken,
      tokenDesc: null,
      decoded: decodedAccess,
      color: '#0d6e6e',
      bg: '#f0f7f7',
      border: '#c8e0e0',
    },
    {
      key: 'agent',
      icon: '🤖',
      title: 'Normal Agent',
      subtitle: 'MCP tool calls via GW',
      url: `${config.chatApiBase}/chat`,
      tokenLabel: 'Agent Credential Token',
      tokenValue: agentToken,
      tokenDesc: 'IS client credentials · Backend',
      decoded: decodedAgent,
      color: '#0ea5e9',
      bg: '#f0f9ff',
      border: '#bae6fd',
    },
    {
      key: 'obo',
      icon: '🔐',
      title: 'OBO Agent',
      subtitle: 'Delegated submitClaim calls',
      url: `${config.oboChatApiBase}/obo_chat`,
      tokenLabel: 'OBO Delegated Token',
      tokenValue: oboToken,
      tokenDesc: 'IS token exchange · User-consented',
      decoded: decodedObo,
      color: '#7c3aed',
      bg: '#faf5ff',
      border: '#ddd6fe',
    },
  ];

  return (
    <div style={{
      width: '380px',
      flexShrink: 0,
      position: 'sticky',
      top: '20px',
      alignSelf: 'flex-start',
      display: 'flex',
      flexDirection: 'column',
      gap: '10px',
      maxHeight: 'calc(100vh - 60px)',
      overflowY: 'auto',
    }}>
      <div style={{
        fontWeight: 700, fontSize: '0.82rem', color: '#64748b',
        textTransform: 'uppercase', letterSpacing: '0.07em',
        paddingBottom: '6px', borderBottom: '1px solid #e2e8f0'
      }}>
        🔍 Token Inspector
      </div>

      {sections.map((s) => (
        <div key={s.key} style={{
          background: s.bg,
          border: `1px solid ${s.border}`,
          borderRadius: '10px',
          padding: '14px 16px',
        }}>
          {/* Section header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '10px' }}>
            <span style={{ fontSize: '1.2rem' }}>{s.icon}</span>
            <div>
              <div style={{ fontWeight: 700, fontSize: '0.9rem', color: s.color, lineHeight: 1.2 }}>{s.title}</div>
              <div style={{ fontSize: '0.75rem', color: '#94a3b8' }}>{s.subtitle}</div>
            </div>
          </div>

          {/* URL */}
          <div style={{ marginBottom: '10px' }}>
            <div style={{ fontSize: '0.7rem', color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '4px' }}>URL</div>
            <div style={{
              fontSize: '0.75rem', color: '#334155', fontFamily: 'monospace',
              background: 'rgba(0,0,0,0.04)', padding: '6px 8px', borderRadius: '5px',
              wordBreak: 'break-all', lineHeight: 1.6
            }}>
              {s.url}
            </div>
          </div>

          {/* Token */}
          <div>
            <div style={{ fontSize: '0.7rem', color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '4px' }}>Token</div>
            <div style={{ fontSize: '0.8rem', fontWeight: 700, color: s.color, marginBottom: '4px' }}>{s.tokenLabel}</div>
            {s.tokenValue ? (
              <>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '6px', marginBottom: '8px' }}>
                  <div style={{
                    flex: 1, fontSize: '0.72rem', color: '#475569', fontFamily: 'monospace',
                    background: 'rgba(0,0,0,0.04)', padding: '6px 8px', borderRadius: '5px',
                    wordBreak: 'break-all', lineHeight: 1.6
                  }}>
                    {truncate(s.tokenValue) || '—'}
                  </div>
                  <button
                    onClick={() => copy(s.tokenValue, s.key)}
                    style={{
                      flexShrink: 0, background: s.color, color: '#fff', border: 'none',
                      borderRadius: '5px', padding: '5px 10px', cursor: 'pointer',
                      fontSize: '0.72rem', fontWeight: 600, marginTop: '2px'
                    }}
                  >
                    {copied === s.key ? '✓' : 'Copy'}
                  </button>
                </div>

                {/* Decoded JWT toggle */}
                <button
                  onClick={() => toggleDecoded(s.key)}
                  style={{
                    width: '100%', background: 'transparent', border: `1px solid ${s.border}`,
                    borderRadius: '6px', padding: '5px 10px', cursor: 'pointer',
                    fontSize: '0.75rem', color: s.color, fontWeight: 600,
                    display: 'flex', justifyContent: 'space-between', alignItems: 'center'
                  }}
                >
                  <span>Decoded Claims</span>
                  <span>{decodedOpen[s.key] ? '▲' : '▼'}</span>
                </button>

                {decodedOpen[s.key] && s.decoded && (
                  <div style={{
                    marginTop: '8px', background: '#1e293b', borderRadius: '8px',
                    padding: '12px 14px',
                  }}>
                    {KEY_CLAIMS.filter(k => s.decoded[k] !== undefined).map(k => (
                      <ClaimRow key={k} label={k} value={
                        k === 'iat' || k === 'exp'
                          ? `${s.decoded[k]} (${new Date(s.decoded[k] * 1000).toLocaleTimeString()})`
                          : typeof s.decoded[k] === 'object'
                            ? JSON.stringify(s.decoded[k])
                            : s.decoded[k]
                      } />
                    ))}
                    {Object.keys(s.decoded)
                      .filter(k => !KEY_CLAIMS.includes(k))
                      .map(k => (
                        <ClaimRow key={k} label={k} value={
                          typeof s.decoded[k] === 'object' ? JSON.stringify(s.decoded[k]) : s.decoded[k]
                        } />
                      ))
                    }
                  </div>
                )}
              </>
            ) : (
              <div style={{
                fontSize: '0.78rem', color: '#94a3b8', fontStyle: 'italic',
                background: 'rgba(0,0,0,0.03)', padding: '6px 8px', borderRadius: '5px'
              }}>
                {s.tokenDesc}
              </div>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
