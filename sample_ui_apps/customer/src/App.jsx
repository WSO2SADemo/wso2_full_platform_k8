import { useState, useEffect } from 'react';
import { getToken, saveToken, exchangeCode, redirectUri } from './auth';
import { LoginScreen } from './components/LoginScreen';
import { Header } from './components/Header';
import { ContentBasedRouting } from './components/ContentBasedRouting';
import { StoreAndForward } from './components/StoreAndForward';
import { ParallelOrchestration } from './components/ParallelOrchestration';
import './App.css';

const TABS = [
  { id: 'cbr', label: 'Content-Based Routing (SOAP)' },
  { id: 'sf',  label: 'Store & Forward' },
  { id: 'pso', label: 'Parallel Orchestration' },
];

// Module-level flag — survives StrictMode double-invoke (unlike useRef)
let exchangeStarted = false;

export default function App() {
  const [authed, setAuthed]       = useState(false);
  const [activeTab, setActiveTab] = useState('cbr');
  const [error, setError]         = useState(null);

  useEffect(() => {
    // Already handling a code exchange (StrictMode second run guard)
    if (exchangeStarted) return;

    const params = new URLSearchParams(window.location.search);
    const code = params.get('code');

    if (code) {
      exchangeStarted = true;
      history.replaceState({}, '', redirectUri());
      exchangeCode(code)
        .then((tokens) => {
          saveToken(tokens.access_token);
          console.log('[token]', tokens.access_token);
          setAuthed(true);
        })
        .catch((e) => {
          exchangeStarted = false;
          setError(
            `Token exchange failed — this is usually a CORS issue when running locally.\n\n` +
            `Workaround: paste your access_token into the browser console:\n` +
            `  sessionStorage.setItem('access_token', '<your-token>')\n` +
            `then reload the page.\n\nError: ${e.message}`
          );
        });
      return;
    }

    if (getToken()) setAuthed(true);
  }, []);

  if (error) {
    return (
      <div className="login-screen">
        <div className="login-card">
          <h1 style={{ color: '#c62828', marginBottom: 12 }}>Auth Error</h1>
          <pre style={{ fontSize: 12, whiteSpace: 'pre-wrap', color: '#333', textAlign: 'left' }}>{error}</pre>
          <button className="btn btn-primary" style={{ marginTop: 16 }} onClick={() => setError(null)}>
            Back to Sign In
          </button>
        </div>
      </div>
    );
  }

  if (!authed) return <LoginScreen />;

  return (
    <div className="app">
      <Header />

      <nav className="tab-nav">
        {TABS.map((t) => (
          <button
            key={t.id}
            className={activeTab === t.id ? 'active' : ''}
            onClick={() => setActiveTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </nav>

      <main className="tab-content">
        {activeTab === 'cbr' && <ContentBasedRouting />}
        {activeTab === 'sf'  && <StoreAndForward />}
        {activeTab === 'pso' && <ParallelOrchestration />}
      </main>
    </div>
  );
}
