import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { passenger } from '../api/client';
import StatusBadge from '../components/StatusBadge';

export default function Passengers() {
  const { flightId }            = useParams();
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [notifyMsg, setNotifyMsg] = useState('');
  const [historyPassenger, setHistoryPassenger] = useState(null);
  const [history, setHistory]   = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);

  const load = () => {
    setLoading(true);
    passenger.getBookings(flightId).then(setBookings).finally(() => setLoading(false));
  };
  useEffect(load, [flightId]);

  const notifyAll = async () => {
    const msg = prompt('Notification message:', `Dear passenger, your flight has been updated. Please check the departure board.`);
    if (!msg) return;
    let sent = 0;
    for (const b of bookings) {
      try {
        await passenger.notify({ passenger_id: b.passenger_id, notification_type: 'EMAIL', message: msg });
        sent++;
      } catch { /* skip */ }
    }
    setNotifyMsg(`Notified ${sent}/${bookings.length} passengers`);
    setTimeout(() => setNotifyMsg(''), 4000);
  };

  const viewHistory = async (pax) => {
    if (historyPassenger?.passenger_id === pax.passenger_id) {
      setHistoryPassenger(null); setHistory([]); return;
    }
    setHistoryPassenger(pax); setHistoryLoading(true);
    try {
      const h = await passenger.getHistory(pax.passenger_id);
      setHistory(h);
    } catch { setHistory([]); }
    finally { setHistoryLoading(false); }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      <Link to={`/flights/${flightId}`} className="text-sm text-blue-600 hover:underline">← Back to Flight</Link>
      <div className="flex justify-between items-center mt-2 mb-6">
        <h1 className="text-2xl font-bold">Passengers — {flightId}</h1>
        <button onClick={notifyAll}
          className="bg-green-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-green-700">
          Notify All
        </button>
      </div>

      {notifyMsg && <div className="bg-green-50 border border-green-200 text-green-700 rounded-lg p-3 mb-4 text-sm">{notifyMsg}</div>}

      {/* Flight History Panel */}
      {historyPassenger && (
        <div className="bg-indigo-50 border border-indigo-200 rounded-xl p-5 mb-4">
          <div className="flex justify-between items-center mb-3">
            <h2 className="font-semibold text-sm">
              Flight History: {historyPassenger.first_name} {historyPassenger.last_name}
            </h2>
            <button onClick={() => { setHistoryPassenger(null); setHistory([]); }}
              className="text-gray-400 hover:text-gray-600 text-sm">Close</button>
          </div>
          {historyLoading ? <p className="text-sm text-gray-500">Loading...</p> : history.length === 0 ? (
            <p className="text-sm text-gray-400">No flight history recorded.</p>
          ) : (
            <div className="space-y-2 max-h-48 overflow-y-auto">
              {history.map(h => (
                <div key={h.id} className="flex items-center gap-3 p-2 bg-white rounded-lg text-sm">
                  <StatusBadge value={h.action} />
                  <div className="flex-1">
                    <p>Flight <strong>{h.flight_id}</strong> · {h.seat_class || '—'}</p>
                    <p className="text-xs text-gray-500">{h.notes}</p>
                  </div>
                  <p className="text-xs text-gray-400">{h.created_at}</p>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {bookings.length === 0 ? (
        <p className="text-gray-400">No passengers on this flight.</p>
      ) : (
        <div className="bg-white rounded-xl border overflow-hidden">
          <table className="w-full text-sm">
            <thead><tr className="bg-gray-50 text-left text-gray-500">
              <th className="px-4 py-3">Name</th><th className="px-4 py-3">Seat</th>
              <th className="px-4 py-3">Class</th><th className="px-4 py-3">Loyalty</th>
              <th className="px-4 py-3">Points</th><th className="px-4 py-3">Special Needs</th>
              <th className="px-4 py-3">Status</th><th className="px-4 py-3"></th>
            </tr></thead>
            <tbody>
              {bookings.map(b => (
                <tr key={b.booking_id} className={`border-t hover:bg-gray-50 ${historyPassenger?.passenger_id === b.passenger_id ? 'bg-indigo-50' : ''}`}>
                  <td className="px-4 py-3 font-medium">{b.first_name} {b.last_name}</td>
                  <td className="px-4 py-3">{b.seat_number || '—'}</td>
                  <td className="px-4 py-3">{b.booking_class}</td>
                  <td className="px-4 py-3"><StatusBadge value={b.loyalty_tier} /></td>
                  <td className="px-4 py-3">{(b.loyalty_points || 0).toLocaleString()}</td>
                  <td className="px-4 py-3 text-xs text-gray-500">{b.special_needs || '—'}</td>
                  <td className="px-4 py-3"><StatusBadge value={b.status} /></td>
                  <td className="px-4 py-3">
                    <button onClick={() => viewHistory(b)}
                      className="text-xs bg-indigo-600 text-white px-3 py-1 rounded hover:bg-indigo-700">
                      History
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
