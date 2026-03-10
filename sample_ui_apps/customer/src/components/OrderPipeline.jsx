import { useState, useEffect } from 'react';
import { CFG } from '../config';
import { authHeaders } from '../auth';
import { apiFetch } from '../utils';
import { ResponseBox } from './ResponseBox';

// ── Static reference data (mirrors order_pipeline_backends.bal) ──────────────

const CUSTOMERS = [
  { id: 'CUST-001', label: 'CUST-001 – Alice Svensson (GOLD)' },
  { id: 'CUST-002', label: 'CUST-002 – Bob Lindqvist (SILVER)' },
  { id: 'CUST-003', label: 'CUST-003 – Carol Andersson (BRONZE)' },
];

const PRODUCTS = [
  { id: 'PROD-A1', label: 'PROD-A1 – Laptop Pro (12,999 SEK)' },
  { id: 'PROD-B2', label: 'PROD-B2 – Wireless Mouse (299 SEK)' },
  { id: 'PROD-C3', label: 'PROD-C3 – USB-C Hub (449 SEK, 0 stock)' },
  { id: 'PROD-D4', label: 'PROD-D4 – Monitor 27in (5,999 SEK)' },
];

// ── Component ─────────────────────────────────────────────────────────────────

const QUEUES = [
  { name: 'errorhandling.order-failure',    label: 'Order Failure',    colorClass: 'queue-count-error' },
  { name: 'errorhandling.order-replay',     label: 'Order Replay',     colorClass: 'queue-count-warn'  },
  { name: 'errorhandling.order-deadletter', label: 'Dead Letter',      colorClass: 'queue-count-warn'  },
];

function rmqHeaders() {
  return {
    'Authorization': `Basic ${btoa(`${CFG.rmqUser}:${CFG.rmqPass}`)}`,
    'Content-Type': 'application/json',
  };
}

