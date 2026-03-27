import React, { useState } from 'react';
import EmployeeDashboard from './EmployeeDashboard';
import OBODashboard from './OBODashboard';

const tabs = [
  { id: 'policies',  label: '📋 Policies Dashboard' },
  { id: 'obo-case',  label: '🔐 OBO Case' },
];

export default function EmployeePortal() {
  const [activeTab, setActiveTab] = useState('policies');

  return (
    <div style={{ display: 'flex', height: '100vh', background: '#f0fdf4', position: 'relative' }}>

      {/* Sidebar — rendered by EmployeeDashboard when on policies tab, hidden otherwise */}
      {activeTab === 'policies' ? (
        <EmployeeDashboard />
      ) : (
        <>
          {/* Minimal sidebar for OBO tab so layout stays consistent */}
          <div style={{ width: '260px', background: '#064e3b', color: 'white', padding: '30px 20px', display: 'flex', flexDirection: 'column', flexShrink: 0 }}>
            <div style={{ marginBottom: '40px' }}>
              <div style={{ fontSize: '1.5rem', marginBottom: '4px' }}>🛡️</div>
              <h3 style={{ margin: 0, color: '#10b981' }}>SafeGuard Insurance</h3>
              <p style={{ margin: '4px 0 0 0', fontSize: '0.8rem', opacity: 0.7 }}>Employee Portal</p>
            </div>
            <div style={{ flex: 1 }}>
              {tabs.map(tab => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  style={{
                    display: 'block', width: '100%', textAlign: 'left',
                    padding: '12px', marginBottom: '4px',
                    background: activeTab === tab.id ? 'rgba(255,255,255,0.15)' : 'transparent',
                    border: 'none', borderRadius: '8px',
                    color: activeTab === tab.id ? '#fff' : 'rgba(255,255,255,0.7)',
                    cursor: 'pointer', fontSize: '0.9rem',
                    fontWeight: activeTab === tab.id ? 600 : 400,
                    transition: 'background 0.15s'
                  }}
                >
                  {tab.label}
                </button>
              ))}
            </div>
          </div>

          <OBODashboard />
        </>
      )}

      {/* Tab switcher overlay on the policies tab */}
      {activeTab === 'policies' && (
        <div style={{
          position: 'fixed', top: '16px', left: '50%', transform: 'translateX(-50%)',
          display: 'flex', gap: '4px', background: 'rgba(255,255,255,0.95)',
          borderRadius: '10px', padding: '4px', boxShadow: '0 2px 12px rgba(0,0,0,0.12)',
          zIndex: 200, border: '1px solid #d1fae5'
        }}>
          {tabs.map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              style={{
                padding: '7px 18px', border: 'none', borderRadius: '7px',
                background: activeTab === tab.id ? '#064e3b' : 'transparent',
                color: activeTab === tab.id ? '#fff' : '#64748b',
                fontWeight: activeTab === tab.id ? 700 : 500,
                fontSize: '0.85rem', cursor: 'pointer',
                transition: 'background 0.15s, color 0.15s'
              }}
            >
              {tab.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
