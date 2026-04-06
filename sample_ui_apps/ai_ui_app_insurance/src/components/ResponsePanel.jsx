import React, { useState } from 'react';

function statusColor(status) {
  if (status === 0) return '#64748b';
  if (status === 446) return '#f97316';
  if (status === 429) return '#f59e0b';
  if (status >= 200 && status < 300) return '#10b981';
  return '#ef4444';
}

function statusLabel(status) {
  if (status === 0) return 'CONNECTION ERROR';
  if (status === 446) return '446 GUARDRAIL';
  if (status === 429) return '429 RATE LIMITED';
  if (status >= 200 && status < 300) return `${status} OK`;
  return `${status} ERROR`;
}

function timeColor(ms) {
  if (ms < 300) return '#10b981';
  if (ms < 1000) return '#f59e0b';
  return '#ef4444';
}

export default function ResponsePanel({ result, loading, cacheComparison }) {
  const [rawOpen, setRawOpen] = useState(false);
  if (loading) {
    return (
      <div style={{ padding: '24px', textAlign: 'center' }}>
        <div style={{ display: 'inline-flex', gap: '6px', alignItems: 'center' }}>
          {[0,1,2].map(n => (
            <span key={n} style={{
              width: 8, height: 8, borderRadius: '50%', background: '#0d6e6e',
              animation: `bounce 1.1s ${n*0.2}s infinite ease-in-out`,
            }}/>
          ))}
          <span style={{ marginLeft: 8, color: '#64748b', fontSize: '0.85rem' }}>Sending to AI Gateway…</span>
        </div>
        <style>{`@keyframes bounce{0%,80%,100%{transform:translateY(0)}40%{transform:translateY(-8px)}}`}</style>
      </div>
    );
  }
  if (!result) return null;

  const aiText = result.data?.choices?.[0]?.message?.content;
  const isGuardrail = result.status === 446;
  const isRateLimit = result.status === 429;
  const guardInfo = isGuardrail ? result.data?.message : null;

  return (
    <div style={{ marginTop: 24 }}>
      {/* Status row */}
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', marginBottom: 14 }}>
        <span style={{
          background: statusColor(result.status), color: '#fff',
          padding: '3px 12px', borderRadius: 20, fontSize: '0.78rem', fontWeight: 700,
        }}>{statusLabel(result.status)}</span>
        <span style={{
          background: timeColor(result.elapsed) + '22', color: timeColor(result.elapsed),
          border: `1px solid ${timeColor(result.elapsed)}55`,
          padding: '3px 12px', borderRadius: 20, fontSize: '0.78rem', fontWeight: 600,
        }}>⏱ {result.elapsed}ms</span>
        {result.elapsed < 300 && result.ok && (
          <span style={{
            background: '#8b5cf622', color: '#8b5cf6', border: '1px solid #8b5cf655',
            padding: '3px 12px', borderRadius: 20, fontSize: '0.78rem', fontWeight: 600,
          }}>⚡ CACHED</span>
        )}
        {isGuardrail && (
          <span style={{
            background: '#f9731622', color: '#f97316', border: '1px solid #f9731655',
            padding: '3px 12px', borderRadius: 20, fontSize: '0.78rem', fontWeight: 600,
          }}>🛡 GUARDRAIL INTERVENED</span>
        )}
        {isRateLimit && (
          <span style={{
            background: '#f59e0b22', color: '#f59e0b', border: '1px solid #f59e0b55',
            padding: '3px 12px', borderRadius: 20, fontSize: '0.78rem', fontWeight: 600,
          }}>⚡ RATE LIMITED</span>
        )}
      </div>

      {/* Cache comparison bar */}
      {cacheComparison && (
        <div style={{ background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: 10, padding: '12px 16px', marginBottom: 14 }}>
          <div style={{ fontSize: '0.78rem', color: '#166534', fontWeight: 700, marginBottom: 8 }}>⚡ Semantic Cache Comparison</div>
          {['fresh', 'cached'].map(k => cacheComparison[k] && (
            <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
              <span style={{ fontSize: '0.72rem', color: '#64748b', width: 60 }}>{k === 'fresh' ? 'FRESH' : 'CACHED'}</span>
              <div style={{
                height: 14, borderRadius: 7,
                width: `${Math.min((cacheComparison[k] / (cacheComparison.fresh || 1)) * 200, 200)}px`,
                minWidth: 20,
                background: k === 'fresh' ? '#f59e0b' : '#10b981',
              }}/>
              <span style={{ fontSize: '0.75rem', fontWeight: 700, color: k === 'fresh' ? '#92400e' : '#065f46' }}>
                {cacheComparison[k]}ms
              </span>
              {k === 'cached' && cacheComparison.fresh && (
                <span style={{ fontSize: '0.72rem', color: '#8b5cf6', fontWeight: 600 }}>
                  {Math.round((1 - cacheComparison.cached / cacheComparison.fresh) * 100)}% faster
                </span>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Guardrail detail */}
      {isGuardrail && guardInfo && (
        <div style={{ background: '#fff7ed', border: '2px solid #f97316', borderRadius: 10, padding: '14px 16px', marginBottom: 14 }}>
          <div style={{ fontWeight: 700, color: '#9a3412', marginBottom: 8, fontSize: '0.85rem' }}>🛡 Guardrail Details</div>
          {[
            ['Type', result.data?.type],
            ['Intervening Guardrail', guardInfo.interveningGuardrail],
            ['Action', guardInfo.action],
            ['Reason', guardInfo.actionReason],
            ['Direction', guardInfo.direction],
          ].map(([k, v]) => v ? (
            <div key={k} style={{ display: 'flex', gap: 8, marginBottom: 4 }}>
              <span style={{ fontSize: '0.72rem', color: '#9a3412', minWidth: 140, fontWeight: 600 }}>{k}</span>
              <span style={{ fontSize: '0.75rem', color: '#7c2d12', wordBreak: 'break-all' }}>{String(v)}</span>
            </div>
          ) : null)}
        </div>
      )}

      {/* Rate limit detail */}
      {isRateLimit && (
        <div style={{ background: '#fffbeb', border: '2px solid #f59e0b', borderRadius: 10, padding: '14px 16px', marginBottom: 14 }}>
          <div style={{ fontWeight: 700, color: '#92400e', fontSize: '0.85rem' }}>⚡ Rate Limit Exceeded</div>
          <div style={{ fontSize: '0.78rem', color: '#78350f', marginTop: 6 }}>
            The API subscription limit has been reached. The gateway is protecting the AI backend from overuse.
          </div>
        </div>
      )}

      {/* AI response text */}
      {aiText && (
        <div style={{ background: '#f0f7f7', border: '1px solid #c8e0e0', borderRadius: 10, padding: '14px 16px', marginBottom: 14 }}>
          <div style={{ fontSize: '0.7rem', color: '#0d6e6e', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 8 }}>
            AI Response
          </div>
          <div style={{ fontSize: '0.88rem', color: '#1e293b', lineHeight: 1.7, whiteSpace: 'pre-wrap' }}>{aiText}</div>
        </div>
      )}

      {/* Raw JSON toggle */}
      <button
        onClick={() => setRawOpen(o => !o)}
        style={{
          background: 'transparent', border: '1px solid #e2e8f0', borderRadius: 6,
          padding: '5px 12px', cursor: 'pointer', fontSize: '0.75rem', color: '#64748b',
          display: 'flex', alignItems: 'center', gap: 6,
        }}
      >
        <span>{rawOpen ? '▲' : '▼'}</span> Raw Response JSON
      </button>
      {rawOpen && (
        <pre style={{
          marginTop: 8, background: '#1e293b', color: '#e2e8f0',
          borderRadius: 8, padding: '12px 14px', fontSize: '0.72rem',
          lineHeight: 1.6, overflowX: 'auto', whiteSpace: 'pre-wrap', wordBreak: 'break-all',
        }}>
          {JSON.stringify(result.data, null, 2)}
        </pre>
      )}
    </div>
  );
}
