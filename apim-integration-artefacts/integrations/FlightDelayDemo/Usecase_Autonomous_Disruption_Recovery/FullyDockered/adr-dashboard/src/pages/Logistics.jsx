import { useEffect, useState } from 'react';
import { disruption, logistics } from '../api/client';
import StatusBadge from '../components/StatusBadge';

export default function Logistics() {
  const [flights, setFlights]       = useState([]);
  const [resources, setResources]   = useState(null);
  const [airport, setAirport]       = useState('');
  const [gates, setGates]           = useState([]);
  const [loading, setLoading]       = useState(true);

  useEffect(() => {
    disruption.getFlights().then(f => {
      setFlights(f);
      // Auto-detect the first airport
      if (f.length > 0 && f[0].origin) {
        setAirport(f[0].origin);
      }
    }).finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!airport) return;
    Promise.all([
      logistics.getResources(airport).catch(() => null),
      logistics.getAvailableGates(airport).catch(() => []),
    ]).then(([r, g]) => { setResources(r); setGates(g); });
  }, [airport]);

  const airports = [...new Set(flights.flatMap(f => [f.origin, f.destination]).filter(Boolean))];

  const assignGate = async (gateId, flightId) => {
    if (!flightId) { alert('Select a flight'); return; }
    try {
      const result = await logistics.assignGate({ flight_id: flightId, gate_id: gateId });
      alert(result.message);
      // Refresh
      if (airport) {
        const [r, g] = await Promise.all([
          logistics.getResources(airport).catch(() => null),
          logistics.getAvailableGates(airport).catch(() => []),
        ]);
        setResources(r); setGates(g);
      }
    } catch (e) { alert(e.message); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Logistics & Ground Operations</h1>

      {/* Airport selector */}
      <div className="flex items-center gap-3 mb-6">
        <label className="text-sm font-medium">Airport:</label>
        <select value={airport} onChange={e => setAirport(e.target.value)}
          className="border rounded-lg px-3 py-2 text-sm">
          <option value="">Select…</option>
          {airports.map(a => <option key={a} value={a}>{a}</option>)}
        </select>
      </div>

      {resources && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <Stat label="Total Gates" value={resources.total_gates} icon="🚪" />
          <Stat label="Available Gates" value={resources.available_gates} icon="✅" />
          <Stat label="Active Catering" value={resources.active_catering_orders} icon="🍽️" />
          <Stat label="Pending Ground Tasks" value={resources.pending_ground_tasks} icon="🔧" />
        </div>
      )}

      {/* Available Gates */}
      {gates.length > 0 && (
        <div className="bg-white rounded-xl border p-5 mb-6">
          <h2 className="font-semibold mb-3">Available Gates at {airport}</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            {gates.map(g => (
              <div key={g.gate_id} className="border rounded-lg p-3">
                <p className="font-medium text-sm">{g.gate_id}</p>
                <p className="text-xs text-gray-500">Terminal {g.terminal} · {g.gate_type}</p>
                <div className="mt-2">
                  <select id={`flight-${g.gate_id}`} className="border rounded px-2 py-1 text-xs w-full mb-1">
                    <option value="">Assign to flight…</option>
                    {flights.filter(f => f.status !== 'CANCELLED').map(f =>
                      <option key={f.flight_id} value={f.flight_id}>{f.flight_number}</option>
                    )}
                  </select>
                  <button onClick={() => assignGate(g.gate_id, document.getElementById(`flight-${g.gate_id}`).value)}
                    className="bg-blue-600 text-white px-3 py-1 rounded text-xs w-full hover:bg-blue-700">
                    Assign
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Flight-specific logistics */}
      <div className="bg-white rounded-xl border p-5">
        <h2 className="font-semibold mb-3">Flight Logistics Overview</h2>
        <div className="space-y-2">
          {flights.map(f => (
            <FlightLogisticsRow key={f.flight_id} flight={f} />
          ))}
        </div>
      </div>
    </div>
  );
}

function FlightLogisticsRow({ flight }) {
  const [expanded, setExpanded] = useState(false);
  const [catering, setCatering] = useState([]);
  const [tasks, setTasks]       = useState([]);

  const toggle = async () => {
    if (!expanded) {
      const [c, t] = await Promise.all([
        logistics.getCatering(flight.flight_id).catch(() => []),
        logistics.getGroundTasks(flight.flight_id).catch(() => []),
      ]);
      setCatering(c); setTasks(t);
    }
    setExpanded(!expanded);
  };

  return (
    <div className="border rounded-lg">
      <button onClick={toggle}
        className="w-full flex items-center justify-between p-3 hover:bg-gray-50 text-left">
        <div className="flex items-center gap-3">
          <span className="text-sm font-medium">{flight.flight_number}</span>
          <span className="text-xs text-gray-500">{flight.origin} → {flight.destination}</span>
          <StatusBadge value={flight.status} />
        </div>
        <span className="text-gray-400">{expanded ? '▲' : '▼'}</span>
      </button>
      {expanded && (
        <div className="px-3 pb-3 grid md:grid-cols-2 gap-3">
          <div>
            <p className="text-xs font-medium text-gray-500 mb-1">Catering ({catering.length})</p>
            {catering.length === 0 ? <p className="text-xs text-gray-400">None</p> : catering.map(c => (
              <div key={c.order_id} className="text-xs bg-gray-50 rounded p-2 mb-1">
                {c.meal_count} meals · Gate {c.delivery_gate || '—'} · <StatusBadge value={c.status} />
              </div>
            ))}
          </div>
          <div>
            <p className="text-xs font-medium text-gray-500 mb-1">Ground Tasks ({tasks.length})</p>
            {tasks.length === 0 ? <p className="text-xs text-gray-400">None</p> : tasks.map(t => (
              <div key={t.task_id} className="text-xs bg-gray-50 rounded p-2 mb-1">
                {t.task_type} · {t.assigned_team || 'Unassigned'} · <StatusBadge value={t.status} />
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function Stat({ label, value, icon }) {
  return (
    <div className="bg-white border rounded-xl p-4">
      <div className="flex items-center gap-2 mb-1">
        <span>{icon}</span>
        <span className="text-xs text-gray-500">{label}</span>
      </div>
      <p className="text-2xl font-bold">{value}</p>
    </div>
  );
}

function Spinner() {
  return <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
}
