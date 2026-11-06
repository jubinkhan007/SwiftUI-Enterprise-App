import React, { useEffect, useMemo, useState } from 'react';
import {
  BarChart3,
  Clock,
  TrendingDown,
  TrendingUp,
  Zap,
  CheckCircle2,
  Download,
  RefreshCw,
  FolderKanban,
  AlertCircle,
  Calendar,
  Layers,
  Users,
  Timer,
  ArrowUpRight
} from 'lucide-react';
import {
  AnalyticsReportPayloadDTO,
  HierarchyTreeDTO,
  NavDestination,
  ProjectTimeReportDTO
} from '../types';
import { api } from '../services/api';

export interface AnalyticsScreenProps {
  onNavigate?: (dest: NavDestination) => void;
}

function formatDurationSeconds(seconds?: number | null): string {
  if (seconds === undefined || seconds === null || isNaN(seconds) || seconds <= 0) {
    return '0h';
  }
  const days = seconds / 86400;
  if (days >= 1) {
    return `${days.toFixed(1)}d`;
  }
  const hours = seconds / 3600;
  if (hours >= 1) {
    return `${hours.toFixed(1)}h`;
  }
  const mins = Math.max(1, Math.round(seconds / 60));
  return `${mins}m`;
}

function formatShortDate(iso: string): string {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export const AnalyticsScreen: React.FC<AnalyticsScreenProps> = ({ onNavigate }) => {
  const [hierarchy, setHierarchy] = useState<HierarchyTreeDTO | null>(null);
  const [selectedProjectId, setSelectedProjectId] = useState<string>('');
  const [rangeDays, setRangeDays] = useState<7 | 30 | 90>(30);
  const [chartMode, setChartMode] = useState<'points' | 'tasks'>('points');

  const [report, setReport] = useState<AnalyticsReportPayloadDTO | null>(null);
  const [timeReport, setTimeReport] = useState<ProjectTimeReportDTO | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isRecomputing, setIsRecomputing] = useState<boolean>(false);
  const [isExporting, setIsExporting] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const allProjects = useMemo(() => {
    const list: { id: string; name: string; spaceName: string }[] = [];
    for (const spaceNode of hierarchy?.spaces || []) {
      for (const projNode of spaceNode.projects || []) {
        list.push({
          id: projNode.project.id,
          name: projNode.project.name,
          spaceName: spaceNode.space.name,
        });
      }
    }
    return list;
  }, [hierarchy]);

  const { startIso, endIso } = useMemo(() => {
    const end = new Date();
    const start = new Date(end.getTime() - rangeDays * 86400 * 1000);
    return {
      startIso: start.toISOString(),
      endIso: end.toISOString(),
    };
  }, [rangeDays]);

  useEffect(() => {
    const loadHierarchy = async () => {
      try {
        const tree = await api.getHierarchy();
        setHierarchy(tree);
        const firstProj = tree.spaces?.[0]?.projects?.[0]?.project;
        if (firstProj?.id) {
          setSelectedProjectId(firstProj.id);
        } else {
          setIsLoading(false);
        }
      } catch (err: any) {
        setError(err.message || 'Failed to load workspace hierarchy.');
        setIsLoading(false);
      }
    };
    loadHierarchy();
  }, []);

  const fetchAnalytics = async (projId: string, recompute: boolean = false) => {
    if (!projId) return;
    if (recompute) {
      setIsRecomputing(true);
    } else {
      setIsLoading(true);
    }
    setError(null);

    try {
      const [rep, tRep] = await Promise.all([
        api.getProjectAnalyticsReport(projId, startIso, endIso, recompute),
        api.getProjectTimeReport(projId).catch(() => null),
      ]);
      setReport(rep);
      setTimeReport(tRep);
    } catch (err: any) {
      setError(err.message || 'Failed to load project analytics.');
    } finally {
      setIsLoading(false);
      setIsRecomputing(false);
    }
  };

  useEffect(() => {
    if (selectedProjectId) {
      fetchAnalytics(selectedProjectId, false);
    }
  }, [selectedProjectId, startIso, endIso]);

  const handleExportCSV = async () => {
    if (!selectedProjectId) return;
    setIsExporting(true);
    try {
      const csv = await api.exportProjectBurndownCSV(selectedProjectId, startIso, endIso);
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `burndown-${selectedProjectId.slice(0, 8)}-${rangeDays}d.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (err: any) {
      setError(err.message || 'Failed to export burndown CSV.');
    } finally {
      setIsExporting(false);
    }
  };

  const burndownSeries = report?.burndown || [];
  const weeklySeries = report?.weeklyThroughput || [];
  const sprintSeries = report?.sprintVelocity || [];

  const burndownSummary = useMemo(() => {
    if (burndownSeries.length === 0) {
      return { peakRemaining: 0, latestRemaining: 0, totalCompletedPts: 0, totalCompletedTasks: 0 };
    }
    const peakRemaining = Math.max(...burndownSeries.map((d) => d.remainingPoints), 0);
    const latestRemaining = burndownSeries[burndownSeries.length - 1]?.remainingPoints ?? 0;
    const totalCompletedPts = burndownSeries.reduce((acc, d) => acc + d.completedPoints, 0);
    const totalCompletedTasks = burndownSeries.reduce((acc, d) => acc + d.completedTasks, 0);
    return { peakRemaining, latestRemaining, totalCompletedPts, totalCompletedTasks };
  }, [burndownSeries]);

  return (
    <div className="flex-1 flex flex-col h-full bg-slate-950 text-slate-100 overflow-hidden">
      {/* Top Header */}
      <header className="px-6 py-4 bg-slate-900/70 border-b border-slate-800/80 flex flex-wrap items-center justify-between gap-4 shrink-0">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 to-teal-500 flex items-center justify-center text-white shadow-lg shadow-indigo-600/20">
            <BarChart3 className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-lg font-bold text-slate-100 flex items-center gap-2">
              Analytics & Burndown
              <span className="text-[11px] font-semibold px-2 py-0.5 rounded-full bg-indigo-500/15 text-indigo-300 border border-indigo-500/30">
                Enterprise Trust
              </span>
            </h1>
            <p className="text-xs text-slate-400">
              Lead Time, Cycle Time, Velocity, Cumulative Flow, and Time Logs with P50/P90 percentiles
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          {/* Project Selector */}
          <div className="flex items-center gap-2 px-3 py-2 rounded-xl bg-slate-800/70 border border-slate-700/70">
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

          {/* Date Range Filter */}
          <div className="flex items-center bg-slate-900/90 border border-slate-800 rounded-xl p-1">
            {([7, 30, 90] as const).map((days) => (
              <button
                key={days}
                onClick={() => setRangeDays(days)}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition cursor-pointer ${
                  rangeDays === days
                    ? 'bg-indigo-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-slate-200'
                }`}
              >
                {days} Days
              </button>
            ))}
          </div>

          {/* Recompute Button */}
          <button
            onClick={() => fetchAnalytics(selectedProjectId, true)}
            disabled={isRecomputing || isLoading || !selectedProjectId}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 disabled:opacity-50 text-slate-200 text-xs font-semibold border border-slate-700 transition cursor-pointer"
            title="Recompute daily snapshots from raw task activity"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isRecomputing ? 'animate-spin text-indigo-400' : ''}`} />
            Recompute
          </button>

          {/* Export CSV Button */}
          <button
            onClick={handleExportCSV}
            disabled={isExporting || !selectedProjectId}
            className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-semibold shadow-lg shadow-indigo-600/25 transition cursor-pointer"
          >
            <Download className="w-3.5 h-3.5" />
            {isExporting ? 'Exporting...' : 'Export CSV'}
          </button>
        </div>
      </header>

      {/* Scrollable Content */}
      <div className="flex-1 overflow-y-auto p-6 space-y-6">
        {error && (
          <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-300 text-xs flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <AlertCircle className="w-4 h-4 text-red-400 shrink-0" />
              <span>{error}</span>
            </div>
            <button
              onClick={() => fetchAnalytics(selectedProjectId, false)}
              className="px-2.5 py-1 rounded-lg bg-red-500/20 hover:bg-red-500/30 text-red-200 font-semibold"
            >
              Retry
            </button>
          </div>
        )}

        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-24 text-slate-400 gap-3">
            <div className="w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
            <p className="text-sm font-medium">Aggregating project telemetry & burndown series...</p>
          </div>
        ) : (
          <>
            {/* 4 KPI Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
              {/* Lead Time */}
              <div className="bg-slate-900/80 border border-slate-800/80 rounded-2xl p-5 shadow-lg">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Lead Time
                  </span>
                  <div className="w-8 h-8 rounded-lg bg-indigo-500/15 border border-indigo-500/30 flex items-center justify-center text-indigo-400">
                    <Clock className="w-4 h-4" />
                  </div>
                </div>
                <div className="text-2xl font-bold text-slate-100 mb-1">
                  {formatDurationSeconds(report?.leadTime?.value)}
                </div>
                <p className="text-[11px] text-slate-400 mb-3">
                  Creation to Done ({report?.leadTime?.sampleSize ?? 0} completed tasks)
                </p>
                <div className="flex items-center gap-2 text-[11px]">
                  <span className="px-2 py-0.5 rounded-md bg-slate-800 text-slate-300 font-medium">
                    P50: {formatDurationSeconds(report?.leadTime?.p50)}
                  </span>
                  <span className="px-2 py-0.5 rounded-md bg-slate-800 text-amber-300 font-medium">
                    P90: {formatDurationSeconds(report?.leadTime?.p90)}
                  </span>
                </div>
              </div>

              {/* Cycle Time */}
              <div className="bg-slate-900/80 border border-slate-800/80 rounded-2xl p-5 shadow-lg">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Cycle Time
                  </span>
                  <div className="w-8 h-8 rounded-lg bg-teal-500/15 border border-teal-500/30 flex items-center justify-center text-teal-400">
                    <Timer className="w-4 h-4" />
                  </div>
                </div>
                <div className="text-2xl font-bold text-slate-100 mb-1">
                  {formatDurationSeconds(report?.cycleTime?.value)}
                </div>
                <p className="text-[11px] text-slate-400 mb-3">
                  In Progress to Done ({report?.cycleTime?.sampleSize ?? 0} tasks)
                </p>
                <div className="flex items-center gap-2 text-[11px]">
                  <span className="px-2 py-0.5 rounded-md bg-slate-800 text-slate-300 font-medium">
                    P50: {formatDurationSeconds(report?.cycleTime?.p50)}
                  </span>
                  <span className="px-2 py-0.5 rounded-md bg-slate-800 text-teal-300 font-medium">
                    P90: {formatDurationSeconds(report?.cycleTime?.p90)}
                  </span>
                </div>
              </div>

              {/* Velocity */}
              <div className="bg-slate-900/80 border border-slate-800/80 rounded-2xl p-5 shadow-lg">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Velocity
                  </span>
                  <div className="w-8 h-8 rounded-lg bg-purple-500/15 border border-purple-500/30 flex items-center justify-center text-purple-400">
                    <Zap className="w-4 h-4" />
                  </div>
                </div>
                <div className="text-2xl font-bold text-slate-100 mb-1">
                  {(report?.velocity?.value ?? 0).toFixed(1)} <span className="text-sm font-medium text-slate-400">pts</span>
                </div>
                <p className="text-[11px] text-slate-400 mb-3">
                  Story points delivered in {rangeDays}d window
                </p>
                <div className="flex items-center gap-2 text-[11px]">
                  <span className="px-2 py-0.5 rounded-md bg-purple-500/15 text-purple-300 font-medium">
                    {report?.velocity?.sampleSize ?? 0} scored tasks
                  </span>
                  <span className="px-2 py-0.5 rounded-md bg-slate-800 text-slate-300 font-medium">
                    ~{((report?.velocity?.value ?? 0) / Math.max(1, rangeDays / 7)).toFixed(1)} pts/wk
                  </span>
                </div>
              </div>

              {/* Throughput */}
              <div className="bg-slate-900/80 border border-slate-800/80 rounded-2xl p-5 shadow-lg">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Throughput
                  </span>
                  <div className="w-8 h-8 rounded-lg bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
                    <CheckCircle2 className="w-4 h-4" />
                  </div>
                </div>
                <div className="text-2xl font-bold text-slate-100 mb-1">
                  {report?.throughput?.value ?? 0} <span className="text-sm font-medium text-slate-400">tasks</span>
                </div>
                <p className="text-[11px] text-slate-400 mb-3">
                  Completed issues over last {rangeDays} days
                </p>
                <div className="flex items-center gap-2 text-[11px]">
                  <span className="px-2 py-0.5 rounded-md bg-emerald-500/15 text-emerald-300 font-medium">
                    {((report?.throughput?.value ?? 0) / rangeDays).toFixed(1)} tasks/day
                  </span>
                  <span className="px-2 py-0.5 rounded-md bg-slate-800 text-slate-300 font-medium">
                    {weeklySeries.length} active weeks
                  </span>
                </div>
              </div>
            </div>

            {/* Burndown & Cumulative Flow Chart */}
            <div className="bg-slate-900/80 border border-slate-800/80 rounded-2xl p-6 shadow-lg space-y-5">
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <h2 className="text-base font-bold text-slate-100 flex items-center gap-2">
                    <TrendingDown className="w-4 h-4 text-indigo-400" />
                    Burndown & Cumulative Flow
                  </h2>
                  <p className="text-xs text-slate-400">
                    Daily open story points vs. daily completed work across {burndownSeries.length} UTC days
                  </p>
                </div>

                <div className="flex items-center gap-3">
                  <div className="flex items-center gap-4 text-xs">
                    <span className="flex items-center gap-1.5 text-indigo-300 font-medium">
                      <span className="w-2.5 h-2.5 rounded-full bg-indigo-500 inline-block" />
                      {chartMode === 'points' ? 'Remaining Points' : 'Created Tasks'}
                    </span>
                    <span className="flex items-center gap-1.5 text-emerald-300 font-medium">
                      <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 inline-block" />
                      {chartMode === 'points' ? 'Completed Points' : 'Completed Tasks'}
                    </span>
                  </div>

                  <div className="flex items-center bg-slate-950 border border-slate-800 rounded-xl p-1">
                    <button
                      onClick={() => setChartMode('points')}
                      className={`px-2.5 py-1 rounded-lg text-xs font-semibold transition cursor-pointer ${
                        chartMode === 'points'
                          ? 'bg-indigo-600/30 text-indigo-300 border border-indigo-500/40'
                          : 'text-slate-400 hover:text-slate-200'
                      }`}
                    >
                      Story Points
                    </button>
                    <button
                      onClick={() => setChartMode('tasks')}
                      className={`px-2.5 py-1 rounded-lg text-xs font-semibold transition cursor-pointer ${
                        chartMode === 'tasks'
                          ? 'bg-indigo-600/30 text-indigo-300 border border-indigo-500/40'
                          : 'text-slate-400 hover:text-slate-200'
                      }`}
                    >
                      Task Count
                    </button>
                  </div>
                </div>
              </div>

              {burndownSeries.length === 0 ? (
                <div className="py-16 text-center text-xs text-slate-500">
                  No daily burndown snapshots available for this date range.
                </div>
              ) : (
                <BurndownSvgChart series={burndownSeries} mode={chartMode} />
              )}

              {/* Summary Strip */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2 border-t border-slate-800/80 text-xs">
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/60">
                  <div className="text-slate-400">Peak Remaining</div>
                  <div className="text-sm font-bold text-slate-100 mt-0.5">
                    {burndownSummary.peakRemaining.toFixed(1)} pts
                  </div>
                </div>
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/60">
                  <div className="text-slate-400">Current Remaining</div>
                  <div className="text-sm font-bold text-indigo-300 mt-0.5">
                    {burndownSummary.latestRemaining.toFixed(1)} pts
                  </div>
                </div>
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/60">
                  <div className="text-slate-400">Points Burned</div>
                  <div className="text-sm font-bold text-emerald-300 mt-0.5">
                    {burndownSummary.totalCompletedPts.toFixed(1)} pts
                  </div>
                </div>
                <div className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/60">
                  <div className="text-slate-400">Tasks Completed</div>
                  <div className="text-sm font-bold text-teal-300 mt-0.5">
                    {burndownSummary.totalCompletedTasks} tasks
                  </div>
                </div>
              </div>
            </div>

            {/* Weekly Throughput & Sprint Velocity */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Weekly Throughput */}
              <div className="bg-slate-900/80 border border-slate-800/80 rounded-2xl p-6 shadow-lg flex flex-col justify-between space-y-4">
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                      <Calendar className="w-4 h-4 text-teal-400" />
                      Weekly Throughput
                    </h3>
                    <span className="text-xs text-slate-400">ISO Week Buckets</span>
                  </div>
                  <p className="text-xs text-slate-400 mb-4">
                    Completed tasks and story points grouped by Monday UTC week start
                  </p>

                  {weeklySeries.length === 0 ? (
                    <div className="py-12 text-center text-xs text-slate-500">
                      No weekly throughput recorded in this window.
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {(() => {
                        const maxTasks = Math.max(...weeklySeries.map((w) => w.completedTasks), 1);
                        return weeklySeries.map((w, idx) => {
                          const pct = Math.round((w.completedTasks / maxTasks) * 100);
                          return (
                            <div key={idx} className="space-y-1">
                              <div className="flex items-center justify-between text-xs">
                                <span className="font-medium text-slate-300">
                                  Week of {formatShortDate(w.weekStart)}
                                </span>
                                <span className="font-semibold text-teal-300">
                                  {w.completedTasks} tasks · {w.completedPoints.toFixed(1)} pts
                                </span>
                              </div>
                              <div className="w-full h-2.5 rounded-full bg-slate-800 overflow-hidden">
                                <div
                                  className="h-full rounded-full bg-gradient-to-r from-indigo-500 to-teal-400 transition-all duration-300"
                                  style={{ width: `${Math.max(pct, w.completedTasks > 0 ? 6 : 0)}%` }}
                                />
                              </div>
                            </div>
                          );
                        });
                      })()}
                    </div>
                  )}
                </div>
              </div>

              {/* Sprint Velocity */}
              <div className="bg-slate-900/80 border border-slate-800/80 rounded-2xl p-6 shadow-lg flex flex-col justify-between space-y-4">
                <div>
                  <div className="flex items-center justify-between mb-1">
                    <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                      <TrendingUp className="w-4 h-4 text-emerald-400" />
                      Sprint Velocity
                    </h3>
                    {onNavigate && (
                      <button
                        onClick={() => onNavigate('backlog')}
                        className="text-xs text-indigo-400 hover:text-indigo-300 font-semibold flex items-center gap-1 cursor-pointer"
                      >
                        Manage Sprints
                        <ArrowUpRight className="w-3.5 h-3.5" />
                      </button>
                    )}
                  </div>
                  <p className="text-xs text-slate-400 mb-4">
                    Story points & tasks completed across overlapping project sprints
                  </p>

                  {sprintSeries.length === 0 ? (
                    <div className="py-12 text-center space-y-2">
                      <Layers className="w-7 h-7 text-slate-600 mx-auto" />
                      <p className="text-xs text-slate-500">
                        No sprints overlap this date range. Create or start a sprint in Backlog & Sprints.
                      </p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {(() => {
                        const maxPts = Math.max(...sprintSeries.map((s) => s.completedPoints), 1);
                        return sprintSeries.map((s) => {
                          const pct = Math.round((s.completedPoints / maxPts) * 100);
                          return (
                            <div
                              key={s.sprintId}
                              className="p-3 rounded-xl bg-slate-950/60 border border-slate-800/70 space-y-2"
                            >
                              <div className="flex items-center justify-between text-xs">
                                <div>
                                  <span className="font-bold text-slate-200">{s.sprintName}</span>
                                  <span className="text-slate-500 ml-2">
                                    {formatShortDate(s.startDate)} – {formatShortDate(s.endDate)}
                                  </span>
                                </div>
                                <span className="font-bold text-emerald-400">
                                  {s.completedPoints.toFixed(1)} pts ({s.completedTasks} tasks)
                                </span>
                              </div>
                              <div className="w-full h-2 rounded-full bg-slate-800 overflow-hidden">
                                <div
                                  className="h-full rounded-full bg-gradient-to-r from-emerald-500 to-teal-400 transition-all duration-300"
                                  style={{ width: `${Math.max(pct, s.completedPoints > 0 ? 6 : 0)}%` }}
                                />
                              </div>
                            </div>
                          );
                        });
                      })()}
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Time & Work Logs Report */}
            <div className="bg-slate-900/80 border border-slate-800/80 rounded-2xl p-6 shadow-lg space-y-5">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                    <Users className="w-4 h-4 text-indigo-400" />
                    Time & Work Logs Report
                  </h3>
                  <p className="text-xs text-slate-400">
                    Cumulative hours logged across contributors and tasks in this project
                  </p>
                </div>
                <span className="px-3 py-1 rounded-full bg-indigo-500/15 border border-indigo-500/30 text-indigo-300 text-xs font-bold">
                  {(timeReport?.totalHours ?? 0).toFixed(1)} hrs total
                </span>
              </div>

              {!timeReport || (timeReport.byUser.length === 0 && timeReport.byTask.length === 0) ? (
                <div className="py-8 text-center text-xs text-slate-500">
                  No work logs recorded for this project yet.
                </div>
              ) : (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  {/* By Contributor */}
                  <div className="space-y-3">
                    <div className="text-xs font-bold text-slate-400 uppercase tracking-wider">
                      By Contributor
                    </div>
                    {timeReport.byUser.map((u) => {
                      const total = Math.max(timeReport.totalHours, 0.1);
                      const pct = Math.min(100, Math.round((u.totalHours / total) * 100));
                      return (
                        <div key={u.userId} className="space-y-1.5">
                          <div className="flex items-center justify-between text-xs">
                            <span className="font-semibold text-slate-200">{u.userDisplayName}</span>
                            <span className="font-bold text-indigo-300">
                              {u.totalHours.toFixed(1)}h ({pct}%)
                            </span>
                          </div>
                          <div className="w-full h-2 rounded-full bg-slate-800 overflow-hidden">
                            <div
                              className="h-full rounded-full bg-indigo-500"
                              style={{ width: `${Math.max(pct, 4)}%` }}
                            />
                          </div>
                        </div>
                      );
                    })}
                  </div>

                  {/* By Task */}
                  <div className="space-y-2.5">
                    <div className="text-xs font-bold text-slate-400 uppercase tracking-wider">
                      Top Tasks by Logged Time
                    </div>
                    {timeReport.byTask.slice(0, 6).map((t) => (
                      <div
                        key={t.taskId}
                        className="flex items-center justify-between px-3.5 py-2.5 rounded-xl bg-slate-950/60 border border-slate-800/70 text-xs"
                      >
                        <span className="font-medium text-slate-200 truncate pr-3">{t.taskTitle}</span>
                        <span className="font-bold text-teal-300 shrink-0">
                          {t.totalHours.toFixed(1)} hrs
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
};

interface BurndownSvgChartProps {
  series: AnalyticsReportPayloadDTO['burndown'];
  mode: 'points' | 'tasks';
}

const BurndownSvgChart: React.FC<BurndownSvgChartProps> = ({ series, mode }) => {
  const width = 860;
  const height = 240;
  const padLeft = 44;
  const padRight = 20;
  const padTop = 20;
  const padBottom = 32;
  const innerW = width - padLeft - padRight;
  const innerH = height - padTop - padBottom;

  const primaryValues = series.map((d) =>
    mode === 'points' ? d.remainingPoints : d.createdTasks
  );
  const secondaryValues = series.map((d) =>
    mode === 'points' ? d.completedPoints : d.completedTasks
  );

  const maxY = Math.max(...primaryValues, ...secondaryValues, 1);

  const toX = (i: number) =>
    padLeft + (i / Math.max(series.length - 1, 1)) * innerW;
  const toY = (v: number) => padTop + innerH - (v / maxY) * innerH;

  const primaryPoints = primaryValues.map((v, i) => `${toX(i)},${toY(v)}`).join(' ');
  const secondaryPoints = secondaryValues.map((v, i) => `${toX(i)},${toY(v)}`).join(' ');

  const primaryArea = `${toX(0)},${padTop + innerH} ${primaryPoints} ${toX(
    series.length - 1
  )},${padTop + innerH}`;

  const yTicks = [0, 0.25, 0.5, 0.75, 1].map((t) => Math.round(maxY * t * 10) / 10);

  return (
    <div className="w-full overflow-x-auto">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="w-full h-60 select-none"
        preserveAspectRatio="none"
      >
        <defs>
          <linearGradient id="burndownPrimaryFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#6366f1" stopOpacity="0.32" />
            <stop offset="100%" stopColor="#6366f1" stopOpacity="0.0" />
          </linearGradient>
        </defs>

        {/* Horizontal grid lines */}
        {yTicks.map((tick, idx) => {
          const y = toY(tick);
          return (
            <g key={idx}>
              <line
                x1={padLeft}
                y1={y}
                x2={width - padRight}
                y2={y}
                stroke="#1e293b"
                strokeDasharray="4 4"
                strokeWidth="1"
              />
              <text
                x={padLeft - 8}
                y={y + 4}
                textAnchor="end"
                fontSize="10"
                fill="#64748b"
              >
                {tick}
              </text>
            </g>
          );
        })}

        {/* Primary Area + Line */}
        <polygon points={primaryArea} fill="url(#burndownPrimaryFill)" />
        <polyline
          fill="none"
          stroke="#6366f1"
          strokeWidth="2.5"
          points={primaryPoints}
        />

        {/* Secondary Line */}
        <polyline
          fill="none"
          stroke="#10b981"
          strokeWidth="2"
          strokeDasharray="5 3"
          points={secondaryPoints}
        />

        {/* Data dots & X-axis labels */}
        {series.map((d, i) => {
          const x = toX(i);
          const y1 = toY(primaryValues[i]);
          const y2 = toY(secondaryValues[i]);
          const stride = Math.max(1, Math.floor(series.length / 6));
          const showLabel = i === 0 || i === series.length - 1 || i % stride === 0;
          return (
            <g key={d.id || i}>
              <circle cx={x} cy={y1} r="3.5" fill="#6366f1" />
              <circle cx={x} cy={y2} r="3" fill="#10b981" />
              {showLabel && (
                <text
                  x={x}
                  y={height - 8}
                  textAnchor="middle"
                  fontSize="10"
                  fill="#94a3b8"
                >
                  {formatShortDate(d.date)}
                </text>
              )}
            </g>
          );
        })}
      </svg>
    </div>
  );
};

