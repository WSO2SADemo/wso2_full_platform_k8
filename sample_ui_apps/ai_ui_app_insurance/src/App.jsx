import React, { useState } from 'react';
import { loadConfig, saveConfig } from './config.js';
import Sidebar from './components/Sidebar.jsx';
import SettingsModal from './components/SettingsModal.jsx';
import PromptTemplate from './features/PromptTemplate.jsx';
import DecoratorAndRateLimit from './features/DecoratorAndRateLimit.jsx';
import SemanticCaching from './features/SemanticCaching.jsx';
import ContentLength from './features/ContentLength.jsx';
import SemanticPromptGuardrail from './features/SemanticPromptGuardrail.jsx';
import UrlGuardrail from './features/UrlGuardrail.jsx';

const FEATURE_MAP = {
  'prompt-template':    { component: PromptTemplate,          title: 'Prompt Template' },
  'decorator-ratelimit': { component: DecoratorAndRateLimit,  title: 'Prompt Decorator + Rate Limiting' },
  'semantic-cache':     { component: SemanticCaching,         title: 'Semantic Caching' },
  'content-length':     { component: ContentLength,           title: 'Content Length Guardrail' },
  'semantic-guardrail': { component: SemanticPromptGuardrail, title: 'Semantic Prompt Guardrail' },
  'url-guardrail':      { component: UrlGuardrail,            title: 'URL Guardrail' },
};

export default function App() {
  const [activeTab, setActiveTab] = useState('decorator-ratelimit');
  const [config, setConfig] = useState(loadConfig);
  const [showSettings, setShowSettings] = useState(!loadConfig().apiKey);

  const handleSave = (newConfig) => {
    saveConfig(newConfig);
    setConfig(newConfig);
  };

  const feature = FEATURE_MAP[activeTab];
  const FeatureComponent = feature?.component;

  const noKey = !config.apiKey;

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden' }}>
      <Sidebar activeTab={activeTab} onTabChange={setActiveTab} onSettings={() => setShowSettings(true)} />

      <div style={{ flex: 1, overflowY: 'auto', background: '#f8fafc' }}>
        {/* Top bar */}
        <div style={{
          position: 'sticky', top: 0, zIndex: 10,
          background: 'rgba(248,250,252,0.9)', backdropFilter: 'blur(8px)',
          borderBottom: '1px solid #e2e8f0',
          padding: '12px 36px',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontWeight: 700, color: '#0f172a', fontSize: '0.95rem' }}>
              {feature?.title}
            </span>
            <span style={{ fontSize: '0.72rem', color: '#94a3b8' }}>
              WSO2 AI Gateway · HealthGuard Insurance Demo
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {noKey && (
              <div style={{
                background: '#fef9c3', border: '1px solid #fde68a',
                borderRadius: 20, padding: '4px 14px',
                fontSize: '0.75rem', color: '#92400e', fontWeight: 600,
              }}>
                ⚠ No API key configured
              </div>
            )}
            {!noKey && (
              <div style={{
                background: '#dcfce7', border: '1px solid #bbf7d0',
                borderRadius: 20, padding: '4px 14px',
                fontSize: '0.75rem', color: '#166534', fontWeight: 600,
              }}>
                ✓ API key set
              </div>
            )}
            <button
              onClick={() => setShowSettings(true)}
              style={{
                background: '#fff', border: '1px solid #e2e8f0', borderRadius: 8,
                padding: '7px 14px', cursor: 'pointer', fontSize: '0.8rem', color: '#475569',
                fontWeight: 600,
              }}
            >
              ⚙️ Settings
            </button>
          </div>
        </div>

        {/* Feature content */}
        {FeatureComponent && <FeatureComponent config={config} />}
      </div>

      {showSettings && (
        <SettingsModal config={config} onSave={handleSave} onClose={() => setShowSettings(false)} />
      )}
    </div>
  );
}
