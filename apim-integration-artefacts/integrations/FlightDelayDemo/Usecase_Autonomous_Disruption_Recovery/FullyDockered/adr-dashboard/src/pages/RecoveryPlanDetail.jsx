import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { adr } from '../api/client';
import StatusBadge from '../components/StatusBadge';

export default function RecoveryPlanDetail() {
  const { id } = useParams();
  const [plan, setPlan]     = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    adr.getRecoveryPlan(id).then(setPlan).finally(() => setLoading(false));
  }, [id]);

  if (loading) return <Spinner />;
  if (!plan) return <p className="text-gray-500">Recovery plan not found.</p>;

  let negotiationLog = [];
  try {
    negotiationLog = typeof plan.negotiation_log === 'string'
      ? JSON.parse(plan.negotiation_log)
      : (plan.negotiation_log || []);
  } catch { /* ignore */ }

  return (
    <div>
      <Link to="/recovery" className="text-sm text-blue-600 hover:underline">← Back to Recovery</Link>
      <div className="flex items-center gap-4 mt-2 mb-6">
        <h1 className="text-2xl font-bold">Recovery Plan</h1>
        <StatusBadge value={plan.status} />
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <Info label="Plan ID" value={plan.plan_id} mono />
        <Info label="Flight" value={plan.flight_id} link={`/flights/${plan.flight_id}`} />
        <Info label="Disruption" value={plan.disruption_id} mono />
        <Info label="Status" value={plan.status} badge />
        <Info label="PAX Affected" value={plan.total_passengers_affected} />
        <Info label="PAX Rebooked" value={plan.passengers_rebooked} />
        <Info label="Crew Reassignments" value={plan.crew_reassignments} />
        <Info label="Gate Changes" value={plan.gate_changes} />
        <Info label="Total Compensations" value={`$${Number(plan.total_compensations).toLocaleString()}`} />
        <Info label="Estimated Cost" value={`$${Number(plan.estimated_cost).toLocaleString()}`} />
      </div>

      {/* Negotiation Log */}
      <div className="bg-white rounded-xl border p-5">
        <h2 className="font-semibold mb-4">Negotiation Log ({negotiationLog.length} steps)</h2>
        <div className="space-y-2">
          {negotiationLog.map((step, i) => (
            <div key={i} className="flex items-start gap-4 p-3 bg-gray-50 rounded-lg">
              <div className="flex-shrink-0 w-8 h-8 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center text-xs font-bold">
                {i + 1}
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-0.5">
                  <AgentBadge agent={step.agent} />
                  <span className="text-xs text-gray-400">
                    {step.timestamp ? new Date(step.timestamp).toLocaleTimeString() : ''}
                  </span>
                </div>
                <p className="text-sm font-medium">{step.action}</p>
                {step.result && <p className="text-sm text-gray-600 mt-0.5">{step.result}</p>}
              </div>
            </div>
          ))}
          {negotiationLog.length === 0 && <p className="text-gray-400 text-sm">No negotiation log available.</p>}
        </div>
      </div>
    </div>
  );
}

function AgentBadge({ agent }) {
  const colors = {
    Orchestrator: 'bg-purple-100 text-purple-700',
    DisruptionService: 'bg-orange-100 text-orange-700',
    CrewService: 'bg-blue-100 text-blue-700',
    PassengerService: 'bg-green-100 text-green-700',
    LogisticsService: 'bg-yellow-100 text-yellow-700',
  };
  return (
    <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${colors[agent] || 'bg-gray-100 text-gray-700'}`}>
      {agent}
    </span>
  );
}

function Info({ label, value, mono, link, badge }) {
  return (
    <div className="bg-white rounded-xl border p-3">
      <p className="text-xs text-gray-500">{label}</p>
      {link ? (
        <Link to={link} className="text-sm font-medium text-blue-600 hover:underline mt-1 block">{value}</Link>
      ) : badge ? (
        <div className="mt-1"><StatusBadge value={value} /></div>
      ) : (
        <p className={`text-sm font-medium mt-1 ${mono ? 'font-mono text-xs break-all' : ''}`}>{value}</p>
      )}
    </div>
  );
}

function Spinner() {
  return <div className="flex justify-center py-12"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
}
