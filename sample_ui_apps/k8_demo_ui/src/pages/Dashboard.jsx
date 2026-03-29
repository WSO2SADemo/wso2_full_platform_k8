import React, { useState } from 'react';
import config from '../config';

const GATEWAYS = {
  wso2K8:    { label: 'WSO2 K8 Gateway',       color: '#FF7300' },
  envoy:     { label: 'Envoy Gateway',          color: '#00adef' },
  universal: { label: 'WSO2 Universal Gateway', color: '#6366f1' },
  azure:     { label: 'Azure APIM',             color: '#0078d4' },
};
import WSO2GatewayTab    from '../tabs/WSO2GatewayTab';
import EnvoyGatewayTab   from '../tabs/EnvoyGatewayTab';
import AzureAPIMTab      from '../tabs/AzureAPIMTab';
import UniversalGatewayTab from '../tabs/UniversalGatewayTab';
import APIMigrationTab   from '../tabs/APIMigrationTab';
import DevPortalTab      from '../tabs/DevPortalTab';

const TABS = [
  { key: 'wso2',      label: 'WSO2 K8 — Patients',        icon: '🟠', cls: 'wso2',      gateway: GATEWAYS.wso2K8 },
  { key: 'envoy',     label: 'Envoy — Patients',           icon: '🔵', cls: 'envoy',     gateway: GATEWAYS.envoy },
  { key: 'universal', label: 'Universal — Prescriptions',  icon: '🟣', cls: 'universal', gateway: GATEWAYS.universal },
  { key: 'azure',     label: 'Azure APIM — Appointments',  icon: '☁️',  cls: 'azure',     gateway: GATEWAYS.azure },
  { key: 'migration', label: 'API Migration',              icon: '🔄', cls: 'migration', gateway: null },
  { key: 'devportal', label: 'Dev Portal',                 icon: '🗂️', cls: 'devportal', gateway: null },
];

export default function Dashboard() {
  const [active, setActive] = useState('wso2');

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

      {active === 'wso2'      && <WSO2GatewayTab />}
      {active === 'envoy'     && <EnvoyGatewayTab />}
      {active === 'universal' && <UniversalGatewayTab />}
      {active === 'azure'     && <AzureAPIMTab />}
      {active === 'migration' && <APIMigrationTab />}
      {active === 'devportal' && <DevPortalTab />}
    </div>
  );
}
