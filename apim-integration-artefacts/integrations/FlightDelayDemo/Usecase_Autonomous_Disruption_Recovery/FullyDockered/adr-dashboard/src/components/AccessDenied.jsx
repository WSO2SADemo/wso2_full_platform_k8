/**
 * Displayed when a user navigates to a page they don't have group-based
 * authorization for. The page is still visible in the sidebar so users
 * know the feature exists — they just can't use it.
 */
export default function AccessDenied({ title, requiredGroup, icon = '🔒' }) {
  return (
    <div className="flex flex-col items-center justify-center h-[calc(100vh-8rem)] text-center px-4">
      <div className="text-6xl mb-6">{icon}</div>
      <h1 className="text-2xl font-bold text-slate-800 mb-2">Access Denied</h1>
      <p className="text-slate-500 max-w-md mb-4">
        You don't have permission to access <strong>{title}</strong>.
      </p>
      <p className="text-sm text-slate-400">
        This feature requires the <code className="bg-slate-100 px-1.5 py-0.5 rounded text-slate-600">{requiredGroup}</code> group.
        Please contact your administrator if you need access.
      </p>
    </div>
  );
}
