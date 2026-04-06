import React, { useState } from 'react';

const NAV = [
  {
    group: '📝 Prompt Management',
    color: '#0ea5e9',
    items: [
      { id: 'decorator-ratelimit', label: 'Decorator + Rate Limiting', icon: '🎨⚡' },
      { id: 'prompt-template', label: 'Prompt Template', icon: '📋' },
    ],
  },
  {
    group: '💾 Semantic Caching',
    color: '#10b981',
    items: [
      { id: 'semantic-cache', label: 'Semantic Cache', icon: '💾' },
    ],
  },
  {
    group: '🛡 AI Guardrails',
    color: '#f97316',
    items: [
      { id: 'content-length',     label: 'Content Length',       icon: '📏' },
      { id: 'semantic-guardrail', label: 'Semantic Prompt',      icon: '🧠' },
      { id: 'url-guardrail',      label: 'URL Guardrail',        icon: '🔗' },
    ],
  },
];

export default function Sidebar({ activeTab, onTabChange, onSettings }) {
  const [collapsed, setCollapsed] = useState({});

  const toggle = (g) => setCollapsed(c => ({ ...c, [g]: !c[g] }));

  return (
    <div style={{
      width: 260, flexShrink: 0, background: '#0f172a',
      display: 'flex', flexDirection: 'column',
      height: '100vh', overflowY: 'auto',
    }}>
      {/* Logo */}
      <div style={{ padding: '20px 20px 16px' }}>
        <div style={{ color: '#5eead4', fontWeight: 800, fontSize: '1.05rem', letterSpacing: '-0.01em' }}>
          🏥 HealthGuard
        </div>
        <div style={{ color: '#475569', fontSize: '0.72rem', marginTop: 2, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
          AI Gateway Demo
        </div>
      </div>

      <div style={{ borderTop: '1px solid #1e293b', margin: '0 16px' }} />

      {/* Nav */}
      <div style={{ flex: 1, padding: '12px 0' }}>
        {NAV.map(({ group, color, items }) => (
          <div key={group}>
            <button
              onClick={() => toggle(group)}
              style={{
                width: '100%', background: 'none', border: 'none',
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: '8px 20px', cursor: 'pointer',
                color: '#64748b', fontSize: '0.7rem', fontWeight: 700,
                textTransform: 'uppercase', letterSpacing: '0.08em',
              }}
            >
              <span>{group}</span>
              <span style={{ fontSize: '0.6rem', color: '#334155' }}>{collapsed[group] ? '▶' : '▼'}</span>
            </button>
            {!collapsed[group] && items.map(({ id, label, icon }) => {
              const active = activeTab === id;
              return (
                <button
                  key={id}
                  onClick={() => onTabChange(id)}
                  style={{
                    width: '100%', border: 'none',
                    display: 'flex', alignItems: 'center', gap: 10,
                    padding: '9px 20px 9px 28px', cursor: 'pointer', textAlign: 'left',
                    color: active ? '#fff' : '#94a3b8',
                    fontSize: '0.85rem',
                    fontWeight: active ? 600 : 400,
                    background: active ? '#0d6e6e22' : 'transparent',
                    borderLeft: active ? `3px solid ${color}` : '3px solid transparent',
                    transition: 'background 0.15s',
                  }}
                >
                  <span style={{ fontSize: '1rem' }}>{icon}</span>
                  {label}
                </button>
              );
            })}
          </div>
        ))}
      </div>

      {/* Settings */}
      <div style={{ borderTop: '1px solid #1e293b', padding: '12px 16px' }}>
        <button
          onClick={onSettings}
          style={{
            width: '100%', background: '#1e293b', border: '1px solid #334155',
            borderRadius: 8, padding: '10px 14px', cursor: 'pointer',
            color: '#94a3b8', fontSize: '0.82rem', fontWeight: 600,
            display: 'flex', alignItems: 'center', gap: 8,
          }}
        >
          ⚙️ Configure Endpoints & Key
        </button>
      </div>
    </div>
  );
}
