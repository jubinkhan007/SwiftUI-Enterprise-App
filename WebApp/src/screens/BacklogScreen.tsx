import React, { useState, useEffect } from 'react';
import { 
  Layers, 
  Plus, 
  Play, 
  CheckCircle2, 
  Calendar, 
  Flame, 
  ArrowUpRight, 
  ChevronDown, 
  Hash, 
  Clock, 
  Sparkles, 
  AlertCircle,
  FolderKanban,
  ArrowRight,
  RotateCcw,
  Check,
  X
} from 'lucide-react';
import { SprintDTO, SprintStatus, TaskItemDTO, HierarchyTreeDTO, NavDestination } from '../types';
import { api } from '../services/api';

export interface BacklogScreenProps {
  onNavigate?: (dest: NavDestination) => void;
}

export const BacklogScreen: React.FC<BacklogScreenProps> = () => {
  const [hierarchy, setHierarchy] = useState<HierarchyTreeDTO | null>(null);
  const [selectedProjectId, setSelectedProjectId] = useState<string>('');
  const [sprints, setSprints] = useState<SprintDTO[]>([]);
  const [sprintIssues, setSprintIssues] = useState<Record<string, TaskItemDTO[]>>({});
  const [backlogTasks, setBacklogTasks] = useState<TaskItemDTO[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  // Create sprint modal
  const [showCreateSprintModal, setShowCreateSprintModal] = useState<boolean>(false);
  const [sprintName, setSprintName] = useState<string>('');
  const [sprintStartDate, setSprintStartDate] = useState<string>(
    new Date().toISOString().split('T')[0]
  );
  const [sprintEndDate, setSprintEndDate] = useState<string>(() => {
    const d = new Date();
    d.setDate(d.getDate() + 14);
    return d.toISOString().split('T')[0];
  });
  const [sprintCapacity, setSprintCapacity] = useState<string>('20');
  const [isSubmittingSprint, setIsSubmittingSprint] = useState<boolean>(false);

  // Initial load: hierarchy
  useEffect(() => {
    const loadHierarchy = async () => {
      try {
        const tree = await api.getHierarchy();
        setHierarchy(tree);
        // Find first project
        const firstSpace = tree.spaces?.[0];
        const firstProj = firstSpace?.projects?.[0]?.project;
        if (firstProj?.id) {
          setSelectedProjectId(firstProj.id);
        }
      } catch (err: any) {
        console.error('Failed to load hierarchy:', err);
        setError('Failed to load project hierarchy.');
      }
    };
    loadHierarchy();
  }, []);

  // Fetch sprints and backlog when selectedProjectId changes
  const loadAgileData = async (projectId: string) => {
    if (!projectId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [fetchedSprints, fetchedBacklog] = await Promise.all([
        api.listSprints(projectId),
        api.getBacklog(projectId),
      ]);
      setSprints(fetchedSprints);
      setBacklogTasks(fetchedBacklog);

      // Load issues for each sprint in parallel
      const issuesMap: Record<string, TaskItemDTO[]> = {};
      await Promise.all(
        fetchedSprints.map(async (s) => {
          try {
            const issues = await api.getSprintIssues(s.id);
            issuesMap[s.id] = issues;
          } catch (e) {
            console.warn(`Failed to fetch issues for sprint ${s.id}`, e);
            issuesMap[s.id] = [];
          }
        })
      );
      setSprintIssues(issuesMap);
    } catch (err: any) {
      console.error('Failed to load agile backlog data:', err);
      setError(err?.message || 'Failed to load sprints and backlog.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (selectedProjectId) {
      loadAgileData(selectedProjectId);
    }
  }, [selectedProjectId]);

  const handleCreateSprint = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedProjectId || !sprintName.trim()) return;
    setIsSubmittingSprint(true);
    try {
      await api.createSprint(selectedProjectId, {
        name: sprintName.trim(),
        startDate: new Date(sprintStartDate).toISOString(),
        endDate: new Date(sprintEndDate).toISOString(),
        capacity: sprintCapacity ? parseInt(sprintCapacity, 10) : undefined,
        status: 'planned',
      });
      setShowCreateSprintModal(false);
      setSprintName('');
      await loadAgileData(selectedProjectId);
    } catch (err: any) {
      alert(`Failed to create sprint: ${err.message || err}`);
    } finally {
      setIsSubmittingSprint(false);
    }
  };

  const handleUpdateSprintStatus = async (sprintId: string, status: SprintStatus) => {
    try {
      await api.updateSprint(sprintId, { status });
      await loadAgileData(selectedProjectId);
    } catch (err: any) {
      alert(`Failed to update sprint: ${err.message || err}`);
    }
  };

  const handleMoveToSprint = async (taskId: string, targetSprintId: string | null) => {
    try {
      // Find task to get current version
      const allTasks = [...backlogTasks, ...Object.values(sprintIssues).flat()];
      const task = allTasks.find((t) => t.id === taskId);
      await api.assignTaskToSprint(
        taskId,
        targetSprintId,
        undefined,
        undefined,
        task?.version
      );
      await loadAgileData(selectedProjectId);
    } catch (err: any) {
      alert(`Failed to move task: ${err.message || err}`);
    }
  };

  // Helper calculations for sprint points
  const calculatePoints = (sprintId: string, capacity?: number) => {
    const issues = sprintIssues[sprintId] || [];
    const assigned = issues.reduce((acc, t) => acc + (t.storyPoints || 0), 0);
    const cap = capacity || 0;
    const isOver = cap > 0 && assigned > cap;
    const progressPercent = cap > 0 ? Math.min(Math.round((assigned / cap) * 100), 100) : 0;
    return { assigned, cap, isOver, progressPercent, count: issues.length };
  };

  const totalBacklogPoints = backlogTasks.reduce((acc, t) => acc + (t.storyPoints || 0), 0);

  // Flatten projects from hierarchy for dropdown
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
      {/* Top Header / Project Bar */}
      <div className="p-6 border-b border-slate-800/80 bg-slate-900/40 backdrop-blur-xl flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 to-purple-600 flex items-center justify-center text-white shadow-lg shadow-indigo-600/30">
              <Layers className="w-5 h-5" />
            </div>
            <div>
              <h1 className="text-xl font-bold tracking-tight text-white flex items-center gap-2">
                Agile Backlog & Sprints
                <span className="text-xs px-2.5 py-0.5 rounded-full bg-indigo-500/10 border border-indigo-500/30 text-indigo-400 font-semibold">
                  Scrum Parity
                </span>
              </h1>
              <p className="text-xs text-slate-400">
                Plan iterations, monitor sprint capacity burnup, and groom product backlog.
              </p>
            </div>
          </div>
        </div>

        {/* Project Selector & Actions */}
        <div className="flex items-center gap-3">
          <div className="relative">
            <select
              aria-label="Select Project"
              value={selectedProjectId}
              onChange={(e) => setSelectedProjectId(e.target.value)}
              className="appearance-none bg-slate-800/90 border border-slate-700/80 hover:border-slate-600 text-slate-200 text-xs font-semibold rounded-xl pl-9 pr-8 py-2.5 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition shadow-inner"
            >
              {allProjects.map((proj) => (
                <option key={proj.id} value={proj.id}>
                  {proj.spaceName} / {proj.name}
                </option>
              ))}
            </select>
            <FolderKanban className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
            <ChevronDown className="w-3.5 h-3.5 text-slate-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>

          <button
            onClick={() => setShowCreateSprintModal(true)}
            disabled={!selectedProjectId}
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 disabled:opacity-50 text-white font-semibold text-xs transition shadow-lg shadow-indigo-600/30 hover:shadow-indigo-500/40 active:scale-95"
          >
            <Plus className="w-4 h-4" />
            Create Sprint
          </button>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 overflow-y-auto p-6 space-y-8">
        {error && (
          <div className="p-4 rounded-2xl bg-red-500/10 border border-red-500/30 text-red-300 text-xs flex items-center gap-3">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-20 text-slate-500 gap-3">
            <RotateCcw className="w-6 h-6 animate-spin text-indigo-500" />
            <p className="text-xs font-medium">Loading sprints and backlog items...</p>
          </div>
        ) : (
          <>
            {/* SPRINTS CONTAINER */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Flame className="w-4 h-4 text-amber-400" />
                  <h2 className="text-sm font-bold text-slate-200 uppercase tracking-wider">
                    Sprints & Iterations ({sprints.length})
                  </h2>
                </div>
              </div>

              {sprints.length === 0 ? (
                <div className="p-8 rounded-2xl border border-dashed border-slate-800 bg-slate-900/20 text-center space-y-3">
                  <Layers className="w-8 h-8 text-slate-600 mx-auto" />
                  <p className="text-xs text-slate-400 font-medium">
                    No sprints created for this project yet.
                  </p>
                  <button
                    onClick={() => setShowCreateSprintModal(true)}
                    className="inline-flex items-center gap-2 px-3 py-1.5 rounded-lg bg-indigo-600/20 border border-indigo-500/30 text-indigo-300 text-xs font-semibold hover:bg-indigo-600/30 transition"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    Create First Sprint
                  </button>
                </div>
              ) : (
                <div className="grid grid-cols-1 gap-5">
                  {sprints.map((sprint) => {
                    const stats = calculatePoints(sprint.id, sprint.capacity);
                    const issues = sprintIssues[sprint.id] || [];
                    const isActive = sprint.status === 'active';
                    const isCompleted = sprint.status === 'completed' || sprint.status === 'closed';

                    return (
                      <div
                        key={sprint.id}
                        className={`rounded-2xl border transition-all duration-200 overflow-hidden shadow-xl ${
                          isActive
                            ? 'bg-slate-900/90 border-indigo-500/50 shadow-indigo-950/20 ring-1 ring-indigo-500/30'
                            : isCompleted
                            ? 'bg-slate-900/40 border-slate-800/60 opacity-80'
                            : 'bg-slate-900/70 border-slate-800/80 hover:border-slate-700/80'
                        }`}
                      >
                        {/* Sprint Card Header */}
                        <div className="p-4 bg-slate-900/80 border-b border-slate-800/60 flex flex-col md:flex-row md:items-center justify-between gap-4">
                          <div className="space-y-1">
                            <div className="flex items-center gap-2.5">
                              <span
                                className={`text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full border ${
                                  isActive
                                    ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400'
                                    : isCompleted
                                    ? 'bg-slate-700/20 border-slate-600/30 text-slate-400'
                                    : 'bg-indigo-500/10 border-indigo-500/30 text-indigo-400'
                                }`}
                              >
                                {sprint.status}
                              </span>
                              <h3 className="text-sm font-bold text-slate-100 flex items-center gap-2">
                                {sprint.name}
                              </h3>
                              <span className="text-xs text-slate-500">
                                ({issues.length} {issues.length === 1 ? 'task' : 'tasks'})
                              </span>
                            </div>

                            <div className="flex items-center gap-4 text-xs text-slate-400">
                              <span className="flex items-center gap-1.5">
                                <Calendar className="w-3.5 h-3.5 text-slate-500" />
                                {new Date(sprint.startDate).toLocaleDateString()} →{' '}
                                {new Date(sprint.endDate).toLocaleDateString()}
                              </span>
                            </div>
                          </div>

                          {/* Capacity Gauge & Lifecycle Buttons */}
                          <div className="flex items-center gap-4">
                            {/* Points Gauge */}
                            <div className="w-40 space-y-1">
                              <div className="flex items-center justify-between text-[11px]">
                                <span className="text-slate-400">Points</span>
                                <span
                                  className={`font-semibold ${
                                    stats.isOver ? 'text-red-400' : 'text-slate-200'
                                  }`}
                                >
                                  {stats.assigned}
                                  {stats.cap > 0 ? ` / ${stats.cap} pts` : ' pts'}
                                </span>
                              </div>
                              {stats.cap > 0 && (
                                <div className="w-full h-1.5 rounded-full bg-slate-800 overflow-hidden">
                                  <div
                                    className={`h-full rounded-full transition-all duration-300 ${
                                      stats.isOver
                                        ? 'bg-red-500'
                                        : isActive
                                        ? 'bg-indigo-500'
                                        : 'bg-slate-500'
                                    }`}
                                    style={{ width: `${stats.progressPercent}%` }}
                                  />
                                </div>
                              )}
                            </div>

                            {/* Status Transition Actions */}
                            <div className="flex items-center gap-2">
                              {sprint.status === 'planned' && (
                                <button
                                  onClick={() => handleUpdateSprintStatus(sprint.id, 'active')}
                                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-600/20 hover:bg-emerald-600/30 border border-emerald-500/40 text-emerald-300 text-xs font-semibold transition shadow-sm active:scale-95"
                                >
                                  <Play className="w-3 h-3 fill-current" />
                                  Start Sprint
                                </button>
                              )}
                              {sprint.status === 'active' && (
                                <button
                                  onClick={() => handleUpdateSprintStatus(sprint.id, 'completed')}
                                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-purple-600/20 hover:bg-purple-600/30 border border-purple-500/40 text-purple-300 text-xs font-semibold transition shadow-sm active:scale-95"
                                >
                                  <CheckCircle2 className="w-3.5 h-3.5" />
                                  Complete Sprint
                                </button>
                              )}
                            </div>
                          </div>
                        </div>

                        {/* Sprint Issue List */}
                        <div className="p-3 divide-y divide-slate-800/40 space-y-1">
                          {issues.length === 0 ? (
                            <div className="py-4 text-center text-xs text-slate-500 italic">
                              No tasks assigned to this sprint. Move items from the backlog below.
                            </div>
                          ) : (
                            issues.map((task) => (
                              <div
                                key={task.id}
                                className="py-2.5 px-3 rounded-xl hover:bg-slate-800/40 transition flex items-center justify-between gap-4 group"
                              >
                                <div className="flex items-center gap-3 min-w-0">
                                  {task.issueKey && (
                                    <span className="text-xs font-mono font-bold text-indigo-400 shrink-0">
                                      {task.issueKey}
                                    </span>
                                  )}
                                  <span className="text-xs font-medium text-slate-200 truncate">
                                    {task.title}
                                  </span>
                                  <span className="text-[10px] uppercase font-semibold px-2 py-0.5 rounded-md bg-slate-800 text-slate-400 border border-slate-700/60 shrink-0">
                                    {task.status}
                                  </span>
                                  {task.storyPoints !== undefined && (
                                    <span className="text-[11px] font-semibold text-slate-400 bg-slate-800/80 px-2 py-0.5 rounded-md shrink-0">
                                      {task.storyPoints} pts
                                    </span>
                                  )}
                                </div>

                                <div className="flex items-center gap-2 shrink-0">
                                  <button
                                    onClick={() => handleMoveToSprint(task.id, null)}
                                    title="Move back to backlog"
                                    className="opacity-0 group-hover:opacity-100 flex items-center gap-1 text-[11px] px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 transition"
                                  >
                                    <RotateCcw className="w-3 h-3 text-slate-400" />
                                    To Backlog
                                  </button>
                                </div>
                              </div>
                            ))
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            {/* PRODUCT BACKLOG SECTION */}
            <div className="space-y-4 pt-4 border-t border-slate-800/80">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Hash className="w-4 h-4 text-indigo-400" />
                  <h2 className="text-sm font-bold text-slate-200 uppercase tracking-wider">
                    Product Backlog ({backlogTasks.length} items • {totalBacklogPoints} total pts)
                  </h2>
                </div>
              </div>

              {backlogTasks.length === 0 ? (
                <div className="p-8 rounded-2xl border border-dashed border-slate-800 bg-slate-900/20 text-center text-xs text-slate-500">
                  Backlog is empty. All tasks are assigned to sprints or completed!
                </div>
              ) : (
                <div className="rounded-2xl border border-slate-800/80 bg-slate-900/70 divide-y divide-slate-800/40 overflow-hidden shadow-xl">
                  {backlogTasks.map((task) => (
                    <div
                      key={task.id}
                      className="p-3.5 hover:bg-slate-800/30 transition flex flex-col sm:flex-row sm:items-center justify-between gap-3 group"
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        {task.issueKey && (
                          <span className="text-xs font-mono font-bold text-indigo-400 shrink-0">
                            {task.issueKey}
                          </span>
                        )}
                        <span className="text-xs font-medium text-slate-200 truncate">
                          {task.title}
                        </span>
                        <span className="text-[10px] uppercase font-semibold px-2 py-0.5 rounded-md bg-slate-800 text-slate-400 border border-slate-700/60 shrink-0">
                          {task.status}
                        </span>
                        {task.storyPoints !== undefined && (
                          <span className="text-[11px] font-semibold text-slate-400 bg-slate-800/80 px-2 py-0.5 rounded-md shrink-0">
                            {task.storyPoints} pts
                          </span>
                        )}
                      </div>

                      <div className="flex items-center gap-2 shrink-0">
                        {/* Assign to Sprint Dropdown */}
                        {sprints.filter((s) => s.status !== 'completed' && s.status !== 'closed')
                          .length > 0 && (
                          <div className="relative">
                            <select
                              aria-label="Assign to Sprint"
                              onChange={(e) => {
                                if (e.target.value) {
                                  handleMoveToSprint(task.id, e.target.value);
                                }
                              }}
                              defaultValue=""
                              className="appearance-none bg-slate-800/90 hover:bg-slate-700 border border-slate-700 hover:border-slate-600 text-slate-200 text-xs font-semibold rounded-xl pl-3 pr-8 py-1.5 focus:outline-none focus:ring-1 focus:ring-indigo-500 transition cursor-pointer"
                            >
                              <option value="" disabled>
                                Assign to Sprint...
                              </option>
                              {sprints
                                .filter((s) => s.status !== 'completed' && s.status !== 'closed')
                                .map((s) => (
                                  <option key={s.id} value={s.id}>
                                    {s.name} ({s.status})
                                  </option>
                                ))}
                            </select>
                            <ChevronDown className="w-3.5 h-3.5 text-slate-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </>
        )}
      </div>

      {/* CREATE SPRINT MODAL */}
      {showCreateSprintModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md animate-in fade-in duration-150">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-md p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-slate-800/80 pb-4">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-400">
                  <Plus className="w-4 h-4" />
                </div>
                <h3 className="text-base font-bold text-slate-100">Create New Sprint</h3>
              </div>
              <button
                onClick={() => setShowCreateSprintModal(false)}
                className="text-slate-400 hover:text-slate-200 p-1.5 rounded-lg hover:bg-slate-800 transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleCreateSprint} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Sprint Name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Sprint 14 - Mobile Parity"
                  value={sprintName}
                  onChange={(e) => setSprintName(e.target.value)}
                  className="w-full bg-slate-800 border border-slate-700/80 rounded-xl px-3.5 py-2 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                    Start Date *
                  </label>
                  <input
                    type="date"
                    required
                    value={sprintStartDate}
                    onChange={(e) => setSprintStartDate(e.target.value)}
                    className="w-full bg-slate-800 border border-slate-700/80 rounded-xl px-3 py-2 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                    End Date *
                  </label>
                  <input
                    type="date"
                    required
                    value={sprintEndDate}
                    onChange={(e) => setSprintEndDate(e.target.value)}
                    className="w-full bg-slate-800 border border-slate-700/80 rounded-xl px-3 py-2 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Story Points Capacity
                </label>
                <input
                  type="number"
                  min="1"
                  placeholder="20"
                  value={sprintCapacity}
                  onChange={(e) => setSprintCapacity(e.target.value)}
                  className="w-full bg-slate-800 border border-slate-700/80 rounded-xl px-3.5 py-2 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition"
                />
              </div>

              <div className="pt-2 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setShowCreateSprintModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingSprint || !sprintName.trim()}
                  className="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold shadow-lg shadow-indigo-600/30 transition disabled:opacity-50"
                >
                  {isSubmittingSprint ? 'Creating...' : 'Create Sprint'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
