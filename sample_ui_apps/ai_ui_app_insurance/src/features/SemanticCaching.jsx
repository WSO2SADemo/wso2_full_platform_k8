import React, { useState } from 'react';
import { callAI } from '../api.js';
import { FeatureHeader, InfoBox, pageStyle, warnStyle } from './PromptTemplate.jsx';
import ResponsePanel from '../components/ResponsePanel.jsx';

const MODELS = ['mistral-small-latest', 'mistral-medium', 'open-mistral-7b'];

const PAIRS = [
  {
    label: 'Medical Claim',
    first:   'template://claim-intake-template?claim_type=Medical&claim_description=I+had+surgery+last+week',
    similar: 'template://claim-intake-template?claim_type=Medical&claim_description=I+underwent+a+surgical+procedure+recently',
  },
  {
    label: 'Dental Claim',
    first:   'template://claim-intake-template?claim_type=Dental&claim_description=I+had+a+tooth+extraction',
    similar: 'template://claim-intake-template?claim_type=Dental&claim_description=I+got+a+dental+procedure+done',
  },
  {
    label: 'Policy Advice',
    first:   'template://policy-advisor-template?customer_question=Does+my+plan+cover+physiotherapy+after+surgery?',
    similar: 'template://policy-advisor-template?customer_question=Is+post-operative+physiotherapy+included+in+my+coverage?',
  },
];

