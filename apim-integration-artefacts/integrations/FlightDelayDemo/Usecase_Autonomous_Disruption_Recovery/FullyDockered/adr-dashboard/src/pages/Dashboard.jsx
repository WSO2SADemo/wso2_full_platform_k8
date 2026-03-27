import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { disruption, adr } from '../api/client';
import StatusBadge from '../components/StatusBadge';

function StatCard({ icon, label, value, color }) {
  return (
    <div className={`rounded-xl border p-5 ${color}`}>
      <div className="flex items-center gap-3 mb-2">
        <span className="text-2xl">{icon}</span>
        <span className="text-sm font-medium text-gray-500">{label}</span>
      </div>
      <p className="text-3xl font-bold">{value ?? '—'}</p>
    </div>
  );
}

export default function Dashboard() {
  const [flights, setFlights]       = useState([]);
  const [delays, setDelays]         = useState([]);
  const [plans, setPlans]           = useState([]);
  const [loading, setLoading]       = useState(true);
  const [error, setError]           = useState(null);

  useEffect(() => {
    Promise.all([
      disruption.getFlights().catch(() => []),
      disruption.getDelays().catch(() => []),
      adr.getRecoveryPlans().catch(() => []),
    ]).then(([f, d, p]) => {
      setFlights(f); setDelays(d); setPlans(p);
    }).catch(e => setError(e.message)).finally(() => setLoading(false));
  }, []);

  if (loading) return <LoadingSpinner />;
  if (error) return <ErrorMsg msg={error} />;

  const delayed    = flights.filter(f => f.status === 'DELAYED').length;
  const scheduled  = flights.filter(f => f.status === 'SCHEDULED').length;
  const unscheduled = flights.filter(f => f.status === 'UNSCHEDULED').length;
  const available  = flights.filter(f => f.status === 'AVAILABLE').length;
  const totalPax   = flights.reduce((s, f) => s + (f.passenger_count || 0), 0);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Dashboard</h1>

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
        <StatCard icon="✈️" label="Total Flights"      value={flights.length}  color="bg-white" />
        <StatCard icon="⚠️" label="Active Disruptions" value={delays.length}   color="bg-yellow-50 border-yellow-200" />
        <StatCard icon="⏱️" label="Delayed Flights"    value={delayed}         color="bg-red-50 border-red-200" />
        <StatCard icon="🔄" label="Recovery Plans"     value={plans.length}    color="bg-purple-50 border-purple-200" />
      </div>
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard icon="📋" label="Scheduled"          value={scheduled}       color="bg-blue-50 border-blue-200" />
        <StatCard icon="🆕" label="Unscheduled"        value={unscheduled}     color="bg-gray-50 border-gray-200" />
        <StatCard icon="✅" label="Available"           value={available}       color="bg-green-50 border-green-200" />
        <StatCard icon="👥" label="Total Passengers"   value={totalPax}        color="bg-indigo-50 border-indigo-200" />
      </div>

      <div className="grid lg:grid-cols-2 gap-6">
        {/* Active Disruptions */}
        <div className="bg-white rounded-xl border p-5">
          <div className="flex justify-between items-center mb-4">
            <h2 className="font-semibold">Active Disruptions</h2>
            <Link to="/disruptions" className="text-sm text-blue-600 hover:underline">View all →</Link>
          </div>
          {delays.length === 0 ? (
            <p className="text-gray-400 text-sm">No active disruptions ✅</p>
          ) : (
            <div className="space-y-3 max-h-72 overflow-y-auto">
              {delays.slice(0, 8).map(d => (
                <div key={d.disruption_id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div>
                    <p className="text-sm font-medium">{d.flight_id}</p>
                    <p className="text-xs text-gray-500">{d.reason || d.disruption_type} — {d.delay_minutes} min</p>
                  </div>
                  <StatusBadge value={d.severity} />
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Recent Flights */}
        <div className="bg-white rounded-xl border p-5">
          <div className="flex justify-between items-center mb-4">
            <h2 className="font-semibold">Flights Overview</h2>
            <Link to="/flights" className="text-sm text-blue-600 hover:underline">View all →</Link>
          </div>
          <div className="space-y-3 max-h-72 overflow-y-auto">
            {flights.slice(0, 8).map(f => (
              <Link key={f.flight_id} to={`/flights/${f.flight_id}`}
                className="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                <div>
                  <p className="text-sm font-medium">{f.flight_number}</p>
                  <p className="text-xs text-gray-500">{f.origin} → {f.destination} · {f.passenger_count} pax</p>
                </div>
                <StatusBadge value={f.status} />
              </Link>
            ))}
          </div>
        </div>

        {/* Recovery Plans */}
        <div className="bg-white rounded-xl border p-5 lg:col-span-2">
          <div className="flex justify-between items-center mb-4">
            <h2 className="font-semibold">Recovery Plans</h2>
            <Link to="/recovery" className="text-sm text-blue-600 hover:underline">Manage →</Link>
          </div>
          {plans.length === 0 ? (
            <p className="text-gray-400 text-sm">No recovery plans yet</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="text-left text-gray-500 border-b">
                  <th className="pb-2">Plan ID</th><th className="pb-2">Flight</th>
                  <th className="pb-2">PAX Affected</th><th className="pb-2">Rebooked</th>
                  <th className="pb-2">Cost</th><th className="pb-2">Status</th>
                </tr></thead>
                <tbody>
                  {plans.slice(0, 5).map(p => (
                    <tr key={p.plan_id} className="border-b last:border-0 hover:bg-gray-50">
                      <td className="py-2"><Link to={`/recovery/${p.plan_id}`} className="text-blue-600 hover:underline">{p.plan_id.substring(0,8)}…</Link></td>
                      <td className="py-2">{p.flight_id}</td>
                      <td className="py-2">{p.total_passengers_affected}</td>
                      <td className="py-2">{p.passengers_rebooked}</td>
                      <td className="py-2">${Number(p.estimated_cost).toLocaleString()}</td>
                      <td className="py-2"><StatusBadge value={p.status} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function LoadingSpinner() {
  return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600" /></div>;
}
function ErrorMsg({ msg }) {
  return <div className="bg-red-50 border border-red-200 text-red-700 rounded-lg p-4">{msg}</div>;
}
