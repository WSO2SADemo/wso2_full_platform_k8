import { useState, useEffect } from 'react';
import { CFG } from '../config';
import { authHeaders } from '../auth';
import { apiFetch } from '../utils';
import { ResponseBox } from './ResponseBox';

export function StoreAndForward() {
  // ── Fund 11 state ──
  const [fund11State, setFund11State] = useState(null);
  const [statusLoading, setStatusLoading] = useState(false);
  const [toggleLoading, setToggleLoading] = useState(false);

  // ── Send notification state ──
  const [form, setForm] = useState({
    personId: 'SE199001011234',
    notificationType: 'STATUS_CHANGE',
    data: JSON.stringify({ benefitAmount: 15000, currency: 'SEK', note: 'Monthly update' }, null, 2),
  });
  const [sendResult, setSendResult] = useState(null);
  const [sendLoading, setSendLoading] = useState(false);

  // ── DLQ state ──
  const [dlq, setDlq] = useState(null);
  const [dlqLoading, setDlqLoading] = useState(false);
  const [retryLoading, setRetryLoading] = useState(false);
  const [retryResult, setRetryResult] = useState(null);

  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));

  useEffect(() => {
    getFund11Status();
    loadDlq();
  }, []);

  // ── Fund 11 ──
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

  // ── Send via queue ──
  async function sendNotification() {
    let data;
    try { data = JSON.parse(form.data); }
    catch { alert('Invalid JSON in Data Payload'); return; }

    setSendLoading(true);
    setSendResult(null);
    try {
      const r = await apiFetch(`${CFG.sfBase}/notifications/send`, {
        method: 'POST',
        headers: authHeaders({ 'Content-Type': 'application/json' }),
        body: JSON.stringify({ personId: form.personId, notificationType: form.notificationType, data }),
      });
      setSendResult(r);
      setTimeout(loadDlq, 1000);
    } catch (e) {
      setSendResult({ status: 0, body: e.message });
    }
    setSendLoading(false);
  }

  // ── DLQ ──
  async function loadDlq() {
    setDlqLoading(true);
    try {
      const r = await apiFetch(`${CFG.sfBase}/notifications/dlq-status`, { headers: authHeaders() });
      setDlq(r.body);
    } catch (e) {
      setDlq({ error: e.message });
    }
    setDlqLoading(false);
  }

  async function retryDlq() {
    setRetryLoading(true);
    setRetryResult(null);
    try {
      const r = await apiFetch(`${CFG.sfBase}/notifications/retry`, {
        method: 'POST',
        headers: authHeaders(),
      });
      setRetryResult(r);
      setTimeout(loadDlq, 600);
    } catch (e) {
      setRetryResult({ status: 0, body: e.message });
    }
    setRetryLoading(false);
  }

  const isOnline = fund11State?.available;

  return (
    <div>
      {/* ── Send via Queue ── */}
      <div className="card">
        <h3>Send Notification via Queue</h3>
        <div className="form-grid">
          <div className="field">
            <label>Person ID</label>
            <input value={form.personId} onChange={set('personId')} />
          </div>
          <div className="field">
            <label>Notification Type</label>
            <select value={form.notificationType} onChange={set('notificationType')}>
              <option value="STATUS_CHANGE">STATUS_CHANGE</option>
              <option value="BENEFIT_UPDATE">BENEFIT_UPDATE</option>
              <option value="REGISTRATION">REGISTRATION</option>
            </select>
          </div>
          <div className="field span2">
            <label>Data Payload (JSON)</label>
            <textarea rows={4} value={form.data} onChange={set('data')} />
          </div>
        </div>
        <div className="actions">
          <button className="btn btn-orange" onClick={sendNotification} disabled={sendLoading}>
            {sendLoading ? <span className="spinner" /> : null} Send Notification
          </button>
        </div>
        {sendResult && <ResponseBox status={sendResult.status} body={sendResult.body} />}
      </div>

      {/* ── DLQ ── */}
      <div className="card">
        <h3>Dead Letter Queue (DLQ)</h3>
        <p className="desc" style={{ marginBottom: 14 }}>
          Messages that failed all 3 retries appear here. Use Manual Retry to re-queue them.
        </p>
        <div className="actions">
          <button className="btn btn-outline" onClick={loadDlq} disabled={dlqLoading}>
            {dlqLoading ? <span className="spinner" /> : null} Refresh
          </button>
          <button className="btn btn-orange" onClick={retryDlq} disabled={retryLoading}>
            {retryLoading ? <span className="spinner" /> : null} Retry
          </button>
        </div>

        {retryResult && <ResponseBox status={retryResult.status} body={retryResult.body} title="Retry Result" />}

        <div style={{ marginTop: 16 }}>
          {dlqLoading && <p className="muted"><span className="spinner" /> Loading…</p>}
          {dlq && !dlqLoading && (
            dlq.count === 0
              ? <p className="text-success">✓ DLQ is empty — all messages delivered successfully.</p>
              : <>
                  <p className="text-warn" style={{ marginBottom: 10 }}>
                    ⚠ {dlq.count} message(s) awaiting manual retry
                  </p>
                  {dlq.messages?.map((m) => (
                    <div key={m.messageId} className="dlq-item">
                      <strong>{m.notificationType} — {m.personId}</strong>
                      <span>ID: {m.messageId}</span>
                      <span>Retries: {m.retryCount} &nbsp;|&nbsp; Created: {m.createdAt}</span>
                      <span>Last attempt: {m.lastAttemptAt || '—'}</span>
                    </div>
                  ))}
                </>
          )}
          {dlq?.error && <p className="text-error">❌ {dlq.error}</p>}
        </div>
      </div>

      {/* ── Fund 11 Toggle ── */}
      <div className="card">
        <h2>Store &amp; Forward Notification</h2>
        <p className="desc">
          Queue a notification for durable delivery via RabbitMQ. Returns 202 immediately and retries Fund 11
          up to 3 times (30 s apart). Toggle Fund 11 offline below to observe retries and DLQ behaviour.
        </p>

        <h3>Fund 11 — Service Window</h3>
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

    </div>
  );
}
