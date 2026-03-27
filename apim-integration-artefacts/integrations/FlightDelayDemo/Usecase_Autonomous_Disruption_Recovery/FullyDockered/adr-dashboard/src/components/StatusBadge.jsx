const colors = {
  SCHEDULED:   'bg-blue-100 text-blue-800',
  UNSCHEDULED: 'bg-gray-200 text-gray-700',
  DELAYED:     'bg-yellow-100 text-yellow-800',
  BOARDING:    'bg-green-100 text-green-800',
  DEPARTED:    'bg-indigo-100 text-indigo-800',
  CANCELLED:   'bg-red-100 text-red-800',
  DETECTED:    'bg-orange-100 text-orange-800',
  RESOLVED:    'bg-green-100 text-green-800',
  RECOVERY_IN_PROGRESS: 'bg-purple-100 text-purple-800',
  AVAILABLE:   'bg-green-100 text-green-800',
  ON_DUTY:     'bg-blue-100 text-blue-800',
  OFF_DUTY:    'bg-gray-100 text-gray-800',
  ASSIGNED:    'bg-blue-100 text-blue-800',
  REASSIGNED:  'bg-orange-100 text-orange-800',
  CONFIRMED:   'bg-green-100 text-green-800',
  CHECKED_IN:  'bg-teal-100 text-teal-800',
  REBOOKED:    'bg-purple-100 text-purple-800',
  OCCUPIED:    'bg-yellow-100 text-yellow-800',
  MAINTENANCE: 'bg-red-100 text-red-800',
  COMPLETED:   'bg-green-100 text-green-800',
  PENDING:     'bg-yellow-100 text-yellow-800',
  IN_PROGRESS: 'bg-blue-100 text-blue-800',
  SENT:        'bg-green-100 text-green-800',
  PREPARING:   'bg-yellow-100 text-yellow-800',
  READY:       'bg-green-100 text-green-800',
  REDIRECTED:  'bg-purple-100 text-purple-800',
  CRITICAL:    'bg-red-100 text-red-800',
  HIGH:        'bg-orange-100 text-orange-800',
  MEDIUM:      'bg-yellow-100 text-yellow-800',
  LOW:         'bg-blue-100 text-blue-800',
  PLATINUM:    'bg-violet-100 text-violet-800',
  GOLD:        'bg-amber-100 text-amber-800',
  SILVER:      'bg-slate-100 text-slate-600',
  STANDARD:    'bg-gray-100 text-gray-600',
};

export default function StatusBadge({ value }) {
  if (!value) return null;
  const cls = colors[value] || 'bg-gray-100 text-gray-700';
  return (
    <span className={`inline-block px-2 py-0.5 rounded-full text-xs font-medium ${cls}`}>
      {value}
    </span>
  );
}
