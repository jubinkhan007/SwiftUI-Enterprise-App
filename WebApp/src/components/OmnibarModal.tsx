import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  Search,
  Sparkles,
  CheckSquare,
  MessageSquare,
  Video,
  User,
  FileText,
  X,
  ArrowRight,
  Copy,
  Check,
  Calendar,
  AlertCircle,
  PlusCircle,
  Loader2
} from 'lucide-react';
import { api } from '../services/api';
import {
  SearchEntityType,
  SearchResultItemDTO,
  AIAssistantResponse,
  SuggestedTaskDTO
} from '../types';
import { DeeplinkRoute, parseDeeplink } from '../services/deeplink';

interface OmnibarModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelectRoute: (route: DeeplinkRoute) => void;
  onTaskCreated?: () => void;
}

type TabType = 'all' | SearchEntityType | 'copilot';
type CopilotMode = 'breakdown' | 'standup';

export const OmnibarModal: React.FC<OmnibarModalProps> = ({
  isOpen,
  onClose,
  onSelectRoute,
  onTaskCreated
}) => {
  const [query, setQuery] = useState('');
  const [activeTab, setActiveTab] = useState<TabType>('all');
  const [results, setResults] = useState<SearchResultItemDTO[]>([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Copilot State
  const [copilotMode, setCopilotMode] = useState<CopilotMode>('breakdown');
  const [copilotPrompt, setCopilotPrompt] = useState('');
  const [isCopilotLoading, setIsCopilotLoading] = useState(false);
  const [copilotResponse, setCopilotResponse] = useState<AIAssistantResponse | null>(null);
  const [isAddingTasks, setIsAddingTasks] = useState(false);
  const [tasksAddedSuccess, setTasksAddedSuccess] = useState(false);
  const [copied, setCopied] = useState(false);

  const inputRef = useRef<HTMLInputElement>(null);

  // Global Cmd+K / Ctrl+K listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        if (isOpen) {
          onClose();
        } else {
          // Trigger open via parent if closed
        }
      }
      if (isOpen && e.key === 'Escape') {
        e.preventDefault();
        onClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  // Focus input when opened
  useEffect(() => {
    if (isOpen) {
      setTimeout(() => {
        inputRef.current?.focus();
      }, 50);
      setSelectedIndex(0);
      fetchSearch('');
    } else {
      setQuery('');
      setResults([]);
      setErrorMessage(null);
      setCopilotResponse(null);
      setTasksAddedSuccess(false);
    }
  }, [isOpen]);

  // Debounced search
  const fetchSearch = useCallback(async (searchQuery: string, tab: TabType = activeTab) => {
    if (tab === 'copilot') return;
    setIsLoading(true);
    setErrorMessage(null);

    const types: SearchEntityType[] | undefined =
      tab === 'all' ? undefined : [tab as SearchEntityType];

    try {
      const resp = await api.search(searchQuery, types, 25);
      setResults(resp.results || []);
      setSelectedIndex(0);
    } catch (err: any) {
      setErrorMessage(err?.message || 'Failed to fetch search results.');
      setResults([]);
    } finally {
      setIsLoading(false);
    }
  }, [activeTab]);

  useEffect(() => {
    if (!isOpen || activeTab === 'copilot') return;
    const timer = setTimeout(() => {
      fetchSearch(query, activeTab);
    }, 200);

    return () => clearTimeout(timer);
  }, [query, activeTab, isOpen, fetchSearch]);

  // Keyboard navigation through results
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (activeTab === 'copilot') return;

    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSelectedIndex((prev) => (prev + 1 < results.length ? prev + 1 : 0));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSelectedIndex((prev) => (prev - 1 >= 0 ? prev - 1 : results.length - 1));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (results[selectedIndex]) {
        handleSelectItem(results[selectedIndex]);
      }
    }
  };

  const handleSelectItem = (item: SearchResultItemDTO) => {
    const route = parseDeeplink(item.deepLink);
    if (route) {
      onSelectRoute(route);
      onClose();
    }
  };

  // AI Copilot Actions
  const handleRunBreakdown = async () => {
    if (!copilotPrompt.trim()) return;
    setIsCopilotLoading(true);
    setCopilotResponse(null);
    setTasksAddedSuccess(false);
    setErrorMessage(null);

    try {
      const resp = await api.breakdownTask(copilotPrompt.trim());
      setCopilotResponse(resp);
    } catch (err: any) {
      setErrorMessage(err?.message || 'Failed to decompose task.');
    } finally {
      setIsCopilotLoading(false);
    }
  };

  const handleRunStandup = async () => {
    setIsCopilotLoading(true);
    setCopilotResponse(null);
    setTasksAddedSuccess(false);
    setErrorMessage(null);

    try {
      const resp = await api.generateStandupSummary();
      setCopilotResponse(resp);
    } catch (err: any) {
      setErrorMessage(err?.message || 'Failed to generate standup summary.');
    } finally {
      setIsCopilotLoading(false);
    }
  };

  const handleAddAllTasks = async () => {
    if (!copilotResponse?.suggestedTasks || copilotResponse.suggestedTasks.length === 0) return;
    setIsAddingTasks(true);

    try {
      for (const t of copilotResponse.suggestedTasks) {
        await api.createTask({
          title: t.title,
          description: t.description || undefined,
          priority: (t.priority?.toLowerCase() as any) || 'medium',
          status: 'todo',
        });
      }
      setTasksAddedSuccess(true);
      onTaskCreated?.();
    } catch (err: any) {
      setErrorMessage(err?.message || 'Failed to create subtasks in project.');
    } finally {
      setIsAddingTasks(false);
    }
  };

  const handleCopySummary = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center pt-16 sm:pt-24 px-4 bg-black/70 backdrop-blur-md animate-in fade-in duration-150"
      onClick={onClose}
    >
      <div
        className="w-full max-w-2xl bg-slate-900 border border-slate-700/80 rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[80vh] text-slate-100"
        onClick={(e) => e.stopPropagation()}
        onKeyDown={handleKeyDown}
      >
        {/* Search Input Bar */}
        <div className="flex items-center px-4 py-3.5 border-b border-slate-800 bg-slate-900/90 gap-3">
          <Search className="w-5 h-5 text-slate-400 shrink-0" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={
              activeTab === 'copilot'
                ? 'Ask Copilot to break down a feature or generate standup...'
                : 'Search tasks, messages, meetings, members... (Type or use ↑↓)'
            }
            className="flex-1 bg-transparent text-sm sm:text-base text-slate-100 placeholder:text-slate-500 outline-none"
          />
          {isLoading && <Loader2 className="w-4 h-4 text-indigo-400 animate-spin shrink-0" />}
          {query && !isLoading && (
            <button
              onClick={() => {
                setQuery('');
                inputRef.current?.focus();
              }}
              className="p-1 hover:bg-slate-800 rounded-md text-slate-400 hover:text-slate-200 transition"
            >
              <X className="w-4 h-4" />
            </button>
          )}
          <kbd className="hidden sm:inline-block px-2 py-0.5 text-[11px] font-semibold text-slate-400 bg-slate-800 border border-slate-700 rounded-md">
            ESC
          </kbd>
        </div>

        {/* Filter Navigation Tabs */}
        <div className="flex items-center gap-1.5 px-4 py-2 border-b border-slate-800/80 bg-slate-950/40 overflow-x-auto scrollbar-none text-xs">
          <button
            onClick={() => {
              setActiveTab('all');
              fetchSearch(query, 'all');
            }}
            className={`px-3 py-1 rounded-full font-medium transition ${
              activeTab === 'all'
                ? 'bg-indigo-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
            }`}
          >
            All
          </button>
          <button
            onClick={() => {
              setActiveTab('task');
              fetchSearch(query, 'task');
            }}
            className={`px-3 py-1 rounded-full font-medium transition flex items-center gap-1.5 ${
              activeTab === 'task'
                ? 'bg-indigo-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
            }`}
          >
            <CheckSquare className="w-3.5 h-3.5" />
            Tasks
          </button>
          <button
            onClick={() => {
              setActiveTab('message');
              fetchSearch(query, 'message');
            }}
            className={`px-3 py-1 rounded-full font-medium transition flex items-center gap-1.5 ${
              activeTab === 'message'
                ? 'bg-indigo-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
            }`}
          >
            <MessageSquare className="w-3.5 h-3.5" />
            Messages
          </button>
          <button
            onClick={() => {
              setActiveTab('meeting');
              fetchSearch(query, 'meeting');
            }}
            className={`px-3 py-1 rounded-full font-medium transition flex items-center gap-1.5 ${
              activeTab === 'meeting'
                ? 'bg-indigo-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
            }`}
          >
            <Video className="w-3.5 h-3.5" />
            Meetings
          </button>
          <button
            onClick={() => {
              setActiveTab('member');
              fetchSearch(query, 'member');
            }}
            className={`px-3 py-1 rounded-full font-medium transition flex items-center gap-1.5 ${
              activeTab === 'member'
                ? 'bg-indigo-600 text-white shadow-sm'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
            }`}
          >
            <User className="w-3.5 h-3.5" />
            People
          </button>

          <div className="h-4 w-[1px] bg-slate-800 mx-1" />

          <button
            onClick={() => setActiveTab('copilot')}
            className={`px-3 py-1 rounded-full font-semibold transition flex items-center gap-1.5 ${
              activeTab === 'copilot'
                ? 'bg-gradient-to-r from-indigo-500 to-purple-600 text-white shadow-md shadow-indigo-500/20'
                : 'text-indigo-400 border border-indigo-500/30 hover:bg-indigo-500/10'
            }`}
          >
            <Sparkles className="w-3.5 h-3.5" />
            AI Copilot
          </button>
        </div>

        {/* Content Body */}
        <div className="flex-1 overflow-y-auto p-2 scrollbar-thin">
          {errorMessage && (
            <div className="m-3 p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 flex items-center gap-2.5 text-xs text-rose-300">
              <AlertCircle className="w-4 h-4 shrink-0 text-rose-400" />
              <span>{errorMessage}</span>
            </div>
          )}

          {activeTab === 'copilot' ? (
            <div className="p-3 space-y-4">
              {/* Copilot submode tabs */}
              <div className="flex gap-2 p-1 bg-slate-950/60 rounded-xl border border-slate-800">
                <button
                  onClick={() => setCopilotMode('breakdown')}
                  className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition ${
                    copilotMode === 'breakdown'
                      ? 'bg-indigo-600 text-white shadow-sm'
                      : 'text-slate-400 hover:text-slate-200'
                  }`}
                >
                  Task Decomposition
                </button>
                <button
                  onClick={() => setCopilotMode('standup')}
                  className={`flex-1 py-1.5 text-xs font-semibold rounded-lg transition ${
                    copilotMode === 'standup'
                      ? 'bg-indigo-600 text-white shadow-sm'
                      : 'text-slate-400 hover:text-slate-200'
                  }`}
                >
                  Daily Standup Generator
                </button>
              </div>

              {copilotMode === 'breakdown' && (
                <div className="space-y-3 bg-slate-950/40 p-4 rounded-xl border border-slate-800/80">
                  <div className="flex flex-col gap-1">
                    <span className="text-sm font-semibold text-slate-200">
                      Feature / Task Requirement
                    </span>
                    <span className="text-xs text-slate-400">
                      Enter a high-level technical or product deliverable to automatically decompose into estimated subtasks.
                    </span>
                  </div>

                  <div className="flex gap-2">
                    <input
                      type="text"
                      value={copilotPrompt}
                      onChange={(e) => setCopilotPrompt(e.target.value)}
                      placeholder="e.g. Build multi-tenant SSO with SAML and Okta"
                      className="flex-1 px-3 py-2 text-sm bg-slate-900 border border-slate-700 rounded-lg text-slate-100 placeholder:text-slate-500 outline-none focus:border-indigo-500"
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          handleRunBreakdown();
                        }
                      }}
                    />
                    <button
                      onClick={handleRunBreakdown}
                      disabled={isCopilotLoading || !copilotPrompt.trim()}
                      className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-semibold text-xs rounded-lg flex items-center gap-1.5 transition shadow-sm"
                    >
                      {isCopilotLoading ? (
                        <Loader2 className="w-4 h-4 animate-spin" />
                      ) : (
                        <Sparkles className="w-4 h-4" />
                      )}
                      Decompose
                    </button>
                  </div>
                </div>
              )}

              {copilotMode === 'standup' && (
                <div className="space-y-3 bg-slate-950/40 p-4 rounded-xl border border-slate-800/80">
                  <div className="flex flex-col gap-1">
                    <span className="text-sm font-semibold text-slate-200">
                      Automated Standup Synthesis
                    </span>
                    <span className="text-xs text-slate-400">
                      Aggregates your completed tasks, active work-in-progress, scheduled meetings, and high-priority blockers.
                    </span>
                  </div>

                  <button
                    onClick={handleRunStandup}
                    disabled={isCopilotLoading}
                    className="w-full py-2.5 bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white font-semibold text-xs rounded-lg flex items-center justify-center gap-2 transition shadow-md"
                  >
                    {isCopilotLoading ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <Calendar className="w-4 h-4" />
                    )}
                    Generate Today's Standup Summary
                  </button>
                </div>
              )}

              {/* Copilot Response Preview */}
              {copilotResponse && (
                <div className="space-y-3 pt-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold uppercase tracking-wider text-indigo-400 flex items-center gap-1.5">
                      <Sparkles className="w-3.5 h-3.5" />
                      AI Output
                    </span>
                    {copilotResponse.summary && (
                      <button
                        onClick={() => handleCopySummary(copilotResponse.summary)}
                        className="flex items-center gap-1 text-xs text-slate-400 hover:text-slate-200 transition px-2 py-1 bg-slate-800 rounded-md"
                      >
                        {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                        {copied ? 'Copied' : 'Copy'}
                      </button>
                    )}
                  </div>

                  <div className="p-3.5 bg-slate-950/80 border border-slate-800 rounded-xl text-xs sm:text-sm text-slate-200 whitespace-pre-wrap font-sans leading-relaxed">
                    {copilotResponse.summary}
                  </div>

                  {/* Suggested Subtasks List */}
                  {copilotResponse.suggestedTasks && copilotResponse.suggestedTasks.length > 0 && (
                    <div className="space-y-2 mt-4">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-semibold text-slate-300">
                          Decomposed Subtasks ({copilotResponse.suggestedTasks.length})
                        </span>
                        {tasksAddedSuccess ? (
                          <span className="text-xs text-emerald-400 flex items-center gap-1">
                            <Check className="w-3.5 h-3.5" />
                            Added to Backlog!
                          </span>
                        ) : (
                          <button
                            onClick={handleAddAllTasks}
                            disabled={isAddingTasks}
                            className="flex items-center gap-1 text-xs text-indigo-400 hover:text-indigo-300 font-semibold px-2.5 py-1 bg-indigo-500/10 border border-indigo-500/20 rounded-md transition"
                          >
                            {isAddingTasks ? (
                              <Loader2 className="w-3.5 h-3.5 animate-spin" />
                            ) : (
                              <PlusCircle className="w-3.5 h-3.5" />
                            )}
                            Add All to Project Backlog
                          </button>
                        )}
                      </div>

                      <div className="space-y-1.5">
                        {copilotResponse.suggestedTasks.map((st, i) => (
                          <div
                            key={i}
                            className="p-2.5 bg-slate-800/40 border border-slate-850 rounded-lg flex items-center justify-between gap-3 text-xs"
                          >
                            <div className="flex flex-col gap-0.5">
                              <span className="font-semibold text-slate-200">{st.title}</span>
                              {st.description && (
                                <span className="text-slate-400 text-[11px] line-clamp-1">
                                  {st.description}
                                </span>
                              )}
                            </div>
                            <div className="flex items-center gap-2 shrink-0">
                              {st.estimateHours != null && (
                                <span className="px-2 py-0.5 rounded bg-blue-500/10 text-blue-400 font-mono text-[10px] font-bold">
                                  {st.estimateHours}h
                                </span>
                              )}
                              <span
                                className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                                  st.priority === 'urgent' || st.priority === 'critical'
                                    ? 'bg-rose-500/10 text-rose-400'
                                    : st.priority === 'high'
                                    ? 'bg-amber-500/10 text-amber-400'
                                    : 'bg-slate-700 text-slate-300'
                                }`}
                              >
                                {st.priority || 'medium'}
                              </span>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>
          ) : (
            /* Search Results List */
            <div className="divide-y divide-slate-800/60">
              {results.length === 0 && !isLoading && (
                <div className="py-12 text-center text-slate-500 space-y-2">
                  <Search className="w-8 h-8 mx-auto opacity-40" />
                  <p className="text-sm font-medium">No results found</p>
                  <p className="text-xs text-slate-600">
                    Try searching with a different keyword or toggle entity filters.
                  </p>
                </div>
              )}

              {results.map((item, idx) => {
                const isSelected = idx === selectedIndex;
                const icon = renderEntityIcon(item.entityType);

                return (
                  <div
                    key={item.id}
                    onClick={() => handleSelectItem(item)}
                    onMouseEnter={() => setSelectedIndex(idx)}
                    className={`flex items-center gap-3 px-3 py-2.5 rounded-xl cursor-pointer transition ${
                      isSelected
                        ? 'bg-indigo-600/15 border border-indigo-500/30'
                        : 'hover:bg-slate-800/50 border border-transparent'
                    }`}
                  >
                    <div className="p-2 rounded-lg bg-slate-800 text-slate-300 shrink-0">
                      {icon}
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-semibold text-slate-100 truncate">
                          {item.title}
                        </span>
                        {item.badge && (
                          <span
                            className={`text-[10px] font-bold px-1.5 py-0.5 rounded shrink-0 ${
                              item.badge.toLowerCase().includes('urgent') ||
                              item.badge.toLowerCase().includes('critical')
                                ? 'bg-rose-500/15 text-rose-400'
                                : item.badge.toLowerCase().includes('high')
                                ? 'bg-amber-500/15 text-amber-400'
                                : item.badge.toLowerCase().includes('done')
                                ? 'bg-emerald-500/15 text-emerald-400'
                                : 'bg-slate-800 text-slate-400'
                            }`}
                          >
                            {item.badge}
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-slate-400 truncate mt-0.5">{item.subtitle}</p>
                    </div>

                    <div className="flex items-center gap-1.5 text-slate-500 shrink-0">
                      {isSelected && (
                        <span className="text-[11px] font-mono text-indigo-400 hidden sm:inline">
                          ↵ Select
                        </span>
                      )}
                      <ArrowRight className="w-4 h-4 opacity-70" />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Footer shortcuts */}
        <div className="px-4 py-2 border-t border-slate-800 bg-slate-950/60 flex items-center justify-between text-[11px] text-slate-400">
          <div className="flex items-center gap-3">
            <span className="flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 bg-slate-800 rounded border border-slate-700 text-slate-300 font-mono">
                ↑↓
              </kbd>
              Navigate
            </span>
            <span className="flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 bg-slate-800 rounded border border-slate-700 text-slate-300 font-mono">
                ↵
              </kbd>
              Open
            </span>
          </div>
          <span className="hidden sm:inline text-slate-500">Universal Omnibar & Copilot</span>
        </div>
      </div>
    </div>
  );
};

function renderEntityIcon(type: SearchEntityType) {
  switch (type) {
    case 'task':
      return <CheckSquare className="w-4 h-4 text-indigo-400" />;
    case 'message':
      return <MessageSquare className="w-4 h-4 text-blue-400" />;
    case 'meeting':
      return <Video className="w-4 h-4 text-purple-400" />;
    case 'member':
      return <User className="w-4 h-4 text-amber-400" />;
    case 'doc':
      return <FileText className="w-4 h-4 text-teal-400" />;
    default:
      return <Search className="w-4 h-4 text-slate-400" />;
  }
}
