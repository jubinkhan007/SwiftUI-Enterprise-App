import React, { useState } from 'react';
import { Building2, LogOut, UserRound, X } from 'lucide-react';
import { UserDTO } from '../types';
import { api } from '../services/api';

interface WorkspaceHeaderProps {
  title?: string;
  subtitle?: string;
  currentUser?: UserDTO | null;
  onLogout?: () => void;
  onProfileSaved?: (user: UserDTO) => void;
  onOpenSyncCenter?: () => void;
  isLive?: boolean;
}

export const WorkspaceHeader: React.FC<WorkspaceHeaderProps> = ({
  title = "Acme Corp",
  subtitle = "Pro Tier Workspace",
  currentUser,
  onLogout,
  onProfileSaved,
  onOpenSyncCenter,
  isLive = true,
}) => {
  const [showProfile, setShowProfile] = useState(false);
  const [displayName, setDisplayName] = useState(currentUser?.displayName || '');
  const [email, setEmail] = useState(currentUser?.email || '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const saveProfile = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!displayName.trim() || !email.includes('@')) {
      setError('Enter a valid name and email address.');
      return;
    }
    setSaving(true);
    setError('');
    try {
      const user = await api.updateProfile(displayName, email);
      onProfileSaved?.(user);
      setShowProfile(false);
    } catch (err: any) {
      setError(err?.message || 'Unable to update profile.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
    <header className="h-14 bg-slate-900/80 border-b border-slate-800 px-6 flex items-center justify-between shrink-0 backdrop-blur-md z-20">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-indigo-600 to-teal-500 flex items-center justify-center shadow-md shadow-indigo-500/20">
          <Building2 className="w-4 h-4 text-white" />
        </div>
        <div className="flex flex-col">
          <span className="text-sm font-bold text-slate-100 leading-tight">{title}</span>
          <span className="text-[11px] font-semibold text-teal-400 leading-tight">{subtitle}</span>
        </div>
      </div>

      {currentUser && (
        <div className="flex items-center gap-3">
          <button
            onClick={onOpenSyncCenter}
            className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-slate-800/80 hover:bg-slate-750 border border-slate-700/60 transition text-xs font-medium"
            title="Open Sync Center"
          >
            <span
              className={`w-2 h-2 rounded-full ${
                isLive ? 'bg-emerald-500 animate-pulse' : 'bg-amber-500'
              }`}
            />
            <span className="text-slate-300 text-[11px] font-semibold">
              {isLive ? 'Live' : 'Offline'}
            </span>
          </button>

          <button
            onClick={() => {
              setDisplayName(currentUser.displayName);
              setEmail(currentUser.email);
              setError('');
              setShowProfile(true);
            }}
            className="flex items-center gap-2 rounded-lg px-2 py-1 hover:bg-slate-800 transition"
            title="Profile"
          >
            <div className="w-7 h-7 rounded-full bg-indigo-600/30 border border-indigo-500/40 flex items-center justify-center text-xs font-bold text-indigo-300">
              {currentUser.displayName.slice(0, 2).toUpperCase()}
            </div>
            <span className="text-xs font-medium text-slate-300 hidden sm:inline">
              {currentUser.displayName}
            </span>
          </button>

          {onLogout && (
            <button
              onClick={onLogout}
              className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-800 transition"
              title="Sign Out"
            >
              <LogOut className="w-4 h-4" />
            </button>
          )}
        </div>
      )}
    </header>
    {showProfile && currentUser && (
      <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
        <form onSubmit={saveProfile} className="w-full max-w-md rounded-2xl border border-slate-700 bg-slate-900 p-6 shadow-2xl">
          <div className="flex items-center justify-between border-b border-slate-800 pb-4">
            <div className="flex items-center gap-3">
              <UserRound className="h-5 w-5 text-indigo-400" />
              <h2 className="text-base font-bold text-slate-100">Profile</h2>
            </div>
            <button type="button" onClick={() => setShowProfile(false)} className="text-slate-400 hover:text-white" title="Close">
              <X className="h-5 w-5" />
            </button>
          </div>
          <div className="space-y-4 py-5">
            <label className="block">
              <span className="mb-1 block text-xs font-semibold text-slate-400">Full name</span>
              <input value={displayName} onChange={e => setDisplayName(e.target.value)} className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-indigo-500" />
            </label>
            <label className="block">
              <span className="mb-1 block text-xs font-semibold text-slate-400">Email</span>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)} className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-100 outline-none focus:border-indigo-500" />
            </label>
            {error && <p className="text-xs text-rose-400">{error}</p>}
          </div>
          <div className="flex justify-end gap-2">
            <button type="button" onClick={() => setShowProfile(false)} className="rounded-lg px-3 py-2 text-xs font-semibold text-slate-400 hover:bg-slate-800">Cancel</button>
            <button type="submit" disabled={saving} className="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-bold text-white hover:bg-indigo-500 disabled:opacity-50">
              {saving ? 'Saving...' : 'Save'}
            </button>
          </div>
        </form>
      </div>
    )}
    </>
  );
};
