import { NavLink } from 'react-router-dom';
import { useAuthContext } from '../auth/AuthContext';

const links = [
  { to: '/',            label: 'Dashboard',    icon: '📊' },
  { to: '/flights',     label: 'Flights',      icon: '✈️' },
  { to: '/disruptions', label: 'Disruptions',  icon: '⚠️' },
  { to: '/crew',        label: 'Crew',         icon: '👨‍✈️' },
  { to: '/logistics',   label: 'Logistics',    icon: '🏗️' },
  { to: '/recovery',    label: 'Recovery',     icon: '🔄' },
  { to: '/ai-chat',     label: 'Admin Agent',  icon: '🤖' },
  { to: '/cs-chat',     label: 'Customer Service Agent',   icon: '🛎️' },
];

export default function Sidebar() {
  const { state, signOut, getDecodedIDToken } = useAuthContext();
  const displayName = state?.displayName || state?.username || 'User';

  const handleLogout = () => {
    signOut();
  };

  return (
    <aside className="fixed left-0 top-0 bottom-0 w-60 bg-slate-900 text-white flex flex-col z-10">
      <div className="px-5 py-5 border-b border-slate-700">
        <h1 className="text-lg font-bold tracking-tight">✈️ ADR Dashboard</h1>
        <p className="text-xs text-slate-400 mt-1">Flight Disruption Recovery</p>
      </div>
      <nav className="flex-1 py-4 overflow-y-auto">
        {links.map(l => (
          <NavLink
            key={l.to}
            to={l.to}
            end={l.to === '/'}
            className={({ isActive }) =>
              `flex items-center gap-3 px-5 py-2.5 text-sm transition-colors ${
                isActive
                  ? 'bg-blue-600/20 text-blue-400 border-r-2 border-blue-400 font-medium'
                  : 'text-slate-300 hover:bg-slate-800 hover:text-white'
              }`
            }
          >
            <span className="text-base">{l.icon}</span>
            {l.label}
          </NavLink>
        ))}
      </nav>
      <div className="px-5 py-4 border-t border-slate-700">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center text-sm font-bold">
            {displayName.charAt(0).toUpperCase()}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium truncate">{displayName}</p>
            <p className="text-xs text-slate-400 truncate">{state?.email || ''}</p>
          </div>
        </div>
        <button
          onClick={handleLogout}
          className="w-full text-left text-xs text-slate-400 hover:text-red-400 transition-colors flex items-center gap-2 py-1"
        >
          <span>🚪</span> Sign Out
        </button>
      </div>
    </aside>
  );
}
