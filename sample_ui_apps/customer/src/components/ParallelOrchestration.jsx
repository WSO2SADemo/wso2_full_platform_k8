import { useState } from 'react';
import { CFG } from '../config';
import { authHeaders } from '../auth';
import { apiFetch } from '../utils';

const DEFAULT_FUND_URLS = [
  'http://customer-backends.ballerina.svc.cluster.local:9091',
  'http://customer-backends.ballerina.svc.cluster.local:9092',
  'http://customer-backends.ballerina.svc.cluster.local:9093',
  'http://customer-backends.ballerina.svc.cluster.local:9094',
  'http://customer-backends.ballerina.svc.cluster.local:9095',
  'http://customer-backends.ballerina.svc.cluster.local:9096',
  'http://customer-backends.ballerina.svc.cluster.local:9097',
  'http://customer-backends.ballerina.svc.cluster.local:9098',
  'http://customer-backends.ballerina.svc.cluster.local:9099',
  'http://customer-backends.ballerina.svc.cluster.local:9100',
];

export function ParallelOrchestration() {
  const [personId, setPersonId] = useState('199001011234');
  const [selected, setSelected] = useState(() => new Set(DEFAULT_FUND_URLS));
  const [extraUrls, setExtraUrls] = useState([]);
  const [newUrl, setNewUrl] = useState('');
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [showRaw, setShowRaw] = useState(false);

  function toggleUrl(url) {
    setSelected(prev => {
      const next = new Set(prev);
      next.has(url) ? next.delete(url) : next.add(url);
      return next;
    });
  }

  function addExtraUrl() {
    const url = newUrl.trim();
    if (!url) return;
    setExtraUrls(prev => [...prev, url]);
    setSelected(prev => new Set([...prev, url]));
    setNewUrl('');
  }

  function removeExtraUrl(url) {
    setExtraUrls(prev => prev.filter(u => u !== url));
    setSelected(prev => { const next = new Set(prev); next.delete(url); return next; });
  }

  async function lookup() {
    setLoading(true);
    setResult(null);
    setError(null);
    const activeFundUrls = [...DEFAULT_FUND_URLS, ...extraUrls].filter(u => selected.has(u));
    try {
      const r = await apiFetch(`${CFG.psoBase}/unemployment/lookup`, {
        method: 'POST',
        headers: authHeaders({
          'Content-Type': 'application/json',
          'fundUrls': activeFundUrls.join(','),
        }),
        body: JSON.stringify({ personId }),
      });
      if (r.ok) {
        setResult(typeof r.body === 'string' ? JSON.parse(r.body) : r.body);
      } else {
        setError(`HTTP ${r.status}: ${JSON.stringify(r.body)}`);
      }
    } catch (e) {
      setError(e.message);
    }
    setLoading(false);
  }

  const s = result?.summary;
  const total = result?.totalFundsQueried ?? 0;

  return (
    <div>
      <div className="card">
        <h2>Scatter and Gather</h2>
        <p className="desc">
          Scatter-gather lookup across 10 Swedish unemployment fund backends in parallel (3 s SLA).
          Returns aggregated valid member data, timeouts, service errors, and blank responses.
        </p>

        <div className="form-grid">
          <div className="field span2">
            <label>Person ID (personnummer)</label>
            <input
              value={personId}
              onChange={(e) => setPersonId(e.target.value)}
              placeholder="199001011234"
            />
          </div>
        </div>

        <div style={{ marginTop: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
            <label style={{ fontWeight: 600 }}>
              Fund Backend URLs <span className="muted" style={{ fontWeight: 400, fontSize: 12 }}>({selected.size} selected — sent as <code>fundUrls</code> header)</span>
            </label>
            <div style={{ display: 'flex', gap: 6 }}>
              <button className="btn btn-outline btn-sm" onClick={() => setSelected(new Set(DEFAULT_FUND_URLS))}>Select Defaults</button>
              <button className="btn btn-outline btn-sm" onClick={() => setSelected(new Set([...DEFAULT_FUND_URLS, ...extraUrls]))}>Select All</button>
              <button className="btn btn-outline btn-sm" onClick={() => setSelected(new Set())}>Clear All</button>
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px 12px', marginBottom: 10 }}>
            {DEFAULT_FUND_URLS.map((url, i) => (
              <label key={url} style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', padding: '4px 6px', borderRadius: 4, background: selected.has(url) ? 'var(--gray)' : 'transparent' }}>
                <input type="checkbox" checked={selected.has(url)} onChange={() => toggleUrl(url)} />
                <span style={{ fontSize: 12 }}><span className="muted">#{i + 1}</span> {url}</span>
              </label>
            ))}
          </div>

          {extraUrls.length > 0 && (
            <div style={{ marginBottom: 10 }}>
              <div className="muted" style={{ fontSize: 12, marginBottom: 4 }}>Additional URLs</div>
              {extraUrls.map((url) => (
                <label key={url} style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', padding: '4px 6px', borderRadius: 4, background: selected.has(url) ? 'var(--gray)' : 'transparent', marginBottom: 2 }}>
                  <input type="checkbox" checked={selected.has(url)} onChange={() => toggleUrl(url)} />
                  <span style={{ fontSize: 12, flex: 1 }}>{url}</span>
                  <button className="btn btn-outline btn-sm" style={{ padding: '1px 8px', color: 'var(--red, #e53)' }} onClick={() => removeExtraUrl(url)}>✕</button>
                </label>
              ))}
            </div>
          )}

          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input
              value={newUrl}
              onChange={(e) => setNewUrl(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && addExtraUrl()}
              placeholder="http://my-fund-backend:9101"
              style={{ flex: 1, fontSize: 12 }}
            />
            <button className="btn btn-outline btn-sm" onClick={addExtraUrl}>+ Add URL</button>
          </div>
        </div>

        <div className="actions">
          <button className="btn btn-orange" onClick={lookup} disabled={loading}>
            {loading ? <span className="spinner" /> : null} Lookup Across All Funds
          </button>
        </div>

        {error && (
          <p className="text-error" style={{ marginTop: 14 }}>❌ {error}</p>
        )}
      </div>

      {result && (
        <>
          {/* Summary bar */}
          <div className="card">
            <h3 style={{ marginBottom: 4 }}>Results for <code style={{ background: 'var(--gray)', padding: '2px 8px', borderRadius: 4 }}>{result.personId}</code></h3>
            <p className="muted" style={{ marginBottom: 16 }}>{total} fund{total !== 1 ? 's' : ''} queried</p>
            <div className="pso-summary">
              <div className="pso-stat pso-valid">
                <span className="pso-count">{s?.validCount ?? 0}</span>
                <span>Active Members</span>
              </div>
              <div className="pso-stat pso-error">
                <span className="pso-count">{s?.errorCount ?? 0}</span>
                <span>Errors / Timeouts</span>
              </div>
              <div className="pso-stat pso-blank">
                <span className="pso-count">{s?.blankCount ?? 0}</span>
                <span>Not Registered</span>
              </div>
            </div>
          </div>

          {/* Valid responses */}
          {result.validResponses?.length > 0 && (
            <div className="card">
              <div className="pso-section-header pso-section-valid">
                <span className="pso-section-icon">✓</span>
                <span>Valid Member Data ({result.validResponses.length})</span>
              </div>
              <table className="pso-table">
                <thead>
                  <tr>
                    <th>Fund</th>
                    <th>Status</th>
                    <th>Member Type</th>
                    <th>Registered Since</th>
                    <th>URL</th>
                  </tr>
                </thead>
                <tbody>
                  {result.validResponses.map((m, i) => (
                    <tr key={i}>
                      <td><strong>{m.fund}</strong></td>
                      <td><span className={`status-badge status-${m.status?.toLowerCase()}`}>{m.status}</span></td>
                      <td>{m.memberType}</td>
                      <td>{m.registeredSince}</td>
                      <td className="muted" style={{ fontSize: 11, fontFamily: 'monospace' }}>{m.url}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Errors */}
          {result.errors?.length > 0 && (
            <div className="card">
              <div className="pso-section-header pso-section-error">
                <span className="pso-section-icon">✕</span>
                <span>Errors &amp; Timeouts ({result.errors.length})</span>
              </div>
              <table className="pso-table">
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>Detail</th>
                    <th>URL</th>
                  </tr>
                </thead>
                <tbody>
                  {result.errors.map((e, i) => (
                    <tr key={i}>
                      <td>
                        <span className={`status-badge ${e.errorType === 'TIMEOUT' ? 'status-inactive' : 'status-error'}`}>
                          {e.errorType}
                        </span>
                      </td>
                      <td className="muted pso-msg">{stripEmbeddedJson(e.message)}</td>
                      <td className="muted" style={{ fontSize: 11, fontFamily: 'monospace' }}>{e.url}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Blank responses */}
          {result.blankResponses?.length > 0 && (
            <div className="card">
              <div className="pso-section-header pso-section-blank">
                <span className="pso-section-icon">—</span>
                <span>Not Registered ({result.blankResponses.length})</span>
              </div>
              <div className="pso-chip-list">
                {result.blankResponses.map((b, i) => (
                  <span key={i} className="pso-chip" title={b.url}>{b.fund}</span>
                ))}
              </div>
              <table className="pso-table" style={{ marginTop: 10 }}>
                <thead>
                  <tr><th>Fund</th><th>URL</th></tr>
                </thead>
                <tbody>
                  {result.blankResponses.map((b, i) => (
                    <tr key={i}>
                      <td><strong>{b.fund}</strong></td>
                      <td className="muted" style={{ fontSize: 11, fontFamily: 'monospace' }}>{b.url}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Raw payload */}
          <div className="card">
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <h3 style={{ margin: 0 }}>Raw Response</h3>
              <button className="btn btn-outline btn-sm" onClick={() => setShowRaw(v => !v)}>
                {showRaw ? 'Hide' : 'Show'} Raw JSON
              </button>
            </div>
            {showRaw && (
              <textarea
                className="response-body"
                readOnly
                value={JSON.stringify(result, null, 2)}
                rows={16}
                style={{ width: '100%', resize: 'vertical', boxSizing: 'border-box', marginTop: 12 }}
                spellCheck={false}
              />
            )}
          </div>
        </>
      )}
    </div>
  );
}

// Strip embedded JSON strings from error messages for cleaner display
// e.g. "HTTP 500 – {"error":"Service unavailable",...}" → "HTTP 500 – Service temporarily unavailable"
function stripEmbeddedJson(msg) {
  try {
    const jsonStart = msg.indexOf('{');
    if (jsonStart === -1) return msg;
    const prefix = msg.slice(0, jsonStart).replace(/[–\-\s]+$/, '').trim();
    const parsed = JSON.parse(msg.slice(jsonStart));
    const detail = parsed.error || parsed.message || parsed.detail || '';
    return detail ? `${prefix}: ${detail}` : prefix || msg;
  } catch {
    return msg;
  }
}
