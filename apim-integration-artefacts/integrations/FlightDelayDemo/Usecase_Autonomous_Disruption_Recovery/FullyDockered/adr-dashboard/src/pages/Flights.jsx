import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { disruption } from '../api/client';
import StatusBadge from '../components/StatusBadge';

export default function Flights() {
  const [flights, setFlights] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showAdd, setShowAdd] = useState(false);

  const load = () => {
    setLoading(true);
    disruption.getFlights().then(setFlights).finally(() => setLoading(false));
  };
  useEffect(load, []);

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Flights</h1>
        <button onClick={() => setShowAdd(!showAdd)}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 transition-colors">
          {showAdd ? 'Cancel' : '+ Add Flight'}
        </button>
      </div>

      {showAdd && <AddFlightForm onCreated={() => { setShowAdd(false); load(); }} />}

      {loading ? <Spinner /> : (
        <div className="bg-white rounded-xl border overflow-hidden">
          <table className="w-full text-sm">
            <thead><tr className="bg-gray-50 text-left text-gray-500">
              <th className="px-4 py-3">Flight #</th><th className="px-4 py-3">Route</th>
              <th className="px-4 py-3">Departure</th><th className="px-4 py-3">Aircraft</th>
              <th className="px-4 py-3">Gate</th><th className="px-4 py-3">PAX</th>
              <th className="px-4 py-3">Seats</th>
              <th className="px-4 py-3">Status</th><th className="px-4 py-3"></th>
            </tr></thead>
            <tbody>
              {flights.map(f => {
                const totalSeats = (f.seats_first || 0) + (f.seats_business || 0) + (f.seats_premium_economy || 0) + (f.seats_economy || 0);
                return (
                  <tr key={f.flight_id} className="border-t hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium">{f.flight_number}</td>
                    <td className="px-4 py-3">{f.origin} → {f.destination}</td>
                    <td className="px-4 py-3 text-xs text-gray-500">{f.scheduled_departure}</td>
                    <td className="px-4 py-3">{f.aircraft_type}</td>
                    <td className="px-4 py-3">{f.gate || '—'}</td>
                    <td className="px-4 py-3">{f.passenger_count}</td>
                    <td className="px-4 py-3 text-xs text-gray-500">
                      {totalSeats > 0 ? `${totalSeats} total` : '—'}
                    </td>
                    <td className="px-4 py-3"><StatusBadge value={f.status} /></td>
                    <td className="px-4 py-3">
                      <Link to={`/flights/${f.flight_id}`} className="text-blue-600 hover:underline text-xs">Details →</Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {flights.length === 0 && <p className="text-center py-8 text-gray-400">No flights registered</p>}
        </div>
      )}
    </div>
  );
}

function AddFlightForm({ onCreated }) {
  const [form, setForm] = useState({
    airline: '', flight_number: '', origin: '', destination: '',
    scheduled_departure: '', scheduled_arrival: '', aircraft_type: '', gate: '', passenger_count: 0,
    status: 'SCHEDULED',
    seats_first: 0, seats_business: 0, seats_premium_economy: 0, seats_economy: 0,
    required_captains: 1, required_first_officers: 1, required_cabin_crew_leads: 1, required_cabin_crew: 4,
  });
  const [saving, setSaving] = useState(false);

  const submit = async (e) => {
    e.preventDefault(); setSaving(true);
    try {
      await disruption.createFlight({
        ...form,
        passenger_count: Number(form.passenger_count),
        seats_first: Number(form.seats_first),
        seats_business: Number(form.seats_business),
        seats_premium_economy: Number(form.seats_premium_economy),
        seats_economy: Number(form.seats_economy),
        required_captains: Number(form.required_captains),
        required_first_officers: Number(form.required_first_officers),
        required_cabin_crew_leads: Number(form.required_cabin_crew_leads),
        required_cabin_crew: Number(form.required_cabin_crew),
      });
      onCreated();
    } catch { alert('Failed to create flight'); }
    finally { setSaving(false); }
  };

  const field = (name, label, type = 'text') => (
    <div>
      <label className="block text-xs text-gray-500 mb-1">{label}</label>
      <input type={type} value={form[name]}
        onChange={e => setForm({ ...form, [name]: e.target.value })}
        className="w-full border rounded-lg px-3 py-2 text-sm" required />
    </div>
  );

  return (
    <form onSubmit={submit} className="bg-white rounded-xl border p-5 mb-6 space-y-4">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {field('airline', 'Airline')}
        {field('flight_number', 'Flight Number')}
        {field('origin', 'Origin (IATA)')}
        {field('destination', 'Destination (IATA)')}
        {field('scheduled_departure', 'Scheduled Departure', 'datetime-local')}
        {field('scheduled_arrival', 'Scheduled Arrival', 'datetime-local')}
        {field('aircraft_type', 'Aircraft Type')}
        {field('gate', 'Gate')}
        {field('passenger_count', 'Passenger Count', 'number')}
        <div>
          <label className="block text-xs text-gray-500 mb-1">Initial Status</label>
          <select value={form.status} onChange={e => setForm({...form, status: e.target.value})}
            className="w-full border rounded-lg px-3 py-2 text-sm">
            <option value="SCHEDULED">SCHEDULED</option>
            <option value="UNSCHEDULED">UNSCHEDULED</option>
            <option value="AVAILABLE">AVAILABLE</option>
          </select>
        </div>
      </div>
      <div>
        <p className="text-xs font-medium text-gray-500 mb-2">Seat Capacity by Class</p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {field('seats_first', 'First Class', 'number')}
          {field('seats_business', 'Business', 'number')}
          {field('seats_premium_economy', 'Premium Economy', 'number')}
          {field('seats_economy', 'Economy', 'number')}
        </div>
      </div>
      <div>
        <p className="text-xs font-medium text-gray-500 mb-2">Crew Requirements</p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {field('required_captains', 'Captains', 'number')}
          {field('required_first_officers', 'First Officers', 'number')}
          {field('required_cabin_crew_leads', 'Cabin Crew Leads', 'number')}
          {field('required_cabin_crew', 'Cabin Crew', 'number')}
        </div>
      </div>
      <div className="flex justify-end">
        <button type="submit" disabled={saving}
          className="bg-green-600 text-white px-6 py-2 rounded-lg text-sm hover:bg-green-700 disabled:opacity-50">
          {saving ? 'Creating…' : 'Create Flight'}
        </button>
      </div>
    </form>
  );
}

function Spinner() {
  return <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
}
