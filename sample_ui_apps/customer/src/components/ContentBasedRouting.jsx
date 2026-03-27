import { useState } from 'react';
import { CFG } from '../config';
import { authHeaders } from '../auth';
import { apiFetch } from '../utils';
import { ResponseBox } from './ResponseBox';
import { QueueMonitor } from './QueueMonitor';

const ROUTING_MAP = {
  AFA:     'AFA → DNE Calculator (Add)',
  Folksam: (amount) =>
    amount > 50000
      ? 'Folksam high-value → DNE Calculator (Multiply)'
      : 'Folksam standard → Oorsprong CountryInfo',
  Alfa:    'Alfa → LearnWebServices (Hello)',
  Skandia: 'Skandia → Unavailable backend (triggers error handling)',
};

const CBR_QUEUES = [
  { name: 'contentbasedrouting.order-failure',    label: 'Order Failure',    colorClass: 'queue-count-error' },
  { name: 'contentbasedrouting.order-replay',     label: 'Order Replay',     colorClass: 'queue-count-warn'  },
  { name: 'contentbasedrouting.order-deadletter', label: 'Dead Letter',      colorClass: 'queue-count-warn'  },
];

function getRoute(sender, amount) {
  const r = ROUTING_MAP[sender];
  return typeof r === 'function' ? r(amount) : r;
}

function buildSoap({ sender, senderId, personalNumber, benefitAmount, benefitType, periodStart, periodEnd, message }) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:un="http://unemployment.sweden.se/notification">
  <soap:Header>
    <un:SenderHeader>
      <un:senderName>${sender}</un:senderName>
      <un:senderId>${senderId}</un:senderId>
    </un:SenderHeader>
  </soap:Header>
  <soap:Body>
    <un:BenefitNotification>
      <un:personalNumber>${personalNumber}</un:personalNumber>
      <un:benefitAmount>${benefitAmount}</un:benefitAmount>
      <un:benefitType>${benefitType}</un:benefitType>
      <un:periodStart>${periodStart}</un:periodStart>
      <un:periodEnd>${periodEnd}</un:periodEnd>
      ${message ? `<un:message>${message}</un:message>` : ''}
    </un:BenefitNotification>
  </soap:Body>
</soap:Envelope>`;
}

export function ContentBasedRouting() {
  const [form, setForm] = useState({
    sender: 'AFA',
    senderId: 'AFA-001',
    personalNumber: 'SE199001011234',
    benefitAmount: 25000,
    benefitType: 'UNEMPLOYMENT',
    periodStart: '2026-01-01',
    periodEnd: '2026-03-31',
    message: '',
  });
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [showXml, setShowXml] = useState(false);
  // xmlOverride: null = use generated envelope; string = user-edited custom payload
  const [xmlOverride, setXmlOverride] = useState(null);

  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));

  const route = getRoute(form.sender, Number(form.benefitAmount));

  function togglePreview() {
    if (!showXml && xmlOverride === null) {
      // Seed the editor with the generated envelope on first open
      setXmlOverride(buildSoap(form));
    }
    setShowXml((v) => !v);
  }

  function resetXml() {
    setXmlOverride(buildSoap(form));
  }

  async function send() {
    setLoading(true);
    setResult(null);
    try {
      const xml = xmlOverride !== null ? xmlOverride : buildSoap(form);
      const r = await apiFetch(`${CFG.cbrBase}/soap/routing`, {
        method: 'POST',
        headers: authHeaders({ 'Content-Type': 'text/xml' }),
        body: xml,
      });
      setResult(r);
    } catch (e) {
      setResult({ status: 0, body: e.message });
    }
    setLoading(false);
  }

  return (
    <div>
      <div className="card">
        <h2>Content-Based Routing — SOAP Integration</h2>
        <p className="desc">
          Submit a Swedish unemployment benefit SOAP notification. The integration validates against XSD and routes
          to different backends based on the sender and benefit amount.
        </p>

        <div className="form-grid">
          <div className="field">
            <label>Sender</label>
            <select value={form.sender} onChange={set('sender')}>
              <option value="AFA">AFA</option>
              <option value="Folksam">Folksam</option>
              <option value="Alfa">Alfa</option>
              <option value="Skandia">Skandia (unavailable)</option>
            </select>
          </div>
          <div className="field">
            <label>Sender ID</label>
            <input value={form.senderId} onChange={set('senderId')} />
          </div>
          <div className="field">
            <label>Personal Number</label>
            <input value={form.personalNumber} onChange={set('personalNumber')} />
          </div>
          <div className="field">
            <label>Benefit Amount (SEK)</label>
            <input type="number" value={form.benefitAmount} onChange={set('benefitAmount')} step="100" />
          </div>
          <div className="field">
            <label>Benefit Type</label>
            <input value={form.benefitType} onChange={set('benefitType')} />
          </div>
          <div className="field">
            <label>Message (optional)</label>
            <input value={form.message} onChange={set('message')} placeholder="Additional notes…" />
          </div>
          <div className="field">
            <label>Period Start</label>
            <input type="date" value={form.periodStart} onChange={set('periodStart')} />
          </div>
          <div className="field">
            <label>Period End</label>
            <input type="date" value={form.periodEnd} onChange={set('periodEnd')} />
          </div>
        </div>

        <div className="routing-preview">
          Expected route: <strong>{route}</strong>
        </div>

        <div className="actions">
          <button className="btn btn-orange" onClick={send} disabled={loading}>
            {loading ? <span className="spinner" /> : null} Send SOAP Request
          </button>
          <button className="btn btn-outline btn-sm" onClick={togglePreview}>
            {showXml ? 'Hide' : 'Preview / Edit'} XML
          </button>
        </div>

        {showXml && (
          <div className="response-box" style={{ marginTop: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
              <h3 style={{ margin: 0 }}>SOAP Envelope <span style={{ color: '#f90', fontSize: 13, fontWeight: 400 }}>(editable — modify to send invalid payloads)</span></h3>
              <button className="btn btn-outline btn-sm" onClick={resetXml} style={{ marginLeft: 12 }}>
                Reset to Generated
              </button>
            </div>
            <textarea
              className="response-body"
              value={xmlOverride !== null ? xmlOverride : buildSoap(form)}
              onChange={(e) => setXmlOverride(e.target.value)}
              rows={22}
              style={{ width: '100%', resize: 'vertical', boxSizing: 'border-box' }}
              spellCheck={false}
            />
          </div>
        )}

        {result && <ResponseBox status={result.status} body={result.body} />}
      </div>

      <QueueMonitor
        queues={CBR_QUEUES}
        failureQueue="contentbasedrouting.order-failure"
        replayQueue="contentbasedrouting.order-replay"
      />
    </div>
  );
}