export default function SemanticCaching({ config }) {
  const [selected, setSelected] = useState(0);
  const [model, setModel] = useState(MODELS[0]);
  const [freshResult, setFreshResult] = useState(null);
  const [cachedResult, setCachedResult] = useState(null);
  const [loadingFresh, setLoadingFresh] = useState(false);
  const [loadingCached, setLoadingCached] = useState(false);
  const color = '#10b981';
  const pair = PAIRS[selected];

  const freshPayload  = { model, messages: [{ role: 'user', content: pair.first }] };
  const cachedPayload = { model, messages: [{ role: 'user', content: pair.similar }] };

  const sendFresh = async () => {
    setLoadingFresh(true); setFreshResult(null); setCachedResult(null);
    const res = await callAI(config.endpoints.semanticCache, config.apiKey, freshPayload);
    setFreshResult(res); setLoadingFresh(false);
  };

  const sendCached = async () => {
    if (!freshResult) return;
    setLoadingCached(true);
    const res = await callAI(config.endpoints.semanticCache, config.apiKey, cachedPayload);
    setCachedResult(res); setLoadingCached(false);
  };

  const cacheComp = freshResult && cachedResult ? {
    fresh: freshResult.elapsed,
    cached: cachedResult.elapsed,
  } : null;

  const preStyle = {
    background: '#1e293b', color: '#7dd3fc', borderRadius: 6,
    padding: '8px 12px', fontSize: '0.68rem', lineHeight: 1.5,
    overflowX: 'auto', margin: '10px 0 0', whiteSpace: 'pre',
  };

  return (
    <div style={pageStyle}>
      <FeatureHeader
        icon="💾" badge="CACHE" color={color}
        title="Semantic Caching"
        desc="Instead of exact-match caching, the gateway uses vector embeddings to detect semantically similar queries. When a new request is similar enough to a cached one (based on a dissimilarity threshold), the cached response is returned instantly — saving cost and latency."
      />

      <InfoBox color={color} title="Gateway Policy: Semantic Cache" items={[
        ['Endpoint', config.endpoints.semanticCache],
        ['Policy', 'Semantic Cache (Synapse mediator)'],
        ['Embedding Provider', 'Azure OpenAI / OpenAI / Mistral'],
        ['Vector DB', 'Zilliz / Milvus'],
        ['Similarity Threshold', '0.35 (L2 distance — lower = stricter)'],
        ['JSON Path', '$.messages[-1].content'],
        ['Applied on', 'Request Flow (lookup) + Response Flow (store)'],
      ]} />

      {/* Pair selector + Model selector */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20, flexWrap: 'wrap', gap: 10 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          {PAIRS.map((p, i) => (
            <button key={i} onClick={() => { setSelected(i); setFreshResult(null); setCachedResult(null); }} style={{
              padding: '7px 16px', borderRadius: 8, cursor: 'pointer', fontSize: '0.82rem',
              border: i === selected ? `2px solid ${color}` : '2px solid #e2e8f0',
              background: i === selected ? '#f0fdf4' : '#fff',
              color: i === selected ? '#065f46' : '#64748b', fontWeight: i === selected ? 600 : 400,
            }}>
              {p.label}
            </button>
          ))}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: '0.75rem', color: '#64748b', fontWeight: 600 }}>Model</span>
          <select value={model} onChange={e => { setModel(e.target.value); setFreshResult(null); setCachedResult(null); }} style={{
            padding: '6px 10px', border: '1px solid #e2e8f0', borderRadius: 8,
            fontSize: '0.8rem', cursor: 'pointer', color: '#0f172a',
          }}>
            {MODELS.map(m => <option key={m} value={m}>{m}</option>)}
          </select>
        </div>
      </div>

      {/* Step 1 & 2 */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginBottom: 20 }}>
        {/* Step 1 */}
        <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 12, padding: '16px 18px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: '0.72rem', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 4 }}>
                Step 1 — First Query (FRESH)
              </div>
              <div style={{ fontSize: '0.88rem', color: '#0f172a', fontStyle: 'italic' }}>"{pair.first}"</div>
              <div style={{ fontSize: '0.72rem', color: '#94a3b8', marginTop: 4 }}>→ Cache MISS: AI model invoked, response stored in vector DB</div>
              <pre style={preStyle}>{JSON.stringify(freshPayload, null, 2)}</pre>
            </div>
            <button onClick={sendFresh} disabled={loadingFresh || !config.apiKey} style={{
              background: color, color: '#fff', border: 'none', borderRadius: 8,
              padding: '9px 18px', cursor: 'pointer', fontSize: '0.82rem', fontWeight: 700, flexShrink: 0,
              opacity: loadingFresh ? 0.6 : 1,
            }}>
              {loadingFresh ? 'Sending…' : '▶ Send'}
            </button>
          </div>
          {freshResult && !loadingFresh && (
            <div style={{ marginTop: 10, display: 'flex', gap: 8, alignItems: 'center' }}>
              <span style={{ background: '#dcfce7', color: '#166534', padding: '2px 10px', borderRadius: 20, fontSize: '0.72rem', fontWeight: 700 }}>{freshResult.status} OK</span>
              <span style={{ background: '#fef3c7', color: '#92400e', padding: '2px 10px', borderRadius: 20, fontSize: '0.72rem', fontWeight: 700 }}>⏱ {freshResult.elapsed}ms · FRESH</span>
            </div>
          )}
        </div>

        {/* Step 2 */}
        <div style={{ background: '#fff', border: `1px solid ${freshResult ? color : '#e2e8f0'}`, borderRadius: 12, padding: '16px 18px', opacity: freshResult ? 1 : 0.5 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: '0.72rem', fontWeight: 700, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 4 }}>
                Step 2 — Semantically Similar Query (CACHED)
              </div>
              <div style={{ fontSize: '0.88rem', color: '#0f172a', fontStyle: 'italic' }}>"{pair.similar}"</div>
              <div style={{ fontSize: '0.72rem', color: '#94a3b8', marginTop: 4 }}>→ Cache HIT expected: embedding similarity &gt; threshold → instant cached response</div>
              <pre style={preStyle}>{JSON.stringify(cachedPayload, null, 2)}</pre>
            </div>
            <button onClick={sendCached} disabled={loadingCached || !freshResult || !config.apiKey} style={{
              background: freshResult ? '#8b5cf6' : '#cbd5e1', color: '#fff', border: 'none', borderRadius: 8,
              padding: '9px 18px', cursor: freshResult ? 'pointer' : 'not-allowed', fontSize: '0.82rem', fontWeight: 700, flexShrink: 0,
              opacity: loadingCached ? 0.6 : 1,
            }}>
              {loadingCached ? 'Sending…' : '▶ Send Similar'}
            </button>
          </div>
          {cachedResult && !loadingCached && (
            <div style={{ marginTop: 10, display: 'flex', gap: 8, alignItems: 'center' }}>
              <span style={{ background: '#dcfce7', color: '#166534', padding: '2px 10px', borderRadius: 20, fontSize: '0.72rem', fontWeight: 700 }}>{cachedResult.status} OK</span>
              <span style={{ background: '#ede9fe', color: '#5b21b6', padding: '2px 10px', borderRadius: 20, fontSize: '0.72rem', fontWeight: 700 }}>⏱ {cachedResult.elapsed}ms · ⚡ CACHED</span>
            </div>
          )}
        </div>
      </div>

      {!config.apiKey && <div style={warnStyle}>Configure your API key in ⚙️ Settings first</div>}

      <ResponsePanel result={cachedResult || freshResult} loading={loadingFresh || loadingCached} cacheComparison={cacheComp} />
    </div>
  );
}
