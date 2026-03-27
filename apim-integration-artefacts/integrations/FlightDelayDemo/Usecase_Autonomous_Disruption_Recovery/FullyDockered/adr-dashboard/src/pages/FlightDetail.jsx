import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { disruption, crew, passenger, logistics } from '../api/client';
import StatusBadge from '../components/StatusBadge';

export default function FlightDetail() {
  const { id } = useParams();
  const [flight, setFlight]         = useState(null);
  const [assignments, setAssign]    = useState([]);
  const [bookings, setBookings]     = useState([]);
  const [alternatives, setAlts]     = useState([]);
  const [catering, setCatering]     = useState([]);
  const [groundTasks, setGround]    = useState([]);
  const [seatInfo, setSeatInfo]     = useState(null);
  const [crewReqs, setCrewReqs]     = useState(null);
  const [assessment, setAssessment] = useState(null);
  const [loading, setLoading]       = useState(true);
  const [delayForm, setDelayForm]   = useState({ delayMinutes: 120, reason: 'Mechanical issue' });
  const [delaying, setDelaying]     = useState(false);
  const [statusChanging, setStatusChanging] = useState(false);
  const [assessing, setAssessing]   = useState(false);

  const load = () => {
    setLoading(true);
    Promise.all([
      disruption.getFlight(id),
      crew.getAssignments(id).catch(() => []),
      passenger.getBookings(id).catch(() => []),
      passenger.getAlternatives(id).catch(() => []),
      logistics.getCatering(id).catch(() => []),
      logistics.getGroundTasks(id).catch(() => []),
      disruption.getFlightSeats(id).catch(() => null),
      disruption.getFlightCrewReqs(id).catch(() => null),
    ]).then(([f, a, b, al, c, g, s, cr]) => {
      setFlight(f); setAssign(a); setBookings(b); setAlts(al); setCatering(c); setGround(g);
      setSeatInfo(s); setCrewReqs(cr);
    }).finally(() => setLoading(false));
  };
  useEffect(load, [id]);

  const reportDelay = async () => {
    setDelaying(true);
    try {
      await disruption.reportDelay(id, { delayMinutes: Number(delayForm.delayMinutes), reason: delayForm.reason });
      load();
    } catch (e) { alert(e.message); }
    finally { setDelaying(false); }
  };

  const changeStatus = async (newStatus) => {
    setStatusChanging(true);
    try {
      await disruption.changeStatus(id, { new_status: newStatus });
      load();
    } catch (e) { alert(e.message); }
    finally { setStatusChanging(false); }
  };

  const runAssessment = async () => {
    setAssessing(true);
    try {
      const result = await disruption.assessFlight(id);
      setAssessment(result);
    } catch (e) { alert(e.message); }
    finally { setAssessing(false); }
  };

  if (loading) return <Spinner />;
  if (!flight) return <p className="text-gray-500">Flight not found.</p>;

  return (
    <div>
      <Link to="/flights" className="text-sm text-blue-600 hover:underline">← Back to Flights</Link>
      <div className="flex items-center gap-4 mt-2 mb-6">
        <h1 className="text-2xl font-bold">{flight.flight_number}</h1>
        <StatusBadge value={flight.status} />
      </div>

      {/* Flight Info */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <Info label="Route" value={`${flight.origin} → ${flight.destination}`} />
        <Info label="Aircraft" value={flight.aircraft_type} />
        <Info label="Gate" value={flight.gate || '—'} />
        <Info label="Passengers" value={flight.passenger_count} />
        <Info label="Scheduled Departure" value={flight.scheduled_departure} />
        <Info label="Scheduled Arrival" value={flight.scheduled_arrival} />
        <Info label="Actual Departure" value={flight.actual_departure || '—'} />
        <Info label="Actual Arrival" value={flight.actual_arrival || '—'} />
      </div>

      {/* Flight Status Controls */}
      {(flight.status === 'UNSCHEDULED' || flight.status === 'AVAILABLE') && (
        <div className="bg-blue-50 border border-blue-200 rounded-xl p-5 mb-6">
          <h2 className="font-semibold mb-2">📋 Flight Scheduling</h2>
          <p className="text-sm text-gray-600 mb-3">
            Current status: <StatusBadge value={flight.status} /> — Change to progress this flight through scheduling.
          </p>
          <div className="flex gap-2">
            {flight.status === 'UNSCHEDULED' && (
              <button onClick={() => changeStatus('AVAILABLE')} disabled={statusChanging}
                className="bg-green-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-green-700 disabled:opacity-50">
                Mark as AVAILABLE
              </button>
            )}
            {(flight.status === 'UNSCHEDULED' || flight.status === 'AVAILABLE') && (
              <button onClick={() => changeStatus('SCHEDULED')} disabled={statusChanging}
                className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50">
                Schedule Flight
              </button>
            )}
          </div>
        </div>
      )}

      {/* Seat Inventory */}
      {seatInfo && (() => {
        const classByKey = {};
        (seatInfo.classes || []).forEach(c => { classByKey[c.seat_class] = c; });
        const get = (cls, field) => classByKey[cls]?.[field] ?? 0;
        return (
          <div className="bg-white rounded-xl border p-5 mb-6">
            <h2 className="font-semibold mb-3">Seat Inventory</h2>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <SeatCard label="First" total={get('FIRST','total_seats')} booked={get('FIRST','booked_seats')} available={get('FIRST','available_seats')} color="bg-violet-50" />
              <SeatCard label="Business" total={get('BUSINESS','total_seats')} booked={get('BUSINESS','booked_seats')} available={get('BUSINESS','available_seats')} color="bg-blue-50" />
              <SeatCard label="Premium Eco" total={get('PREMIUM_ECONOMY','total_seats')} booked={get('PREMIUM_ECONOMY','booked_seats')} available={get('PREMIUM_ECONOMY','available_seats')} color="bg-cyan-50" />
              <SeatCard label="Economy" total={get('ECONOMY','total_seats')} booked={get('ECONOMY','booked_seats')} available={get('ECONOMY','available_seats')} color="bg-green-50" />
            </div>
            <div className="mt-3 flex items-center gap-4 text-sm text-gray-600">
              <span>Total: <strong>{seatInfo.total_capacity}</strong></span>
              <span>Booked: <strong>{seatInfo.total_booked}</strong></span>
              <span>Available: <strong className={seatInfo.total_available > 0 ? 'text-green-600' : 'text-red-600'}>{seatInfo.total_available}</strong></span>
            </div>
          </div>
        );
      })()}

      {/* Crew Requirements */}
      {crewReqs && (() => {
        const roles = (crewReqs.requirements || []).map(r => ({
          role: r.role,
          required: r.required_count,
          assigned: r.assigned_count,
          gap: Math.max(0, r.required_count - r.assigned_count),
        }));
        const totalGaps = roles.reduce((s, r) => s + r.gap, 0);
        return (
          <div className="bg-white rounded-xl border p-5 mb-6">
            <h2 className="font-semibold mb-3">Crew Requirements vs Assigned</h2>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {roles.map(r => (
                <div key={r.role} className="border rounded-lg p-3">
                  <p className="text-xs text-gray-500">{r.role}</p>
                  <p className="text-lg font-bold">{r.assigned} / {r.required}</p>
                  <div className="w-full bg-gray-200 rounded-full h-2 mt-1">
                    <div className={`h-2 rounded-full ${r.assigned >= r.required ? 'bg-green-500' : 'bg-orange-500'}`}
                      style={{ width: `${Math.min(100, r.required > 0 ? (r.assigned / r.required) * 100 : 0)}%` }} />
                  </div>
                  <p className="text-xs mt-1">{r.gap > 0 ? <span className="text-red-500">Gap: {r.gap}</span> : <span className="text-green-500">Filled</span>}</p>
                </div>
              ))}
            </div>
            {totalGaps > 0 && (
              <p className="text-sm text-red-500 mt-2 font-medium">Warning: {totalGaps} crew position(s) unfilled</p>
            )}
          </div>
        );
      })()}

      {/* Disruption Assessment */}
      <div className="bg-indigo-50 border border-indigo-200 rounded-xl p-5 mb-6">
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-semibold">🧠 AI-Ready Disruption Assessment</h2>
          <button onClick={runAssessment} disabled={assessing}
            className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-indigo-700 disabled:opacity-50">
            {assessing ? 'Assessing…' : 'Run Assessment'}
          </button>
        </div>
        {assessment && (
          <div className="bg-white rounded-lg p-4 space-y-2 text-sm">
            <div className="flex gap-2 items-center">
              <span className="font-medium">Severity:</span>
              <StatusBadge value={assessment.severity} />
            </div>
            <p><strong>Passengers:</strong> {assessment.passengers_affected} affected</p>
            <p><strong>Seat Availability:</strong> {assessment.total_alternative_seats} seats across alternatives</p>
            <p><strong>Crew Staffing:</strong> {assessment.crew_gaps} gap(s)</p>
            <div>
              <strong>Recommendations:</strong>
              <ul className="list-disc ml-4 mt-1 space-y-0.5">
                {(assessment.recommendations || []).map((r, i) => <li key={i}>{r}</li>)}
              </ul>
            </div>
          </div>
        )}
      </div>

      {/* Report Delay */}
      {flight.status !== 'DELAYED' && (
        <div className="bg-yellow-50 border border-yellow-200 rounded-xl p-5 mb-6">
          <h2 className="font-semibold mb-3">⚠️ Report Delay</h2>
          <div className="flex gap-3 items-end">
            <div>
              <label className="block text-xs text-gray-500 mb-1">Delay (min)</label>
              <input type="number" value={delayForm.delayMinutes}
                onChange={e => setDelayForm({ ...delayForm, delayMinutes: e.target.value })}
                className="border rounded-lg px-3 py-2 text-sm w-28" />
            </div>
            <div className="flex-1">
              <label className="block text-xs text-gray-500 mb-1">Reason</label>
              <input type="text" value={delayForm.reason}
                onChange={e => setDelayForm({ ...delayForm, reason: e.target.value })}
                className="border rounded-lg px-3 py-2 text-sm w-full" />
            </div>
            <button onClick={reportDelay} disabled={delaying}
              className="bg-yellow-600 text-white px-5 py-2 rounded-lg text-sm hover:bg-yellow-700 disabled:opacity-50">
              {delaying ? 'Reporting…' : 'Report Delay'}
            </button>
          </div>
        </div>
      )}

      <div className="grid lg:grid-cols-2 gap-6">
        {/* Crew Assignments */}
        <Section title="👨‍✈️ Crew Assignments" count={assignments.length}>
          {assignments.map(a => (
            <div key={a.assignment_id} className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm font-medium">{a.crew_id}</p>
                <p className="text-xs text-gray-500">{a.role}</p>
              </div>
              <StatusBadge value={a.status} />
            </div>
          ))}
        </Section>

        {/* Passengers */}
        <Section title="🧳 Passengers" count={bookings.length}
          action={<Link to={`/passengers/${id}`} className="text-xs text-blue-600 hover:underline">View all →</Link>}>
          {bookings.slice(0, 5).map(b => (
            <div key={b.booking_id} className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm font-medium">{b.first_name} {b.last_name}</p>
                <p className="text-xs text-gray-500">Seat {b.seat_number || '—'} · {b.booking_class}</p>
              </div>
              <StatusBadge value={b.loyalty_tier} />
            </div>
          ))}
          {bookings.length > 5 && <p className="text-xs text-gray-400 text-center mt-2">+ {bookings.length - 5} more</p>}
        </Section>

        {/* Alternative Flights */}
        <Section title="🔀 Alternative Flights" count={alternatives.length}>
          {alternatives.map(a => (
            <div key={a.flight_id} className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm font-medium">{a.flight_number}</p>
                <p className="text-xs text-gray-500">{a.origin} → {a.destination} · {a.available_seats} seats</p>
              </div>
              <StatusBadge value={a.status} />
            </div>
          ))}
        </Section>

        {/* Catering */}
        <Section title="🍽️ Catering Orders" count={catering.length}>
          {catering.map(c => (
            <div key={c.order_id} className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm font-medium">{c.meal_count} meals</p>
                <p className="text-xs text-gray-500">Gate: {c.delivery_gate || '—'} · {c.special_meals || 'Standard'}</p>
              </div>
              <StatusBadge value={c.status} />
            </div>
          ))}
        </Section>

        {/* Ground Tasks */}
        <Section title="🏗️ Ground Tasks" count={groundTasks.length}>
          {groundTasks.map(t => (
            <div key={t.task_id} className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
              <div>
                <p className="text-sm font-medium">{t.task_type}</p>
                <p className="text-xs text-gray-500">{t.assigned_team || 'Unassigned'} · Gate {t.gate || '—'}</p>
              </div>
              <StatusBadge value={t.status} />
            </div>
          ))}
        </Section>
      </div>
    </div>
  );
}

function Info({ label, value }) {
  return (
    <div className="bg-white rounded-xl border p-3">
      <p className="text-xs text-gray-500">{label}</p>
      <p className="text-sm font-medium mt-1">{value}</p>
    </div>
  );
}

function Section({ title, count, action, children }) {
  return (
    <div className="bg-white rounded-xl border p-5">
      <div className="flex justify-between items-center mb-3">
        <h2 className="font-semibold text-sm">{title} <span className="text-gray-400">({count})</span></h2>
        {action}
      </div>
      <div className="space-y-2 max-h-64 overflow-y-auto">
        {count === 0 ? <p className="text-gray-400 text-xs">None</p> : children}
      </div>
    </div>
  );
}

function SeatCard({ label, total, booked, available, color }) {
  const pct = total > 0 ? ((booked / total) * 100).toFixed(0) : 0;
  return (
    <div className={`rounded-lg p-3 ${color}`}>
      <p className="text-xs font-medium text-gray-600">{label}</p>
      <p className="text-xl font-bold">{available}<span className="text-sm font-normal text-gray-500"> / {total}</span></p>
      <div className="w-full bg-gray-200 rounded-full h-2 mt-1">
        <div className="bg-blue-600 h-2 rounded-full" style={{ width: `${pct}%` }} />
      </div>
      <p className="text-xs text-gray-500 mt-1">{booked} booked ({pct}%)</p>
    </div>
  );
}

function Spinner() {
  return <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
}
