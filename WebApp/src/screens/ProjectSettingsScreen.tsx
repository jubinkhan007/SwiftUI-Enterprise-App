import React, { useState, useEffect, useMemo } from 'react';
import {
  Settings,
  Plus,
  Trash2,
  CheckCircle2,
  AlertCircle,
  FolderKanban,
  Sliders,
  Zap,
  Check,
  X,
  RefreshCw,
  Tag,
  ArrowRight,
  Shield,
  Layers,
  Sparkles,
  HelpCircle
} from 'lucide-react';
import {
  WorkflowBundleDTO,
  WorkflowStatusDTO,
  WorkflowStatusCategory,
  AutomationRuleDTO,
  CreateWorkflowStatusRequest,
  CreateAutomationRuleRequest,
  HierarchyTreeDTO,
  NavDestination,
  TaskPriority
} from '../types';
import { api } from '../services/api';

export interface ProjectSettingsScreenProps {
  onNavigate?: (dest: NavDestination) => void;
}

const PRESET_COLORS = [
  '#4F46E5', // Indigo
  '#2563EB', // Blue
  '#06B6D4', // Cyan
  '#10B981', // Emerald
  '#F59E0B', // Amber
  '#EF4444', // Red
  '#8B5CF6', // Purple
  '#EC4899', // Pink
  '#64748B', // Slate
];

const TRIGGER_OPTIONS = [
  { id: 'task.status_changed', title: 'Status Changed', desc: 'Fires when a task moves to a new status' },
  { id: 'task.created', title: 'Task Created', desc: 'Fires immediately upon task creation' },
  { id: 'task.updated', title: 'Task Updated', desc: 'Fires when task attributes are edited' },
  { id: 'task.priority_changed', title: 'Priority Changed', desc: 'Fires when task urgency shifts' },
  { id: 'task.type_changed', title: 'Type Changed', desc: 'Fires when type (bug, story, epic) changes' },
  { id: 'sprint.completed', title: 'Sprint Completed', desc: 'Fires when a sprint is closed' },
];

const ACTION_OPTIONS = [
  { id: 'setPriority', title: 'Set Priority', desc: 'Change task priority' },
  { id: 'setStatusId', title: 'Set Status', desc: 'Move task to a workflow status' },
  { id: 'assignUserId', title: 'Assign User', desc: 'Assign task to a team member UUID' },
  { id: 'addLabel', title: 'Add Label', desc: 'Attach a label tag to the task' },
  { id: 'removeLabel', title: 'Remove Label', desc: 'Detach a label tag from the task' },
  { id: 'moveUncompletedToNextSprint', title: 'Move Uncompleted to Next Sprint', desc: 'Migrate unfinished tasks to active sprint' },
];

