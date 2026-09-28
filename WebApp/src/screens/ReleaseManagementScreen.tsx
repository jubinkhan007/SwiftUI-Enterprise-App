import React, { useState, useEffect } from 'react';
import {
  Package,
  Plus,
  CheckCircle2,
  Calendar,
  Lock,
  FileText,
  Copy,
  Download,
  Check,
  X,
  AlertCircle,
  FolderKanban,
  Rocket,
  ShieldCheck,
  ChevronRight,
  ExternalLink,
  Layers,
  Bug,
  Sparkles
} from 'lucide-react';
import {
  ReleaseDTO,
  ReleaseProgressDTO,
  ReleaseStatus,
  TaskItemDTO,
  HierarchyTreeDTO,
  NavDestination
} from '../types';
import { api, buildReleaseNotesMarkdown } from '../services/api';

export interface ReleaseManagementScreenProps {
  onNavigate?: (dest: NavDestination) => void;
}

export const ReleaseManagementScreen: React.FC<ReleaseManagementScreenProps> = ({ onNavigate }) => {
  const [hierarchy, setHierarchy] = useState<HierarchyTreeDTO | null>(null);
  const [selectedProjectId, setSelectedProjectId] = useState<string>('');
  const [releases, setReleases] = useState<ReleaseDTO[]>([]);
  const [progressMap, setProgressMap] = useState<Record<string, ReleaseProgressDTO>>({});
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<'all' | ReleaseStatus>('all');

  // Create Release Modal
  const [showCreateModal, setShowCreateModal] = useState<boolean>(false);
  const [newReleaseName, setNewReleaseName] = useState<string>('');
  const [newReleaseDesc, setNewReleaseDesc] = useState<string>('');
  const [newReleaseDate, setNewReleaseDate] = useState<string>(() => {
    const d = new Date();
    d.setDate(d.getDate() + 30);
    return d.toISOString().split('T')[0];
  });
  const [isSubmittingCreate, setIsSubmittingCreate] = useState<boolean>(false);

  // Release Detail & Notes Modal
  const [activeRelease, setActiveRelease] = useState<ReleaseDTO | null>(null);
  const [activeReleaseIssues, setActiveReleaseIssues] = useState<TaskItemDTO[]>([]);
  const [isLoadingIssues, setIsLoadingIssues] = useState<boolean>(false);
  const [detailTab, setDetailTab] = useState<'overview' | 'issues' | 'notes' | 'ship'>('overview');
  const [copiedNotes, setCopiedNotes] = useState<boolean>(false);

  // Finalize / Ship Modal
  const [showShipModal, setShowShipModal] = useState<boolean>(false);
  const [shipLockIssues, setShipLockIssues] = useState<boolean>(true);
  const [isShipping, setIsShipping] = useState<boolean>(false);

  // Load project hierarchy
  useEffect(() => {
    const loadHierarchy = async () => {
      try {
        const tree = await api.getHierarchy();
        setHierarchy(tree);
        const firstSpace = tree.spaces?.[0];
        const firstProj = firstSpace?.projects?.[0]?.project;
        if (firstProj?.id) {
          setSelectedProjectId(firstProj.id);
        }
      } catch (err: any) {
        console.error('Failed to load hierarchy:', err);
        setError(err.message || 'Failed to load project hierarchy');
      }
    };
    loadHierarchy();
  }, []);

  // Load releases and progress for selected project
  const loadReleases = async (projId: string) => {
    if (!projId) return;
    setIsLoading(true);
    setError(null);
    try {
      const list = await api.getProjectReleases(projId);
      setReleases(list);

      // Load progress in parallel for each release
      const progEntries = await Promise.all(
        list.map(async (r) => {
          try {
            const p = await api.getReleaseProgress(r.id);
            return [r.id, p] as const;
          } catch {
            return [r.id, null] as const;
          }
        })
      );

      const nextMap: Record<string, ReleaseProgressDTO> = {};
      for (const [id, p] of progEntries) {
        if (p) nextMap[id] = p;
      }
      setProgressMap(nextMap);
    } catch (err: any) {
      console.error('Failed to load releases:', err);
      setError(err.message || 'Failed to load releases');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (selectedProjectId) {
      loadReleases(selectedProjectId);
    }
  }, [selectedProjectId]);

  // Load issues when active release opens
  const openReleaseDetail = async (release: ReleaseDTO) => {
    setActiveRelease(release);
    setDetailTab('overview');
    setIsLoadingIssues(true);
    try {
      const issues = await api.getReleaseIssues(release.id);
      setActiveReleaseIssues(issues);
    } catch (err) {
      console.error('Failed to load release issues:', err);
      setActiveReleaseIssues([]);
    } finally {
      setIsLoadingIssues(false);
    }
  };

  const handleCreateRelease = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newReleaseName.trim() || !selectedProjectId) return;
    setIsSubmittingCreate(true);
    try {
      await api.createRelease(selectedProjectId, {
        name: newReleaseName.trim(),
        description: newReleaseDesc.trim() || undefined,
        releaseDate: newReleaseDate ? new Date(newReleaseDate).toISOString() : undefined,
      });
      setShowCreateModal(false);
      setNewReleaseName('');
      setNewReleaseDesc('');
      await loadReleases(selectedProjectId);
    } catch (err: any) {
      alert(`Failed to create release: ${err.message || err}`);
    } finally {
      setIsSubmittingCreate(false);
    }
  };

  const handleShipRelease = async () => {
    if (!activeRelease) return;
    setIsShipping(true);
    try {
      const updated = await api.finalizeRelease(activeRelease.id, shipLockIssues);
      setActiveRelease(updated);
      setShowShipModal(false);
      await loadReleases(selectedProjectId);
    } catch (err: any) {
      alert(`Failed to ship release: ${err.message || err}`);
    } finally {
      setIsShipping(false);
    }
  };

  const handleCopyNotes = () => {
    if (!activeRelease) return;
    const progress = progressMap[activeRelease.id] || null;
    const md = buildReleaseNotesMarkdown(activeRelease, progress, activeReleaseIssues);
    navigator.clipboard.writeText(md);
    setCopiedNotes(true);
    setTimeout(() => setCopiedNotes(false), 2000);
  };

  const handleDownloadNotes = () => {
    if (!activeRelease) return;
    const progress = progressMap[activeRelease.id] || null;
    const md = buildReleaseNotesMarkdown(activeRelease, progress, activeReleaseIssues);
    const blob = new Blob([md], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${activeRelease.name.toLowerCase().replace(/\s+/g, '-')}-release-notes.md`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  // Filtered and sorted releases (Unreleased first)
  const filteredReleases = releases
    .filter((r) => statusFilter === 'all' || r.status === statusFilter)
    .sort((lhs, rhs) => {
      if (lhs.status !== rhs.status) return lhs.status === 'unreleased' ? -1 : 1;
      const d1 = lhs.releaseDate ? new Date(lhs.releaseDate).getTime() : Infinity;
      const d2 = rhs.releaseDate ? new Date(rhs.releaseDate).getTime() : Infinity;
      return d1 - d2;
    });

  // Extract all projects from hierarchy
  const allProjects: { id: string; name: string; spaceName: string }[] = [];
  hierarchy?.spaces?.forEach((s) => {
    s.projects?.forEach((p) => {
      allProjects.push({
        id: p.project.id,
        name: p.project.name,
        spaceName: s.space.name,
      });
    });
  });

  return (
    <div className="flex-1 flex flex-col h-full bg-slate-950 text-slate-100 overflow-hidden font-sans">
      {/* Top Header Bar */}
      <header className="px-6 py-4 bg-slate-900/60 border-b border-slate-800/80 backdrop-blur-md flex flex-wrap items-center justify-between gap-4 shrink-0">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-500 to-purple-600 flex items-center justify-center text-white shadow-lg shadow-indigo-500/20">
            <Package className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight text-white flex items-center gap-2">
              Releases & Versions
            </h1>
            <p className="text-xs text-slate-400 font-medium">
              Manage version milestones, scope progress, release notes, and ship readiness
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {/* Project Switcher */}
          <div className="flex items-center gap-2 bg-slate-800/80 px-3 py-1.5 rounded-xl border border-slate-700/60">
            <FolderKanban className="w-4 h-4 text-indigo-400" />
            <select
              value={selectedProjectId}
              onChange={(e) => setSelectedProjectId(e.target.value)}
              className="bg-transparent text-xs font-semibold text-slate-200 outline-hidden cursor-pointer"
            >
              {allProjects.map((p) => (
                <option key={p.id} value={p.id} className="bg-slate-900 text-slate-200">
                  {p.spaceName} / {p.name}
                </option>
              ))}
            </select>
          </div>

          {/* New Release Button */}
          <button
            onClick={() => setShowCreateModal(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 active:scale-95 text-white font-semibold text-xs transition shadow-lg shadow-indigo-600/30"
          >
            <Plus className="w-4 h-4" />
            New Version
          </button>
        </div>
      </header>

      {/* Filter Chips Bar */}
      <div className="px-6 py-3 bg-slate-900/40 border-b border-slate-800/50 flex items-center justify-between gap-4 shrink-0">
        <div className="flex items-center gap-2">
          {(['all', 'unreleased', 'released', 'archived'] as const).map((status) => (
            <button
              key={status}
              onClick={() => setStatusFilter(status)}
              className={`px-3 py-1 rounded-lg text-xs font-semibold transition ${
                statusFilter === status
                  ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/40'
                  : 'bg-slate-800/40 text-slate-400 hover:text-slate-200 border border-transparent'
              }`}
            >
              {status.charAt(0).toUpperCase() + status.slice(1)}
              {status === 'all'
                ? ` (${releases.length})`
                : ` (${releases.filter((r) => r.status === status).length})`}
            </button>
          ))}
        </div>

        <div className="text-xs text-slate-400">
          Showing {filteredReleases.length} {filteredReleases.length === 1 ? 'version' : 'versions'}
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 overflow-y-auto p-6 space-y-4">
        {error && (
          <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs flex items-center gap-3">
            <AlertCircle className="w-5 h-5 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-24 text-slate-500 gap-3">
            <div className="w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
            <p className="text-sm font-medium">Loading release versions...</p>
          </div>
        ) : filteredReleases.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 text-center max-w-md mx-auto">
            <div className="w-16 h-16 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 mb-4 shadow-inner">
              <Package className="w-8 h-8 opacity-60" />
            </div>
            <h3 className="text-base font-bold text-slate-200 mb-1">No releases found</h3>
            <p className="text-xs text-slate-400 mb-6 leading-relaxed">
              Create your first version release to track target release dates, issue completion, story points burnt, and automatically build release notes.
            </p>
            <button
              onClick={() => setShowCreateModal(true)}
              className="flex items-center gap-2 px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs transition shadow-lg shadow-indigo-600/30"
            >
              <Plus className="w-4 h-4" />
              Create First Release
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
            {filteredReleases.map((release) => {
              const progress = progressMap[release.id];
              const issuesProgress =
                progress && progress.totalIssues > 0
                  ? Math.round((progress.doneIssues / progress.totalIssues) * 100)
                  : 0;

              return (
                <div
                  key={release.id}
                  className="bg-slate-900/80 border border-slate-800/80 hover:border-indigo-500/50 rounded-2xl p-5 shadow-lg transition-all duration-200 flex flex-col justify-between group"
                >
                  <div>
                    {/* Top Row: Title, Status, Lock */}
                    <div className="flex items-start justify-between gap-3 mb-2">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <h3 className="text-base font-bold text-slate-100 truncate group-hover:text-indigo-300 transition-colors">
                            {release.name}
                          </h3>
                          {release.isLocked && (
                            <span title="Locked release" className="text-amber-400">
                              <Lock className="w-3.5 h-3.5" />
                            </span>
                          )}
                        </div>
                        {release.description && (
                          <p className="text-xs text-slate-400 mt-1 line-clamp-2 leading-relaxed">
                            {release.description}
                          </p>
                        )}
                      </div>

                      <span
                        className={`px-2.5 py-1 rounded-full text-[11px] font-bold shrink-0 capitalize ${
                          release.status === 'released'
                            ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                            : release.status === 'unreleased'
                            ? 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20'
                            : 'bg-slate-500/10 text-slate-400 border border-slate-500/20'
                        }`}
                      >
                        {release.status}
                      </span>
                    </div>

                    {/* Dates */}
                    <div className="flex flex-wrap items-center gap-3 text-xs text-slate-400 mt-3 mb-4">
                      {release.releaseDate && (
                        <div className="flex items-center gap-1.5">
                          <Calendar className="w-3.5 h-3.5 text-indigo-400" />
                          <span>Planned: {new Date(release.releaseDate).toLocaleDateString()}</span>
                        </div>
                      )}
                      {release.status === 'released' && release.releasedAt && (
                        <div className="flex items-center gap-1.5 text-emerald-400">
                          <CheckCircle2 className="w-3.5 h-3.5" />
                          <span>Shipped: {new Date(release.releasedAt).toLocaleDateString()}</span>
                        </div>
                      )}
                    </div>

                    {/* Progress Section */}
                    {progress ? (
                      <div className="space-y-2.5 bg-slate-950/40 p-3.5 rounded-xl border border-slate-800/60 mb-4">
                        <div className="flex items-center justify-between text-xs font-semibold">
                          <span className="text-slate-300">
                            {progress.doneIssues}/{progress.totalIssues} issues
                          </span>
                          <span className="text-indigo-400">
                            {progress.donePoints}/{progress.totalPoints} pts ({issuesProgress}%)
                          </span>
                        </div>

                        {/* Progress Bar */}
                        <div className="w-full h-2 rounded-full bg-slate-800 overflow-hidden">
                          <div
                            className="h-full bg-gradient-to-r from-indigo-500 to-purple-500 rounded-full transition-all duration-500"
                            style={{ width: `${issuesProgress}%` }}
                          />
                        </div>

                        {/* Badges footer */}
                        <div className="flex items-center justify-between text-[11px] text-slate-400 pt-1">
                          <span>Remaining: {progress.remainingIssues}</span>
                          <div className="flex items-center gap-2">
                            {progress.bugCount > 0 && (
                              <span className="flex items-center gap-1 text-amber-400">
                                <Bug className="w-3 h-3" />
                                {progress.bugCount} bugs
                              </span>
                            )}
                            {progress.criticalBugCount > 0 && (
                              <span className="flex items-center gap-1 text-red-400 font-bold">
                                <AlertCircle className="w-3 h-3" />
                                {progress.criticalBugCount} critical
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                    ) : (
                      <div className="p-3 rounded-xl bg-slate-950/30 text-xs text-slate-500 mb-4">
                        Loading progress metrics...
                      </div>
                    )}
                  </div>

                  {/* Card Actions */}
                  <div className="flex items-center gap-2 pt-2 border-t border-slate-800/60">
                    <button
                      onClick={() => openReleaseDetail(release)}
                      className="flex-1 flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold text-xs transition"
                    >
                      <FileText className="w-3.5 h-3.5 text-indigo-400" />
                      Details & Notes
                    </button>

                    {release.status === 'unreleased' && (
                      <button
                        onClick={() => {
                          setActiveRelease(release);
                          setShowShipModal(true);
                        }}
                        className="flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl bg-emerald-600/20 hover:bg-emerald-600/30 border border-emerald-500/30 text-emerald-300 font-semibold text-xs transition"
                      >
                        <Rocket className="w-3.5 h-3.5" />
                        Ship
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* CREATE RELEASE MODAL */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-lg p-6 shadow-2xl relative animate-in fade-in zoom-in-95 duration-150">
            <button
              onClick={() => setShowCreateModal(false)}
              className="absolute top-4 right-4 text-slate-400 hover:text-slate-100"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex items-center gap-3 mb-5">
              <div className="w-10 h-10 rounded-xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center">
                <Package className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-white">Create New Release</h3>
                <p className="text-xs text-slate-400">Define a milestone version for tracking deliverables</p>
              </div>
            </div>

            <form onSubmit={handleCreateRelease} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-300 mb-1.5">
                  Version Name <span className="text-red-400">*</span>
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. v2.4.0 - Enterprise Parity"
                  value={newReleaseName}
                  onChange={(e) => setNewReleaseName(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-slate-100 focus:outline-hidden focus:border-indigo-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-1.5">Target Release Date</label>
                <input
                  type="date"
                  value={newReleaseDate}
                  onChange={(e) => setNewReleaseDate(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-slate-100 focus:outline-hidden focus:border-indigo-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-300 mb-1.5">Description</label>
                <textarea
                  rows={3}
                  placeholder="Goals, key features, and scope of this release..."
                  value={newReleaseDesc}
                  onChange={(e) => setNewReleaseDesc(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2.5 text-xs text-slate-100 focus:outline-hidden focus:border-indigo-500"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold text-xs transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingCreate || !newReleaseName.trim()}
                  className="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-semibold text-xs transition shadow-lg shadow-indigo-600/30 flex items-center gap-1.5"
                >
                  {isSubmittingCreate ? 'Creating...' : 'Create Release'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* RELEASE DETAIL & NOTES MODAL */}
      {activeRelease && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-4xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-150">
            {/* Header */}
            <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between shrink-0 bg-slate-900/90">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center">
                  <Package className="w-5 h-5" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-lg font-bold text-white">{activeRelease.name}</h2>
                    <span
                      className={`px-2 py-0.5 rounded-full text-[10px] font-bold capitalize ${
                        activeRelease.status === 'released'
                          ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                          : activeRelease.status === 'unreleased'
                          ? 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20'
                          : 'bg-slate-500/10 text-slate-400 border border-slate-500/20'
                      }`}
                    >
                      {activeRelease.status}
                    </span>
                    {activeRelease.isLocked && (
                      <span className="text-amber-400 flex items-center gap-1 text-xs">
                        <Lock className="w-3.5 h-3.5" /> Locked
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-slate-400 mt-0.5">
                    {activeRelease.releaseDate && `Planned: ${new Date(activeRelease.releaseDate).toLocaleDateString()} • `}
                    {activeRelease.releasedAt && `Shipped: ${new Date(activeRelease.releasedAt).toLocaleDateString()} • `}
                    {activeReleaseIssues.length} linked issues
                  </p>
                </div>
              </div>

              <button
                onClick={() => setActiveRelease(null)}
                className="text-slate-400 hover:text-slate-100 p-1 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Navigation Tabs */}
            <div className="flex items-center gap-2 px-6 border-b border-slate-800 bg-slate-950/40 shrink-0">
              {(['overview', 'issues', 'notes'] as const).map((tab) => (
                <button
                  key={tab}
                  onClick={() => setDetailTab(tab)}
                  className={`py-3 px-4 text-xs font-semibold border-b-2 transition ${
                    detailTab === tab
                      ? 'border-indigo-500 text-indigo-400'
                      : 'border-transparent text-slate-400 hover:text-slate-200'
                  }`}
                >
                  {tab === 'overview' && 'Progress & Metrics'}
                  {tab === 'issues' && `Issues (${activeReleaseIssues.length})`}
                  {tab === 'notes' && 'Release Notes (Markdown)'}
                </button>
              ))}

              {activeRelease.status === 'unreleased' && (
                <button
                  onClick={() => setShowShipModal(true)}
                  className="ml-auto my-auto flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-xs transition shadow-md shadow-emerald-600/20"
                >
                  <Rocket className="w-3.5 h-3.5" />
                  Ship Version
                </button>
              )}
            </div>

            {/* Body */}
            <div className="flex-1 overflow-y-auto p-6">
              {detailTab === 'overview' && (
                <div className="space-y-6">
                  {/* Summary Metric Cards */}
                  {(() => {
                    const p = progressMap[activeRelease.id];
                    return (
                      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                        <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800">
                          <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                            Total Issues
                          </span>
                          <div className="text-2xl font-bold text-white mt-1">
                            {p?.totalIssues ?? activeReleaseIssues.length}
                          </div>
                          <span className="text-[11px] text-indigo-400 font-medium">
                            {p?.doneIssues ?? activeReleaseIssues.filter(t => t.status === 'done').length} completed
                          </span>
                        </div>

                        <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800">
                          <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                            Story Points
                          </span>
                          <div className="text-2xl font-bold text-white mt-1">
                            {p?.totalPoints ?? activeReleaseIssues.reduce((a, t) => a + (t.storyPoints || 0), 0)}
                          </div>
                          <span className="text-[11px] text-emerald-400 font-medium">
                            {p?.donePoints ?? 0} points burnt
                          </span>
                        </div>

                        <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800">
                          <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                            Remaining
                          </span>
                          <div className="text-2xl font-bold text-amber-400 mt-1">
                            {p?.remainingIssues ?? 0}
                          </div>
                          <span className="text-[11px] text-slate-400 font-medium">unresolved issues</span>
                        </div>

                        <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800">
                          <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                            Bugs & Critical
                          </span>
                          <div className="text-2xl font-bold text-red-400 mt-1">
                            {p?.bugCount ?? 0}
                          </div>
                          <span className="text-[11px] text-red-400 font-bold">
                            {p?.criticalBugCount ?? 0} critical
                          </span>
                        </div>
                      </div>
                    );
                  })()}

                  {/* Description */}
                  {activeRelease.description && (
                    <div className="p-4 rounded-xl bg-slate-950/40 border border-slate-800/80">
                      <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider mb-2">
                        Release Goals & Scope
                      </h4>
                      <p className="text-xs text-slate-300 leading-relaxed whitespace-pre-wrap">
                        {activeRelease.description}
                      </p>
                    </div>
                  )}

                  {/* Progress Visualization */}
                  {(() => {
                    const p = progressMap[activeRelease.id];
                    const percent =
                      p && p.totalIssues > 0 ? Math.round((p.doneIssues / p.totalIssues) * 100) : 0;
                    return (
                      <div className="p-5 rounded-xl bg-slate-950/40 border border-slate-800/80 space-y-3">
                        <div className="flex items-center justify-between text-xs font-bold">
                          <span className="text-slate-200">Overall Milestone Completion</span>
                          <span className="text-indigo-400">{percent}%</span>
                        </div>
                        <div className="w-full h-3 rounded-full bg-slate-800 overflow-hidden">
                          <div
                            className="h-full bg-gradient-to-r from-indigo-500 via-purple-500 to-emerald-500 rounded-full transition-all duration-500"
                            style={{ width: `${percent}%` }}
                          />
                        </div>
                      </div>
                    );
                  })()}
                </div>
              )}

              {detailTab === 'issues' && (
                <div className="space-y-3">
                  {isLoadingIssues ? (
                    <div className="py-12 text-center text-xs text-slate-400">Loading release issues...</div>
                  ) : activeReleaseIssues.length === 0 ? (
                    <div className="py-12 text-center text-xs text-slate-400">
                      No issues assigned to this release version yet.
                      <p className="mt-1 text-slate-500">
                        Assign tasks by selecting "{activeRelease.name}" as their Affected Version in task details.
                      </p>
                    </div>
                  ) : (
                    <div className="divide-y divide-slate-800/80 border border-slate-800 rounded-xl overflow-hidden bg-slate-950/40">
                      {activeReleaseIssues.map((task) => (
                        <div
                          key={task.id}
                          className="p-3.5 flex items-center justify-between gap-4 hover:bg-slate-900/50 transition"
                        >
                          <div className="flex items-center gap-3 min-w-0">
                            {task.issueKey && (
                              <span className="text-xs font-mono font-bold text-indigo-400 shrink-0">
                                {task.issueKey}
                              </span>
                            )}
                            <span className="text-xs font-medium text-slate-200 truncate">{task.title}</span>
                          </div>

                          <div className="flex items-center gap-3 shrink-0 text-xs">
                            {task.storyPoints !== undefined && (
                              <span className="px-2 py-0.5 rounded-md bg-slate-800 text-slate-300 font-semibold text-[10px]">
                                {task.storyPoints} pts
                              </span>
                            )}
                            <span
                              className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold capitalize ${
                                task.status === 'done'
                                  ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                                  : task.status === 'in_progress'
                                  ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                                  : 'bg-slate-800 text-slate-400 border border-slate-700'
                              }`}
                            >
                              {task.status.replace('_', ' ')}
                            </span>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}

              {detailTab === 'notes' && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-slate-400 font-medium">
                      Auto-generated Markdown based on linked issues, completed tasks, and bug metrics
                    </span>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={handleCopyNotes}
                        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition"
                      >
                        {copiedNotes ? (
                          <>
                            <Check className="w-3.5 h-3.5 text-emerald-400" />
                            Copied!
                          </>
                        ) : (
                          <>
                            <Copy className="w-3.5 h-3.5 text-indigo-400" />
                            Copy Markdown
                          </>
                        )}
                      </button>
                      <button
                        onClick={handleDownloadNotes}
                        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition"
                      >
                        <Download className="w-3.5 h-3.5 text-indigo-400" />
                        Download .md
                      </button>
                    </div>
                  </div>

                  <div className="p-4 rounded-xl bg-slate-950 font-mono text-xs text-slate-200 border border-slate-800 whitespace-pre-wrap leading-relaxed shadow-inner max-h-96 overflow-y-auto">
                    {buildReleaseNotesMarkdown(
                      activeRelease,
                      progressMap[activeRelease.id] || null,
                      activeReleaseIssues
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* FINALIZE / SHIP MODAL */}
      {showShipModal && activeRelease && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-md p-6 shadow-2xl relative animate-in fade-in zoom-in-95 duration-150">
            <button
              onClick={() => setShowShipModal(false)}
              className="absolute top-4 right-4 text-slate-400 hover:text-slate-100"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 rounded-xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center">
                <Rocket className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-white">Ship {activeRelease.name}?</h3>
                <p className="text-xs text-slate-400">Finalize and publish this release version</p>
              </div>
            </div>

            <p className="text-xs text-slate-300 leading-relaxed mb-4">
              Marking this release as <strong>Released</strong> will stamp the release date with the current timestamp.
            </p>

            <label className="flex items-center gap-2.5 p-3 rounded-xl bg-slate-950 border border-slate-800 cursor-pointer mb-6">
              <input
                type="checkbox"
                checked={shipLockIssues}
                onChange={(e) => setShipLockIssues(e.target.checked)}
                className="w-4 h-4 rounded text-indigo-600 focus:ring-indigo-500 bg-slate-900 border-slate-700"
              />
              <div className="text-xs">
                <span className="font-bold text-slate-200">Lock version against modifications</span>
                <p className="text-[11px] text-slate-400 mt-0.5">
                  Prevents assigning new issues or editing closed tasks
                </p>
              </div>
            </label>

            <div className="flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setShowShipModal(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold text-xs transition"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleShipRelease}
                disabled={isShipping}
                className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-xs transition shadow-lg shadow-emerald-600/30 flex items-center gap-1.5"
              >
                {isShipping ? 'Finalizing...' : 'Confirm & Ship'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
