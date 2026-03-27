import { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { disruption, adr } from '../api/client';
import StatusBadge from '../components/StatusBadge';

export default function Recovery() {
  const location = useLocation();
  const [plans, setPlans]           = useState([]);
  const [flights, setFlights]       = useState([]);
  const [loading, setLoading]       = useState(true);
  const [recovering, setRecovering] = useState(false);
  const [result, setResult]         = useState(null);
  const [form, setForm]             = useState({
    flightId: location.state?.flightId || '',
    disruptionType: location.state?.disruptionType || 'Mechanical issue',
  });

  const load = () => {
    setLoading(true);
    Promise.all([
      adr.getRecoveryPlans().catch(() => []),
      disruption.getFlights().catch(() => []),
    ]).then(([p, f]) => { setPlans(p); setFlights(f); }).finally(() => setLoading(false));
  };
  useEffect(load, []);

  const triggerRecovery = async () => {
    if (!form.flightId) { alert('Select a flight'); return; }
    setRecovering(true); setResult(null);
    try {
      const res = await adr.triggerRecovery({
        flightId: form.flightId,
        disruptionType: form.disruptionType,
      });
      setResult(res);
      load();
    } catch (e) { alert(`Recovery failed: ${e.message}`); }
    finally { setRecovering(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">🔄 ADR Recovery</h1>

      {/* Trigger Recovery */}
      <div className="bg-gradient-to-r from-purple-50 to-indigo-50 border border-purple-200 rounded-xl p-6 mb-6">
        <h2 className="font-semibold mb-1">Trigger Autonomous Disruption Recovery</h2>
        <p className="text-sm text-gray-500 mb-4">
          The orchestrator will coordinate all agents: Disruption Detection → Crew → Passenger → Logistics
        </p>
        <div className="flex gap-3 items-end flex-wrap">
          <div className="flex-1 min-w-[200px]">
            <label className="block text-xs text-gray-500 mb-1">Flight</label>
            <select value={form.flightId} onChange={e => setForm({ ...form, flightId: e.target.value })}
              className="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="">Select flight…</option>
              {flights.map(f => (
                <option key={f.flight_id} value={f.flight_id}>
                  {f.flight_number} ({f.origin}→{f.destination}) [{f.status}]
                </option>
              ))}
            </select>
          </div>
          <div className="flex-1 min-w-[200px]">
            <label className="block text-xs text-gray-500 mb-1">Disruption Type</label>
            <select value={form.disruptionType} onChange={e => setForm({ ...form, disruptionType: e.target.value })}
              className="w-full border rounded-lg px-3 py-2 text-sm">
              <option>Mechanical issue</option>
              <option>Weather delay</option>
              <option>Crew shortage</option>
              <option>Air traffic control</option>
              <option>Security incident</option>
              <option>Bird strike</option>
            </select>
          </div>
          <button onClick={triggerRecovery} disabled={recovering || !form.flightId}
            className="bg-purple-600 text-white px-6 py-2 rounded-lg text-sm hover:bg-purple-700 disabled:opacity-50 whitespace-nowrap">
            {recovering ? (
              <span className="flex items-center gap-2">
                <span className="animate-spin h-4 w-4 border-2 border-white border-t-transparent rounded-full" />
                Running Recovery…
              </span>
            ) : '🚀 Start Recovery'}
          </button>
        </div>
      </div>

      {/* Recovery Result */}
      {result && (
        <div className="bg-white rounded-xl border p-6 mb-6">
          <div className="flex items-center gap-3 mb-4">
            <span className="text-2xl">✅</span>
            <div>
              <h2 className="font-semibold">Recovery Complete</h2>
              <p className="text-sm text-gray-500">{result.message}</p>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            <MiniStat label="Passengers Affected" value={result.passengers?.total_affected} />
            <MiniStat label="Rebooked" value={result.passengers?.rebooked} />
            <MiniStat label="Crew Reassignments" value={result.crew?.reassignments} />
            <MiniStat label="Est. Cost" value={`$${Number(result.estimated_cost).toLocaleString()}`} />
            {result.passengers?.compensated_no_alternatives > 0 && (
              <MiniStat label="No-Seat Compensations" value={result.passengers.compensated_no_alternatives} />
            )}
          </div>

          {/* Negotiation Log */}
          <h3 className="font-semibold text-sm mb-3">Negotiation Log</h3>
          <div className="space-y-2 max-h-96 overflow-y-auto">
            {(result.negotiation_log || []).map((step, i) => (
              <div key={i} className="flex gap-3 p-3 bg-gray-50 rounded-lg text-sm">
                <div className="flex-shrink-0">
                  <AgentIcon agent={step.agent} />
                </div>
                <div className="flex-1">
                  <div className="flex justify-between">
                    <p className="font-medium text-xs">{step.agent}</p>
                    <p className="text-xs text-gray-400">{new Date(step.timestamp).toLocaleTimeString()}</p>
                  </div>
                  <p className="text-sm">{step.action}</p>
                  {step.result && <p className="text-xs text-gray-500 mt-0.5">{step.result}</p>}
                </div>
              </div>
            ))}
          </div>

          <div className="mt-4 text-right">
            <Link to={`/recovery/${result.plan_id}`} className="text-blue-600 hover:underline text-sm">
              View Full Plan →
            </Link>
          </div>
        </div>
      )}

      {/* Previous Recovery Plans */}
      <div className="bg-white rounded-xl border p-5">
        <h2 className="font-semibold mb-4">Recovery Plans History</h2>
        {plans.length === 0 ? (
          <p className="text-gray-400 text-sm">No recovery plans yet. Trigger one above.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead><tr className="text-left text-gray-500 border-b">
                <th className="pb-2 pr-4">Plan ID</th>
                <th className="pb-2 pr-4">Flight</th>
                <th className="pb-2 pr-4">PAX Affected</th>
                <th className="pb-2 pr-4">Rebooked</th>
                <th className="pb-2 pr-4">Crew Changes</th>
                <th className="pb-2 pr-4">Gate Changes</th>
                <th className="pb-2 pr-4">Compensation</th>
                <th className="pb-2 pr-4">Cost</th>
                <th className="pb-2">Status</th>
              </tr></thead>
              <tbody>
                {plans.map(p => (
                  <tr key={p.plan_id} className="border-b last:border-0 hover:bg-gray-50">
                    <td className="py-3 pr-4">
                      <Link to={`/recovery/${p.plan_id}`} className="text-blue-600 hover:underline font-mono text-xs">
                        {p.plan_id.substring(0, 8)}…
                      </Link>
                    </td>
                    <td className="py-3 pr-4">
                      <Link to={`/flights/${p.flight_id}`} className="text-blue-600 hover:underline">{p.flight_id}</Link>
                    </td>
                    <td className="py-3 pr-4">{p.total_passengers_affected}</td>
                    <td className="py-3 pr-4">{p.passengers_rebooked}</td>
                    <td className="py-3 pr-4">{p.crew_reassignments}</td>
                    <td className="py-3 pr-4">{p.gate_changes}</td>
                    <td className="py-3 pr-4">${Number(p.total_compensations).toLocaleString()}</td>
                    <td className="py-3 pr-4">${Number(p.estimated_cost).toLocaleString()}</td>
                    <td className="py-3"><StatusBadge value={p.status} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

function AgentIcon({ agent }) {
  const icons = {
    Orchestrator: '🎯', DisruptionService: '⚠️', CrewService: '👨‍✈️',
    PassengerService: '🧳', LogisticsService: '🏗️',
  };
  return <span className="text-lg">{icons[agent] || '🔹'}</span>;
}

function MiniStat({ label, value }) {
  return (
    <div className="bg-gray-50 rounded-lg p-3 text-center">
      <p className="text-xs text-gray-500">{label}</p>
      <p className="text-lg font-bold mt-1">{value ?? '—'}</p>
    </div>
  );
}

function Spinner() {
  return <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
}