export const ProjectSettingsScreen: React.FC<ProjectSettingsScreenProps> = () => {
  const [hierarchy, setHierarchy] = useState<HierarchyTreeDTO | null>(null);
  const [selectedProjectId, setSelectedProjectId] = useState<string>('');
  const [workflow, setWorkflow] = useState<WorkflowBundleDTO | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'statuses' | 'rules'>('statuses');

  // Modals
  const [showCreateStatusModal, setShowCreateStatusModal] = useState<boolean>(false);
  const [showCreateRuleModal, setShowCreateRuleModal] = useState<boolean>(false);

  // Create Status Form State
  const [newStatusName, setNewStatusName] = useState<string>('');
  const [newStatusColor, setNewStatusColor] = useState<string>('#4F46E5');
  const [newStatusCategory, setNewStatusCategory] = useState<WorkflowStatusCategory>('backlog');
  const [newStatusDefault, setNewStatusDefault] = useState<boolean>(false);
  const [newStatusFinal, setNewStatusFinal] = useState<boolean>(false);
  const [isSubmittingStatus, setIsSubmittingStatus] = useState<boolean>(false);

  // Automation Rule Builder Form State
  const [newRuleName, setNewRuleName] = useState<string>('');
  const [newRuleEnabled, setNewRuleEnabled] = useState<boolean>(true);
  const [newRuleTrigger, setNewRuleTrigger] = useState<string>('task.status_changed');
  const [triggerToStatusId, setTriggerToStatusId] = useState<string>('');
  const [newRuleActionType, setNewRuleActionType] = useState<string>('setPriority');
  const [actionPriority, setActionPriority] = useState<TaskPriority>('medium');
  const [actionStatusId, setActionStatusId] = useState<string>('');
  const [actionUserId, setActionUserId] = useState<string>('');
  const [actionLabel, setActionLabel] = useState<string>('');
  const [isSubmittingRule, setIsSubmittingRule] = useState<boolean>(false);

  // Load project hierarchy
  useEffect(() => {
    let isMounted = true;
    async function loadHierarchy() {
      try {
        const tree = await api.getHierarchy();
        if (!isMounted) return;
        setHierarchy(tree);

        // Auto-select first project
        if (tree?.spaces?.length) {
          for (const space of tree.spaces) {
            if (space.projects?.length) {
              setSelectedProjectId(space.projects[0].project.id);
              break;
            }
          }
        }
      } catch (err: any) {
        if (isMounted) setError(err.message || 'Failed to load projects');
      }
    }
    loadHierarchy();
    return () => { isMounted = false; };
  }, []);

  // Fetch workflow bundle when project changes
  const fetchWorkflow = async (projectId: string) => {
    if (!projectId) return;
    setIsLoading(true);
    setError(null);
    try {
      const bundle = await api.getProjectWorkflow(projectId);
      setWorkflow(bundle);
      if (bundle.statuses.length > 0 && !actionStatusId) {
        setActionStatusId(bundle.statuses[0].id);
      }
    } catch (err: any) {
      setError(err.message || 'Failed to fetch workflow settings');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (selectedProjectId) {
      fetchWorkflow(selectedProjectId);
    }
  }, [selectedProjectId]);

  // Flattened projects list for dropdown
  const allProjects = useMemo(() => {
    if (!hierarchy?.spaces) return [];
    const list: { id: string; name: string; spaceName: string }[] = [];
    for (const space of hierarchy.spaces) {
      for (const p of space.projects || []) {
        list.push({
          id: p.project.id,
          name: p.project.name,
          spaceName: space.space.name,
        });
      }
    }
    return list;
  }, [hierarchy]);

  // Helper to show transient success banner
  const triggerSuccess = (msg: string) => {
    setSuccessMessage(msg);
    setTimeout(() => setSuccessMessage(null), 4000);
  };

  // Status Handlers
  const handleCreateStatus = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedProjectId || !newStatusName.trim()) return;

    setIsSubmittingStatus(true);
    setError(null);
    try {
      const payload: CreateWorkflowStatusRequest = {
        name: newStatusName.trim(),
        color: newStatusColor,
        category: newStatusCategory,
        isDefault: newStatusDefault,
        isFinal: newStatusFinal,
      };
      await api.createWorkflowStatus(selectedProjectId, payload);
      triggerSuccess(`Status "${newStatusName.trim()}" created successfully`);
      setShowCreateStatusModal(false);
      setNewStatusName('');
      setNewStatusColor('#4F46E5');
      setNewStatusCategory('backlog');
      setNewStatusDefault(false);
      setNewStatusFinal(false);
      await fetchWorkflow(selectedProjectId);
    } catch (err: any) {
      setError(err.message || 'Failed to create status');
    } finally {
      setIsSubmittingStatus(false);
    }
  };

  const handleDeleteStatus = async (status: WorkflowStatusDTO) => {
    if (status.isLocked) {
      setError('System statuses cannot be deleted.');
      return;
    }
    if (!window.confirm(`Delete status "${status.name}"? This cannot be undone.`)) {
      return;
    }

    try {
      await api.deleteWorkflowStatus(status.id);
      triggerSuccess(`Status "${status.name}" deleted`);
      await fetchWorkflow(selectedProjectId);
    } catch (err: any) {
      setError(err.message || 'Failed to delete status. Check if tasks are assigned to it.');
    }
  };

  // Rule Handlers
  const generatedActionsJson = useMemo(() => {
    switch (newRuleActionType) {
      case 'setPriority':
        return JSON.stringify([{ type: 'setPriority', value: actionPriority }]);
      case 'setStatusId':
        if (!actionStatusId) return null;
        return JSON.stringify([{ type: 'setStatusId', value: actionStatusId }]);
      case 'assignUserId':
        if (!actionUserId.trim()) return null;
        return JSON.stringify([{ type: 'assignUserId', value: actionUserId.trim() }]);
      case 'addLabel':
        if (!actionLabel.trim()) return null;
        return JSON.stringify([{ type: 'addLabel', value: actionLabel.trim() }]);
      case 'removeLabel':
        if (!actionLabel.trim()) return null;
        return JSON.stringify([{ type: 'removeLabel', value: actionLabel.trim() }]);
      case 'moveUncompletedToNextSprint':
        return JSON.stringify([{ type: 'moveUncompletedToNextSprint' }]);
      default:
        return null;
    }
  }, [newRuleActionType, actionPriority, actionStatusId, actionUserId, actionLabel]);

  const generatedTriggerConfigJson = useMemo(() => {
    if (newRuleTrigger === 'task.status_changed' && triggerToStatusId) {
      return JSON.stringify({ toStatusId: triggerToStatusId });
    }
    return null;
  }, [newRuleTrigger, triggerToStatusId]);

  const hasSelfTriggerWarning = useMemo(() => {
    return (
      newRuleTrigger === 'task.status_changed' &&
      newRuleActionType === 'setStatusId' &&
      triggerToStatusId &&
      actionStatusId &&
      triggerToStatusId === actionStatusId
    );
  }, [newRuleTrigger, newRuleActionType, triggerToStatusId, actionStatusId]);

  const canSubmitRule = useMemo(() => {
    if (!newRuleName.trim()) return false;
    if (!generatedActionsJson) return false;
    return true;
  }, [newRuleName, generatedActionsJson]);

  const handleCreateRule = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedProjectId || !canSubmitRule) return;

    setIsSubmittingRule(true);
    setError(null);
    try {
      const payload: CreateAutomationRuleRequest = {
        name: newRuleName.trim(),
        isEnabled: newRuleEnabled,
        triggerType: newRuleTrigger,
        triggerConfigJson: generatedTriggerConfigJson,
        actionsJson: generatedActionsJson,
      };
      await api.createAutomationRule(selectedProjectId, payload);
      triggerSuccess(`Rule "${newRuleName.trim()}" created successfully`);
      setShowCreateRuleModal(false);
      setNewRuleName('');
      setNewRuleEnabled(true);
      setNewRuleTrigger('task.status_changed');
      setTriggerToStatusId('');
      setNewRuleActionType('setPriority');
      setActionLabel('');
      setActionUserId('');
      await fetchWorkflow(selectedProjectId);
    } catch (err: any) {
      setError(err.message || 'Failed to create automation rule');
    } finally {
      setIsSubmittingRule(false);
    }
  };

  const handleToggleRule = async (rule: AutomationRuleDTO) => {
    try {
      await api.updateAutomationRule(rule.id, { isEnabled: !rule.isEnabled });
      await fetchWorkflow(selectedProjectId);
    } catch (err: any) {
      setError(err.message || 'Failed to toggle rule state');
    }
  };

  const handleDeleteRule = async (rule: AutomationRuleDTO) => {
    if (!window.confirm(`Delete automation rule "${rule.name}"?`)) return;
    try {
      await api.deleteAutomationRule(rule.id);
      triggerSuccess(`Rule "${rule.name}" deleted`);
      await fetchWorkflow(selectedProjectId);
    } catch (err: any) {
      setError(err.message || 'Failed to delete rule');
    }
  };

  const categoryColor = (cat: WorkflowStatusCategory) => {
    switch (cat) {
      case 'backlog':
        return 'text-slate-400 bg-slate-800/80 border-slate-700';
      case 'active':
        return 'text-blue-400 bg-blue-950/60 border-blue-800/60';
      case 'completed':
        return 'text-emerald-400 bg-emerald-950/60 border-emerald-800/60';
      case 'cancelled':
        return 'text-rose-400 bg-rose-950/60 border-rose-800/60';
    }
  };

  return (
    <div className="flex flex-col h-full bg-slate-950 text-slate-100 overflow-y-auto">
      {/* Top Header */}
      <div className="p-6 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md sticky top-0 z-10 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 to-violet-500 flex items-center justify-center shadow-lg shadow-indigo-500/20">
            <Sliders className="w-5 h-5 text-white" />
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h1 className="text-xl font-bold tracking-tight text-white">Project Settings &amp; Workflow</h1>
              {workflow && (
                <span className="px-2 py-0.5 rounded-full text-xs font-semibold bg-indigo-950 text-indigo-300 border border-indigo-800/60">
                  v{workflow.workflowVersion}
                </span>
              )}
            </div>
            <p className="text-xs text-slate-400">Configure lifecycle columns, state categories, and trigger-action automations</p>
          </div>
        </div>

        {/* Project Selector & Actions */}
        <div className="flex items-center flex-wrap gap-3">
          <div className="flex items-center space-x-2 bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-1.5 shadow-inner">
            <FolderKanban className="w-4 h-4 text-slate-400" />
            <select
              aria-label="Select Project"
              value={selectedProjectId}
              onChange={(e) => setSelectedProjectId(e.target.value)}
              className="bg-transparent text-sm font-medium text-slate-200 focus:outline-none cursor-pointer"
            >
              {allProjects.map((p) => (
                <option key={p.id} value={p.id} className="bg-slate-900 text-slate-200">
                  {p.spaceName} / {p.name}
                </option>
              ))}
            </select>
          </div>

          <button
            onClick={() => fetchWorkflow(selectedProjectId)}
            title="Refresh"
            aria-label="Refresh workflow"
            className="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition-colors border border-slate-700"
          >
            <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
          </button>

          <button
            onClick={() => setShowCreateStatusModal(true)}
            className="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold shadow-md shadow-indigo-600/30 transition-colors"
          >
            <Plus className="w-4 h-4" />
            <span>New Status</span>
          </button>

          <button
            onClick={() => setShowCreateRuleModal(true)}
            className="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-violet-600 hover:bg-violet-500 text-white text-sm font-semibold shadow-md shadow-violet-600/30 transition-colors"
          >
            <Zap className="w-4 h-4" />
            <span>New Rule</span>
          </button>
        </div>
      </div>

      {/* Alerts */}
      <div className="px-6 pt-4">
        {error && (
          <div className="mb-4 p-3 rounded-lg bg-rose-950/70 border border-rose-800/80 flex items-center justify-between text-rose-200 text-sm">
            <div className="flex items-center space-x-2">
              <AlertCircle className="w-4 h-4 text-rose-400 shrink-0" />
              <span>{error}</span>
            </div>
            <button onClick={() => setError(null)} className="text-rose-400 hover:text-rose-300">
              <X className="w-4 h-4" />
            </button>
          </div>
        )}
        {successMessage && (
          <div className="mb-4 p-3 rounded-lg bg-emerald-950/70 border border-emerald-800/80 flex items-center space-x-2 text-emerald-200 text-sm">
            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
            <span>{successMessage}</span>
          </div>
        )}
      </div>

      {/* Tabs */}
      <div className="px-6 border-b border-slate-800 flex space-x-4">
        <button
          onClick={() => setActiveTab('statuses')}
          className={`py-3 px-2 border-b-2 text-sm font-semibold flex items-center space-x-2 transition-all ${
            activeTab === 'statuses'
              ? 'border-indigo-500 text-indigo-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Layers className="w-4 h-4" />
          <span>Workflow Statuses</span>
          {workflow && (
            <span className="px-2 py-0.5 text-xs rounded-full bg-slate-800 text-slate-300">
              {workflow.statuses.length}
            </span>
          )}
        </button>

        <button
          onClick={() => setActiveTab('rules')}
          className={`py-3 px-2 border-b-2 text-sm font-semibold flex items-center space-x-2 transition-all ${
            activeTab === 'rules'
              ? 'border-violet-500 text-violet-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Zap className="w-4 h-4" />
          <span>Automation Rules</span>
          {workflow && (
            <span className="px-2 py-0.5 text-xs rounded-full bg-slate-800 text-slate-300">
              {workflow.rules.length}
            </span>
          )}
        </button>
      </div>

      {/* Content Area */}
      <div className="p-6 flex-1">
        {isLoading && !workflow ? (
          <div className="flex flex-col items-center justify-center py-24 space-y-3">
            <RefreshCw className="w-8 h-8 text-indigo-400 animate-spin" />
            <p className="text-sm text-slate-400">Loading project workflow...</p>
          </div>
        ) : activeTab === 'statuses' ? (
          /* Workflow Statuses List */
          <div className="space-y-4 max-w-5xl">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-base font-bold text-white">Configured Statuses</h2>
                <p className="text-xs text-slate-400">Tasks move linearly or dynamically through these project steps</p>
              </div>
              <button
                onClick={() => setShowCreateStatusModal(true)}
                className="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-indigo-400 border border-slate-700 text-xs font-semibold"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Add Custom Status</span>
              </button>
            </div>

            {workflow?.statuses && workflow.statuses.length > 0 ? (
              <div className="grid gap-3">
                {workflow.statuses
                  .slice()
                  .sort((a, b) => a.position - b.position)
                  .map((status, index) => (
                    <div
                      key={status.id}
                      className="p-4 rounded-xl bg-slate-900 border border-slate-800 flex items-center justify-between hover:border-slate-700 transition-all shadow-sm"
                    >
                      <div className="flex items-center space-x-4">
                        <span className="text-xs font-mono text-slate-500 w-5">{index + 1}</span>
                        <div
                          className="w-4 h-4 rounded-full ring-2 ring-slate-800 shadow-sm shrink-0"
                          style={{ backgroundColor: status.color }}
                        />
                        <div>
                          <div className="flex items-center space-x-2">
                            <span className="font-semibold text-white text-sm">{status.name}</span>
                            <span className={`px-2 py-0.5 rounded-full text-xs font-medium border capitalize ${categoryColor(status.category)}`}>
                              {status.category}
                            </span>
                          </div>
                          <div className="flex items-center space-x-2 text-xs text-slate-400 mt-0.5">
                            {status.isDefault && (
                              <span className="text-indigo-400 font-medium">Default entry</span>
                            )}
                            {status.isDefault && status.isFinal && <span>•</span>}
                            {status.isFinal && (
                              <span className="text-emerald-400 font-medium">Final state</span>
                            )}
                            {status.legacyStatus && (
                              <>
                                <span>•</span>
                                <span className="text-slate-500">Legacy: {status.legacyStatus}</span>
                              </>
                            )}
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center space-x-3">
                        {status.isLocked ? (
                          <div className="flex items-center space-x-1 px-2.5 py-1 rounded-md bg-slate-800 text-slate-400 text-xs border border-slate-700">
                            <Shield className="w-3.5 h-3.5" />
                            <span>System Locked</span>
                          </div>
                        ) : (
                          <button
                            onClick={() => handleDeleteStatus(status)}
                            title="Delete status"
                            className="p-2 rounded-lg bg-slate-800/80 hover:bg-rose-950/50 hover:text-rose-400 text-slate-400 border border-slate-700/60 transition-colors"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
              </div>
            ) : (
              <div className="text-center py-16 bg-slate-900/40 rounded-2xl border border-dashed border-slate-800">
                <Layers className="w-10 h-10 text-slate-600 mx-auto mb-2" />
                <p className="text-sm text-slate-400">No workflow statuses found for this project.</p>
              </div>
            )}
          </div>
        ) : (
          /* Automation Rules List */
          <div className="space-y-4 max-w-5xl">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-base font-bold text-white">Configured Automations</h2>
                <p className="text-xs text-slate-400">Rules evaluate automatically when tasks undergo lifecycle events</p>
              </div>
              <button
                onClick={() => setShowCreateRuleModal(true)}
                className="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-violet-400 border border-slate-700 text-xs font-semibold"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Add Automation</span>
              </button>
            </div>

            {workflow?.rules && workflow.rules.length > 0 ? (
              <div className="grid gap-3">
                {workflow.rules.map((rule) => {
                  let parsedActions: any[] = [];
                  try {
                    if (rule.actionsJson) parsedActions = JSON.parse(rule.actionsJson);
                  } catch {
                    parsedActions = [];
                  }

                  let parsedTriggerConfig: any = null;
                  try {
                    if (rule.triggerConfigJson) parsedTriggerConfig = JSON.parse(rule.triggerConfigJson);
                  } catch {
                    parsedTriggerConfig = null;
                  }

                  return (
                    <div
                      key={rule.id}
                      className={`p-4 rounded-xl bg-slate-900 border transition-all shadow-sm ${
                        rule.isEnabled ? 'border-slate-800' : 'border-slate-800/40 opacity-70'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-4">
                        <div className="space-y-2 flex-1">
                          <div className="flex items-center space-x-3">
                            <span className="font-semibold text-white text-sm">{rule.name}</span>
                            <span className={`px-2 py-0.5 rounded-full text-xs font-semibold ${
                              rule.isEnabled ? 'bg-violet-950 text-violet-300 border border-violet-800' : 'bg-slate-800 text-slate-400'
                            }`}>
                              {rule.isEnabled ? 'Enabled' : 'Disabled'}
                            </span>
                          </div>

                          {/* Trigger -> Action Representation */}
                          <div className="flex flex-wrap items-center gap-2 text-xs">
                            <div className="flex items-center space-x-1 px-2.5 py-1 rounded-md bg-slate-800 text-slate-300 border border-slate-700 font-mono">
                              <Sparkles className="w-3 h-3 text-indigo-400" />
                              <span>{rule.triggerType}</span>
                              {parsedTriggerConfig?.toStatusId && (
                                <span className="text-slate-400">(to: {parsedTriggerConfig.toStatusId.slice(0, 8)}...)</span>
                              )}
                            </div>

                            <ArrowRight className="w-3.5 h-3.5 text-slate-500" />

                            {parsedActions.length > 0 ? (
                              parsedActions.map((act, idx) => (
                                <div
                                  key={idx}
                                  className="flex items-center space-x-1 px-2.5 py-1 rounded-md bg-violet-950/60 text-violet-300 border border-violet-800/60 font-mono"
                                >
                                  <span>{act.type}</span>
                                  {act.value && <span className="text-violet-400 font-bold">: {act.value}</span>}
                                </div>
                              ))
                            ) : (
                              <span className="text-slate-500 italic">No action body</span>
                            )}
                          </div>
                        </div>

                        {/* Controls */}
                        <div className="flex items-center space-x-3 shrink-0">
                          {/* Toggle switch */}
                          <button
                            onClick={() => handleToggleRule(rule)}
                            className={`w-11 h-6 flex items-center rounded-full p-1 cursor-pointer transition-colors ${
                              rule.isEnabled ? 'bg-violet-600' : 'bg-slate-700'
                            }`}
                            title={rule.isEnabled ? 'Disable rule' : 'Enable rule'}
                          >
                            <div
                              className={`bg-white w-4 h-4 rounded-full shadow-md transform transition-transform ${
                                rule.isEnabled ? 'translate-x-5' : 'translate-x-0'
                              }`}
                            />
                          </button>

                          <button
                            onClick={() => handleDeleteRule(rule)}
                            title="Delete rule"
                            className="p-2 rounded-lg bg-slate-800/80 hover:bg-rose-950/50 hover:text-rose-400 text-slate-400 border border-slate-700/60 transition-colors"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="text-center py-16 bg-slate-900/40 rounded-2xl border border-dashed border-slate-800">
                <Zap className="w-10 h-10 text-slate-600 mx-auto mb-2" />
                <p className="text-sm text-slate-400">No automation rules configured yet.</p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* CREATE STATUS MODAL */}
      {showCreateStatusModal && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-5 animate-in fade-in zoom-in-95 duration-200">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center space-x-2">
                <div className="w-8 h-8 rounded-lg bg-indigo-600/20 text-indigo-400 flex items-center justify-center">
                  <Layers className="w-4 h-4" />
                </div>
                <h3 className="text-base font-bold text-white">Create Workflow Status</h3>
              </div>
              <button
                onClick={() => setShowCreateStatusModal(false)}
                className="text-slate-400 hover:text-slate-200 p-1 rounded-md"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateStatus} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Status Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g., In QA, Staging Verification"
                  value={newStatusName}
                  onChange={(e) => setNewStatusName(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg bg-slate-800 border border-slate-700 text-white text-sm focus:outline-none focus:border-indigo-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Badge Color</label>
                <div className="flex items-center space-x-2 mb-2">
                  <div
                    className="w-8 h-8 rounded-lg ring-2 ring-slate-700 shrink-0"
                    style={{ backgroundColor: newStatusColor }}
                  />
                  <input
                    type="text"
                    value={newStatusColor}
                    onChange={(e) => setNewStatusColor(e.target.value)}
                    placeholder="#4F46E5"
                    className="w-full px-3 py-1.5 rounded-lg bg-slate-800 border border-slate-700 text-white font-mono text-sm focus:outline-none"
                  />
                </div>
                <div className="flex flex-wrap gap-2">
                  {PRESET_COLORS.map((c) => (
                    <button
                      key={c}
                      type="button"
                      onClick={() => setNewStatusColor(c)}
                      className={`w-6 h-6 rounded-full border-2 transition-transform ${
                        newStatusColor.toLowerCase() === c.toLowerCase() ? 'scale-110 border-white' : 'border-transparent'
                      }`}
                      style={{ backgroundColor: c }}
                    />
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Category</label>
                <select
                  value={newStatusCategory}
                  onChange={(e) => setNewStatusCategory(e.target.value as WorkflowStatusCategory)}
                  className="w-full px-3 py-2 rounded-lg bg-slate-800 border border-slate-700 text-white text-sm focus:outline-none"
                >
                  <option value="backlog">Backlog — Not yet in progress</option>
                  <option value="active">Active — Currently in work / review</option>
                  <option value="completed">Completed — Finished lifecycle</option>
                  <option value="cancelled">Cancelled — Abandoned or voided</option>
                </select>
              </div>

              <div className="pt-2 border-t border-slate-800 space-y-3">
                <label className="flex items-center space-x-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={newStatusDefault}
                    onChange={(e) => setNewStatusDefault(e.target.checked)}
                    className="rounded bg-slate-800 border-slate-700 text-indigo-600 focus:ring-0"
                  />
                  <span className="text-xs text-slate-300">Set as Default Entry Status for new tasks</span>
                </label>

                <label className="flex items-center space-x-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={newStatusFinal}
                    onChange={(e) => setNewStatusFinal(e.target.checked)}
                    className="rounded bg-slate-800 border-slate-700 text-indigo-600 focus:ring-0"
                  />
                  <span className="text-xs text-slate-300">Mark as Final / Resolution Status</span>
                </label>
              </div>

              <div className="pt-4 flex items-center justify-end space-x-3">
                <button
                  type="button"
                  onClick={() => setShowCreateStatusModal(false)}
                  className="px-4 py-2 rounded-lg text-sm text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingStatus || !newStatusName.trim()}
                  className="px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold shadow-md shadow-indigo-600/30 disabled:opacity-50"
                >
                  {isSubmittingStatus ? 'Creating...' : 'Create Status'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* CREATE AUTOMATION RULE BUILDER MODAL */}
      {showCreateRuleModal && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-xl w-full p-6 shadow-2xl space-y-5 animate-in fade-in zoom-in-95 duration-200 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center space-x-2">
                <div className="w-8 h-8 rounded-lg bg-violet-600/20 text-violet-400 flex items-center justify-center">
                  <Zap className="w-4 h-4" />
                </div>
                <h3 className="text-base font-bold text-white">Automation Rule Builder</h3>
              </div>
              <button
                onClick={() => setShowCreateRuleModal(false)}
                className="text-slate-400 hover:text-slate-200 p-1 rounded-md"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateRule} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Rule Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g., Auto-escalate critical bugs"
                  value={newRuleName}
                  onChange={(e) => setNewRuleName(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg bg-slate-800 border border-slate-700 text-white text-sm focus:outline-none focus:border-violet-500"
                />
              </div>

              {/* TRIGGER SECTION */}
              <div className="p-3.5 rounded-xl bg-slate-800/60 border border-slate-700 space-y-3">
                <div className="flex items-center space-x-2">
                  <Sparkles className="w-4 h-4 text-indigo-400" />
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-300">When (Trigger)</span>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  {TRIGGER_OPTIONS.map((opt) => (
                    <button
                      key={opt.id}
                      type="button"
                      onClick={() => setNewRuleTrigger(opt.id)}
                      className={`p-2.5 rounded-lg border text-left transition-all ${
                        newRuleTrigger === opt.id
                          ? 'bg-indigo-950/70 border-indigo-500 text-white'
                          : 'bg-slate-900/60 border-slate-800 text-slate-400 hover:text-slate-200'
                      }`}
                    >
                      <div className="text-xs font-bold">{opt.title}</div>
                      <div className="text-[10px] text-slate-500 truncate">{opt.desc}</div>
                    </button>
                  ))}
                </div>

                {newRuleTrigger === 'task.status_changed' && (
                  <div className="pt-2 border-t border-slate-700/60">
                    <label className="block text-[11px] font-medium text-slate-400 mb-1">To Status (Optional filter)</label>
                    <select
                      value={triggerToStatusId}
                      onChange={(e) => setTriggerToStatusId(e.target.value)}
                      className="w-full px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-slate-200 text-xs focus:outline-none"
                    >
                      <option value="">Any Status</option>
                      {workflow?.statuses.map((s) => (
                        <option key={s.id} value={s.id}>
                          {s.name} ({s.category})
                        </option>
                      ))}
                    </select>
                  </div>
                )}
              </div>

              {/* ACTION SECTION */}
              <div className="p-3.5 rounded-xl bg-slate-800/60 border border-slate-700 space-y-3">
                <div className="flex items-center space-x-2">
                  <Zap className="w-4 h-4 text-violet-400" />
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-300">Then (Action)</span>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  {ACTION_OPTIONS.map((act) => (
                    <button
                      key={act.id}
                      type="button"
                      onClick={() => setNewRuleActionType(act.id)}
                      className={`p-2.5 rounded-lg border text-left transition-all ${
                        newRuleActionType === act.id
                          ? 'bg-violet-950/70 border-violet-500 text-white'
                          : 'bg-slate-900/60 border-slate-800 text-slate-400 hover:text-slate-200'
                      }`}
                    >
                      <div className="text-xs font-bold">{act.title}</div>
                      <div className="text-[10px] text-slate-500 truncate">{act.desc}</div>
                    </button>
                  ))}
                </div>

                {/* Contextual Action Parameter */}
                <div className="pt-2 border-t border-slate-700/60">
                  {newRuleActionType === 'setPriority' && (
                    <div>
                      <label className="block text-[11px] font-medium text-slate-400 mb-1">Target Priority</label>
                      <select
                        value={actionPriority}
                        onChange={(e) => setActionPriority(e.target.value as TaskPriority)}
                        className="w-full px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-slate-200 text-xs focus:outline-none"
                      >
                        <option value="low">Low</option>
                        <option value="medium">Medium</option>
                        <option value="high">High</option>
                        <option value="critical">Critical</option>
                      </select>
                    </div>
                  )}

                  {newRuleActionType === 'setStatusId' && (
                    <div>
                      <label className="block text-[11px] font-medium text-slate-400 mb-1">Target Status</label>
                      <select
                        value={actionStatusId}
                        onChange={(e) => setActionStatusId(e.target.value)}
                        className="w-full px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-slate-200 text-xs focus:outline-none"
                      >
                        {workflow?.statuses.map((s) => (
                          <option key={s.id} value={s.id}>
                            {s.name} ({s.category})
                          </option>
                        ))}
                      </select>
                    </div>
                  )}

                  {newRuleActionType === 'assignUserId' && (
                    <div>
                      <label className="block text-[11px] font-medium text-slate-400 mb-1">Assignee User UUID</label>
                      <input
                        type="text"
                        placeholder="e.g., 00000000-0000-0000-0000-000000000001"
                        value={actionUserId}
                        onChange={(e) => setActionUserId(e.target.value)}
                        className="w-full px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-white font-mono text-xs focus:outline-none"
                      />
                    </div>
                  )}

                  {(newRuleActionType === 'addLabel' || newRuleActionType === 'removeLabel') && (
                    <div>
                      <label className="block text-[11px] font-medium text-slate-400 mb-1">Label Tag</label>
                      <input
                        type="text"
                        placeholder="e.g., blocker, regression, frontend"
                        value={actionLabel}
                        onChange={(e) => setActionLabel(e.target.value)}
                        className="w-full px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs focus:outline-none"
                      />
                    </div>
                  )}

                  {newRuleActionType === 'moveUncompletedToNextSprint' && (
                    <p className="text-xs text-slate-400 italic">
                      Remaining open tasks in the completed sprint will automatically migrate to the next planned sprint.
                    </p>
                  )}
                </div>
              </div>

              {/* WARNING ALERT */}
              {hasSelfTriggerWarning && (
                <div className="p-3 rounded-lg bg-amber-950/70 border border-amber-800 text-amber-200 text-xs flex items-center space-x-2">
                  <AlertCircle className="w-4 h-4 text-amber-400 shrink-0" />
                  <span>This rule can re-trigger itself (trigger To Status matches target action status).</span>
                </div>
              )}

              {/* LIVE PREVIEW & JSON */}
              <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 font-mono text-xs space-y-1">
                <div className="text-[11px] text-slate-500 font-sans font-semibold">Inspection Preview:</div>
                <div className="text-indigo-400">triggerType: "{newRuleTrigger}"</div>
                {generatedTriggerConfigJson && (
                  <div className="text-slate-400">triggerConfigJson: {generatedTriggerConfigJson}</div>
                )}
                <div className="text-violet-400">actionsJson: {generatedActionsJson || 'null'}</div>
              </div>

              <div className="pt-2 flex items-center justify-end space-x-3">
                <button
                  type="button"
                  onClick={() => setShowCreateRuleModal(false)}
                  className="px-4 py-2 rounded-lg text-sm text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingRule || !canSubmitRule}
                  className="px-4 py-2 rounded-lg bg-violet-600 hover:bg-violet-500 text-white text-sm font-semibold shadow-md shadow-violet-600/30 disabled:opacity-50"
                >
                  {isSubmittingRule ? 'Creating...' : 'Create Automation'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
