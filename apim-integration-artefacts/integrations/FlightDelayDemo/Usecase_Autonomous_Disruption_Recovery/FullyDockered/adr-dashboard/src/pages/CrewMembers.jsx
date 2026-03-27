import { useEffect, useState } from 'react';
import { crew, disruption } from '../api/client';
import StatusBadge from '../components/StatusBadge';

export default function CrewMembers() {
  const [members, setMembers]   = useState([]);
  const [flights, setFlights]   = useState([]);
  const [loading, setLoading]   = useState(true);
  const [showAdd, setShowAdd]   = useState(false);
  const [compliance, setCompliance] = useState(null);
  const [evaluation, setEvaluation] = useState(null);
  const [evalFlightId, setEvalFlightId] = useState('');

  const load = () => {
    setLoading(true);
    Promise.all([
      crew.getMembers(),
      disruption.getFlights().catch(() => []),
    ]).then(([m, f]) => { setMembers(m); setFlights(f); }).finally(() => setLoading(false));
  };
  useEffect(load, []);

  const checkCompliance = async (member) => {
    const hours = prompt('Additional duty hours to check:', '2');
    if (!hours) return;
    try {
      const result = await crew.checkCompliance({
        crew_id: member.crew_id,
        flight_id: 'COMPLIANCE_CHECK',
        additional_hours: Number(hours),
      });
      setCompliance(result);
    } catch (e) { alert(e.message); }
  };

  const assignToFlight = async (member) => {
    const flightId = prompt('Flight ID to assign to:', '');
    if (!flightId) return;
    try {
      const result = await crew.assignCrew({
        crew_id: member.crew_id,
        flight_id: flightId,
        role: member.role,
      });
      alert(result.message || 'Crew assigned successfully');
      load();
    } catch (e) { alert(e.message); }
  };

  const evaluateFlight = async () => {
    if (!evalFlightId) { alert('Select a flight'); return; }
    try {
      const result = await crew.evaluateCrew(evalFlightId);
      setEvaluation(result);
    } catch (e) { alert(e.message); }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Crew Members</h1>
        <button onClick={() => setShowAdd(!showAdd)}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700">
          {showAdd ? 'Cancel' : '+ Add Crew'}
        </button>
      </div>

      {showAdd && <AddCrewForm onCreated={() => { setShowAdd(false); load(); }} />}

      {compliance && (
        <div className={`rounded-xl border p-4 mb-4 ${compliance.compliant ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200'}`}>
          <div className="flex justify-between items-start">
            <div>
              <p className="font-medium">{compliance.compliant ? 'COMPLIANT' : 'NON-COMPLIANT'}</p>
              <p className="text-sm mt-1">{compliance.message}</p>
              <p className="text-xs text-gray-500 mt-1">
                Current: {compliance.current_duty_hours}h · Requested: +{compliance.requested_additional_hours}h · 
                Projected: {compliance.projected_total}h / {compliance.max_duty_hours}h max
              </p>
            </div>
            <button onClick={() => setCompliance(null)} className="text-gray-400 hover:text-gray-600">X</button>
          </div>
        </div>
      )}

      {/* Crew Fitness Evaluation */}
      <div className="bg-indigo-50 border border-indigo-200 rounded-xl p-4 mb-4">
        <div className="flex items-center gap-3 mb-2">
          <h2 className="font-semibold text-sm">Crew Fitness Evaluation</h2>
          <select value={evalFlightId} onChange={e => setEvalFlightId(e.target.value)}
            className="border rounded-lg px-3 py-1 text-sm">
            <option value="">Select flight…</option>
            {flights.map(f => (
              <option key={f.flight_id} value={f.flight_id}>{f.flight_number} ({f.origin}→{f.destination})</option>
            ))}
          </select>
          <button onClick={evaluateFlight} disabled={!evalFlightId}
            className="bg-indigo-600 text-white px-4 py-1 rounded-lg text-sm hover:bg-indigo-700 disabled:opacity-50">
            Evaluate
          </button>
        </div>
        {evaluation && (
          <div className="bg-white rounded-lg p-3 mt-2 text-sm space-y-2">
            <p><strong>Flight:</strong> {evaluation.flight_id}</p>
            {(evaluation.candidates || []).length > 0 ? (
              <div className="space-y-1">
                {evaluation.candidates.map((c, i) => (
                  <div key={i} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                    <div>
                      <span className="font-medium">{c.crew_id}</span>
                      <span className="text-xs text-gray-500 ml-2">{c.role}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <StatusBadge value={c.fitness} />
                      <span className="text-xs text-gray-500">{c.remaining_hours}h remaining</span>
                    </div>
                  </div>
                ))}
              </div>
            ) : <p className="text-gray-400">No candidates found.</p>}
            {(evaluation.gaps || []).length > 0 && (
              <p className="text-sm text-red-500">Gaps: {evaluation.gaps.join(', ')}</p>
            )}
          </div>
        )}
      </div>

      {loading ? <Spinner /> : (
        <div className="bg-white rounded-xl border overflow-hidden">
          <table className="w-full text-sm">
            <thead><tr className="bg-gray-50 text-left text-gray-500">
              <th className="px-4 py-3">Name</th><th className="px-4 py-3">Role</th>
              <th className="px-4 py-3">Base Airport</th><th className="px-4 py-3">Duty Hours</th>
              <th className="px-4 py-3">Certification</th><th className="px-4 py-3">Status</th>
              <th className="px-4 py-3"></th>
            </tr></thead>
            <tbody>
              {members.map(m => (
                <tr key={m.crew_id} className="border-t hover:bg-gray-50">
                  <td className="px-4 py-3">
                    <p className="font-medium">{m.first_name} {m.last_name}</p>
                    <p className="text-xs text-gray-400">{m.crew_id}</p>
                  </td>
                  <td className="px-4 py-3">{m.role}</td>
                  <td className="px-4 py-3">{m.base_airport}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="w-20 bg-gray-200 rounded-full h-2">
                        <div className="bg-blue-600 h-2 rounded-full" 
                          style={{ width: `${Math.min(100, (m.duty_hours_today / m.max_duty_hours) * 100)}%` }} />
                      </div>
                      <span className="text-xs text-gray-500">{m.duty_hours_today}/{m.max_duty_hours}h</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-xs">{m.certification || '—'}</td>
                  <td className="px-4 py-3"><StatusBadge value={m.status} /></td>
                  <td className="px-4 py-3">
                    <div className="flex gap-1">
                      <button onClick={() => checkCompliance(m)}
                        className="text-xs bg-indigo-600 text-white px-3 py-1 rounded hover:bg-indigo-700">
                        Compliance
                      </button>
                      {m.status === 'AVAILABLE' && (
                        <button onClick={() => assignToFlight(m)}
                          className="text-xs bg-green-600 text-white px-3 py-1 rounded hover:bg-green-700">
                          Assign
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function AddCrewForm({ onCreated }) {
  const [form, setForm] = useState({
    first_name: '', last_name: '', role: 'PILOT', base_airport: '',
    certification: '', phone: '', email: '',
  });
  const [saving, setSaving] = useState(false);

  const submit = async (e) => {
    e.preventDefault(); setSaving(true);
    try { await crew.createMember(form); onCreated(); }
    catch { alert('Failed to create crew member'); }
    finally { setSaving(false); }
  };

  return (
    <form onSubmit={submit} className="bg-white rounded-xl border p-5 mb-6 grid grid-cols-2 md:grid-cols-4 gap-4">
      <Input label="First Name" value={form.first_name} onChange={v => setForm({...form, first_name: v})} />
      <Input label="Last Name" value={form.last_name} onChange={v => setForm({...form, last_name: v})} />
      <div>
        <label className="block text-xs text-gray-500 mb-1">Role</label>
        <select value={form.role} onChange={e => setForm({...form, role: e.target.value})}
          className="w-full border rounded-lg px-3 py-2 text-sm">
          <option>PILOT</option><option>FIRST_OFFICER</option><option>CABIN_CREW</option><option>PURSER</option>
        </select>
      </div>
      <Input label="Base Airport" value={form.base_airport} onChange={v => setForm({...form, base_airport: v})} />
      <Input label="Certification" value={form.certification} onChange={v => setForm({...form, certification: v})} />
      <Input label="Phone" value={form.phone} onChange={v => setForm({...form, phone: v})} />
      <Input label="Email" value={form.email} type="email" onChange={v => setForm({...form, email: v})} />
      <div className="flex items-end">
        <button type="submit" disabled={saving}
          className="bg-green-600 text-white px-6 py-2 rounded-lg text-sm hover:bg-green-700 disabled:opacity-50 w-full">
          {saving ? 'Creating…' : 'Create'}
        </button>
      </div>
    </form>
  );
}

function Input({ label, value, onChange, type = 'text' }) {
  return (
    <div>
      <label className="block text-xs text-gray-500 mb-1">{label}</label>
      <input type={type} value={value} onChange={e => onChange(e.target.value)}
        className="w-full border rounded-lg px-3 py-2 text-sm" required />
    </div>
  );
}

function Spinner() {
  return <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
}
