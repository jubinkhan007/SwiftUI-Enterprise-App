import React, { useEffect, useState } from 'react';
import { UserSessionDTO } from '../types';
import { api } from '../services/api';
import { 
  ShieldCheck, 
  Monitor, 
  Smartphone, 
  Trash2, 
  RefreshCw, 
  AlertTriangle, 
  Lock,
  User
} from 'lucide-react';

export const SessionAuditScreen: React.FC = () => {
  const [sessions, setSessions] = useState<UserSessionDTO[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchSessions = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await api.getSessions();
      setSessions(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load user sessions');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSessions();
  }, []);

  const handleRevokeSession = async (sessionId: string) => {
    if (!confirm('Are you sure you want to revoke this active session?')) return;
    try {
      await api.revokeSession(sessionId);
      setSessions(prev => prev.filter(s => s.id !== sessionId));
    } catch (err: any) {
      alert(`Failed to revoke session: ${err.message}`);
    }
  };

  const getDeviceIcon = (deviceType: string) => {
    if (deviceType.toLowerCase().includes('mobile') || deviceType.toLowerCase().includes('phone') || deviceType.toLowerCase().includes('ios') || deviceType.toLowerCase().includes('android')) {
      return <Smartphone className="w-5 h-5 text-indigo-400" />;
    }
    return <Monitor className="w-5 h-5 text-indigo-400" />;
  };

  const currentUser = api.currentUser;

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-slate-950 text-slate-100">
      {/* Top Header */}
      <div className="p-6 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
            <ShieldCheck className="w-6 h-6 text-indigo-400" />
            Security & Session Audit
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Review active device sessions and manage authentication access
          </p>
        </div>

        <button
          onClick={fetchSessions}
          className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 transition border border-slate-700 flex items-center gap-2 text-xs font-semibold"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh Sessions
        </button>
      </div>

      {/* Main Body */}
      <div className="flex-1 overflow-y-auto p-6 max-w-4xl mx-auto w-full space-y-6">
        {/* User Info Card */}
        {currentUser && (
          <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-6 shadow-xl flex items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-bold text-base shadow-lg">
                {currentUser.displayName.slice(0, 2).toUpperCase()}
              </div>
              <div>
                <h2 className="text-base font-bold text-slate-100 flex items-center gap-2">
                  {currentUser.displayName}
                  {currentUser.isSuperAdmin && (
                    <span className="text-[10px] font-semibold uppercase tracking-wider bg-amber-500/20 text-amber-300 border border-amber-500/30 px-2 py-0.5 rounded-md">
                      Super Admin
                    </span>
                  )}
                </h2>
                <p className="text-xs text-slate-400 mt-0.5">{currentUser.email}</p>
              </div>
            </div>

            <div className="text-right text-xs text-slate-400">
              <span className="font-semibold text-slate-200">Role:</span> {currentUser.role || 'Member'}
            </div>
          </div>
        )}

        {/* Sessions Section */}
        <div>
          <h3 className="text-sm font-bold text-slate-200 uppercase tracking-wider mb-4 flex items-center gap-2">
            <Lock className="w-4 h-4 text-indigo-400" />
            Active Device Sessions ({sessions.length})
          </h3>

          {loading && sessions.length === 0 ? (
            <div className="flex items-center justify-center h-48 text-slate-400 gap-3">
              <RefreshCw className="w-6 h-6 animate-spin text-indigo-400" />
              <span>Fetching sessions...</span>
            </div>
          ) : error ? (
            <div className="p-4 rounded-xl bg-red-950/40 border border-red-800 text-red-300 text-sm">
              {error}
            </div>
          ) : sessions.length === 0 ? (
            <div className="border border-dashed border-slate-800 rounded-2xl p-8 text-center text-slate-500 text-sm">
              No active sessions found.
            </div>
          ) : (
            <div className="space-y-3">
              {sessions.map(session => (
                <div
                  key={session.id}
                  className="bg-slate-900/60 border border-slate-800 rounded-2xl p-4 flex items-center justify-between gap-4 transition hover:border-slate-700"
                >
                  <div className="flex items-center gap-4 min-w-0">
                    <div className="p-3 rounded-xl bg-slate-800/80 border border-slate-700/60 shrink-0">
                      {getDeviceIcon(session.deviceType)}
                    </div>

                    <div className="min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <h4 className="text-sm font-bold text-slate-200 truncate">
                          {session.deviceType}
                        </h4>
                        <span className="text-[10px] font-mono bg-slate-800 text-slate-300 px-2 py-0.5 rounded">
                          {session.ipAddress}
                        </span>
                      </div>
                      <p className="text-xs text-slate-400 truncate max-w-md">
                        {session.userAgent}
                      </p>
                    </div>
                  </div>

                  <button
                    onClick={() => handleRevokeSession(session.id)}
                    className="p-2.5 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 transition text-xs font-semibold flex items-center gap-1.5 shrink-0"
                    title="Revoke session access"
                  >
                    <Trash2 className="w-4 h-4" />
                    <span>Revoke</span>
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
