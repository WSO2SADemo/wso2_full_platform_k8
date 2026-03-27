import { useState, useRef, useEffect, useCallback } from 'react';
import { useAuthContext } from '../auth/AuthContext';
import { csAgent } from '../api/client';

const SUGGESTIONS = [
  'Show me all flights',
  'What are the active disruptions?',
  'Get passenger details for P001',
  'Show bookings for flight FL001',
];

/* ── Helpers ─────────────────────────────────────────────────────────── */
function decodeJwtPayload(token) {
  try {
    const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(base64));
  } catch { return null; }
}

function TokenBadge({ label, token }) {
  if (!token) return null;
  const decoded = decodeJwtPayload(token);
  const exp = decoded?.exp ? new Date(decoded.exp * 1000).toLocaleTimeString() : '—';
  const sub = decoded?.sub || decoded?.client_id || '—';
  return (
    <div className="border border-slate-200 rounded-lg p-3 bg-white">
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs font-semibold text-slate-600">{label}</span>
        <span className="text-[10px] text-slate-400">exp {exp}</span>
      </div>
      <div className="text-[10px] text-slate-500 mb-1">sub: {sub}</div>
      <details>
        <summary className="text-[10px] text-teal-600 cursor-pointer hover:text-teal-800">Show JWT</summary>
        <pre className="mt-1 text-[9px] bg-slate-50 rounded p-2 overflow-x-auto max-h-32 break-all whitespace-pre-wrap select-all">{token}</pre>
        {decoded && (
          <>
            <summary className="text-[10px] text-teal-600 cursor-pointer hover:text-teal-800 mt-1">Decoded payload</summary>
            <pre className="mt-1 text-[9px] bg-slate-50 rounded p-2 overflow-x-auto max-h-40 break-all whitespace-pre-wrap">{JSON.stringify(decoded, null, 2)}</pre>
          </>
        )}
      </details>
    </div>
  );
}

