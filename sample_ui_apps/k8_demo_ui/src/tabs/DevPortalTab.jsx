import React, { useCallback, useEffect, useState } from 'react';
import config from '../config';

const COLOR    = '#FF7300';
const API_BASE = config.apimBase;  // /api/devportal — Express backend proxies to APIM with admin auth

// ── fetch helper — no token needed; backend handles auth ──────────────────────
async function apiFetch(path) {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { Accept: 'application/json' },
  });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json();
}

// ── sub-components ─────────────────────────────────────────────────────────────
function Tag({ label }) {
  return (
    <span style={{
      display: 'inline-block', padding: '2px 8px', borderRadius: 12,
      background: '#f1f5f9', color: '#475569', fontSize: '0.72rem',
      fontWeight: 600, marginRight: 4, marginBottom: 2,
    }}>{label}</span>
  );
}

function StatusBadge({ text, ok }) {
  return <span className={`badge ${ok ? 'success' : 'error'}`}>{text}</span>;
}

function SectionHeader({ title, count, onRefresh, loading }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
      <p className="section-title" style={{ margin: 0 }}>
        {title} {count != null && <span style={{ fontWeight: 400, opacity: 0.7 }}>({count})</span>}
      </p>
      {onRefresh && (
        <button className="btn-secondary" style={{ padding: '4px 12px', fontSize: '0.78rem' }}
          onClick={onRefresh} disabled={loading}>
          {loading
            ? <span className="spinner" style={{ borderTopColor: '#0f172a', width: 14, height: 14 }} />
            : '↺ Refresh'}
        </button>
      )}
    </div>
  );
}

