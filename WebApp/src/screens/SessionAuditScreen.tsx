import React, { useEffect, useMemo, useState } from 'react';
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
  CheckCircle2,
  XCircle,
  Search,
  LogOut,
  Users
} from 'lucide-react';

type RoleKey = 'owner' | 'admin' | 'manager' | 'member' | 'viewer' | 'guest';

const ROLE_ORDER: RoleKey[] = ['owner', 'admin', 'manager', 'member', 'viewer', 'guest'];

const ROLE_META: Record<RoleKey, { label: string; badge: string; summary: string }> = {
  owner: {
    label: 'Owner',
    badge: 'bg-purple-500/20 text-purple-300 border-purple-500/30',
    summary: 'Full ownership: billing, workspace deletion, and every admin capability.',
  },
  admin: {
    label: 'Admin',
    badge: 'bg-blue-500/20 text-blue-300 border-blue-500/30',
    summary: 'Team management, member roles, workspace settings, and audit log access.',
  },
  manager: {
    label: 'Manager',
    badge: 'bg-amber-500/20 text-amber-300 border-amber-500/30',
    summary: 'Sprint and release planning, inviting teammates, and analytics export.',
  },
  member: {
    label: 'Member',
    badge: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30',
    summary: 'Standard contributor: create and edit tasks, comment, and upload files.',
  },
  viewer: {
    label: 'Viewer',
    badge: 'bg-slate-500/20 text-slate-300 border-slate-500/30',
    summary: 'Read-only visibility into tasks, projects, and analytics.',
  },
  guest: {
    label: 'Guest',
    badge: 'bg-zinc-500/20 text-zinc-400 border-zinc-500/30',
    summary: 'Restricted access to assigned tasks and notifications only.',
  },
};

const PERMISSION_CATEGORIES: { category: string; permissions: string[] }[] = [
  {
    category: 'Tasks',
    permissions: [
      'tasks.read', 'tasks.create', 'tasks.edit', 'tasks.delete', 'tasks.assign',
      'tasks.create_subtask', 'tasks.change_type', 'tasks.relate', 'tasks.manage_checklist',
    ],
  },
  {
    category: 'Saved Views',
    permissions: ['views.create', 'views.update', 'views.delete', 'views.share', 'views.set_default'],
  },
  {
    category: 'Team & Members',
    permissions: ['members.view', 'members.invite', 'members.manage', 'members.remove'],
  },
  {
    category: 'Projects',
    permissions: ['projects.read', 'projects.create', 'projects.edit', 'projects.delete', 'projects.archive'],
  },
  {
    category: 'Agile & Releases',
    permissions: ['sprints.manage', 'releases.manage', 'issues.edit_bug_fields'],
  },
  {
    category: 'Analytics & Reports',
    permissions: ['analytics.view', 'analytics.export', 'reports.export'],
  },
  {
    category: 'Collaboration',
    permissions: ['comments.create', 'attachments.upload', 'attachments.download', 'notifications.read'],
  },
  {
    category: 'Workspace Settings',
    permissions: ['org.settings', 'org.delete', 'audit_log.view'],
  },
];

const ALL_PERMISSIONS = PERMISSION_CATEGORIES.flatMap(c => c.permissions);
const TASK_CORE = [
  'tasks.read', 'tasks.create', 'tasks.edit', 'tasks.assign',
  'tasks.create_subtask', 'tasks.change_type', 'tasks.relate', 'tasks.manage_checklist',
];
const COLLAB = ['comments.create', 'attachments.upload', 'attachments.download', 'notifications.read'];

const ROLE_PERMISSIONS: Record<RoleKey, Set<string>> = {
  guest: new Set(['tasks.read', 'members.view', 'notifications.read']),
  viewer: new Set(['tasks.read', 'members.view', 'projects.read', 'analytics.view', 'attachments.download', 'notifications.read']),
  member: new Set([...TASK_CORE, ...COLLAB, 'views.create', 'views.update', 'views.delete', 'members.view', 'projects.read', 'analytics.view']),
  manager: new Set([
    ...TASK_CORE, ...COLLAB, 'tasks.delete',
    'views.create', 'views.update', 'views.delete', 'views.share', 'views.set_default',
    'members.view', 'members.invite',
    'projects.read', 'projects.create', 'projects.edit',
    'analytics.view', 'analytics.export', 'reports.export',
    'sprints.manage', 'releases.manage', 'issues.edit_bug_fields',
  ]),
  admin: new Set([
    ...TASK_CORE, ...COLLAB, 'tasks.delete',
    'views.create', 'views.update', 'views.delete', 'views.share', 'views.set_default',
    'members.view', 'members.invite', 'members.manage', 'members.remove',
    'projects.read', 'projects.create', 'projects.edit', 'projects.delete', 'projects.archive',
    'analytics.view', 'analytics.export', 'reports.export',
    'sprints.manage', 'releases.manage', 'issues.edit_bug_fields',
    'org.settings', 'audit_log.view',
  ]),
  owner: new Set(ALL_PERMISSIONS),
};

