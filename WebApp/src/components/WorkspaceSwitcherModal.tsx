import React, { useState, useEffect } from 'react';
import { WorkspaceDTO } from '../types';
import { api } from '../services/api';
import { 
  Building2, 
  CheckCircle2, 
  Plus, 
  Search, 
  X, 
  ArrowRight, 
  KeyRound,
  Sparkles
} from 'lucide-react';

interface WorkspaceSwitcherModalProps {
  isOpen: boolean;
  onClose: () => void;
  onWorkspaceSelected?: (workspace: WorkspaceDTO) => void;
}

export const WorkspaceSwitcherModal: React.FC<WorkspaceSwitcherModalProps> = ({
  isOpen,
  onClose,
  onWorkspaceSelected,
}) => {
  const [workspaces, setWorkspaces] = useState<WorkspaceDTO[]>([]);
  const [activeOrgId, setActiveOrgId] = useState<string | null>(localStorage.getItem('taskflow_org_id') || 'org-a');
  const [loading, setLoading] = useState(false);

  // Sub-modal states
  const [mode, setMode] = useState<'list' | 'join' | 'create'>('list');

  // Search & Join state
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<WorkspaceDTO[]>([]);
  const [searchLoading, setSearchLoading] = useState(false);
  const [inviteCode, setInviteCode] = useState('');
  const [joinStatus, setJoinStatus] = useState<string | null>(null);

  // Create state
  const [newWorkspaceName, setNewWorkspaceName] = useState('');
  const [createLoading, setCreateLoading] = useState(false);

  useEffect(() => {
    if (isOpen) {
      setMode('list');
      setLoading(true);
      api.getWorkspaces()
        .then(res => setWorkspaces(res))
        .catch(err => {
          console.warn('Fallback default workspace:', err);
          setWorkspaces([
            { id: 'org-a', name: 'Acme Workspace', subscriptionTier: 'pro', memberCount: 12, currentUserRole: 'owner' },
            { id: 'org-b', name: 'Stark Industries', subscriptionTier: 'enterprise', memberCount: 45, currentUserRole: 'member' }
          ]);
        })
        .finally(() => setLoading(false));
    }
  }, [isOpen]);

  const handleSelectWorkspace = (ws: WorkspaceDTO) => {
    setActiveOrgId(ws.id);
    api.setOrgId(ws.id);
    onWorkspaceSelected?.(ws);
    onClose();
  };

  const handleSearch = async (q: string) => {
    setSearchQuery(q);
    if (!q.trim()) {
      setSearchResults([]);
      return;
    }
    setSearchLoading(true);
    try {
      const results = await api.searchWorkspaces(q.trim());
      setSearchResults(results);
    } catch {
      // Mock search results fallback
      setSearchResults([
        { id: 'org-external-1', name: `${q.trim()} Global Technologies`, subscriptionTier: 'enterprise', memberCount: 88 },
        { id: 'org-external-2', name: `${q.trim()} Open Source Lab`, subscriptionTier: 'community', memberCount: 14 }
      ]);
    } finally {
      setSearchLoading(false);
    }
  };

  const handleSendJoinRequest = async (orgId: string) => {
    try {
      await api.joinWorkspace(orgId);
      setJoinStatus('Join request sent to workspace admins!');
      setTimeout(() => setJoinStatus(null), 3000);
    } catch (err: any) {
      alert(`Join failed: ${err.message}`);
    }
  };

  const handleJoinWithCode = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!inviteCode.trim()) return;
    try {
      await api.joinWorkspace('org-code', inviteCode.trim());
      alert('Joined workspace successfully!');
      setInviteCode('');
      setMode('list');
    } catch (err: any) {
      alert(`Failed to join with code: ${err.message}`);
    }
  };

  const handleCreateSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newWorkspaceName.trim()) return;
    setCreateLoading(true);
    try {
      const created = await api.createWorkspace(newWorkspaceName.trim());
      setWorkspaces(prev => [...prev, created]);
      handleSelectWorkspace(created);
    } catch (err: any) {
      alert(`Failed to create workspace: ${err.message}`);
    } finally {
      setCreateLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col">
        {/* Modal Header */}
        <div className="p-6 border-b border-slate-800/80 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-indigo-600 to-teal-500 flex items-center justify-center text-white shadow-md">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base font-bold text-slate-100">
                {mode === 'list' && 'Workspaces'}
                {mode === 'join' && 'Join Workspace'}
                {mode === 'create' && 'Create Workspace'}
              </h2>
              <p className="text-xs text-slate-400">
                {mode === 'list' && 'Switch between workspaces or discover new teams'}
                {mode === 'join' && 'Search organizations or enter an invite code'}
                {mode === 'create' && 'Set up a new organization workspace'}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-6 space-y-4">
          {mode === 'list' && (
            <>
              {loading ? (
                <div className="py-12 text-center text-slate-400 text-xs">Loading workspaces...</div>
              ) : (
                <div className="space-y-2 max-h-72 overflow-y-auto">
                  {workspaces.map(ws => {
                    const isActive = activeOrgId === ws.id;
                    return (
                      <div
                        key={ws.id}
                        onClick={() => handleSelectWorkspace(ws)}
                        className={`p-3.5 rounded-2xl border transition cursor-pointer flex items-center justify-between ${
                          isActive
                            ? 'bg-indigo-600/20 border-indigo-500/50 shadow-md shadow-indigo-600/10'
                            : 'bg-slate-950/60 border-slate-800/80 hover:bg-slate-800/50 text-slate-300'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-lg bg-slate-800 flex items-center justify-center text-xs font-bold text-indigo-400 border border-slate-700">
                            {ws.name.slice(0, 2).toUpperCase()}
                          </div>
                          <div>
                            <div className="flex items-center gap-2">
                              <span className="text-sm font-bold text-slate-100">{ws.name}</span>
                              {ws.subscriptionTier && (
                                <span className="text-[10px] px-1.5 py-0.5 rounded-md bg-teal-500/10 text-teal-400 font-semibold border border-teal-500/20 capitalize">
                                  {ws.subscriptionTier}
                                </span>
                              )}
                            </div>
                            <span className="text-[11px] text-slate-400">
                              {ws.currentUserRole ? `Role: ${ws.currentUserRole}` : 'Active Workspace'}
                            </span>
                          </div>
                        </div>

                        {isActive && (
                          <CheckCircle2 className="w-5 h-5 text-teal-400" />
                        )}
                      </div>
                    );
                  })}
                </div>
              )}

              {/* Action Buttons */}
              <div className="pt-3 border-t border-slate-800/80 grid grid-cols-2 gap-3">
                <button
                  onClick={() => setMode('join')}
                  className="py-2.5 px-3 rounded-xl bg-slate-800/80 hover:bg-slate-800 text-slate-200 border border-slate-700/80 text-xs font-semibold flex items-center justify-center gap-2 transition cursor-pointer"
                >
                  <Search className="w-4 h-4 text-indigo-400" />
                  Join Workspace
                </button>
                <button
                  onClick={() => setMode('create')}
                  className="py-2.5 px-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold flex items-center justify-center gap-2 transition shadow-lg shadow-indigo-600/20 cursor-pointer"
                >
                  <Plus className="w-4 h-4" />
                  New Workspace
                </button>
              </div>
            </>
          )}

          {mode === 'join' && (
            <div className="space-y-4">
              {joinStatus && (
                <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 text-xs font-semibold flex items-center gap-2">
                  <CheckCircle2 className="w-4 h-4 shrink-0" />
                  {joinStatus}
                </div>
              )}

              {/* Search Workspaces */}
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Search Workspace Directory
                </label>
                <div className="relative">
                  <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    placeholder="Search by workspace name..."
                    value={searchQuery}
                    onChange={(e) => handleSearch(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-3 py-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  />
                </div>
              </div>

              {searchResults.length > 0 && (
                <div className="space-y-2 max-h-48 overflow-y-auto">
                  {searchResults.map(res => (
                    <div
                      key={res.id}
                      className="p-3 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between"
                    >
                      <div>
                        <span className="text-xs font-bold text-slate-200 block">{res.name}</span>
                        <span className="text-[11px] text-slate-400">Public Organization</span>
                      </div>
                      <button
                        onClick={() => handleSendJoinRequest(res.id)}
                        className="px-3 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold flex items-center gap-1 cursor-pointer transition"
                      >
                        Request to Join
                      </button>
                    </div>
                  ))}
                </div>
              )}

              {/* Join with Invite Code */}
              <form onSubmit={handleJoinWithCode} className="pt-3 border-t border-slate-800 space-y-2">
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block">
                  Or Join with Invite Code
                </label>
                <div className="flex items-center gap-2">
                  <div className="relative flex-1">
                    <KeyRound className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
                    <input
                      type="text"
                      placeholder="e.g. INV-9821-X"
                      value={inviteCode}
                      onChange={(e) => setInviteCode(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-3 py-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 font-mono"
                    />
                  </div>
                  <button
                    type="submit"
                    disabled={!inviteCode.trim()}
                    className="px-4 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition disabled:opacity-50 cursor-pointer"
                  >
                    Join
                  </button>
                </div>
              </form>

              <button
                type="button"
                onClick={() => setMode('list')}
                className="w-full py-2 text-center text-xs text-slate-400 hover:text-slate-200 cursor-pointer"
              >
                ← Back to Workspaces
              </button>
            </div>
          )}

          {mode === 'create' && (
            <form onSubmit={handleCreateSubmit} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Workspace Name
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Acme Engineering or Quantum Labs"
                  value={newWorkspaceName}
                  onChange={(e) => setNewWorkspaceName(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                />
              </div>

              <div className="pt-2 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setMode('list')}
                  className="px-4 py-2 text-xs font-semibold text-slate-400 hover:text-slate-200 cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createLoading || !newWorkspaceName.trim()}
                  className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition shadow-lg shadow-indigo-600/30 cursor-pointer disabled:opacity-50"
                >
                  {createLoading ? 'Creating...' : 'Create Workspace'}
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};
