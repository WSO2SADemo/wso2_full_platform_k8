import React, { useState } from 'react';
import config from '../config';

const GATEWAYS = {
  envoy:     { label: 'Envoy Gateway',          color: '#00adef' },
  universal: { label: 'WSO2 Universal Gateway', color: '#6366f1' },
};
import EnvoyGatewayTab   from '../tabs/EnvoyGatewayTab';
import UniversalGatewayTab from '../tabs/UniversalGatewayTab';
import APIMigrationTab   from '../tabs/APIMigrationTab';
import DevPortalTab      from '../tabs/DevPortalTab';

const TABS = [
  { key: 'envoy',     label: 'Envoy — Patients',           icon: '🔵', cls: 'envoy',     gateway: GATEWAYS.envoy },
  { key: 'universal', label: 'Universal — Prescriptions',  icon: '🟣', cls: 'universal', gateway: GATEWAYS.universal },
  // { key: 'migration', label: 'API Migration',              icon: '🔄', cls: 'migration', gateway: null },
  { key: 'devportal', label: 'Dev Portal',                 icon: '🗂️', cls: 'devportal', gateway: null },
];

export default function Dashboard() {
  const [active, setActive] = useState('envoy');

  return (
    <div>
      <div className="tab-bar">
        {TABS.map(t => (
          <button
            key={t.key}
            className={`tab-btn ${active === t.key ? `active ${t.cls}` : ''}`}
            onClick={() => setActive(t.key)}
          >
            <span>{t.icon}</span>
            <span className="label">{t.label}</span>
          </button>
        ))}
      </div>

      {active === 'envoy'     && <EnvoyGatewayTab />}
      {active === 'universal' && <UniversalGatewayTab />}
      {/* {active === 'migration' && <APIMigrationTab />} */}
      {active === 'devportal' && <DevPortalTab />}
    </div>
  );
}