export function OrderPipeline() {
  // Pipeline backend services – one entry per deployed APIM API
  const SERVICES = [
    { key: 'customer', label: 'Customer Profile', port: 9110, path: 'customer', base: CFG.opCustomerBase },
    { key: 'pricing',  label: 'Pricing',           port: 9112, path: 'pricing',  base: CFG.opPricingBase },
    { key: 'purchase', label: 'Purchase',          port: 9113, path: 'purchase', base: CFG.opPurchaseBase },
  ];

  // Backend service states: { key → { available, state } | { error } | null }
  const [serviceStates, setServiceStates] = useState({});
  const [refreshLoading, setRefreshLoading] = useState({});
  const [toggleLoading, setToggleLoading]   = useState({});

  // Order form
  const [customerId, setCustomerId] = useState('CUST-001');
  const [items, setItems]           = useState([{ productId: 'PROD-A1', quantity: 1 }]);
  const [orderLoading, setOrderLoading] = useState(false);
  const [orderResult, setOrderResult]   = useState(null);

  // Queue monitor: { queueName → { count, messages, error } }
  const [queueData, setQueueData]     = useState({});
  const [replayLoading, setReplayLoading] = useState(false);
  const [replayResult,  setReplayResult]  = useState(null);

  useEffect(() => { loadAllStatuses(); }, []);

  // Queue auto-refresh every 2 s
  useEffect(() => {
    loadQueues();
    const id = setInterval(loadQueues, 2000);
    return () => clearInterval(id);
  }, []);

  // ── Service status ──────────────────────────────────────────────────────────

  async function refreshService(svc) {
    setRefreshLoading((r) => ({ ...r, [svc.key]: true }));
    try {
      const r = await apiFetch(
        `${svc.base}/${svc.path}/admin/status`,
        { headers: authHeaders() }
      );
      setServiceStates((s) => ({ ...s, [svc.key]: r.body }));
    } catch (e) {
      setServiceStates((s) => ({ ...s, [svc.key]: { error: e.message } }));
    }
    setRefreshLoading((r) => ({ ...r, [svc.key]: false }));
  }

  function loadAllStatuses() {
    SERVICES.forEach((svc) => refreshService(svc));
  }

  async function toggleService(svc) {
    setToggleLoading((t) => ({ ...t, [svc.key]: true }));
    try {
      await apiFetch(`${svc.base}/${svc.path}/admin/toggle`, {
        method: 'POST',
        headers: authHeaders(),
      });
      const r = await apiFetch(
        `${svc.base}/${svc.path}/admin/status`,
        { headers: authHeaders() }
      );
      setServiceStates((s) => ({ ...s, [svc.key]: r.body }));
    } catch (e) {
      setServiceStates((s) => ({ ...s, [svc.key]: { error: e.message } }));
    }
    setToggleLoading((t) => ({ ...t, [svc.key]: false }));
  }

  // ── Queue monitor ───────────────────────────────────────────────────────────

  async function loadQueues() {
    const results = await Promise.all(
      QUEUES.map(async (q) => {
        const encoded = encodeURIComponent(q.name);
        try {
          const [statsRes, msgRes] = await Promise.all([
            fetch(`${CFG.rmqBase}/api/queues/%2F/${encoded}`, { headers: rmqHeaders() }),
            fetch(`${CFG.rmqBase}/api/queues/%2F/${encoded}/get`, {
              method: 'POST',
              headers: rmqHeaders(),
              body: JSON.stringify({ count: 20, ackmode: 'ack_requeue_true', encoding: 'auto' }),
            }),
          ]);
          const stats    = statsRes.ok    ? await statsRes.json()  : null;
          const messages = msgRes.ok      ? await msgRes.json()    : [];
          return { name: q.name, count: stats?.messages ?? messages.length, messages, error: null };
        } catch (e) {
          return { name: q.name, count: 0, messages: [], error: e.message };
        }
      })
    );
    const next = {};
    results.forEach((r) => { next[r.name] = r; });
    setQueueData(next);
  }

  // ── Replay: move all Order Failure messages → Order Replay ──────────────────

  async function replayFailures() {
    setReplayLoading(true);
    setReplayResult(null);
    const failureQueue = 'errorhandling.order-failure';
    const replayQueue  = 'errorhandling.order-replay';
    const encoded = encodeURIComponent(failureQueue);
    try {
      // Drain all messages from the failure queue (ack_requeue_false = consume & remove)
      const res = await fetch(`${CFG.rmqBase}/api/queues/%2F/${encoded}/get`, {
        method: 'POST',
        headers: rmqHeaders(),
        body: JSON.stringify({ count: 1000, ackmode: 'ack_requeue_false', encoding: 'auto' }),
      });
      const messages = res.ok ? await res.json() : [];

      // Publish each message to the replay queue via the default exchange
      await Promise.all(messages.map((msg) =>
        fetch(`${CFG.rmqBase}/api/exchanges/%2F/amq.default/publish`, {
          method: 'POST',
          headers: rmqHeaders(),
          body: JSON.stringify({
            properties:       msg.properties ?? {},
            routing_key:      replayQueue,
            payload:          msg.payload,
            payload_encoding: msg.payload_encoding ?? 'string',
          }),
        })
      ));

      setReplayResult({ moved: messages.length });
    } catch (e) {
      setReplayResult({ error: e.message });
    }
    setReplayLoading(false);
    loadQueues();
  }

  // ── Order items helpers ─────────────────────────────────────────────────────

  function addItem() {
    setItems((prev) => [...prev, { productId: 'PROD-B2', quantity: 1 }]);
  }

  function removeItem(idx) {
    setItems((prev) => prev.filter((_, i) => i !== idx));
  }

  function updateItem(idx, field, value) {
    setItems((prev) =>
      prev.map((item, i) =>
        i === idx ? { ...item, [field]: field === 'quantity' ? Math.max(1, Number(value)) : value } : item
      )
    );
  }

  // ── Submit order ────────────────────────────────────────────────────────────

  async function processOrder() {
    setOrderLoading(true);
    setOrderResult(null);
    try {
      const r = await apiFetch(`${CFG.opBase}/orders/process`, {
        method: 'POST',
        headers: authHeaders({ 'Content-Type': 'application/json' }),
        body: JSON.stringify({ customerId, items }),
      });
      setOrderResult(r);
    } catch (e) {
      setOrderResult({ status: 0, body: e.message });
    }
    setOrderLoading(false);
  }

  // ── Render helpers ──────────────────────────────────────────────────────────

  function ServiceToggle({ svc, step }) {
    const st          = serviceStates[svc.key];
    const isOnline    = st?.available;
    const isRefreshing = !!refreshLoading[svc.key];
    const isToggling  = !!toggleLoading[svc.key];

    return (
      <div style={{ marginBottom: 20 }}>
        <h3>Step {step} — {svc.label} <span style={{ fontWeight: 400, color: 'var(--muted)', fontSize: 12 }}>port {svc.port}</span></h3>
        <div className="toggle-wrap">
          {isRefreshing
            ? <span className="spinner" />
            : st
              ? <span className={`fund11-badge ${st.error ? 'badge-offline' : isOnline ? 'badge-online' : 'badge-offline'}`}>
                  {st.error ? '⚠ Error' : (st.state ?? '…')}
                </span>
              : <span className="spinner" />
          }
          <button className="btn btn-outline btn-sm" onClick={() => refreshService(svc)} disabled={isRefreshing || isToggling}>
            Refresh
          </button>
          <button className="btn btn-orange btn-sm" onClick={() => toggleService(svc)} disabled={isToggling || isRefreshing}>
            {isToggling ? <span className="spinner" /> : null}
            {isOnline ? 'Take Offline' : 'Bring Online'}
          </button>
        </div>
        {st?.error && (
          <p className="text-error" style={{ marginTop: 10 }}>❌ {st.error}</p>
        )}
      </div>
    );
  }

  function SuccessCard({ body }) {
    if (!body?.purchaseId) return null;
    return (
      <div className="pipeline-result-card">
        <div className="pipeline-result-header">
          <span className="badge-status-success">CONFIRMED</span>
          <strong>{body.purchaseId}</strong>
        </div>
        <div className="pipeline-result-grid">
          <div className="pipeline-result-field">
            <span className="pipeline-result-label">Tracking Ref</span>
            <span className="pipeline-result-value">{body.trackingRef}</span>
          </div>
          <div className="pipeline-result-field">
            <span className="pipeline-result-label">Delivery Date</span>
            <span className="pipeline-result-value">{body.deliveryDate}</span>
          </div>
          <div className="pipeline-result-field">
            <span className="pipeline-result-label">Status</span>
            <span className="pipeline-result-value">{body.status}</span>
          </div>
        </div>
      </div>
    );
  }

  const isSuccess = orderResult?.status === 200 && orderResult?.body?.purchaseId;

  return (
    <div>

      {/* ── 1. Process Order ── */}
      <div className="card">
        <h2>Process Order</h2>
        <p className="desc">
          Each order is processed through a sequential three-step pipeline: Customer Profile → Pricing →
          Purchase. Toggle any backend service offline to simulate a service window and observe how the
          integration handles step failures with correlation IDs.
        </p>

        <div className="form-grid" style={{ marginTop: 16 }}>
          <div className="field">
            <label>Customer</label>
            <select value={customerId} onChange={(e) => setCustomerId(e.target.value)}>
              {CUSTOMERS.map((c) => (
                <option key={c.id} value={c.id}>{c.label}</option>
              ))}
            </select>
          </div>
        </div>

        <div style={{ marginTop: 16 }}>
          <label style={{ display: 'block', marginBottom: 8, fontWeight: 600, fontSize: 13 }}>Items</label>
          {items.map((item, idx) => (
            <div key={idx} className="pipeline-item-row">
              <select
                value={item.productId}
                onChange={(e) => updateItem(idx, 'productId', e.target.value)}
                style={{ flex: 1 }}
              >
                {PRODUCTS.map((p) => (
                  <option key={p.id} value={p.id}>{p.label}</option>
                ))}
              </select>
              <input
                type="number"
                min="1"
                value={item.quantity}
                onChange={(e) => updateItem(idx, 'quantity', e.target.value)}
                style={{ width: 70 }}
              />
              {items.length > 1 && (
                <button className="btn btn-outline btn-sm" onClick={() => removeItem(idx)}>✕</button>
              )}
            </div>
          ))}
          <button className="btn btn-outline btn-sm" onClick={addItem} style={{ marginTop: 8 }}>
            + Add Item
          </button>
        </div>

        <div className="actions" style={{ marginTop: 20 }}>
          <button className="btn btn-orange" onClick={processOrder} disabled={orderLoading}>
            {orderLoading ? <span className="spinner" /> : null} Process Order
          </button>
        </div>

        {orderResult && (
          isSuccess
            ? <SuccessCard body={orderResult.body} />
            : <ResponseBox status={orderResult.status} body={orderResult.body} />
        )}
      </div>

      {/* ── 2. Message Queue Monitor ── */}
      <div className="card">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
          <h3 style={{ margin: 0 }}>Message Queue Monitor</h3>
          <span className="live-indicator">
            <span className="live-dot" />
            auto-refresh 2 s
          </span>
        </div>

        <div className="queue-grid">
          {QUEUES.map((q) => {
            const d           = queueData[q.name];
            const count       = d?.count ?? '…';
            const messages    = d?.messages ?? [];
            const hasError    = !!d?.error;
            const isEmpty     = !hasError && d && count === 0;
            const isFailQueue = q.name === 'errorhandling.order-failure';

            return (
              <div key={q.name} className="queue-card">
                <div className="queue-card-header">
                  <span className="queue-card-title">{q.label}</span>
                  <span className={`queue-count-badge ${hasError ? 'queue-count-error' : isEmpty ? 'queue-count-zero' : q.colorClass}`}>
                    {hasError ? '⚠' : count}
                  </span>
                </div>
                <div className="queue-name-label">{q.name}</div>

                {isFailQueue && (
                  <div style={{ marginTop: 8 }}>
                    <button
                      className="btn btn-orange btn-sm"
                      onClick={replayFailures}
                      disabled={replayLoading || isEmpty}
                      style={{ width: '100%' }}
                    >
                      {replayLoading ? <span className="spinner" /> : null}
                      Move to Order Replay
                    </button>
                    {replayResult && !replayLoading && (
                      replayResult.error
                        ? <p className="text-error" style={{ fontSize: 11, marginTop: 6 }}>❌ {replayResult.error}</p>
                        : <p style={{ fontSize: 11, marginTop: 6, color: 'var(--success)' }}>✓ Moved {replayResult.moved} message{replayResult.moved !== 1 ? 's' : ''}</p>
                    )}
                  </div>
                )}

                {hasError && (
                  <p className="text-error" style={{ fontSize: 11, marginTop: 8 }}>❌ {d.error}</p>
                )}

                {!hasError && isEmpty && (
                  <div className="queue-empty">✓ Empty</div>
                )}

                {!hasError && messages.length > 0 && (
                  <div className="queue-messages">
                    {messages.map((msg, i) => {
                      let display;
                      try {
                        const parsed = JSON.parse(msg.payload);
                        display = JSON.stringify(parsed, null, 1);
                      } catch {
                        display = msg.payload;
                      }
                      return (
                        <pre key={i} className="queue-message-item">{display}</pre>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* ── 3. Service Window Simulator ── */}
      <div className="card">
        <h3>Service Window Simulator</h3>
        <p className="desc">
          Take individual pipeline services offline to inject failures and observe retry and dead-letter behaviour.
        </p>

        {SERVICES.map((svc, i) => (
          <ServiceToggle key={svc.key} svc={svc} step={i + 1} />
        ))}
      </div>

    </div>
  );
}
