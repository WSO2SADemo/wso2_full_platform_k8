import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { disruption } from '../api/client';
import StatusBadge from '../components/StatusBadge';

export default function Disruptions() {
  const [delays, setDelays]   = useState([]);
  const [loading, setLoading] = useState(true);

  const load = () => {
    setLoading(true);
    disruption.getDelays().then(setDelays).finally(() => setLoading(false));
  };
  useEffect(load, []);

  const resolve = async (id) => {
    if (!confirm('Resolve this disruption?')) return;
    await disruption.resolveDisruption(id);
    load();
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Active Disruptions</h1>
        <button onClick={load} className="text-sm text-blue-600 hover:underline">↻ Refresh</button>
      </div>

      {delays.length === 0 ? (
        <div className="bg-green-50 border border-green-200 rounded-xl p-8 text-center">
          <p className="text-green-700 font-medium">✅ No active disruptions</p>
          <p className="text-green-600 text-sm mt-1">All flights are operating normally.</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl border overflow-hidden">
          <table className="w-full text-sm">
            <thead><tr className="bg-gray-50 text-left text-gray-500">
              <th className="px-4 py-3">Disruption ID</th>
              <th className="px-4 py-3">Flight</th>
              <th className="px-4 py-3">Type</th>
              <th className="px-4 py-3">Delay</th>
              <th className="px-4 py-3">Reason</th>
              <th className="px-4 py-3">Severity</th>
              <th className="px-4 py-3">Status</th>
              <th className="px-4 py-3">Detected</th>
              <th className="px-4 py-3"></th>
            </tr></thead>
            <tbody>
              {delays.map(d => (
                <tr key={d.disruption_id} className="border-t hover:bg-gray-50">
                  <td className="px-4 py-3 font-mono text-xs">{d.disruption_id.substring(0, 8)}…</td>
                  <td className="px-4 py-3">
                    <Link to={`/flights/${d.flight_id}`} className="text-blue-600 hover:underline">{d.flight_id}</Link>
                  </td>
                  <td className="px-4 py-3">{d.disruption_type}</td>
                  <td className="px-4 py-3 font-medium">{d.delay_minutes} min</td>
                  <td className="px-4 py-3 text-gray-600">{d.reason || '—'}</td>
                  <td className="px-4 py-3"><StatusBadge value={d.severity} /></td>
                  <td className="px-4 py-3"><StatusBadge value={d.status} /></td>
                  <td className="px-4 py-3 text-xs text-gray-500">{d.detected_at}</td>
                  <td className="px-4 py-3 flex gap-2">
                    <Link to={`/recovery`} state={{ flightId: d.flight_id, disruptionType: d.reason || d.disruption_type }}
                      className="text-xs bg-purple-600 text-white px-3 py-1 rounded hover:bg-purple-700">
                      Recover
                    </Link>
                    <button onClick={() => resolve(d.disruption_id)}
                      className="text-xs bg-green-600 text-white px-3 py-1 rounded hover:bg-green-700">
                      Resolve
                    </button>
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

function Spinner() {
  return <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
}
