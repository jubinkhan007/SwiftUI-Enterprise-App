import React, { useState, useEffect } from 'react';
import {
  RefreshCw,
  AlertTriangle,
  CheckCircle2,
  Clock,
  Trash2,
  Check,
  X,
  Layers,
  ArrowRight,
} from 'lucide-react';
import { syncEngine, LocalSyncOperation } from '../services/syncEngine';

interface SyncCenterModalProps {
  isOpen: boolean;
  onClose: () => void;
  isLive?: boolean;
}

export const SyncCenterModal: React.FC<SyncCenterModalProps> = ({
  isOpen,
  onClose,
  isLive = true,
}) => {
  const [pendingOps, setPendingOps] = useState<LocalSyncOperation[]>([]);
  const [attentionOps, setAttentionOps] = useState<LocalSyncOperation[]>([]);
  const [isSyncing, setIsSyncing] = useState(false);
  const [lastSyncedText, setLastSyncedText] = useState('Just now');

  useEffect(() => {
    const update = () => {
      setPendingOps(syncEngine.getPendingOperations());
      setAttentionOps(syncEngine.getAttentionOperations());
      setIsSyncing(syncEngine.isSyncing());
    };

    update();
    const unsub = syncEngine.subscribe(update);
    return unsub;
  }, []);

  if (!isOpen) return null;

  const handleSyncNow = async () => {
    await syncEngine.syncNow(() => {
      setLastSyncedText('Just now');
    });
  };

  const getStatusBadge = () => {
    if (isSyncing) {
      return {
        text: `Syncing (${pendingOps.length})`,
        color: 'bg-blue-500',
        textColor: 'text-blue-400',
      };
    }
    if (attentionOps.length > 0) {
      return {
        text: 'Attention Needed',
        color: 'bg-red-500',
        textColor: 'text-red-400',
      };
    }
    if (isLive) {
      return {
        text: 'Online',
        color: 'bg-emerald-500',
        textColor: 'text-emerald-400',
      };
    }
    return {
      text: 'Offline',
      color: 'bg-amber-500',
      textColor: 'text-amber-400',
    };
  };

  const status = getStatusBadge();

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-fadeIn">
      <div className="bg-slate-900 border border-slate-800 w-full max-w-lg rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[85vh]">
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-900/50">
          <div className="flex items-center gap-2">
            <RefreshCw className={`w-5 h-5 text-indigo-400 ${isSyncing ? 'animate-spin' : ''}`} />
            <h2 className="text-lg font-bold text-white tracking-tight">Sync Center</h2>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handleSyncNow}
              disabled={isSyncing}
              className="px-3 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-semibold text-xs transition flex items-center gap-1.5 shadow-sm shadow-indigo-600/30"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin' : ''}`} />
              Sync Now
            </button>
            <button
              onClick={onClose}
              className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto space-y-5 flex-1">
          {/* Status Card */}
          <div className="p-4 rounded-xl bg-slate-800/60 border border-slate-750 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className={`w-2.5 h-2.5 rounded-full ${status.color} animate-pulse`} />
                <span className={`text-sm font-bold ${status.textColor}`}>{status.text}</span>
              </div>
              <span className="text-xs text-slate-400">Last: {lastSyncedText}</span>
            </div>
            <div className="border-t border-slate-700/60 pt-2.5 grid grid-cols-2 gap-2 text-xs">
              <div className="flex items-center justify-between text-slate-300">
                <span className="text-slate-400">Pending Operations:</span>
                <span className="font-semibold text-white">{pendingOps.length}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-slate-400">Needs Attention:</span>
                <span
                  className={`font-semibold ${
                    attentionOps.length > 0 ? 'text-red-400' : 'text-slate-300'
                  }`}
                >
                  {attentionOps.length}
                </span>
              </div>
            </div>
          </div>

          {/* Needs Attention Section (Conflicts & Retries) */}
          {attentionOps.length > 0 && (
            <div className="space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-red-400">
                <AlertTriangle className="w-4 h-4" />
                <span>Needs Attention</span>
              </div>
              <div className="space-y-2.5">
                {attentionOps.map((op) => (
                  <div
                    key={op.id}
                    className="p-4 rounded-xl bg-red-950/20 border border-red-800/40 space-y-3"
                  >
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-bold text-red-300 tracking-wider">
                        {op.operation} {op.entityType.toUpperCase()}
                      </span>
                      <span className="font-mono text-slate-500">{op.entityId.slice(0, 8)}</span>
                    </div>

                    {op.lastError && (
                      <p className="text-xs text-red-200/90 leading-relaxed">{op.lastError}</p>
                    )}

                    {/* Conflict Resolution Buttons */}
                    <div className="flex items-center gap-2 pt-1">
                      {op.remoteSnapshot ? (
                        <>
                          <button
                            onClick={() => syncEngine.resolveConflictUseTheirs(op)}
                            className="flex-1 py-1.5 px-3 rounded-lg bg-slate-800 hover:bg-slate-750 text-slate-200 text-xs font-semibold border border-slate-700 transition"
                          >
                            Use Theirs
                          </button>
                          <button
                            onClick={() => syncEngine.resolveConflictKeepMine(op)}
                            className="flex-1 py-1.5 px-3 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold transition shadow-sm shadow-indigo-600/30"
                          >
                            Keep Mine
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            onClick={() => syncEngine.retry(op)}
                            className="flex-1 py-1.5 px-3 rounded-lg bg-slate-800 hover:bg-slate-750 text-slate-200 text-xs font-semibold border border-slate-700 transition"
                          >
                            Retry
                          </button>
                          <button
                            onClick={() => syncEngine.discard(op)}
                            className="flex-1 py-1.5 px-3 rounded-lg bg-red-700/80 hover:bg-red-600 text-white text-xs font-semibold transition"
                          >
                            Discard
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Pending Operations Section */}
          {pendingOps.length > 0 && (
            <div className="space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-slate-200">
                <Layers className="w-4 h-4 text-indigo-400" />
                <span>Pending Operations</span>
              </div>
              <div className="p-2 rounded-xl bg-slate-800/40 border border-slate-750 divide-y divide-slate-800">
                {pendingOps.map((op) => (
                  <div key={op.id} className="py-2.5 px-3 flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-slate-200">
                        {op.operation} {op.entityType.toUpperCase()}
                      </span>
                    </div>
                    <span className="font-mono text-slate-500">{op.entityId.slice(0, 8)}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {pendingOps.length === 0 && attentionOps.length === 0 && (
            <div className="py-8 text-center space-y-2">
              <div className="w-10 h-10 rounded-full bg-emerald-500/10 text-emerald-400 flex items-center justify-center mx-auto">
                <CheckCircle2 className="w-5 h-5" />
              </div>
              <p className="text-sm font-semibold text-slate-200">All Changes In Sync</p>
              <p className="text-xs text-slate-400">
                Local edits and remote server state are fully synchronized.
              </p>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-slate-800 bg-slate-900/50 flex justify-end">
          <button
            onClick={onClose}
            className="w-full sm:w-auto px-5 py-2 rounded-xl bg-slate-800 hover:bg-slate-750 text-slate-300 font-semibold text-xs border border-slate-700 transition"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
