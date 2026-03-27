import { useAuthContext } from '../auth/AuthContext';
import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

export default function Login() {
  const { signIn, state } = useAuthContext();
  const navigate = useNavigate();

  useEffect(() => {
    if (state.isAuthenticated) {
      navigate('/', { replace: true });
    }
  }, [state.isAuthenticated, navigate]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 via-blue-950 to-slate-900">
      <div className="bg-white/10 backdrop-blur-lg rounded-2xl shadow-2xl p-10 max-w-md w-full text-center border border-white/20">
        <div className="text-6xl mb-4">✈️</div>
        <h1 className="text-2xl font-bold text-white mb-2">ADR Flight Delay</h1>
        <p className="text-slate-300 text-sm mb-8">
          Autonomous Disruption Recovery Dashboard
        </p>

        <button
          onClick={() => signIn()}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-6 rounded-lg transition-colors shadow-lg hover:shadow-xl"
        >
          Sign In with WSO2 Identity Server
        </button>

        <p className="text-slate-400 text-xs mt-6">
          Demo users: <span className="text-slate-300">adr_admin / Admin@123</span>
          {' '}or{' '}
          <span className="text-slate-300">adr_operator / Operator@123</span>
        </p>
      </div>
    </div>
  );
}
