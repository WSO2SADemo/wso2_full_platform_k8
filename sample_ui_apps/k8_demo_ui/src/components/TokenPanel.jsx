import React, { useState } from 'react';

function highlightJson(obj) {
  const json = JSON.stringify(obj, null, 2);
  return json
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g,
      (match) => {
        let cls = 'json-number';
        if (/^"/.test(match)) cls = /:$/.test(match) ? 'json-key' : 'json-string';
        else if (/true|false/.test(match)) cls = 'json-bool';
        return `<span class="${cls}">${match}</span>`;
      }
    );
}

function decodeJwt(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const json = decodeURIComponent(
      atob(payload).split('').map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)).join('')
    );
    return JSON.parse(json);
  } catch {
    return null;
  }
}

export function TokenPanel({ token, label = 'Access Token' }) {
  const [showRaw, setShowRaw] = useState(false);
  if (!token) return null;

  const decoded = decodeJwt(token);
  const parts = token.split('.');

  return (
    <div className="card" style={{ marginTop: '1rem' }}>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
        <p className="section-title" style={{ margin: 0 }}>🔑 {label}</p>
        <button
          className="btn-secondary"
          style={{ padding: '4px 14px', fontSize: '0.8rem' }}
          onClick={() => setShowRaw(r => !r)}
        >
          {showRaw ? 'Show Decoded' : 'Show Raw JWT'}
        </button>
      </div>

      {/* Raw JWT view */}
      {showRaw && (
        <div className="code-block" style={{ wordBreak: 'break-all', fontSize: '0.72rem' }}>
          <span style={{ color: '#f472b6' }}>{parts[0]}</span>
          <span style={{ color: '#94a3b8' }}>.</span>
          <span style={{ color: '#86efac' }}>{parts[1]}</span>
          <span style={{ color: '#94a3b8' }}>.</span>
          <span style={{ color: '#fbbf24' }}>{parts[2]}</span>
        </div>
      )}

      {/* Decoded view — always rendered when not in raw mode */}
      {!showRaw && (
        <>
          {/* Summary badges */}
          {decoded?.exp && (
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '0.75rem' }}>
              {decoded.sub   && <span className="badge info">sub: {decoded.sub}</span>}
              {decoded.iss   && <span className="badge info">iss: {decoded.iss.replace('https://', '')}</span>}
              {decoded.exp   && <span className="badge info">exp: {new Date(decoded.exp * 1000).toLocaleTimeString()}</span>}
              {decoded.scope && <span className="badge success">scope: {decoded.scope}</span>}
            </div>
          )}

          {/* Full decoded payload */}
          <p className="section-title">Decoded Payload</p>
          {decoded ? (
            <div
              className="code-block"
              dangerouslySetInnerHTML={{ __html: highlightJson(decoded) }}
            />
          ) : (
            <p style={{ color: 'var(--color-text-sub)', fontSize: '0.85rem' }}>Unable to decode token.</p>
          )}
        </>
      )}
    </div>
  );
}

export function ResponsePanel({ response, status, label = 'API Response' }) {
  if (!response && !status) return null;

  const isOk = status >= 200 && status < 300;

  return (
    <div className="card" style={{ marginTop: '1rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
        <p className="section-title" style={{ margin: 0 }}>📡 {label}</p>
        {status && (
          <span className={`badge ${isOk ? 'success' : 'error'}`}>
            {isOk ? '✓' : '✗'} HTTP {status}
          </span>
        )}
      </div>
      {response !== null && (
        <div
          className="code-block"
          dangerouslySetInnerHTML={{
            __html: typeof response === 'string'
              ? response
              : highlightJson(response)
          }}
        />
      )}
    </div>
  );
}
