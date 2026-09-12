import React, { useState } from 'react';
import { 
  Zap, 
  FileText, 
  Bell, 
  Bookmark, 
  Sparkles, 
  ArrowRight, 
  CheckCircle2, 
  Clock, 
  Plus 
} from 'lucide-react';

interface TemplateItem {
  id: string;
  name: string;
  category: string;
  description: string;
  icon: string;
}

interface ReminderItem {
  id: string;
  title: string;
  scheduledTime: string;
  recurrence: string;
}

interface DraftItem {
  id: string;
  title: string;
  targetChannel: string;
  lastModified: string;
  preview: string;
}

const INITIAL_TEMPLATES: TemplateItem[] = [
  {
    id: 't-1',
    name: 'Agile Sprint Board',
    category: 'Project Management',
    description: 'Pre-configured columns for To Do, In Progress, Code Review, QA, and Done with sprint milestone metrics.',
    icon: '⚡'
  },
  {
    id: 't-2',
    name: 'Bug Triage Workflow',
    category: 'Engineering',
    description: 'Standardized defect report template with severity tags, reproduction steps, and root cause analysis fields.',
    icon: '🐛'
  },
  {
    id: 't-3',
    name: 'Incident Postmortem',
    category: 'Operations',
    description: 'Structure post-incident retrospectives with timeline details, root causes, and preventive action items.',
    icon: '🚨'
  },
  {
    id: 't-4',
    name: 'Product Architecture RFC',
    category: 'Design',
    description: 'Request for Comments template for technical proposals, database schemas, and API design specifications.',
    icon: '🏗️'
  }
];

const INITIAL_REMINDERS: ReminderItem[] = [
  {
    id: 'r-1',
    title: 'Daily Engineering Standup',
    scheduledTime: '10:00 AM',
    recurrence: 'Every weekday'
  },
  {
    id: 'r-2',
    title: 'Submit Weekly Time Log',
    scheduledTime: '05:00 PM',
    recurrence: 'Every Friday'
  },
  {
    id: 'r-3',
    title: 'Sprint Retrospective & Demo',
    scheduledTime: '02:00 PM',
    recurrence: 'Every 2 weeks'
  }
];

const INITIAL_DRAFTS: DraftItem[] = [
  {
    id: 'd-1',
    title: 'Q3 Enterprise Scale Strategy',
    targetChannel: '#announcements',
    lastModified: '2 hours ago',
    preview: 'Team, here is our preliminary technical blueprint for supporting multi-region data replication...'
  },
  {
    id: 'd-2',
    title: 'Vapor Swift 6 Migration Plan',
    targetChannel: '#engineering',
    lastModified: 'Yesterday',
    preview: 'We are planning to upgrade our core microservices to Swift 6 to take advantage of strict concurrency checks...'
  }
];

