import { useState } from 'react';
import { CFG } from '../config';
import { authHeaders } from '../auth';
import { apiFetch } from '../utils';

export function ParallelOrchestration() {
  const [personId, setPersonId] = useState('199001011234');
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function lookup() {
    setLoading(true);
    setResult(null);
    setError(null);
    try {
      const r = await apiFetch(`${CFG.psoBase}/unemployment/lookup`, {
        method: 'POST',
        headers: authHeaders({ 'Content-Type': 'application/json' }),
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
        <h2>Parallel Service Orchestration</h2>
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
            <p className="muted" style={{ marginBottom: 16 }}>{total} funds queried</p>
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
                  </tr>
                </thead>
                <tbody>
                  {result.validResponses.map((m) => (
                    <tr key={m.fund}>
                      <td><strong>{m.fund}</strong></td>
                      <td><span className={`status-badge status-${m.status?.toLowerCase()}`}>{m.status}</span></td>
                      <td>{m.memberType}</td>
                      <td>{m.registeredSince}</td>
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
                    <th>Fund</th>
                    <th>Type</th>
                    <th>Detail</th>
                  </tr>
                </thead>
                <tbody>
                  {result.errors.map((e) => (
                    <tr key={e.fund}>
                      <td><strong>{e.fund}</strong></td>
                      <td>
                        <span className={`status-badge ${e.errorType === 'TIMEOUT' ? 'status-inactive' : 'status-error'}`}>
                          {e.errorType}
                        </span>
                      </td>
                      <td className="muted pso-msg">{stripEmbeddedJson(e.message)}</td>
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
                {result.blankResponses.map((b) => (
                  <span key={b.fund} className="pso-chip">{b.fund}</span>
                ))}
              </div>
            </div>
          )}
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
