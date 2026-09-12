import React, { useEffect, useState } from 'react';
import { TaskItemDTO, TaskPriority, TaskStatus, TaskType } from '../types';
import { api } from '../services/api';
import { 
  Plus, 
  Search, 
  Filter, 
  RefreshCw, 
  CheckCircle2, 
  Clock, 
  AlertCircle, 
  User, 
  Layers,
  ChevronRight,
  ChevronLeft,
  ArrowLeft,
  ArrowRight,
  MoreVertical,
  Edit3,
  Edit2,
  Trash2,
  RotateCcw,
  GripVertical,
  GripHorizontal,
  X,
  Tag,
  Hash,
  Sparkles
} from 'lucide-react';

interface KanbanBoardScreenProps {
  myTasksOnly?: boolean;
}

export interface BoardColumn {
  id: string;
  status: TaskStatus;
  title: string;
  color: string;
}

const COLOR_OPTIONS = [
  { label: 'Slate', value: 'border-slate-500/30 text-slate-300' },
  { label: 'Blue', value: 'border-blue-500/30 text-blue-400' },
  { label: 'Amber', value: 'border-amber-500/30 text-amber-400' },
  { label: 'Emerald', value: 'border-emerald-500/30 text-emerald-400' },
  { label: 'Purple', value: 'border-purple-500/30 text-purple-400' },
  { label: 'Rose', value: 'border-rose-500/30 text-rose-400' },
  { label: 'Cyan', value: 'border-cyan-500/30 text-cyan-400' },
];

const DEFAULT_COLUMNS: BoardColumn[] = [
  { id: 'col-todo', status: 'todo', title: 'To Do', color: 'border-slate-500/30 text-slate-300' },
  { id: 'col-in_progress', status: 'in_progress', title: 'In Progress', color: 'border-blue-500/30 text-blue-400' },
  { id: 'col-in_review', status: 'in_review', title: 'In Review', color: 'border-amber-500/30 text-amber-400' },
  { id: 'col-done', status: 'done', title: 'Done', color: 'border-emerald-500/30 text-emerald-400' },
];

