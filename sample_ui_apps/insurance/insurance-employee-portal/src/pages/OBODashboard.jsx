import React from 'react';

const steps = [
  {
    icon: '💬',
    title: '1. Employee sends request',
    desc: 'You ask the agent to submit or update a claim. For read-only queries (policy list, claim status) the agent responds immediately.',
    color: '#7c3aed'
  },
  {
    icon: '🔍',
    title: '2. Agent detects privilege need',
    desc: 'The agent attempts submitClaim but finds no delegated token for this session. It signals that user consent is required.',
    color: '#7c3aed'
  },
  {
    icon: '🔐',
    title: '3. Consent URL returned',
    desc: 'A popup opens to WSO2 IS with requested_actor=agentID. The customer (or you, as the authorized employee) grants the agent permission.',
    color: '#7c3aed'
  },
  {
    icon: '🎫',
    title: '4. OBO token issued',
    desc: 'IS issues a delegated JWT — it carries the user\'s identity (sub) and the agent\'s identity (act). The user\'s role must include the required scopes.',
    color: '#7c3aed'
  },
  {
    icon: '✅',
    title: '5. Request retried with delegation',
    desc: 'Your original message is automatically retried. submitClaim injects the OBO token — the backend sees a verified, user-consented agent action.',
    color: '#059669'
  },
];

export default function OBODashboard() {
  return (
    <div style={{ flex: 1, padding: '40px', overflowY: 'auto' }}>

      {/* Header */}
      <div style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ margin: 0, color: '#064e3b' }}>
          🔐 On-Behalf-Of (OBO) Flow Demo
        </h2>
        <p style={{ color: '#64748b', marginTop: '6px', fontSize: '0.95rem' }}>
          Demonstrates WSO2 IS Agentic AI — the agent acts with explicit user-delegated consent, only when a privileged operation is needed.
        </p>
      </div>

      {/* How it works */}
      <div className="card" style={{ marginBottom: '2rem' }}>
        <h3 style={{ marginTop: 0, color: '#7c3aed' }}>How the OBO flow works</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
          {steps.map((step, i) => (
            <div key={i} style={{
              display: 'flex', gap: '16px', alignItems: 'flex-start',
              padding: '12px 16px', borderRadius: '10px',
              background: i === steps.length - 1 ? '#f0fdf4' : '#faf5ff',
              border: `1px solid ${i === steps.length - 1 ? '#bbf7d0' : '#ede9fe'}`
            }}>
              <span style={{ fontSize: '1.4rem', flexShrink: 0 }}>{step.icon}</span>
              <div>
                <div style={{ fontWeight: 600, color: step.color, marginBottom: '2px', fontSize: '0.9rem' }}>{step.title}</div>
                <div style={{ fontSize: '0.85rem', color: '#475569' }}>{step.desc}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Try it */}
      <div className="card" style={{ marginBottom: '2rem', border: '1px dashed #c4b5fd' }}>
        <h3 style={{ marginTop: 0, color: '#7c3aed' }}>Try it out</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '16px' }}>
          {[
            { type: 'READ',       prompt: 'List all active policies.' },
            { type: 'READ',       prompt: 'Show claims for policy POL-HEALTH-001.' },
            { type: 'PRIVILEGED', prompt: 'Submit a hospitalization claim for $800 for policy POL-HEALTH-001.' },
          ].map((ex, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: '12px',
              padding: '10px 14px', borderRadius: '8px',
              background: ex.type === 'READ' ? '#f0f9ff' : '#faf5ff',
              border: `1px solid ${ex.type === 'READ' ? '#bae6fd' : '#ddd6fe'}`
            }}>
              <span style={{
                fontSize: '0.7rem', fontWeight: 700, padding: '2px 8px', borderRadius: '4px',
                background: ex.type === 'READ' ? '#0ea5e9' : '#7c3aed', color: '#fff', flexShrink: 0
              }}>
                {ex.type}
              </span>
              <span style={{ fontSize: '0.875rem', color: '#334155', fontStyle: 'italic' }}>
                "{ex.prompt}"
              </span>
            </div>
          ))}
        </div>
        <p style={{ margin: 0, fontSize: '0.85rem', color: '#94a3b8' }}>
          Use the <strong style={{ color: '#7c3aed' }}>🔐 OBO Agent</strong> button on the My Insurance page to try the OBO flow.
        </p>
      </div>

      {/* Token anatomy */}
      <div className="card" style={{ background: '#1e1b4b', color: '#c4b5fd', border: '1px solid #4c1d95' }}>
        <h3 style={{ margin: '0 0 12px', color: '#a78bfa' }}>What makes the OBO token special</h3>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '12px' }}>
          {[
            { label: 'Issued by',   value: 'WSO2 IS (token exchange)' },
            { label: 'Subject (sub)', value: 'The user (customer/employee)' },
            { label: 'Actor (act)', value: 'Insurance Agent (agentID)' },
            { label: 'Grant type',  value: 'authorization_code + actor_token' },
            { label: 'Proof',       value: 'User explicitly consented' },
            { label: 'Scope',       value: 'ordinary_api_scope privilege_api_scope' },
          ].map((item, i) => (
            <div key={i} style={{ padding: '10px', background: 'rgba(255,255,255,0.05)', borderRadius: '8px' }}>
              <div style={{ fontSize: '0.7rem', color: '#818cf8', marginBottom: '2px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                {item.label}
              </div>
              <div style={{ fontSize: '0.85rem', color: '#e0e7ff', fontWeight: 600 }}>{item.value}</div>
            </div>
          ))}
        </div>
      </div>

    </div>
  );
}