function MessageBubble({ msg, onAuthorize }) {
  const isUser = msg.role === 'user';
  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} mb-4`}>
      <div className={`max-w-[75%] rounded-2xl px-4 py-3 ${
        isUser
          ? 'bg-teal-600 text-white rounded-br-md'
          : 'bg-slate-100 text-slate-800 rounded-bl-md border border-slate-200'
      }`}>
        {/* CS Agent icon */}
        {!isUser && (
          <div className="flex items-center gap-2 mb-1 text-xs text-slate-500">
            <span>🛎️</span> <span className="font-semibold">Customer Service Agent</span>
            {msg.functionCalled && (
              <span className="bg-teal-100 text-teal-700 px-1.5 py-0.5 rounded text-[10px] font-mono">
                {msg.functionCalled}
              </span>
            )}}
          </div>
        )}
        <div className="text-sm whitespace-pre-wrap leading-relaxed">{msg.text}</div>
        {/* OBO consent button — opens popup */}
        {msg.consentUrl && (
          <button
            onClick={() => onAuthorize(msg.consentUrl)}
            className="mt-2 inline-flex items-center gap-1.5 bg-teal-600 text-white text-xs font-medium rounded-lg px-3 py-2 hover:bg-teal-700 transition-colors cursor-pointer border-none"
          >
            🔐 Authorize Agent
          </button>
        )}
        {/* Show function result summary for AI responses */}
        {msg.functionResult && (
          <details className="mt-2 text-xs">
            <summary className="cursor-pointer text-slate-500 hover:text-slate-700">
              View raw data
            </summary>
            <pre className="mt-1 p-2 bg-slate-200/50 rounded text-[11px] overflow-x-auto max-h-48">
              {JSON.stringify(msg.functionResult, null, 2)}
            </pre>
          </details>
        )}
        <div className={`text-[10px] mt-1 ${isUser ? 'text-teal-200' : 'text-slate-400'}`}>
          {msg.time}
        </div>
      </div>
    </div>
  );
}

export default function CustomerServiceChat() {
  const { getAccessToken } = useAuthContext();
  const [messages, setMessages] = useState([
    {
      role: 'assistant',
      text: "Hello! I'm the Customer Service Agent. I can help you check flight status, look up passenger details, view bookings, find rebooking alternatives, and more.\n\nAll my capabilities come from 14 MCP tools discovered from existing REST APIs — no LLM, just direct tool execution!",
      time: new Date().toLocaleTimeString(),
      functionCalled: null,
      functionResult: null,
    },
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [sessionId, setSessionId] = useState(null);
  const [showTokens, setShowTokens] = useState(false);
  const [userToken, setUserToken] = useState(null);
  const [agentToken, setAgentToken] = useState(null);
  const [oboToken, setOboToken] = useState(null);
  const bottomRef = useRef(null);
  const inputRef = useRef(null);
  const pendingMessageRef = useRef(null);

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Focus input on mount
  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  // Fetch user token for debug display
  useEffect(() => {
    getAccessToken().then(t => setUserToken(t)).catch(() => {});
  }, [getAccessToken]);

  // Listen for OBO authorization success from popup window
  useEffect(() => {
    function handleMessage(e) {
      if (e.data?.type === 'obo_authorized' && pendingMessageRef.current) {
        const msg = pendingMessageRef.current;
        pendingMessageRef.current = null;
        // Add a status message
        setMessages(prev => [...prev, {
          role: 'assistant',
          text: '✅ Authorization successful! Retrying your request...',
          time: new Date().toLocaleTimeString(),
          functionCalled: null,
          functionResult: null,
        }]);
        // Auto-resubmit the original message
        setTimeout(() => sendMessage(msg), 500);
      }
    }
    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [sessionId]); // eslint-disable-line react-hooks/exhaustive-deps

  const sendMessage = useCallback(async (text) => {
    const trimmed = (text || input).trim();
    if (!trimmed || loading) return;

    // Only show user bubble if it's a fresh message (not auto-retry)
    if (!text || text !== pendingMessageRef.current) {
      const userMsg = {
        role: 'user',
        text: trimmed,
        time: new Date().toLocaleTimeString(),
      };
      setMessages((prev) => [...prev, userMsg]);
    }
    setInput('');
    setLoading(true);
    setError(null);

    try {
      const resp = await csAgent.chat(trimmed, sessionId);

      // Store session_id for subsequent messages
      if (resp.session_id) {
        setSessionId(resp.session_id);
      }

      // Capture tokens for debug pane
      if (resp.agent_token) setAgentToken(resp.agent_token);
      if (resp.obo_token) setOboToken(resp.obo_token);

      // Handle OBO consent URL (agent needs user authorization)
      if (resp.consent_url) {
        // Store the user's message so we can auto-retry after auth
        pendingMessageRef.current = trimmed;
        const consentMsg = {
          role: 'assistant',
          text: resp.response || 'I need your authorization to proceed. Please click the button below to authorize me.',
          time: new Date().toLocaleTimeString(),
          functionCalled: null,
          functionResult: null,
          consentUrl: resp.consent_url,
        };
        setMessages((prev) => [...prev, consentMsg]);
      } else {
        const aiMsg = {
          role: 'assistant',
          text: resp.response || 'No response from CS agent.',
          time: new Date().toLocaleTimeString(),
          functionCalled: resp.function_called || null,
          functionResult: resp.function_result || null,
        };
        setMessages((prev) => [...prev, aiMsg]);
      }
    } catch (err) {
      setError(err.message);
      const errMsg = {
        role: 'assistant',
        text: `⚠️ Error: ${err.message}\n\nPlease try again or check if the CS agent service is running.`,
        time: new Date().toLocaleTimeString(),
        functionCalled: null,
        functionResult: null,
      };
      setMessages((prev) => [...prev, errMsg]);
    } finally {
      setLoading(false);
      inputRef.current?.focus();
    }
  }, [input, loading, sessionId]);

  const handleAuthorize = useCallback((consentUrl) => {
    window.open(consentUrl, 'obo_consent', 'width=600,height=700,popup=yes');
  }, []);

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  return (
    <div className="flex flex-col h-[calc(100vh-2rem)]">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-2">
            🛎️ Customer Service Agent
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            MCP-powered customer service agent — Tools discovered from existing REST APIs
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowTokens(v => !v)}
            className={`text-xs px-2.5 py-1.5 rounded-lg border transition-colors ${showTokens ? 'bg-amber-100 border-amber-300 text-amber-800' : 'bg-slate-50 border-slate-200 text-slate-500 hover:bg-slate-100'}`}
          >
            🔑 {showTokens ? 'Hide' : 'Show'} Tokens
          </button>
          <span className="inline-block w-2 h-2 rounded-full bg-green-500 animate-pulse" />
          <span className="text-xs text-slate-500">Connected</span>
        </div>
      </div>

      {/* Token Debug Pane */}
      {showTokens && (
        <div className="mb-4 p-4 bg-amber-50 border border-amber-200 rounded-xl">
          <h3 className="text-xs font-bold text-amber-800 mb-3 flex items-center gap-1.5">
            🔑 Token Inspector <span className="font-normal text-amber-600">(debug)</span>
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <TokenBadge label="User Token (IS Login)" token={userToken} />
            <TokenBadge label="CS Agent Token (OBO Step 1)" token={agentToken} />
            <TokenBadge label="OBO Delegated Token" token={oboToken} />
          </div>
          {sessionId && (
            <div className="mt-2 text-[10px] text-amber-600">Session: {sessionId}</div>
          )}
        </div>
      )}

      {/* Chat area */}
      <div className="flex-1 overflow-y-auto bg-white rounded-xl border border-slate-200 shadow-sm p-4 mb-4">
        {messages.map((msg, i) => (
          <MessageBubble key={i} msg={msg} onAuthorize={handleAuthorize} />
        ))}

        {/* Typing indicator */}
        {loading && (
          <div className="flex justify-start mb-4">
            <div className="bg-slate-100 rounded-2xl rounded-bl-md px-4 py-3 border border-slate-200">
              <div className="flex items-center gap-2 text-xs text-slate-500 mb-1">
                <span>🛎️</span> <span className="font-semibold">Customer Service Agent</span>
              </div>
              <div className="flex gap-1">
                <span className="w-2 h-2 bg-slate-400 rounded-full animate-bounce [animation-delay:0ms]" />
                <span className="w-2 h-2 bg-slate-400 rounded-full animate-bounce [animation-delay:150ms]" />
                <span className="w-2 h-2 bg-slate-400 rounded-full animate-bounce [animation-delay:300ms]" />
              </div>
            </div>
          </div>
        )}

        <div ref={bottomRef} />
      </div>

      {/* Suggestion chips */}
      {messages.length <= 1 && (
        <div className="flex flex-wrap gap-2 mb-3">
          {SUGGESTIONS.map((s, i) => (
            <button
              key={i}
              onClick={() => sendMessage(s)}
              disabled={loading}
              className="text-xs bg-teal-50 text-teal-700 border border-teal-200 rounded-full px-3 py-1.5 hover:bg-teal-100 transition-colors disabled:opacity-50"
            >
              {s}
            </button>
          ))}
        </div>
      )}

      {/* Input area */}
      <div className="flex gap-2">
        <textarea
          ref={inputRef}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Ask about flights, passengers, bookings, disruptions, rebooking..."
          rows={1}
          disabled={loading}
          className="flex-1 resize-none rounded-xl border border-slate-300 bg-white px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500 focus:border-transparent disabled:opacity-60 placeholder:text-slate-400"
        />
        <button
          onClick={() => sendMessage()}
          disabled={loading || !input.trim()}
          className="rounded-xl bg-teal-600 text-white px-5 py-3 text-sm font-medium hover:bg-teal-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          {loading ? (
            <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
            </svg>
          ) : (
            'Send'
          )}
        </button>
      </div>

      {error && (
        <p className="text-xs text-red-500 mt-1">Last error: {error}</p>
      )}
    </div>
  );
}