// ── API detail panel ───────────────────────────────────────────────────────────
function ApiDetailPanel({ api, onClose }) {
  const [swagger,  setSwagger]  = useState(null);
  const [swErr,    setSwErr]    = useState(null);
  const [loadSw,   setLoadSw]   = useState(false);
  const [policies, setPolicies] = useState(null);
  const [polErr,   setPolErr]   = useState(null);

  useEffect(() => {
    if (!api) return;

    setSwagger(null); setSwErr(null); setLoadSw(true);
    apiFetch(`/apis/${api.id}/swagger`)
      .then(d => setSwagger(typeof d === 'string' ? d : JSON.stringify(d, null, 2)))
      .catch(e => setSwErr(e.message))
      .finally(() => setLoadSw(false));

    setPolicies(null); setPolErr(null);
    apiFetch(`/apis/${api.id}/subscription-policies`)
      .then(d => setPolicies(d.list || []))
      .catch(e => setPolErr(e.message));
  }, [api]);

  if (!api) return null;

  const gwUrls = api.endpointURLs || [];

  return (
    <div className="dp-detail-panel">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1rem' }}>
        <div>
          <h3 style={{ margin: '0 0 4px', fontSize: '1.1rem' }}>{api.name}</h3>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
            <span className="badge info">v{api.version}</span>
            <span className="badge info">{api.type || 'HTTP'}</span>
            {api.lifeCycleStatus && (
              <StatusBadge text={api.lifeCycleStatus} ok={api.lifeCycleStatus === 'PUBLISHED'} />
            )}
            {(api.tags || []).map(t => <Tag key={t} label={t} />)}
          </div>
        </div>
        <button onClick={onClose}
          style={{ background: 'none', border: 'none', fontSize: '1.4rem', cursor: 'pointer', color: '#64748b', lineHeight: 1 }}>
          ×
        </button>
      </div>

      {api.description && (
        <p style={{ fontSize: '0.88rem', color: '#475569', margin: '0 0 1rem', lineHeight: 1.6 }}>
          {api.description}
        </p>
      )}

      {/* Gateway URLs */}
      {gwUrls.length > 0 && (
        <div style={{ marginBottom: '1rem' }}>
          <p className="section-title">Gateway Endpoints</p>
          {gwUrls.map((e, i) => (
            <div key={i} style={{ marginBottom: '0.5rem' }}>
              <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#64748b', textTransform: 'uppercase' }}>
                {e.environmentName} · {e.environmentType}
              </span>
              <div className="code-block" style={{ fontSize: '0.78rem', padding: '0.5rem 0.75rem', marginTop: '0.25rem' }}>
                {e.URLs?.http  && <div><span style={{ color: '#94a3b8' }}>HTTP  </span><span style={{ color: '#86efac' }}>{e.URLs.http}</span></div>}
                {e.URLs?.https && <div><span style={{ color: '#94a3b8' }}>HTTPS </span><span style={{ color: '#86efac' }}>{e.URLs.https}</span></div>}
                {e.URLs?.ws    && <div><span style={{ color: '#94a3b8' }}>WS    </span><span style={{ color: '#86efac' }}>{e.URLs.ws}</span></div>}
                {e.URLs?.wss   && <div><span style={{ color: '#94a3b8' }}>WSS   </span><span style={{ color: '#86efac' }}>{e.URLs.wss}</span></div>}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Subscription tiers */}
      <div style={{ marginBottom: '1rem' }}>
        <p className="section-title">Subscription Policies</p>
        {polErr   && <span className="badge error">{polErr}</span>}
        {!polErr && !policies && <span style={{ fontSize: '0.82rem', color: '#94a3b8' }}>Loading…</span>}
        {policies && policies.length === 0 && <span style={{ fontSize: '0.82rem', color: '#94a3b8' }}>None</span>}
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {(policies || []).map(p => (
            <span key={p.name} style={{
              padding: '4px 12px', borderRadius: 20, fontSize: '0.78rem',
              fontWeight: 600, background: '#fef3c7', color: '#92400e',
            }}>
              {p.displayName || p.name}
              {p.requestCount ? ` · ${p.requestCount}/${p.unitTime}${p.timeUnit}` : ''}
            </span>
          ))}
        </div>
      </div>

      {/* Swagger snippet */}
      <div>
        <p className="section-title">OpenAPI Spec (excerpt)</p>
        {loadSw && <span style={{ fontSize: '0.82rem', color: '#94a3b8' }}>Loading…</span>}
        {swErr  && <span className="badge error">{swErr}</span>}
        {swagger && (
          <div className="code-block" style={{ fontSize: '0.72rem', padding: '0.75rem 1rem', maxHeight: 200 }}>
            {swagger.slice(0, 1200)}{swagger.length > 1200 ? '\n…' : ''}
          </div>
        )}
      </div>
    </div>
  );
}

// ── Applications panel ─────────────────────────────────────────────────────────
function AppsPanel() {
  const [apps,    setApps]    = useState(null);
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState(null);

  const load = useCallback(() => {
    setLoading(true); setError(null);
    apiFetch('/applications?limit=25')
      .then(d => setApps(d.list || []))
      .catch(e => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="card" style={{ marginBottom: '1rem' }}>
      <SectionHeader title="Applications" count={apps?.length} onRefresh={load} loading={loading} />
      {error && <span className="badge error">✗ {error}</span>}
      {!error && !apps && loading && <span style={{ fontSize: '0.82rem', color: '#94a3b8' }}>Loading…</span>}
      {apps && apps.length === 0 && <span style={{ fontSize: '0.82rem', color: '#94a3b8' }}>No applications found.</span>}
      <div className="dp-app-grid">
        {(apps || []).map(app => (
          <div key={app.applicationId} className="dp-app-card">
            <div style={{ fontWeight: 700, fontSize: '0.9rem', marginBottom: 4 }}>{app.name}</div>
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 6 }}>
              <StatusBadge text={app.status} ok={app.status === 'APPROVED'} />
              <span className="badge info">{app.throttlingPolicy || 'Unlimited'}</span>
            </div>
            {app.description && (
              <p style={{ fontSize: '0.78rem', color: '#64748b', margin: 0 }}>{app.description}</p>
            )}
            <div style={{ marginTop: 6, fontSize: '0.72rem', color: '#94a3b8' }}>
              ID: {app.applicationId.slice(0, 16)}…
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Main tab ───────────────────────────────────────────────────────────────────
export default function DevPortalTab() {
  const [apis,        setApis]        = useState(null);
  const [apisLoading, setApisLoading] = useState(false);
  const [apisErr,     setApisErr]     = useState(null);
  const [search,      setSearch]      = useState('');
  const [activeTag,   setActiveTag]   = useState('');
  const [allTags,     setAllTags]     = useState([]);
  const [selectedApi, setSelectedApi] = useState(null);
  const [section, setSection] = useState('catalog');

  // Load tags once on mount
  useEffect(() => {
    apiFetch('/tags?limit=50')
      .then(d => setAllTags((d.list || []).map(t => t.value)))
      .catch(() => {});
  }, []);

  // Load APIs whenever search/tag changes
  const loadApis = useCallback(() => {
    setApisLoading(true); setApisErr(null);
    const qs = new URLSearchParams({ limit: '50' });
    if (search)    qs.set('query', search);
    if (activeTag) qs.set('tag',   activeTag);
    apiFetch(`/apis?${qs}`)
      .then(d => setApis(d.list || []))
      .catch(e => setApisErr(e.message))
      .finally(() => setApisLoading(false));
  }, [search, activeTag]);

  useEffect(() => { loadApis(); }, [loadApis]);

  const apimDisplayBase = import.meta.env.VITE_APIM_BASE || 'https://am.wso2.com';

  const flowSteps = [
    { label: '1. Backend token (admin)',  done: true },
    { label: '2. DCR → OAuth2 token',     done: true },
    { label: '3. DevPortal API v3',        done: !!apis },
    { label: '4. Browse / Subscribe',      done: !!selectedApi },
  ];

  return (
    <div>
      {/* Header */}
      <div className="gateway-header" style={{ background: `linear-gradient(135deg, ${COLOR}, #c05500)` }}>
        <div style={{ fontSize: '2rem' }}>🗂️</div>
        <div>
          <h2>Custom Developer Portal — WSO2 APIM</h2>
          <p>DevPortal REST API v3 · {apimDisplayBase}/api/am/devportal/v3 · server-side admin auth</p>
        </div>
      </div>

      {/* Flow diagram */}
      <div className="flow-steps">
        {flowSteps.map((s, i) => (
          <React.Fragment key={i}>
            {i > 0 && <span className="flow-step arrow">→</span>}
            <span className={`flow-step ${s.done ? 'done' : ''}`}>{s.done ? '✓ ' : ''}{s.label}</span>
          </React.Fragment>
        ))}
      </div>

      {/* Auth note */}
      <div className="code-block" style={{ fontSize: '0.78rem', padding: '0.6rem 1rem', marginBottom: '1rem' }}>
        <span style={{ color: '#94a3b8' }}># Backend auth flow (no user login required){'\n'}</span>
        <span style={{ color: '#fbbf24' }}>POST </span>
        <span style={{ color: '#86efac' }}>{apimDisplayBase}/client-registration/v0.17/register</span>
        <span style={{ color: '#94a3b8' }}>  ← DCR with Basic admin:admin{'\n'}</span>
        <span style={{ color: '#fbbf24' }}>POST </span>
        <span style={{ color: '#86efac' }}>{apimDisplayBase}/oauth2/token</span>
        <span style={{ color: '#94a3b8' }}>  ← password grant → Bearer token (cached){'\n'}</span>
        <span style={{ color: '#fbbf24' }}>GET  </span>
        <span style={{ color: '#86efac' }}>{apimDisplayBase}/api/am/devportal/v3/apis</span>
        <span style={{ color: '#94a3b8' }}>  ← proxied by Express server</span>
      </div>

      {/* Section nav */}
      <div style={{ display: 'flex', gap: 8, marginBottom: '1rem' }}>
        {[
          { key: 'catalog', label: '🔍 API Catalog' },
          { key: 'apps',    label: '📦 Applications' },
        ].map(s => (
          <button key={s.key}
            onClick={() => setSection(s.key)}
            className="btn-secondary"
            style={{
              padding: '6px 16px', fontSize: '0.85rem',
              ...(section === s.key ? { background: COLOR, color: '#fff', borderColor: COLOR } : {}),
            }}>
            {s.label}
          </button>
        ))}
      </div>

      {/* ── API Catalog ── */}
      {section === 'catalog' && (
        <>
          <div className="card" style={{ marginBottom: '1rem' }}>
            <SectionHeader title="API Catalog" count={apis?.length} onRefresh={loadApis} loading={apisLoading} />

            {/* Search */}
            <div className="input-row" style={{ marginBottom: '0.75rem' }}>
              <input
                type="text"
                placeholder="Search APIs…"
                value={search}
                onChange={e => setSearch(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && loadApis()}
                style={{ minWidth: 240 }}
              />
              <button className="btn-primary"
                style={{ background: COLOR, padding: '8px 18px', fontSize: '0.88rem' }}
                onClick={loadApis} disabled={apisLoading}>
                Search
              </button>
            </div>

            {/* Tag filter pills */}
            {allTags.length > 0 && (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: '0.75rem' }}>
                {['', ...allTags].map(t => (
                  <button key={t || '__all'}
                    onClick={() => setActiveTag(t === activeTag ? '' : t)}
                    style={{
                      padding: '3px 10px', borderRadius: 20, border: '1.5px solid',
                      fontSize: '0.75rem', fontWeight: 600, cursor: 'pointer',
                      borderColor: activeTag === t ? COLOR : '#e2e8f0',
                      background:  activeTag === t ? COLOR : '#fff',
                      color:       activeTag === t ? '#fff' : '#475569',
                    }}>
                    {t || 'All'}
                  </button>
                ))}
              </div>
            )}

            {apisErr && <span className="badge error">✗ {apisErr}</span>}
            {!apisErr && !apis && apisLoading && (
              <span style={{ fontSize: '0.82rem', color: '#94a3b8' }}>Loading APIs…</span>
            )}
            {apis && apis.length === 0 && (
              <span style={{ fontSize: '0.82rem', color: '#94a3b8' }}>No APIs found.</span>
            )}

            {/* API grid */}
            <div className="dp-api-grid">
              {(apis || []).map(api => (
                <div
                  key={api.id}
                  className={`dp-api-card ${selectedApi?.id === api.id ? 'selected' : ''}`}
                  onClick={() => setSelectedApi(selectedApi?.id === api.id ? null : api)}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div style={{ fontWeight: 700, fontSize: '0.92rem', marginBottom: 4 }}>{api.name}</div>
                    <span className="badge info" style={{ flexShrink: 0, marginLeft: 6 }}>v{api.version}</span>
                  </div>
                  <div style={{ fontSize: '0.78rem', color: '#64748b', marginBottom: 6, fontFamily: 'JetBrains Mono, monospace' }}>
                    {api.context}
                  </div>
                  {api.description && (
                    <p style={{
                      fontSize: '0.78rem', color: '#475569', margin: '0 0 8px', lineHeight: 1.5,
                      display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden',
                    }}>
                      {api.description}
                    </p>
                  )}
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, alignItems: 'center' }}>
                    {api.lifeCycleStatus && (
                      <StatusBadge text={api.lifeCycleStatus} ok={api.lifeCycleStatus === 'PUBLISHED'} />
                    )}
                    {(api.tags || []).slice(0, 3).map(t => <Tag key={t} label={t} />)}
                    {(api.tags || []).length > 3 && (
                      <span style={{ fontSize: '0.7rem', color: '#94a3b8' }}>+{(api.tags.length - 3)} more</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Detail panel */}
          {selectedApi && (
            <div className="card" style={{ marginBottom: '1rem' }}>
              <ApiDetailPanel api={selectedApi} onClose={() => setSelectedApi(null)} />
            </div>
          )}
        </>
      )}

      {section === 'apps' && <AppsPanel />}
    </div>
  );
}
