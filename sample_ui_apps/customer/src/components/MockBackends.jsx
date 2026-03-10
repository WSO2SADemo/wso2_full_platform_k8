import { useState, useEffect } from 'react';
import { CFG } from '../config';
import { authHeaders } from '../auth';
import { apiFetch, uuidv4 } from '../utils';
import { ResponseBox } from './ResponseBox';

export function MockBackends() {
  const [fund11State, setFund11State] = useState(null);
  const [statusLoading, setStatusLoading] = useState(false);
  const [toggleLoading, setToggleLoading] = useState(false);

  const [directForm, setDirectForm] = useState({
    messageId: uuidv4(),
    personId: 'SE199001011234',
    notificationType: 'STATUS_CHANGE',
    retryCount: 0,
    data: JSON.stringify({ amount: 15000, currency: 'SEK' }, null, 2),
  });
  const [directResult, setDirectResult] = useState(null);
  const [directLoading, setDirectLoading] = useState(false);

  useEffect(() => { getFund11Status(); }, []);

  const setField = (k) => (e) => setDirectForm((f) => ({ ...f, [k]: e.target.value }));

  async function getFund11Status() {
    setStatusLoading(true);
    try {
      const r = await apiFetch(`${CFG.mockBase}/notifications/admin/status`, { headers: authHeaders() });
      setFund11State(r.body);
    } catch (e) {
      setFund11State({ error: e.message });
    }
    setStatusLoading(false);
  }

  async function toggleFund11() {
    setToggleLoading(true);
    try {
      await apiFetch(`${CFG.mockBase}/notifications/admin/toggle`, {
        method: 'POST',
        headers: authHeaders(),
      });
      await getFund11Status();
    } catch (e) {
      alert('Toggle error: ' + e.message);
    }
    setToggleLoading(false);
  }

  async function sendDirect() {
    let data;
    try { data = JSON.parse(directForm.data); }
    catch { alert('Invalid JSON in Data field'); return; }

    setDirectLoading(true);
    setDirectResult(null);
    const now = new Date().toISOString();
    try {
      const r = await apiFetch(`${CFG.mockBase}/notifications`, {
        method: 'POST',
        headers: authHeaders({ 'Content-Type': 'application/json' }),
        body: JSON.stringify({
          messageId: directForm.messageId || uuidv4(),
          personId: directForm.personId,
          notificationType: directForm.notificationType,
          data,
          retryCount: Number(directForm.retryCount),
          createdAt: now,
          lastAttemptAt: now,
        }),
      });
      setDirectResult(r);
      setDirectForm((f) => ({ ...f, messageId: uuidv4() }));
    } catch (e) {
      setDirectResult({ status: 0, body: e.message });
    }
    setDirectLoading(false);
  }

  const isOnline = fund11State?.available;

  return (
    <div>
      <div className="card">
        <h2>Fund 11 — Notification Receiver</h2>
        <p className="desc">
          Toggle Fund 11 offline to simulate a service window. While offline the Store &amp; Forward integration
          will queue retries and eventually move messages to the DLQ.
        </p>

        <div className="toggle-wrap">
          {statusLoading
            ? <span className="spinner" />
            : fund11State
              ? <span className={`fund11-badge ${isOnline ? 'badge-online' : 'badge-offline'}`}>
                  {fund11State.state ?? (fund11State.error ? '⚠ Error' : '…')}
                </span>
              : null
          }
          <button className="btn btn-outline btn-sm" onClick={getFund11Status} disabled={statusLoading}>
            Refresh
          </button>
          <button className="btn btn-orange btn-sm" onClick={toggleFund11} disabled={toggleLoading}>
            {toggleLoading ? <span className="spinner" /> : null}
            {isOnline ? 'Take Offline' : 'Bring Online'}
          </button>
        </div>

        {fund11State?.error && (
          <p className="text-error" style={{ marginTop: 10 }}>❌ {fund11State.error}</p>
        )}
      </div>

      <div className="card">
        <h3>Send Direct Notification to Fund 11</h3>
        <p className="desc" style={{ marginBottom: 14 }}>
          POST directly to the mock notification receiver (bypasses the RabbitMQ queue).
          Useful for testing the 503 service-window behaviour.
        </p>

        <div className="form-grid">
          <div className="field span2">
            <label>Message ID (UUID)</label>
            <input value={directForm.messageId} onChange={setField('messageId')} placeholder="auto-generated" />
          </div>
          <div className="field">
            <label>Person ID</label>
            <input value={directForm.personId} onChange={setField('personId')} />
          </div>
          <div className="field">
            <label>Notification Type</label>
            <select value={directForm.notificationType} onChange={setField('notificationType')}>
              <option value="STATUS_CHANGE">STATUS_CHANGE</option>
              <option value="BENEFIT_UPDATE">BENEFIT_UPDATE</option>
              <option value="REGISTRATION">REGISTRATION</option>
            </select>
          </div>
          <div className="field">
            <label>Retry Count</label>
            <input type="number" value={directForm.retryCount} onChange={setField('retryCount')} min={0} max={3} />
          </div>
          <div className="field span2">
            <label>Data (JSON)</label>
            <textarea rows={3} value={directForm.data} onChange={setField('data')} />
          </div>
        </div>

        <div className="actions">
          <button className="btn btn-orange" onClick={sendDirect} disabled={directLoading}>
            {directLoading ? <span className="spinner" /> : null} Send Direct
          </button>
        </div>

        {directResult && <ResponseBox status={directResult.status} body={directResult.body} />}
      </div>
    </div>
  );
}
