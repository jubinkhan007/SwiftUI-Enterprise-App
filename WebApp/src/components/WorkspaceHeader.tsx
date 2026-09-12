import React from 'react';
import { Building2, LogOut, Shield } from 'lucide-react';
import { UserDTO } from '../types';

interface WorkspaceHeaderProps {
  title?: string;
  subtitle?: string;
  currentUser?: UserDTO | null;
  onLogout?: () => void;
}

export const WorkspaceHeader: React.FC<WorkspaceHeaderProps> = ({
  title = "Acme Corp",
  subtitle = "Pro Tier Workspace",
  currentUser,
  onLogout,
}) => {
  return (
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
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-full bg-indigo-600/30 border border-indigo-500/40 flex items-center justify-center text-xs font-bold text-indigo-300">
              {currentUser.displayName.slice(0, 2).toUpperCase()}
            </div>
            <span className="text-xs font-medium text-slate-300 hidden sm:inline">
              {currentUser.displayName}
            </span>
          </div>

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
  );
};
