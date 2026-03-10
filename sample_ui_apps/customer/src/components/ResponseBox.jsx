import { prettyPrint } from '../utils';

export function ResponseBox({ status, body, title = 'Response' }) {
  if (status === null) return null;

  const ok   = status >= 200 && status < 300;
  const warn = status >= 400 && status < 500;
  const cls  = ok ? 'badge-ok' : warn ? 'badge-warn' : 'badge-err';

  return (
    <div className="response-box">
      <h3>
        {title}
        <span className={`status-badge ${cls}`}>HTTP {status}</span>
      </h3>
      <pre className="response-body">{prettyPrint(body)}</pre>
    </div>
  );
}