export const KanbanBoardScreen: React.FC<KanbanBoardScreenProps> = ({ myTasksOnly = false }) => {
  const [tasks, setTasks] = useState<TaskItemDTO[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Board Columns State & Persistence
  const [columns, setColumns] = useState<BoardColumn[]>(() => {
    try {
      const stored = localStorage.getItem('taskflow_board_columns');
      return stored ? JSON.parse(stored) : DEFAULT_COLUMNS;
    } catch {
      return DEFAULT_COLUMNS;
    }
  });

  const saveColumns = (newCols: BoardColumn[]) => {
    setColumns(newCols);
    try {
      localStorage.setItem('taskflow_board_columns', JSON.stringify(newCols));
    } catch (err) {
      console.error(err);
    }
  };

  // Column Rearrange / Drag state
  const [draggedColIndex, setDraggedColIndex] = useState<number | null>(null);

  const moveColumnLeft = (index: number) => {
    if (index <= 0) return;
    const newCols = [...columns];
    const temp = newCols[index];
    newCols[index] = newCols[index - 1];
    newCols[index - 1] = temp;
    saveColumns(newCols);
  };

  const moveColumnRight = (index: number) => {
    if (index >= columns.length - 1) return;
    const newCols = [...columns];
    const temp = newCols[index];
    newCols[index] = newCols[index + 1];
    newCols[index + 1] = temp;
    saveColumns(newCols);
  };

  const handleColumnHeaderDragStart = (e: React.DragEvent, index: number) => {
    setDraggedColIndex(index);
    e.dataTransfer.setData('type', 'column');
  };

  const handleColumnHeaderDrop = (e: React.DragEvent, targetIndex: number) => {
    e.preventDefault();
    if (draggedColIndex === null || draggedColIndex === targetIndex) return;
    const newCols = [...columns];
    const [removed] = newCols.splice(draggedColIndex, 1);
    newCols.splice(targetIndex, 0, removed);
    saveColumns(newCols);
    setDraggedColIndex(null);
  };

  // Column Edit Modal State
  const [editingColumn, setEditingColumn] = useState<BoardColumn | null>(null);
  const [editColTitle, setEditColTitle] = useState('');
  const [editColColor, setEditColColor] = useState('');

  const openEditColumnModal = (col: BoardColumn) => {
    setEditingColumn(col);
    setEditColTitle(col.title);
    setEditColColor(col.color);
  };

  const handleSaveEditColumn = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingColumn || !editColTitle.trim()) return;
    const newCols = columns.map(c =>
      c.id === editingColumn.id
        ? { ...c, title: editColTitle.trim(), color: editColColor }
        : c
    );
    saveColumns(newCols);
    setEditingColumn(null);
  };

  // Column Delete Modal State
  const [deletingColumn, setDeletingColumn] = useState<BoardColumn | null>(null);
  const [targetFallbackStatus, setTargetFallbackStatus] = useState<TaskStatus>('todo');

  const openDeleteColumnModal = (col: BoardColumn) => {
    if (columns.length <= 1) {
      alert('The board must have at least one column.');
      return;
    }
    setDeletingColumn(col);
    const fallback = columns.find(c => c.id !== col.id);
    if (fallback) setTargetFallbackStatus(fallback.status);
  };

  const handleConfirmDeleteColumn = async () => {
    if (!deletingColumn) return;
    const tasksInCol = getTasksByStatus(deletingColumn.status);

    if (tasksInCol.length > 0) {
      for (const t of tasksInCol) {
        try {
          await api.updateTask(t.id, { status: targetFallbackStatus });
        } catch (err) {
          console.error(`Failed to move task ${t.id} on column delete:`, err);
        }
      }
      await fetchTasks();
    }

    const newCols = columns.filter(c => c.id !== deletingColumn.id);
    saveColumns(newCols);
    setDeletingColumn(null);
  };

  // Add Column Modal State
  const [showAddColumnModal, setShowAddColumnModal] = useState(false);
  const [newColTitle, setNewColTitle] = useState('');
  const [newColColor, setNewColColor] = useState(COLOR_OPTIONS[0].value);

  const handleAddColumn = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newColTitle.trim()) return;
    const statusKey = newColTitle.trim().toLowerCase().replace(/\s+/g, '_');
    const newCol: BoardColumn = {
      id: `col-${Date.now()}`,
      status: statusKey,
      title: newColTitle.trim(),
      color: newColColor,
    };
    saveColumns([...columns, newCol]);
    setShowAddColumnModal(false);
    setNewColTitle('');
  };

  const handleResetColumns = () => {
    if (confirm('Reset board columns to default layout (To Do, In Progress, In Review, Done)?')) {
      saveColumns(DEFAULT_COLUMNS);
    }
  };

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedPriority, setSelectedPriority] = useState<string>('all');
  const [selectedType, setSelectedType] = useState<string>('all');

  // Drag and Drop State
  const [draggedTask, setDraggedTask] = useState<TaskItemDTO | null>(null);
  const [dragOverColumn, setDragOverColumn] = useState<TaskStatus | null>(null);

  // Quick Move Modal State
  const [movingTask, setMovingTask] = useState<TaskItemDTO | null>(null);
  const [targetStatus, setTargetStatus] = useState<TaskStatus>('todo');

  // Full Task Edit Modal State
  const [editingTask, setEditingTask] = useState<TaskItemDTO | null>(null);
  const [editTitle, setEditTitle] = useState('');
  const [editDesc, setEditDesc] = useState('');
  const [editStatus, setEditStatus] = useState<TaskStatus>('todo');
  const [editPriority, setEditPriority] = useState<TaskPriority>('medium');
  const [editTaskType, setEditTaskType] = useState<TaskType>('task');
  const [editStoryPoints, setEditStoryPoints] = useState<number>(1);
  const [editAssigneeId, setEditAssigneeId] = useState('');
  const [editLabels, setEditLabels] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  const fetchTasks = async () => {
    setLoading(true);
    setError(null);
    try {
      let data = await api.getTasks();
      if (myTasksOnly && api.currentUser) {
        data = data.filter(t => t.assigneeId === api.currentUser?.id);
      }
      setTasks(data);
    } catch (err: any) {
      setError(err.message || 'Failed to load tasks');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchTasks();
  }, [myTasksOnly]);

  // Handle Drag Events
  const handleDragStart = (e: React.DragEvent, task: TaskItemDTO) => {
    setDraggedTask(task);
    e.dataTransfer.setData('text/plain', task.id);
    e.dataTransfer.effectAllowed = 'move';
  };

  const handleDragEnd = () => {
    setDraggedTask(null);
    setDragOverColumn(null);
  };

  const handleDragOver = (e: React.DragEvent, colStatus: TaskStatus) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    if (dragOverColumn !== colStatus) {
      setDragOverColumn(colStatus);
    }
  };

  const handleDragLeave = (e: React.DragEvent) => {
    if (!e.currentTarget.contains(e.relatedTarget as Node)) {
      setDragOverColumn(null);
    }
  };

  const handleDrop = async (e: React.DragEvent, targetColStatus: TaskStatus) => {
    e.preventDefault();
    setDragOverColumn(null);
    
    if (draggedTask && draggedTask.status !== targetColStatus) {
      const taskId = draggedTask.id;
      const newStatus = targetColStatus;

      // Optimistic local state update
      setTasks(prev => prev.map(t => t.id === taskId ? { ...t, status: newStatus } : t));

      try {
        await api.moveTask(taskId, newStatus);
      } catch (err: any) {
        console.error('Failed to move task:', err);
        // Rollback on error
        fetchTasks();
      }
    }
  };

  const handleMoveTask = async (taskId: string, newStatus: TaskStatus) => {
    // Optimistic local update
    setTasks(prev => prev.map(t => t.id === taskId ? { ...t, status: newStatus } : t));
    setMovingTask(null);

    try {
      await api.moveTask(taskId, newStatus);
    } catch (err: any) {
      alert(`Failed to move task: ${err.message}`);
      fetchTasks();
    }
  };

  const openEditModal = (task: TaskItemDTO) => {
    setEditingTask(task);
    setEditTitle(task.title);
    setEditDesc(task.description || '');
    setEditStatus(task.status);
    setEditPriority(task.priority);
    setEditTaskType(task.taskType);
    setEditStoryPoints(task.storyPoints ?? 1);
    setEditAssigneeId(task.assigneeId || '');
    setEditLabels(task.labels ? task.labels.join(', ') : '');
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingTask) return;

    setIsSaving(true);
    try {
      const updated = await api.updateTask(editingTask.id, {
        title: editTitle,
        description: editDesc,
        status: editStatus,
        priority: editPriority,
        taskType: editTaskType,
        storyPoints: editStoryPoints,
        assigneeId: editAssigneeId,
        labels: editLabels.split(',').map(l => l.trim()).filter(Boolean),
      });

      setTasks(prev => prev.map(t => t.id === updated.id ? updated : t));
      setEditingTask(null);
    } catch (err: any) {
      alert(`Failed to save task: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const filteredTasks = tasks.filter(task => {
    const matchesSearch = searchQuery === '' || 
      task.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (task.issueKey && task.issueKey.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesPriority = selectedPriority === 'all' || task.priority === selectedPriority;
    const matchesType = selectedType === 'all' || task.taskType === selectedType;

    return matchesSearch && matchesPriority && matchesType;
  });

  const getTasksByStatus = (status: TaskStatus) => {
    return filteredTasks.filter(t => t.status === status || (status === 'in_review' && (t.status as string) === 'review'));
  };

  const getPriorityBadgeClass = (priority: TaskPriority) => {
    switch (priority) {
      case 'critical':
      case 'urgent': return 'bg-red-500/20 text-red-400 border-red-500/30';
      case 'high': return 'bg-orange-500/20 text-orange-400 border-orange-500/30';
      case 'medium': return 'bg-blue-500/20 text-blue-400 border-blue-500/30';
      case 'low': return 'bg-slate-500/20 text-slate-400 border-slate-500/30';
    }
  };

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-slate-950 text-slate-100">
      {/* Top Bar Header */}
      <div className="p-6 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
            <Layers className="w-6 h-6 text-indigo-400" />
            {myTasksOnly ? 'My Tasks Board' : 'All Tasks Kanban Board'}
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Drag and drop cards across columns to update status, or click to edit task details
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={handleResetColumns}
            className="p-2 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-300 transition border border-slate-700 flex items-center gap-2 text-xs font-medium cursor-pointer"
            title="Reset columns to default layout"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            Reset Layout
          </button>

          <button
            onClick={() => setShowAddColumnModal(true)}
            className="px-3 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white transition flex items-center gap-2 text-xs font-semibold shadow-lg shadow-indigo-600/30 cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            Add Column
          </button>

          <button
            onClick={fetchTasks}
            className="p-2 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-300 transition border border-slate-700 flex items-center gap-2 text-xs font-medium cursor-pointer"
            title="Refresh tasks"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="px-6 py-4 border-b border-slate-800/80 bg-slate-900/40 flex flex-wrap items-center justify-between gap-4">
        {/* Search Input */}
        <div className="relative flex-1 min-w-[240px] max-w-md">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            placeholder="Search by title or issue key (e.g. TF-1)..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-950/80 border border-slate-800 text-slate-200 pl-10 pr-4 py-2 rounded-xl text-sm focus:outline-none focus:border-indigo-500 transition"
          />
        </div>

        {/* Dropdown Filters */}
        <div className="flex items-center gap-3 flex-wrap">
          <div className="flex items-center gap-2 bg-slate-950/60 border border-slate-800 px-3 py-1.5 rounded-xl">
            <Filter className="w-3.5 h-3.5 text-slate-400" />
            <span className="text-xs text-slate-400 font-medium">Priority:</span>
            <select
              value={selectedPriority}
              onChange={(e) => setSelectedPriority(e.target.value)}
              className="bg-transparent text-xs text-slate-200 focus:outline-none cursor-pointer"
            >
              <option value="all">All Priorities</option>
              <option value="critical">Critical</option>
              <option value="high">High</option>
              <option value="medium">Medium</option>
              <option value="low">Low</option>
            </select>
          </div>

          <div className="flex items-center gap-2 bg-slate-950/60 border border-slate-800 px-3 py-1.5 rounded-xl">
            <span className="text-xs text-slate-400 font-medium">Type:</span>
            <select
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
              className="bg-transparent text-xs text-slate-200 focus:outline-none cursor-pointer"
            >
              <option value="all">All Types</option>
              <option value="task">Task</option>
              <option value="bug">Bug</option>
              <option value="story">Story</option>
              <option value="epic">Epic</option>
            </select>
          </div>
        </div>
      </div>

      {/* Board Columns Grid with Drag & Drop */}
      <div className="flex-1 overflow-x-auto p-6">
        {loading && tasks.length === 0 ? (
          <div className="flex items-center justify-center h-64 text-slate-400 gap-3">
            <RefreshCw className="w-6 h-6 animate-spin text-indigo-400" />
            <span>Loading tasks...</span>
          </div>
        ) : error ? (
          <div className="p-4 rounded-xl bg-red-950/40 border border-red-800 text-red-300 max-w-md mx-auto my-8">
            <p className="font-semibold">Error</p>
            <p className="text-sm">{error}</p>
          </div>
        ) : (
          <div className="flex gap-6 h-full min-w-full pb-4 items-start">
            {columns.map((col, index) => {
              const colTasks = getTasksByStatus(col.status);
              const isOver = dragOverColumn === col.status;

              return (
                <div 
                  key={col.id} 
                  onDragOver={(e) => handleDragOver(e, col.status)}
                  onDragLeave={handleDragLeave}
                  onDrop={(e) => handleDrop(e, col.status)}
                  className={`w-80 shrink-0 bg-slate-900/40 border rounded-2xl p-4 flex flex-col h-full max-h-full transition-all duration-200 ${
                    isOver 
                      ? 'border-indigo-500 bg-indigo-500/10 ring-2 ring-indigo-500/30 scale-[1.01]' 
                      : 'border-slate-800/80'
                  }`}
                >
                  {/* Column Header */}
                  <div 
                    draggable
                    onDragStart={(e) => handleColumnHeaderDragStart(e, index)}
                    onDrop={(e) => handleColumnHeaderDrop(e, index)}
                    onDragOver={(e) => e.preventDefault()}
                    className="flex items-center justify-between pb-3 mb-3 border-b border-slate-800 cursor-grab active:cursor-grabbing group/colheader"
                  >
                    <div className="flex items-center gap-2">
                      <GripHorizontal className="w-3.5 h-3.5 text-slate-600 group-hover/colheader:text-slate-400 shrink-0" />
                      <span className={`px-2.5 py-1 text-xs font-semibold rounded-lg border ${col.color}`}>
                        {col.title}
                      </span>
                      <span className="text-xs font-semibold text-slate-400 bg-slate-800/80 px-2 py-0.5 rounded-md">
                        {colTasks.length}
                      </span>
                    </div>

                    {/* Column Actions (Move left/right, Edit, Delete) */}
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => moveColumnLeft(index)}
                        disabled={index === 0}
                        className="p-1 rounded text-slate-500 hover:text-slate-200 hover:bg-slate-800 disabled:opacity-20 disabled:hover:bg-transparent transition cursor-pointer"
                        title="Move column left"
                      >
                        <ArrowLeft className="w-3.5 h-3.5" />
                      </button>
                      
                      <button
                        onClick={() => moveColumnRight(index)}
                        disabled={index === columns.length - 1}
                        className="p-1 rounded text-slate-500 hover:text-slate-200 hover:bg-slate-800 disabled:opacity-20 disabled:hover:bg-transparent transition cursor-pointer"
                        title="Move column right"
                      >
                        <ArrowRight className="w-3.5 h-3.5" />
                      </button>

                      <button
                        onClick={() => openEditColumnModal(col)}
                        className="p-1 rounded text-slate-500 hover:text-indigo-400 hover:bg-slate-800 transition cursor-pointer"
                        title="Edit column name & color"
                      >
                        <Edit2 className="w-3.5 h-3.5" />
                      </button>

                      <button
                        onClick={() => openDeleteColumnModal(col)}
                        className="p-1 rounded text-slate-500 hover:text-rose-400 hover:bg-slate-800 transition cursor-pointer"
                        title="Delete column"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>

                  {/* Task List (Drop Zone) */}
                  <div className="flex-1 overflow-y-auto space-y-3 pr-1">
                    {colTasks.length === 0 ? (
                      <div className={`border border-dashed rounded-xl p-8 text-center text-xs transition ${
                        isOver ? 'border-indigo-400 text-indigo-300 bg-indigo-500/10' : 'border-slate-800 text-slate-500'
                      }`}>
                        {isOver ? 'Drop task here to update status' : `No tasks in ${col.title.toLowerCase()}`}
                      </div>
                    ) : (
                      colTasks.map(task => {
                        const isDragging = draggedTask?.id === task.id;

                        return (
                          <div
                            key={task.id}
                            draggable={true}
                            onDragStart={(e) => handleDragStart(e, task)}
                            onDragEnd={handleDragEnd}
                            className={`bg-slate-900/90 hover:bg-slate-800/80 border border-slate-800 hover:border-indigo-500/50 rounded-xl p-4 transition shadow-md group relative cursor-grab active:cursor-grabbing ${
                              isDragging ? 'opacity-40 border-indigo-500/80 shadow-2xl scale-[0.98]' : ''
                            }`}
                          >
                            {/* Issue Key & Type Badge */}
                            <div className="flex items-center justify-between mb-2">
                              <div className="flex items-center gap-1.5">
                                <GripVertical className="w-3.5 h-3.5 text-slate-600 group-hover:text-slate-400" />
                                <span className="text-xs font-mono font-semibold text-indigo-400 bg-indigo-500/10 px-2 py-0.5 rounded border border-indigo-500/20">
                                  {task.issueKey || `TASK-${task.id.slice(0,4)}`}
                                </span>
                              </div>

                              <div className="flex items-center gap-1.5">
                                <span className={`text-[10px] font-semibold px-2 py-0.5 rounded border uppercase tracking-wider ${getPriorityBadgeClass(task.priority)}`}>
                                  {task.priority}
                                </span>
                                
                                <button
                                  onClick={() => openEditModal(task)}
                                  className="text-slate-400 hover:text-indigo-300 p-1 rounded-md hover:bg-slate-800 transition"
                                  title="Edit Task Details"
                                >
                                  <Edit3 className="w-3.5 h-3.5" />
                                </button>

                                <button 
                                  onClick={() => {
                                    setMovingTask(task);
                                    setTargetStatus(task.status);
                                  }}
                                  className="text-slate-400 hover:text-slate-200 p-1 rounded-md hover:bg-slate-800 transition"
                                  title="Change status"
                                >
                                  <MoreVertical className="w-3.5 h-3.5" />
                                </button>
                              </div>
                            </div>

                            {/* Task Title */}
                            <h3 
                              onClick={() => openEditModal(task)}
                              className="text-sm font-semibold text-slate-200 mb-2 line-clamp-2 hover:text-indigo-300 transition cursor-pointer"
                            >
                              {task.title}
                            </h3>

                            {/* Description if present */}
                            {task.description && (
                              <p className="text-xs text-slate-400 line-clamp-2 mb-3">
                                {task.description}
                              </p>
                            )}

                            {/* Labels */}
                            {task.labels && task.labels.length > 0 && (
                              <div className="flex flex-wrap gap-1 mb-3">
                                {task.labels.map((label, idx) => (
                                  <span key={idx} className="text-[10px] bg-slate-800 text-slate-300 px-1.5 py-0.5 rounded flex items-center gap-1 border border-slate-700">
                                    <Tag className="w-2.5 h-2.5 text-indigo-400" />
                                    {label}
                                  </span>
                                ))}
                              </div>
                            )}

                            {/* Task Footer: Assignee & Story points */}
                            <div className="flex items-center justify-between pt-2 border-t border-slate-800/60 text-xs text-slate-400">
                              <div className="flex items-center gap-1.5">
                                <div className="w-5 h-5 rounded-full bg-indigo-600/30 border border-indigo-500/40 flex items-center justify-center text-[10px] font-bold text-indigo-300">
                                  {task.assigneeId ? task.assigneeId.slice(0,2).toUpperCase() : <User className="w-3 h-3" />}
                                </div>
                                <span className="text-[11px] text-slate-400 truncate max-w-[100px]">
                                  {task.assigneeId ? `User ${task.assigneeId.slice(0,4)}` : 'Unassigned'}
                                </span>
                              </div>

                              {task.storyPoints !== undefined && (
                                <span className="text-[10px] font-medium bg-slate-800 px-1.5 py-0.5 rounded text-slate-300">
                                  {task.storyPoints} pts
                                </span>
                              )}
                            </div>
                          </div>
                        );
                      })
                    )}
                  </div>
                </div>
              );
            })}

            {/* Add Column Placeholder Card */}
            <div
              onClick={() => setShowAddColumnModal(true)}
              className="w-72 shrink-0 border border-dashed border-slate-800 hover:border-indigo-500/50 rounded-2xl p-6 flex flex-col items-center justify-center cursor-pointer transition text-slate-400 hover:text-indigo-300 hover:bg-indigo-500/5 min-h-[300px]"
            >
              <div className="w-10 h-10 rounded-full bg-indigo-600/20 flex items-center justify-center mb-2 text-indigo-400">
                <Plus className="w-5 h-5" />
              </div>
              <span className="text-xs font-bold">Add New Column</span>
              <span className="text-[11px] text-slate-500 mt-1">Create custom task status</span>
            </div>
          </div>
        )}
      </div>

      {/* Full Task Edit Modal */}
      {editingTask && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-md flex items-center justify-center p-4">
          <form 
            onSubmit={handleSaveEdit} 
            className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-xl shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto"
          >
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                <Edit3 className="w-5 h-5 text-indigo-400" />
                Edit Task <span className="text-indigo-400 font-mono">{editingTask.issueKey || editingTask.title}</span>
              </h2>
              <button
                type="button"
                onClick={() => setEditingTask(null)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Title
                </label>
                <input
                  type="text"
                  required
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-sm text-slate-100 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Description
                </label>
                <textarea
                  rows={4}
                  value={editDesc}
                  onChange={(e) => setEditDesc(e.target.value)}
                  placeholder="Task details and acceptance criteria..."
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Status
                  </label>
                  <select
                    value={editStatus}
                    onChange={(e) => setEditStatus(e.target.value as TaskStatus)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1 cursor-pointer"
                  >
                    {columns.map(c => (
                      <option key={c.id} value={c.status}>{c.title}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Priority
                  </label>
                  <select
                    value={editPriority}
                    onChange={(e) => setEditPriority(e.target.value as TaskPriority)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1 cursor-pointer"
                  >
                    <option value="critical">Critical</option>
                    <option value="high">High</option>
                    <option value="medium">Medium</option>
                    <option value="low">Low</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Task Type
                  </label>
                  <select
                    value={editTaskType}
                    onChange={(e) => setEditTaskType(e.target.value as TaskType)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1 cursor-pointer"
                  >
                    <option value="task">Task</option>
                    <option value="bug">Bug</option>
                    <option value="story">Story</option>
                    <option value="epic">Epic</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Story Points
                  </label>
                  <input
                    type="number"
                    min={0}
                    max={100}
                    value={editStoryPoints}
                    onChange={(e) => setEditStoryPoints(parseInt(e.target.value) || 0)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Labels (Comma-Separated)
                </label>
                <input
                  type="text"
                  placeholder="frontend, ui, billing"
                  value={editLabels}
                  onChange={(e) => setEditLabels(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setEditingTask(null)}
                className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSaving}
                className="px-4 py-2 rounded-xl text-xs font-semibold bg-indigo-600 hover:bg-indigo-500 text-white transition shadow-lg shadow-indigo-600/30 flex items-center gap-2"
              >
                {isSaving ? (
                  <>
                    <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                    <span>Saving...</span>
                  </>
                ) : (
                  <span>Save Changes</span>
                )}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Quick Move Status Modal */}
      {movingTask && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <h2 className="text-lg font-bold text-slate-100">
              Move Task Status
            </h2>
            <p className="text-sm text-slate-400">
              Change status for task <span className="text-indigo-400 font-mono">{movingTask.issueKey || movingTask.title}</span>
            </p>

            <div className="space-y-2">
              <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                Select Target Status
              </label>
              <div className="grid grid-cols-1 gap-2 max-h-48 overflow-y-auto">
                {columns.map(c => (
                  <button
                    key={c.id}
                    type="button"
                    onClick={() => setTargetStatus(c.status)}
                    className={`p-3 rounded-xl border text-xs font-semibold flex items-center justify-between transition ${c.color} ${
                      targetStatus === c.status ? 'bg-indigo-600/20 border-indigo-500 ring-1 ring-indigo-500' : 'bg-slate-950/60'
                    }`}
                  >
                    <span>{c.title}</span>
                    {targetStatus === c.status && <CheckCircle2 className="w-4 h-4 text-indigo-400" />}
                  </button>
                ))}
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
              <button
                onClick={() => setMovingTask(null)}
                className="px-4 py-2 rounded-xl text-sm font-medium bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
              >
                Cancel
              </button>
              <button
                onClick={() => handleMoveTask(movingTask.id, targetStatus)}
                className="px-4 py-2 rounded-xl text-sm font-medium bg-indigo-600 hover:bg-indigo-500 text-white transition shadow-lg shadow-indigo-600/30"
              >
                Confirm Move
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Column Modal */}
      {editingColumn && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-slate-800">
              <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <Edit2 className="w-4 h-4 text-indigo-400" /> Edit Column
              </h3>
              <button onClick={() => setEditingColumn(null)} className="text-slate-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveEditColumn} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Column Title
                </label>
                <input
                  type="text"
                  value={editColTitle}
                  onChange={(e) => setEditColTitle(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Color Theme
                </label>
                <div className="grid grid-cols-2 gap-2">
                  {COLOR_OPTIONS.map(opt => (
                    <button
                      key={opt.label}
                      type="button"
                      onClick={() => setEditColColor(opt.value)}
                      className={`px-3 py-2 rounded-xl text-xs font-semibold border flex items-center justify-between transition ${opt.value} ${
                        editColColor === opt.value ? 'ring-2 ring-indigo-500 bg-slate-800/80' : 'bg-slate-950/60'
                      }`}
                    >
                      <span>{opt.label}</span>
                      {editColColor === opt.value && <Sparkles className="w-3.5 h-3.5 text-indigo-400" />}
                    </button>
                  ))}
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setEditingColumn(null)}
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-indigo-600 text-white hover:bg-indigo-500 shadow-lg shadow-indigo-600/30"
                >
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Column Modal */}
      {deletingColumn && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-slate-800">
              <h3 className="text-base font-bold text-rose-400 flex items-center gap-2">
                <Trash2 className="w-4 h-4 text-rose-400" /> Delete Column "{deletingColumn.title}"
              </h3>
              <button onClick={() => setDeletingColumn(null)} className="text-slate-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <p className="text-xs text-slate-300 leading-relaxed">
              Are you sure you want to delete the column <strong className="text-white">"{deletingColumn.title}"</strong>?
            </p>

            {getTasksByStatus(deletingColumn.status).length > 0 && (
              <div className="bg-slate-950 p-3 rounded-xl border border-slate-800 space-y-2">
                <label className="text-xs font-semibold text-amber-400 block">
                  ⚠️ Column contains {getTasksByStatus(deletingColumn.status).length} task(s). Reassign tasks to:
                </label>
                <select
                  value={targetFallbackStatus}
                  onChange={(e) => setTargetFallbackStatus(e.target.value as TaskStatus)}
                  className="w-full bg-slate-900 border border-slate-800 rounded-lg p-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                >
                  {columns.filter(c => c.id !== deletingColumn.id).map(c => (
                    <option key={c.id} value={c.status}>
                      Move to "{c.title}"
                    </option>
                  ))}
                </select>
              </div>
            )}

            <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setDeletingColumn(null)}
                className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700"
              >
                Cancel
              </button>
              <button
                onClick={handleConfirmDeleteColumn}
                className="px-4 py-2 rounded-xl text-xs font-medium bg-rose-600 text-white hover:bg-rose-500 shadow-lg shadow-rose-600/30"
              >
                Delete Column
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Column Modal */}
      {showAddColumnModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-slate-800">
              <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <Plus className="w-4 h-4 text-indigo-400" /> Add Board Column
              </h3>
              <button onClick={() => setShowAddColumnModal(false)} className="text-slate-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleAddColumn} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Column Name
                </label>
                <input
                  type="text"
                  placeholder="e.g. Testing, Blocked, Backlog"
                  value={newColTitle}
                  onChange={(e) => setNewColTitle(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider block mb-1">
                  Color Theme
                </label>
                <div className="grid grid-cols-2 gap-2">
                  {COLOR_OPTIONS.map(opt => (
                    <button
                      key={opt.label}
                      type="button"
                      onClick={() => setNewColColor(opt.value)}
                      className={`px-3 py-2 rounded-xl text-xs font-semibold border flex items-center justify-between transition ${opt.value} ${
                        newColColor === opt.value ? 'ring-2 ring-indigo-500 bg-slate-800/80' : 'bg-slate-950/60'
                      }`}
                    >
                      <span>{opt.label}</span>
                      {newColColor === opt.value && <Sparkles className="w-3.5 h-3.5 text-indigo-400" />}
                    </button>
                  ))}
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowAddColumnModal(false)}
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl text-xs font-medium bg-indigo-600 text-white hover:bg-indigo-500 shadow-lg shadow-indigo-600/30"
                >
                  Create Column
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