function formatPermissionLabel(raw: string): string {
  const action = raw.split('.').pop() || raw;
  const words = action.replace(/_/g, ' ');
  return words.charAt(0).toUpperCase() + words.slice(1);
}

function getSessionAnomalies(session: UserSessionDTO, primaryIp: string | null): string[] {
  const flags: string[] = [];
  const ip = (session.ipAddress || '').trim();
  if (primaryIp && ip && ip !== primaryIp) {
    flags.push('Different IP');
  }
  const ua = (session.userAgent || '').toLowerCase();
  if (!ua || ua.includes('curl') || ua.includes('python') || ua.includes('postman') || ua.includes('bot')) {
    flags.push('CLI / Automated');
  }
  if (session.createdAt) {
    const ageMs = Date.now() - new Date(session.createdAt).getTime();
    if (ageMs > 30 * 24 * 60 * 60 * 1000) {
      flags.push('Stale >30d');
    }
  }
  return flags;
}

export const SessionAuditScreen: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'sessions' | 'rbac'>('sessions');
  const [sessions, setSessions] = useState<UserSessionDTO[]>([]);
  const [loading, setLoading] = useState(true);
  const [revokingOthers, setRevokingOthers] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // RBAC Matrix State
  const [permSearch, setPermSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [compareRoleA, setCompareRoleA] = useState<RoleKey>('admin');
  const [compareRoleB, setCompareRoleB] = useState<RoleKey>('member');
  const [showDiffOnly, setShowDiffOnly] = useState(false);

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

  const primarySessionId = sessions[0]?.id || null;
  const primaryIp = sessions[0]?.ipAddress?.trim() || null;

  const distinctIpCount = useMemo(() => {
    return new Set(sessions.map(s => (s.ipAddress || '').trim()).filter(Boolean)).size;
  }, [sessions]);

  const anomalousCount = useMemo(() => {
    return sessions.filter(s => getSessionAnomalies(s, primaryIp).length > 0).length;
  }, [sessions, primaryIp]);

  const handleRevokeSession = async (sessionId: string) => {
    if (!confirm('Are you sure you want to revoke this active session?')) return;
    try {
      await api.revokeSession(sessionId);
      setSessions(prev => prev.filter(s => s.id !== sessionId));
      setNotice('Session revoked successfully.');
      setTimeout(() => setNotice(null), 3500);
    } catch (err: any) {
      alert(`Failed to revoke session: ${err.message}`);
    }
  };

  const handleRevokeAllOthers = async () => {
    if (sessions.length <= 1) return;
    if (!confirm(`Sign out all ${sessions.length - 1} other active device(s)? Your current session will remain signed in.`)) {
      return;
    }
    setRevokingOthers(true);
    try {
      await api.revokeOtherSessions();
      if (primarySessionId) {
        setSessions(prev => prev.filter(s => s.id === primarySessionId));
      } else {
        await fetchSessions();
      }
      setNotice('All other active sessions have been terminated.');
      setTimeout(() => setNotice(null), 3500);
    } catch (err: any) {
      // Safe fallback to sequential revocation if backend endpoint isn't deployed
      try {
        const others = sessions.filter(s => s.id !== primarySessionId);
        await Promise.all(others.map(s => api.revokeSession(s.id)));
        setSessions(prev => prev.filter(s => s.id === primarySessionId));
        setNotice(`Revoked ${others.length} other active session(s).`);
        setTimeout(() => setNotice(null), 3500);
      } catch (fallbackErr: any) {
        alert(`Failed to revoke other sessions: ${fallbackErr.message || err.message}`);
      }
    } finally {
      setRevokingOthers(false);
    }
  };

  const getDeviceIcon = (deviceType: string) => {
    const dt = (deviceType || '').toLowerCase();
    if (dt.includes('mobile') || dt.includes('phone') || dt.includes('ios') || dt.includes('android')) {
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
            Security, Sessions &amp; RBAC Governance
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Monitor device anomalies, bulk-revoke sessions, and inspect the workspace role permission matrix
          </p>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center bg-slate-900 border border-slate-800 rounded-xl p-1 gap-1">
            <button
              type="button"
              onClick={() => setActiveTab('sessions')}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 transition cursor-pointer ${
                activeTab === 'sessions'
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              <Lock className="w-3.5 h-3.5" />
              Sessions ({sessions.length})
            </button>
            <button
              type="button"
              onClick={() => setActiveTab('rbac')}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 transition cursor-pointer ${
                activeTab === 'rbac'
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              <Users className="w-3.5 h-3.5" />
              Role Permission Matrix
            </button>
          </div>

          {activeTab === 'sessions' && (
            <button
              onClick={fetchSessions}
              className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 transition border border-slate-700 flex items-center gap-2 text-xs font-semibold cursor-pointer"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          )}
        </div>
      </div>

      {notice && (
        <div className="px-6 py-2.5 bg-emerald-950/70 border-b border-emerald-700/40 text-emerald-300 text-xs font-semibold flex items-center justify-between">
          <span>{notice}</span>
          <button onClick={() => setNotice(null)} className="text-emerald-400 hover:text-white">✕</button>
        </div>
      )}

      {/* Main Body */}
      <div className="flex-1 overflow-y-auto p-6 max-w-6xl mx-auto w-full space-y-6">
        {activeTab === 'sessions' ? (
          <>
            {/* User Info & Bulk Action Card */}
            {currentUser && (
              <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 shadow-xl flex flex-wrap items-center justify-between gap-4">
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
                    <p className="text-xs text-slate-400 mt-0.5">{currentUser.email} • Role: <strong className="text-slate-200 capitalize">{currentUser.role || 'member'}</strong></p>
                  </div>
                </div>

                {sessions.length > 1 && (
                  <button
                    type="button"
                    onClick={handleRevokeAllOthers}
                    disabled={revokingOthers}
                    className="px-4 py-2.5 rounded-xl bg-rose-600/20 hover:bg-rose-600/30 text-rose-300 border border-rose-500/40 text-xs font-bold flex items-center gap-2 transition cursor-pointer disabled:opacity-50"
                  >
                    <LogOut className="w-4 h-4" />
                    {revokingOthers ? 'Signing Out...' : `Sign Out All Other Devices (${sessions.length - 1})`}
                  </button>
                )}
              </div>
            )}

            {/* Security Posture KPI Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800">
                <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400">Active Sessions</span>
                <div className="text-2xl font-black text-slate-100 mt-1">{sessions.length}</div>
              </div>
              <div className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800">
                <span className="text-[10px] font-semibold uppercase tracking-wider text-slate-400">Distinct IP Addresses</span>
                <div className="text-2xl font-black text-indigo-400 mt-1">{distinctIpCount}</div>
              </div>
              <div className={`p-4 rounded-2xl bg-slate-900/60 border ${anomalousCount > 0 ? 'border-amber-500/40' : 'border-emerald-500/30'}`}>
                <span className={`text-[10px] font-semibold uppercase tracking-wider ${anomalousCount > 0 ? 'text-amber-400' : 'text-emerald-400'}`}>
                  Device Anomaly Alerts
                </span>
                <div className={`text-2xl font-black mt-1 ${anomalousCount > 0 ? 'text-amber-300' : 'text-emerald-400'}`}>
                  {anomalousCount}
                </div>
              </div>
            </div>

            {/* Anomaly Alert Banner */}
            {anomalousCount > 0 && (
              <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
                  <div>
                    <h4 className="text-xs font-bold text-amber-300">
                      {anomalousCount} Session Anomaly Alert{anomalousCount === 1 ? '' : 's'} Detected
                    </h4>
                    <p className="text-xs text-slate-300 mt-0.5">
                      One or more logins originate from a different IP address, automated/CLI user agent, or have been active for more than 30 days.
                    </p>
                  </div>
                </div>
                {sessions.length > 1 && (
                  <button
                    type="button"
                    onClick={handleRevokeAllOthers}
                    disabled={revokingOthers}
                    className="px-3 py-1.5 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs transition cursor-pointer"
                  >
                    Revoke Suspicious / Other Devices
                  </button>
                )}
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
                  {sessions.map(session => {
                    const anomalies = getSessionAnomalies(session, primaryIp);
                    const isPrimary = session.id === primarySessionId;
                    return (
                      <div
                        key={session.id}
                        className={`bg-slate-900/60 border rounded-2xl p-4 flex items-center justify-between gap-4 transition ${
                          anomalies.length > 0
                            ? 'border-amber-500/40 hover:border-amber-500/70'
                            : 'border-slate-800 hover:border-slate-700'
                        }`}
                      >
                        <div className="flex items-center gap-4 min-w-0">
                          <div className={`p-3 rounded-xl border shrink-0 ${
                            anomalies.length > 0
                              ? 'bg-amber-500/10 border-amber-500/30'
                              : 'bg-slate-800/80 border-slate-700/60'
                          }`}>
                            {getDeviceIcon(session.deviceType)}
                          </div>

                          <div className="min-w-0">
                            <div className="flex items-center gap-2 mb-1 flex-wrap">
                              <h4 className="text-sm font-bold text-slate-200 truncate">
                                {session.deviceType}
                              </h4>
                              {isPrimary && (
                                <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-emerald-500/15 text-emerald-300 border border-emerald-500/30">
                                  CURRENT SESSION
                                </span>
                              )}
                              <span className="text-[10px] font-mono bg-slate-800 text-slate-300 px-2 py-0.5 rounded">
                                {session.ipAddress}
                              </span>
                              {anomalies.map(flag => (
                                <span
                                  key={flag}
                                  className="text-[10px] font-bold px-2 py-0.5 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30"
                                >
                                  ⚠ {flag}
                                </span>
                              ))}
                            </div>
                            <p className="text-xs text-slate-400 truncate max-w-lg">
                              {session.userAgent}
                            </p>
                            <p className="text-[11px] text-slate-500 mt-0.5">
                              {session.createdAt ? `Signed in ${new Date(session.createdAt).toLocaleString()} • ` : ''}
                              Expires {new Date(session.expiresAt).toLocaleDateString()}
                            </p>
                          </div>
                        </div>

                        <button
                          onClick={() => handleRevokeSession(session.id)}
                          className="p-2.5 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 transition text-xs font-semibold flex items-center gap-1.5 shrink-0 cursor-pointer"
                          title="Revoke session access"
                        >
                          <Trash2 className="w-4 h-4" />
                          <span>Revoke</span>
                        </button>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </>
        ) : (
          /* ===================== ROLE PERMISSION MATRIX (RBAC) ===================== */
          <div className="space-y-5">
            {/* Role Summary Strip */}
            <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2.5">
              {ROLE_ORDER.map(role => {
                const count = ROLE_PERMISSIONS[role].size;
                const isMine = (currentUser?.role || '').toLowerCase() === role;
                return (
                  <div
                    key={role}
                    className={`p-3 rounded-2xl bg-slate-900/70 border ${
                      isMine ? 'border-indigo-500 ring-1 ring-indigo-500/40' : 'border-slate-800'
                    }`}
                  >
                    <div className="flex items-center justify-between gap-1">
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded border uppercase ${ROLE_META[role].badge}`}>
                        {ROLE_META[role].label}
                      </span>
                      {isMine && <span className="text-[9px] font-bold text-indigo-400">YOU</span>}
                    </div>
                    <div className="text-base font-black text-slate-100 mt-2">
                      {count} <span className="text-[11px] font-normal text-slate-500">/ {ALL_PERMISSIONS.length}</span>
                    </div>
                    <p className="text-[10px] text-slate-400 mt-1 line-clamp-2">{ROLE_META[role].summary}</p>
                  </div>
                );
              })}
            </div>

            {/* Filters & Role Comparison Diff Controls */}
            <div className="bg-slate-900/70 border border-slate-800 rounded-2xl p-4 flex flex-wrap items-center justify-between gap-3">
              <div className="relative flex-1 min-w-[220px]">
                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
                <input
                  type="text"
                  placeholder="Search permissions (e.g. audit, sprints, delete)..."
                  value={permSearch}
                  onChange={e => setPermSearch(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                />
              </div>

              <select
                value={selectedCategory}
                onChange={e => setSelectedCategory(e.target.value)}
                className="bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
              >
                <option value="all">All Categories</option>
                {PERMISSION_CATEGORIES.map(c => (
                  <option key={c.category} value={c.category}>{c.category}</option>
                ))}
              </select>

              <div className="flex items-center gap-2 text-xs bg-slate-950 border border-slate-800 rounded-xl px-3 py-1.5">
                <span className="text-slate-400 font-semibold">Diff:</span>
                <select
                  value={compareRoleA}
                  onChange={e => setCompareRoleA(e.target.value as RoleKey)}
                  className="bg-transparent text-indigo-300 font-semibold focus:outline-none"
                >
                  {ROLE_ORDER.map(r => <option key={r} value={r}>{ROLE_META[r].label}</option>)}
                </select>
                <span className="text-slate-500">vs</span>
                <select
                  value={compareRoleB}
                  onChange={e => setCompareRoleB(e.target.value as RoleKey)}
                  className="bg-transparent text-amber-300 font-semibold focus:outline-none"
                >
                  {ROLE_ORDER.map(r => <option key={r} value={r}>{ROLE_META[r].label}</option>)}
                </select>
                <label className="flex items-center gap-1.5 ml-2 pl-2 border-l border-slate-800 text-slate-300 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={showDiffOnly}
                    onChange={e => setShowDiffOnly(e.target.checked)}
                    className="rounded border-slate-700 bg-slate-900"
                  />
                  <span>Differences Only</span>
                </label>
              </div>
            </div>

            {/* 6-Role Permission Matrix Table */}
            <div className="bg-slate-900/60 border border-slate-800 rounded-2xl overflow-hidden shadow-xl">
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-slate-950/80 border-b border-slate-800 text-[11px] uppercase tracking-wider text-slate-400">
                      <th className="py-3 px-4">Permission</th>
                      {ROLE_ORDER.map(role => (
                        <th key={role} className="py-3 px-3 text-center">
                          <span className={`px-2 py-0.5 rounded border text-[10px] font-bold ${ROLE_META[role].badge}`}>
                            {ROLE_META[role].label}
                          </span>
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {PERMISSION_CATEGORIES.filter(c => selectedCategory === 'all' || c.category === selectedCategory).map(cat => {
                      const q = permSearch.trim().toLowerCase();
                      const filtered = cat.permissions.filter(p => {
                        const matchesQuery = !q || p.toLowerCase().includes(q) || formatPermissionLabel(p).toLowerCase().includes(q);
                        if (!matchesQuery) return false;
                        if (showDiffOnly) {
                          return ROLE_PERMISSIONS[compareRoleA].has(p) !== ROLE_PERMISSIONS[compareRoleB].has(p);
                        }
                        return true;
                      });
                      if (filtered.length === 0) return null;

                      return (
                        <React.Fragment key={cat.category}>
                          <tr className="bg-slate-950/50 border-y border-slate-800/80">
                            <td colSpan={ROLE_ORDER.length + 1} className="py-2 px-4 text-[11px] font-bold uppercase tracking-wider text-indigo-300">
                              {cat.category}
                            </td>
                          </tr>
                          {filtered.map(perm => {
                            const hasA = ROLE_PERMISSIONS[compareRoleA].has(perm);
                            const hasB = ROLE_PERMISSIONS[compareRoleB].has(perm);
                            const isDiff = hasA !== hasB;
                            return (
                              <tr
                                key={perm}
                                className={`border-b border-slate-800/50 hover:bg-slate-800/30 transition ${
                                  isDiff && showDiffOnly ? 'bg-amber-500/5' : ''
                                }`}
                              >
                                <td className="py-2.5 px-4">
                                  <div className="flex items-center gap-2">
                                    <div>
                                      <div className="text-xs font-semibold text-slate-200">{formatPermissionLabel(perm)}</div>
                                      <div className="text-[10px] font-mono text-slate-500">{perm}</div>
                                    </div>
                                    {isDiff && (
                                      <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-amber-500/15 text-amber-300 border border-amber-500/30">
                                        DIFF
                                      </span>
                                    )}
                                  </div>
                                </td>
                                {ROLE_ORDER.map(role => {
                                  const allowed = ROLE_PERMISSIONS[role].has(perm);
                                  return (
                                    <td key={role} className="py-2.5 px-3 text-center">
                                      {allowed ? (
                                        <CheckCircle2 className="w-4 h-4 text-emerald-400 mx-auto" />
                                      ) : (
                                        <XCircle className="w-4 h-4 text-slate-700 mx-auto" />
                                      )}
                                    </td>
                                  );
                                })}
                              </tr>
                            );
                          })}
                        </React.Fragment>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
