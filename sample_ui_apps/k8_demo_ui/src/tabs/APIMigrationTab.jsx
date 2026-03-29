import React, { useState } from 'react';

const COLOR = '#16a34a';

const STEPS_META = [
  { key: 'login',   label: 'Step 1 — Login (DevOps user)',          icon: '🔐' },
  { key: 'export',  label: 'Step 2 — Export API from Azure APIM',   icon: '📤' },
  { key: 'prepare', label: 'Step 3 — Extract & patch api.json',     icon: '🔧' },
  { key: 'delete',  label: 'Step 4 — Delete existing API (admin)',  icon: '🗑️' },
  { key: 'import',  label: 'Step 5 — Import to WSO2 K8 Gateway',    icon: '📥' },
];

export default function APIMigrationTab() {
  const [apiName, setApiName]   = useState('MedicalAppointmentsAPI');
  const [version, setVersion]   = useState('1.0.0');
  const [running, setRunning]   = useState(false);
  const [results, setResults]   = useState([]);   // [{step, status, output}]
  const [error, setError]       = useState(null);
  const [done, setDone]         = useState(false);

  const runStep = async (step) => {
    setRunning(true);
    setError(null);
    if (step === 'all') { setResults([]); setDone(false); }

    try {
      const res = await fetch('/api/migrate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ apiName, version, step }),
      });
      const data = await res.json();
      if (step === 'all') {
        setResults(data.steps || []);
        setDone(data.success);
      } else {
        setResults(prev => {
          const updated = [...prev];
          (data.steps || []).forEach(s => {
            const idx = updated.findIndex(r => r.step === s.step);
            if (idx >= 0) updated[idx] = s; else updated.push(s);
          });
          return updated;
        });
      }
      if (!data.success) setError('One or more steps failed — see output below.');
    } catch (e) {
      setError('Server unreachable: ' + e.message);
    } finally {
      setRunning(false);
    }
  };

  const getResult = (label) => results.find(r => r.step === label);

  const flowSteps = [
    { label: 'Azure APIM',      done: !!getResult('Export API') },
    { label: 'Export',          done: !!getResult('Export API') },
    { label: 'Patch api.json',  done: !!getResult('Extract & patch api.json') },
    { label: 'WSO2 K8 Gateway', done: !!getResult('Import updated API') },
  ];

  return (
    <div>
      {/* Header */}
      <div className="gateway-header" style={{ background: `linear-gradient(135deg, ${COLOR}, #15803d)` }}>
        <div style={{ fontSize: '2rem' }}>🔄</div>
        <div>
          <h2>API Migration — Azure APIM → WSO2 K8 Gateway</h2>
          <p>Export from Azure · Patch gateway config · Import to WSO2 APK via apictl</p>
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

      {/* Config */}
      <div className="card" style={{ marginBottom: '1rem' }}>
        <p className="section-title">API Details</p>
        <div className="input-row">
          <label style={{ fontSize: '0.9rem', fontWeight: 500 }}>API Name</label>
          <input type="text" value={apiName} onChange={e => setApiName(e.target.value)} style={{ minWidth: '260px' }} />
          <label style={{ fontSize: '0.9rem', fontWeight: 500 }}>Version</label>
          <input type="text" value={version} onChange={e => setVersion(e.target.value)} style={{ minWidth: '80px' }} />
        </div>

        {/* Run all button */}
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', marginTop: '0.5rem' }}>
          <button
            className="btn-primary"
            style={{ background: COLOR, minWidth: '160px' }}
            onClick={() => runStep('all')}
            disabled={running || !apiName || !version}
          >
            {running ? <><span className="spinner" style={{ borderTopColor: '#fff', marginRight: '8px' }} /> Running…</> : '▶ Run Full Migration'}
          </button>
          {done && <span className="badge success">✓ Migration complete</span>}
          {error && <span className="badge error">✗ {error}</span>}
        </div>
      </div>

      {/* Step-by-step cards */}
      {STEPS_META.map(({ key, label, icon }) => {
        const result = getResult(
          key === 'login'   ? 'Login (DevOps user)'         :
          key === 'export'  ? 'Export API'                  :
          key === 'prepare' ? 'Extract & patch api.json'    :
          key === 'delete'  ? 'Login (admin) & Delete existing API' :
                              'Import updated API'
        );
        const isOk = result?.status === 'success';

        return (
          <div key={key} className="card" style={{ marginBottom: '1rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
              <p className="section-title" style={{ margin: 0 }}>{icon} {label}</p>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                {result && (
                  <span className={`badge ${isOk ? 'success' : 'error'}`}>
                    {isOk ? '✓ Done' : '✗ Failed'}
                  </span>
                )}
                <button
                  className="btn-secondary"
                  style={{ padding: '4px 14px', fontSize: '0.8rem' }}
                  onClick={() => runStep(key)}
                  disabled={running}
                >
                  Run step
                </button>
              </div>
            </div>

            {/* Command preview */}
            <div className="code-block" style={{ fontSize: '0.78rem', padding: '0.75rem 1rem', marginBottom: result ? '0.75rem' : 0 }}>
              {key === 'login'   && `apictl login Production -u Pereira -k`}
              {key === 'export'  && `apictl export api -n ${apiName} -v ${version} -r Pereira -e Production --format JSON -k`}
              {key === 'prepare' && `unzip ${apiName}_${version}.zip\n# patch api.json:\n#   gatewayVendor: "wso2"\n#   gatewayType: "wso2/apk"\n#   initiatedFromGateway: false\n# copy deployment_environments.yaml`}
              {key === 'delete'  && `apictl delete api -n ${apiName} -v ${version} -r admin -e Production -k`}
              {key === 'import'  && `apictl import api -f ${apiName}-${version} -e Production --update -k --preserve-provider=false --verbose`}
            </div>

            {/* Output */}
            {result && (
              <div className="code-block" style={{ fontSize: '0.75rem', padding: '0.75rem 1rem', background: isOk ? '#0d1f0f' : '#1f0d0d' }}>
                <span style={{ color: '#94a3b8' }}># output{'\n'}</span>
                <span style={{ color: isOk ? '#86efac' : '#fca5a5' }}>{result.output}</span>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
