import { useState, useEffect } from 'react';
import { CFG } from '../config';

function rmqHeaders() {
  return {
    'Authorization': `Basic ${btoa(`${CFG.rmqUser}:${CFG.rmqPass}`)}`,
    'Content-Type': 'application/json',
  };
}

/**
 * QueueMonitor – auto-refreshing RabbitMQ queue panel.
 *
 * Props:
 *   queues        – array of { name, label, colorClass }
 *   failureQueue  – (optional) queue name that gets the "Move to Replay" button
 *   replayQueue   – (optional) target queue for the replay action
 */
export function QueueMonitor({ queues, failureQueue, replayQueue }) {
  const [queueData,     setQueueData]     = useState({});
  const [replayLoading, setReplayLoading] = useState(false);
  const [replayResult,  setReplayResult]  = useState(null);

  useEffect(() => {
    loadQueues();
    const id = setInterval(loadQueues, 2000);
    return () => clearInterval(id);
  }, []);

  async function loadQueues() {
    const results = await Promise.all(
      queues.map(async (q) => {
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
          const stats    = statsRes.ok ? await statsRes.json() : null;
          const messages = msgRes.ok   ? await msgRes.json()   : [];
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

  async function replayFailures() {
    setReplayLoading(true);
    setReplayResult(null);
    const encoded = encodeURIComponent(failureQueue);
    try {
      const res = await fetch(`${CFG.rmqBase}/api/queues/%2F/${encoded}/get`, {
        method: 'POST',
        headers: rmqHeaders(),
        body: JSON.stringify({ count: 1000, ackmode: 'ack_requeue_false', encoding: 'auto' }),
      });
      if (!res.ok) throw new Error(`Failed to fetch messages: HTTP ${res.status}`);
      const messages = await res.json();

      let moved = 0;
      let failed = 0;
      for (const msg of messages) {
        const pubRes = await fetch(`${CFG.rmqBase}/api/exchanges/%2F/amq.default/publish`, {
          method: 'POST',
          headers: rmqHeaders(),
          body: JSON.stringify({
            properties:       { delivery_mode: msg.properties?.delivery_mode ?? 2, headers: msg.properties?.headers ?? {} },
            routing_key:      replayQueue,
            payload:          msg.payload,
            payload_encoding: msg.payload_encoding ?? 'string',
          }),
        });
        if (pubRes.ok) {
          const body = await pubRes.json();
          body.routed ? moved++ : failed++;
        } else {
          failed++;
        }
      }

      if (failed > 0) {
        setReplayResult({ error: `${moved} moved, ${failed} failed to route — check queue name or shovel plugin` });
      } else {
        setReplayResult({ moved });
      }
    } catch (e) {
      setReplayResult({ error: e.message });
    }
    setReplayLoading(false);
    loadQueues();
  }

  return (
    <div className="card">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
        <h3 style={{ margin: 0 }}>Message Queue Monitor</h3>
        <span className="live-indicator">
          <span className="live-dot" />
          auto-refresh 2 s
        </span>
      </div>

      <div className="queue-grid">
        {queues.map((q) => {
          const d           = queueData[q.name];
          const count       = d?.count ?? '…';
          const messages    = d?.messages ?? [];
          const hasError    = !!d?.error;
          const isEmpty     = !hasError && d && count === 0;
          const isFailQueue = failureQueue && q.name === failureQueue;

          return (
            <div key={q.name} className="queue-card">
              <div className="queue-card-header">
                <span className="queue-card-title">{q.label}</span>
                <span className={`queue-count-badge ${hasError ? 'queue-count-error' : isEmpty ? 'queue-count-zero' : (q.colorClass || 'queue-count-warn')}`}>
                  {hasError ? '⚠' : count}
                </span>
              </div>
              <div className="queue-name-label">{q.name}</div>

              {isFailQueue && replayQueue && (
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
  );
}