export const ProductivityScreen: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'templates' | 'reminders' | 'drafts'>('templates');

  const handleUseTemplate = (templateName: string) => {
    alert(`Template "${templateName}" applied to workspace!`);
  };

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-slate-950 text-slate-100">
      {/* Top Header */}
      <div className="p-6 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
            <Zap className="w-6 h-6 text-amber-400" />
            Productivity Hub
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Access organization templates, manage recurring reminders, and review saved drafts
          </p>
        </div>
      </div>

      {/* Tabs Bar */}
      <div className="px-6 border-b border-slate-800 bg-slate-900/40 flex items-center gap-4">
        <button
          onClick={() => setActiveTab('templates')}
          className={`py-3 px-2 text-xs font-semibold border-b-2 transition flex items-center gap-2 ${
            activeTab === 'templates'
              ? 'border-indigo-500 text-indigo-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Sparkles className="w-4 h-4" />
          Org Templates ({INITIAL_TEMPLATES.length})
        </button>

        <button
          onClick={() => setActiveTab('reminders')}
          className={`py-3 px-2 text-xs font-semibold border-b-2 transition flex items-center gap-2 ${
            activeTab === 'reminders'
              ? 'border-indigo-500 text-indigo-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Bell className="w-4 h-4" />
          Scheduled Reminders ({INITIAL_REMINDERS.length})
        </button>

        <button
          onClick={() => setActiveTab('drafts')}
          className={`py-3 px-2 text-xs font-semibold border-b-2 transition flex items-center gap-2 ${
            activeTab === 'drafts'
              ? 'border-indigo-500 text-indigo-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Bookmark className="w-4 h-4" />
          Saved Drafts ({INITIAL_DRAFTS.length})
        </button>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 overflow-y-auto p-6">
        {activeTab === 'templates' && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {INITIAL_TEMPLATES.map(tpl => (
              <div
                key={tpl.id}
                className="bg-slate-900/60 border border-slate-800 hover:border-slate-700 rounded-2xl p-5 shadow-lg flex flex-col justify-between transition group"
              >
                <div>
                  <div className="flex items-center justify-between gap-2 mb-3">
                    <span className="text-2xl">{tpl.icon}</span>
                    <span className="text-[10px] font-semibold uppercase tracking-wider bg-slate-800 text-indigo-300 px-2.5 py-1 rounded-md">
                      {tpl.category}
                    </span>
                  </div>

                  <h3 className="text-base font-bold text-slate-100 mb-2">
                    {tpl.name}
                  </h3>

                  <p className="text-xs text-slate-400 leading-relaxed mb-4">
                    {tpl.description}
                  </p>
                </div>

                <div className="pt-4 border-t border-slate-800/80 flex justify-end">
                  <button
                    onClick={() => handleUseTemplate(tpl.name)}
                    className="px-3.5 py-1.5 rounded-xl bg-indigo-600/20 border border-indigo-500/40 text-indigo-300 hover:bg-indigo-600 hover:text-white transition text-xs font-semibold flex items-center gap-1.5"
                  >
                    <span>Apply Template</span>
                    <ArrowRight className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        {activeTab === 'reminders' && (
          <div className="space-y-4 max-w-3xl">
            {INITIAL_REMINDERS.map(rem => (
              <div
                key={rem.id}
                className="bg-slate-900/60 border border-slate-800 rounded-2xl p-4 flex items-center justify-between gap-4"
              >
                <div className="flex items-center gap-3.5">
                  <div className="p-2.5 rounded-xl bg-indigo-500/10 border border-indigo-500/30 text-indigo-400">
                    <Bell className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-slate-200">
                      {rem.title}
                    </h3>
                    <div className="flex items-center gap-2 mt-1 text-xs text-slate-400">
                      <Clock className="w-3.5 h-3.5" />
                      <span>{rem.scheduledTime}</span>
                      <span>•</span>
                      <span>{rem.recurrence}</span>
                    </div>
                  </div>
                </div>

                <span className="text-xs font-semibold text-emerald-400 bg-emerald-500/10 px-3 py-1 rounded-full border border-emerald-500/20">
                  Active
                </span>
              </div>
            ))}
          </div>
        )}

        {activeTab === 'drafts' && (
          <div className="space-y-4 max-w-3xl">
            {INITIAL_DRAFTS.map(draft => (
              <div
                key={draft.id}
                className="bg-slate-900/60 border border-slate-800 rounded-2xl p-5 space-y-3"
              >
                <div className="flex items-center justify-between gap-2">
                  <h3 className="text-sm font-bold text-slate-200">
                    {draft.title}
                  </h3>
                  <span className="text-[11px] text-slate-500">
                    {draft.lastModified}
                  </span>
                </div>

                <p className="text-xs text-slate-400 italic line-clamp-2 bg-slate-950/60 p-3 rounded-xl border border-slate-800/80">
                  "{draft.preview}"
                </p>

                <div className="flex items-center justify-between text-xs text-slate-400 pt-1">
                  <span>Target: <strong className="text-indigo-400">{draft.targetChannel}</strong></span>
                  <button 
                    onClick={() => alert(`Opening draft "${draft.title}"`)}
                    className="text-xs font-semibold text-indigo-400 hover:underline"
                  >
                    Continue Editing
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
