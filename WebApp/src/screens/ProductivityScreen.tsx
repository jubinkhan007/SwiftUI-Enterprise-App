import React, { useEffect, useState } from 'react';
import { 
  Zap, 
  FileText, 
  Bell, 
  Clock, 
  Sparkles, 
  Plus, 
  Trash2, 
  Edit3, 
  Send, 
  CheckCircle2, 
  X, 
  Calendar, 
  AlertCircle,
  Copy,
  RefreshCw,
  Eye,
  User,
  Building2,
  Smile,
  Shield,
  Search
} from 'lucide-react';
import { 
  MessageTemplateDTO, 
  ScheduledMessageDTO, 
  ReminderDTO, 
  UserPresenceDTO, 
  PresenceState, 
  CreateTemplateRequest, 
  CreateReminderRequest,
  ConversationDTO,
  NavDestination
} from '../types';
import { api } from '../services/api';

interface ProductivityScreenProps {
  onNavigate?: (dest: NavDestination) => void;
}

const STATUS_PRESETS = [
  { emoji: '📅', text: 'In a meeting', durationMins: 60 },
  { emoji: '🎯', text: 'Focus time', durationMins: 120 },
  { emoji: '💬', text: 'Working remotely', durationMins: 480 },
  { emoji: '🤒', text: 'Out sick', durationMins: 1440 },
  { emoji: '🌴', text: 'On vacation', durationMins: 4320 },
];

export const ProductivityScreen: React.FC<ProductivityScreenProps> = ({ onNavigate }) => {
  const [activeTab, setActiveTab] = useState<'templates' | 'reminders' | 'scheduled' | 'status'>('templates');
  const [loading, setLoading] = useState(false);
  const [notice, setNotice] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  // Templates State
  const [templates, setTemplates] = useState<MessageTemplateDTO[]>([]);
  const [templateScopeFilter, setTemplateScopeFilter] = useState<'all' | 'user' | 'org'>('all');
  const [showCreateTemplateModal, setShowCreateTemplateModal] = useState(false);
  const [editingTemplate, setEditingTemplate] = useState<MessageTemplateDTO | null>(null);
  const [templateName, setTemplateName] = useState('');
  const [templateShortcut, setTemplateShortcut] = useState('');
  const [templateBody, setTemplateBody] = useState('');
  const [templateScope, setTemplateScope] = useState<'user' | 'org'>('user');
  const [renderedPreview, setRenderedPreview] = useState<{ id: string; text: string } | null>(null);

  // Reminders State
  const [reminders, setReminders] = useState<ReminderDTO[]>([]);
  const [reminderFilter, setReminderFilter] = useState<'all' | 'pending' | 'fired' | 'dismissed'>('all');
  const [showCreateReminderModal, setShowCreateReminderModal] = useState(false);
  const [reminderBody, setReminderBody] = useState('');
  const [reminderDateTime, setReminderDateTime] = useState('');

  // Scheduled Messages State
  const [scheduledMessages, setScheduledMessages] = useState<ScheduledMessageDTO[]>([]);
  const [scheduledFilter, setScheduledFilter] = useState<'all' | 'scheduled' | 'sent' | 'cancelled'>('all');
  const [conversations, setConversations] = useState<ConversationDTO[]>([]);
  const [showCreateScheduledModal, setShowCreateScheduledModal] = useState(false);
  const [selectedConversationId, setSelectedConversationId] = useState('');
  const [scheduledMessageBody, setScheduledMessageBody] = useState('');
  const [scheduledMessageDateTime, setScheduledMessageDateTime] = useState('');

  // Presence & Status State
  const [presence, setPresence] = useState<UserPresenceDTO | null>(null);
  const [customEmoji, setCustomEmoji] = useState('🎯');
  const [customText, setCustomText] = useState('');
  const [customDuration, setCustomDuration] = useState<number>(60); // minutes

  const showNotification = (message: string, type: 'success' | 'error' = 'success') => {
    setNotice({ type, message });
    setTimeout(() => setNotice(null), 4000);
  };

  const loadData = async () => {
    setLoading(true);
    try {
      const [tpls, rems, scheds, myPresence, convs] = await Promise.all([
        api.getTemplates(templateScopeFilter),
        api.getReminders(reminderFilter === 'all' ? undefined : reminderFilter),
        api.getScheduledMessages(scheduledFilter === 'all' ? undefined : scheduledFilter),
        api.getMyPresence().catch(() => null),
        api.getConversations().catch(() => [])
      ]);
      setTemplates(tpls);
      setReminders(rems);
      setScheduledMessages(scheds);
      setPresence(myPresence);
      setConversations(convs);
    } catch (err: any) {
      console.error('Failed to load productivity data:', err);
      showNotification(err.message || 'Error loading data', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [templateScopeFilter, reminderFilter, scheduledFilter]);

  // ===================== TEMPLATES HANDLERS =====================
  const handleSaveTemplate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!templateName.trim() || !templateBody.trim()) {
      showNotification('Template name and body are required.', 'error');
      return;
    }
    try {
      if (editingTemplate) {
        await api.updateTemplate(editingTemplate.id, {
          name: templateName.trim(),
          body: templateBody.trim(),
          shortcut: templateShortcut.trim() || null
        });
        showNotification(`Template "${templateName}" updated!`);
      } else {
        await api.createTemplate({
          name: templateName.trim(),
          body: templateBody.trim(),
          shortcut: templateShortcut.trim() || null,
          scope: templateScope
        });
        showNotification(`Template "${templateName}" created!`);
      }
      setShowCreateTemplateModal(false);
      setEditingTemplate(null);
      setTemplateName('');
      setTemplateShortcut('');
      setTemplateBody('');
      const tpls = await api.getTemplates(templateScopeFilter);
      setTemplates(tpls);
    } catch (err: any) {
      showNotification(err.message || 'Failed to save template', 'error');
    }
  };

  const handleDeleteTemplate = async (id: string) => {
    if (!confirm('Are you sure you want to delete this template?')) return;
    try {
      await api.deleteTemplate(id);
      showNotification('Template deleted.');
      setTemplates(prev => prev.filter(t => t.id !== id));
    } catch (err: any) {
      showNotification(err.message || 'Failed to delete template', 'error');
    }
  };

  const handleTestRender = async (tpl: MessageTemplateDTO) => {
    try {
      const rendered = await api.renderTemplate(tpl.id, conversations[0]?.id || null);
      setRenderedPreview({ id: tpl.id, text: rendered.body });
    } catch (err: any) {
      showNotification(err.message || 'Render failed', 'error');
    }
  };

  // ===================== REMINDERS HANDLERS =====================
  const handleCreateReminder = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!reminderBody.trim() || !reminderDateTime) {
      showNotification('Body and reminder time are required.', 'error');
      return;
    }
    try {
      const dt = new Date(reminderDateTime).toISOString();
      await api.createReminder({
        body: reminderBody.trim(),
        remindAt: dt
      });
      showNotification('Reminder created successfully!');
      setShowCreateReminderModal(false);
      setReminderBody('');
      setReminderDateTime('');
      const rems = await api.getReminders(reminderFilter === 'all' ? undefined : reminderFilter);
      setReminders(rems);
    } catch (err: any) {
      showNotification(err.message || 'Failed to create reminder', 'error');
    }
  };

  const handleSnoozeReminder = async (id: string, minutes: number) => {
    try {
      await api.snoozeReminder(id, minutes);
      showNotification(`Reminder snoozed for ${minutes} minutes.`);
      const rems = await api.getReminders(reminderFilter === 'all' ? undefined : reminderFilter);
      setReminders(rems);
    } catch (err: any) {
      showNotification(err.message || 'Failed to snooze reminder', 'error');
    }
  };

  const handleDismissReminder = async (id: string) => {
    try {
      await api.dismissReminder(id);
      showNotification('Reminder marked dismissed.');
      const rems = await api.getReminders(reminderFilter === 'all' ? undefined : reminderFilter);
      setReminders(rems);
    } catch (err: any) {
      showNotification(err.message || 'Failed to dismiss reminder', 'error');
    }
  };

  const handleDeleteReminder = async (id: string) => {
    try {
      await api.deleteReminder(id);
      showNotification('Reminder deleted.');
      setReminders(prev => prev.filter(r => r.id !== id));
    } catch (err: any) {
      showNotification(err.message || 'Failed to delete reminder', 'error');
    }
  };

  // ===================== SCHEDULED MESSAGES HANDLERS =====================
  const handleCreateScheduledMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedConversationId || !scheduledMessageBody.trim() || !scheduledMessageDateTime) {
      showNotification('Conversation, message body, and scheduled time are required.', 'error');
      return;
    }
    try {
      const dt = new Date(scheduledMessageDateTime).toISOString();
      await api.createScheduledMessage(selectedConversationId, {
        body: scheduledMessageBody.trim(),
        scheduledFor: dt
      });
      showNotification('Message scheduled successfully!');
      setShowCreateScheduledModal(false);
      setScheduledMessageBody('');
      setScheduledMessageDateTime('');
      const scheds = await api.getScheduledMessages(scheduledFilter === 'all' ? undefined : scheduledFilter);
      setScheduledMessages(scheds);
    } catch (err: any) {
      showNotification(err.message || 'Failed to schedule message', 'error');
    }
  };

  const handleSendNow = async (id: string) => {
    try {
      await api.sendScheduledMessageNow(id);
      showNotification('Message dispatched immediately!');
      const scheds = await api.getScheduledMessages(scheduledFilter === 'all' ? undefined : scheduledFilter);
      setScheduledMessages(scheds);
    } catch (err: any) {
      showNotification(err.message || 'Failed to send message now', 'error');
    }
  };

  const handleCancelScheduled = async (id: string) => {
    try {
      await api.cancelScheduledMessage(id);
      showNotification('Scheduled message cancelled.');
      const scheds = await api.getScheduledMessages(scheduledFilter === 'all' ? undefined : scheduledFilter);
      setScheduledMessages(scheds);
    } catch (err: any) {
      showNotification(err.message || 'Failed to cancel scheduled message', 'error');
    }
  };

  // ===================== PRESENCE & STATUS HANDLERS =====================
  const handleUpdateStatus = async (emoji: string, text: string, minutes: number) => {
    try {
      const expiresAt = minutes > 0 ? new Date(Date.now() + minutes * 60 * 1000).toISOString() : null;
      const updated = await api.setCustomStatus({
        emoji: emoji.trim() || undefined,
        text: text.trim() || undefined,
        expiresAt
      });
      setPresence(updated);
      showNotification('Custom status updated!');
    } catch (err: any) {
      showNotification(err.message || 'Failed to update status', 'error');
    }
  };

  const handleClearStatus = async () => {
    try {
      const updated = await api.clearCustomStatus();
      setPresence(updated);
      showNotification('Status cleared.');
    } catch (err: any) {
      showNotification(err.message || 'Failed to clear status', 'error');
    }
  };

  const handleSetPresenceState = async (state: PresenceState) => {
    try {
      const updated = await api.sendHeartbeat(state);
      setPresence(updated);
      showNotification(`Presence set to ${state}`);
    } catch (err: any) {
      showNotification(err.message || 'Failed to update presence', 'error');
    }
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
            Standardize templates, manage scheduled messages, track reminders, and customize your status
          </p>
        </div>

        <div className="flex items-center gap-3">
          {presence && (
            <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-900 border border-slate-800 text-xs">
              <span className={`w-2.5 h-2.5 rounded-full ${
                presence.state === 'online' ? 'bg-emerald-500 shadow-sm shadow-emerald-500/50' :
                presence.state === 'away' ? 'bg-amber-500' : 'bg-slate-500'
              }`} />
              <span className="capitalize font-semibold text-slate-300">{presence.state}</span>
              {presence.customStatusEmoji && (
                <span className="ml-1 px-2 py-0.5 rounded-md bg-slate-800 text-slate-200 flex items-center gap-1">
                  <span>{presence.customStatusEmoji}</span>
                  {presence.customStatusText && <span>{presence.customStatusText}</span>}
                </span>
              )}
            </div>
          )}

          <button
            onClick={loadData}
            disabled={loading}
            className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
            title="Refresh"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Notifications Banner */}
      {notice && (
        <div className={`px-6 py-2.5 text-xs font-semibold flex items-center justify-between transition ${
          notice.type === 'success' ? 'bg-emerald-950/80 text-emerald-300 border-b border-emerald-800/50' : 'bg-red-950/80 text-red-300 border-b border-red-800/50'
        }`}>
          <span>{notice.message}</span>
          <button onClick={() => setNotice(null)} className="hover:opacity-80">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Tabs Header */}
      <div className="px-6 border-b border-slate-800 bg-slate-900/40 flex items-center gap-6 overflow-x-auto">
        <button
          onClick={() => setActiveTab('templates')}
          className={`py-3 text-xs font-semibold border-b-2 transition flex items-center gap-2 ${
            activeTab === 'templates'
              ? 'border-indigo-500 text-indigo-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Sparkles className="w-4 h-4" />
          Reusable Templates ({templates.length})
        </button>

        <button
          onClick={() => setActiveTab('scheduled')}
          className={`py-3 text-xs font-semibold border-b-2 transition flex items-center gap-2 ${
            activeTab === 'scheduled'
              ? 'border-indigo-500 text-indigo-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Clock className="w-4 h-4" />
          Scheduled Sends ({scheduledMessages.length})
        </button>

        <button
          onClick={() => setActiveTab('reminders')}
          className={`py-3 text-xs font-semibold border-b-2 transition flex items-center gap-2 ${
            activeTab === 'reminders'
              ? 'border-indigo-500 text-indigo-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Bell className="w-4 h-4" />
          Reminders ({reminders.length})
        </button>

        <button
          onClick={() => setActiveTab('status')}
          className={`py-3 text-xs font-semibold border-b-2 transition flex items-center gap-2 ${
            activeTab === 'status'
              ? 'border-indigo-500 text-indigo-400'
              : 'border-transparent text-slate-400 hover:text-slate-200'
          }`}
        >
          <Smile className="w-4 h-4" />
          Status & Presence
        </button>
      </div>

      {/* Main Tab Content */}
      <div className="flex-1 overflow-y-auto p-6">
        {/* ===================== TEMPLATES TAB ===================== */}
        {activeTab === 'templates' && (
          <div className="max-w-6xl mx-auto space-y-6">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div className="flex items-center gap-2">
                {(['all', 'org', 'user'] as const).map(scope => (
                  <button
                    key={scope}
                    onClick={() => setTemplateScopeFilter(scope)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition capitalize ${
                      templateScopeFilter === scope
                        ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/20'
                        : 'bg-slate-900 border border-slate-800 text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    {scope === 'all' ? 'All Templates' : scope === 'org' ? 'Organization' : 'My Personal'}
                  </button>
                ))}
              </div>

              <button
                onClick={() => {
                  setEditingTemplate(null);
                  setTemplateName('');
                  setTemplateShortcut('');
                  setTemplateBody('');
                  setTemplateScope('user');
                  setShowCreateTemplateModal(true);
                }}
                className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs flex items-center gap-1.5 transition shadow-lg shadow-indigo-600/30"
              >
                <Plus className="w-4 h-4" />
                New Template
              </button>
            </div>

            {templates.length === 0 ? (
              <div className="p-12 text-center bg-slate-900/40 border border-slate-800/80 rounded-2xl">
                <FileText className="w-12 h-12 text-slate-600 mx-auto mb-3" />
                <h3 className="text-base font-bold text-slate-300">No templates found</h3>
                <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
                  Create reusable message and task templates with dynamic placeholders like {'{{user.name}}'} and {'{{date}}'}.
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {templates.map(tpl => (
                  <div
                    key={tpl.id}
                    className="p-4 rounded-2xl bg-slate-900/80 border border-slate-800/80 flex flex-col justify-between hover:border-slate-700 transition group"
                  >
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-slate-100 flex items-center gap-1.5">
                          {tpl.scope === 'org' ? (
                            <Building2 className="w-3.5 h-3.5 text-indigo-400" />
                          ) : (
                            <User className="w-3.5 h-3.5 text-emerald-400" />
                          )}
                          {tpl.name}
                        </span>
                        <div className="flex items-center gap-1.5">
                          <span className={`text-[10px] uppercase font-bold px-2 py-0.5 rounded-full ${
                            tpl.scope === 'org' ? 'bg-indigo-500/20 text-indigo-300' : 'bg-emerald-500/20 text-emerald-300'
                          }`}>
                            {tpl.scope}
                          </span>
                          {tpl.shortcut && (
                            <span className="text-[10px] font-mono px-2 py-0.5 rounded-md bg-slate-800 text-slate-300 border border-slate-700">
                              /{tpl.shortcut}
                            </span>
                          )}
                        </div>
                      </div>

                      <p className="text-xs text-slate-400 font-mono whitespace-pre-wrap bg-slate-950 p-3 rounded-xl border border-slate-900/80 line-clamp-4">
                        {tpl.body}
                      </p>

                      {renderedPreview?.id === tpl.id && (
                        <div className="mt-2 p-2.5 rounded-xl bg-indigo-950/60 border border-indigo-800/60 text-indigo-200 text-xs font-sans">
                          <span className="text-[10px] font-bold uppercase tracking-wider text-indigo-400 block mb-1">
                            Rendered Preview:
                          </span>
                          <p className="whitespace-pre-wrap">{renderedPreview.text}</p>
                        </div>
                      )}
                    </div>

                    <div className="mt-4 pt-3 border-t border-slate-800/60 flex items-center justify-between text-xs">
                      <button
                        onClick={() => handleTestRender(tpl)}
                        className="text-indigo-400 hover:text-indigo-300 flex items-center gap-1 font-semibold transition"
                      >
                        <Eye className="w-3.5 h-3.5" />
                        {renderedPreview?.id === tpl.id ? 'Hide Preview' : 'Test Render'}
                      </button>

                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => {
                            setEditingTemplate(tpl);
                            setTemplateName(tpl.name);
                            setTemplateShortcut(tpl.shortcut || '');
                            setTemplateBody(tpl.body);
                            setTemplateScope(tpl.scope);
                            setShowCreateTemplateModal(true);
                          }}
                          className="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition"
                          title="Edit"
                        >
                          <Edit3 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          onClick={() => handleDeleteTemplate(tpl.id)}
                          className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-800 transition"
                          title="Delete"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ===================== SCHEDULED SENDS TAB ===================== */}
        {activeTab === 'scheduled' && (
          <div className="max-w-6xl mx-auto space-y-6">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div className="flex items-center gap-2">
                {(['all', 'scheduled', 'sent', 'cancelled'] as const).map(st => (
                  <button
                    key={st}
                    onClick={() => setScheduledFilter(st)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition capitalize ${
                      scheduledFilter === st
                        ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/20'
                        : 'bg-slate-900 border border-slate-800 text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    {st === 'all' ? 'All Scheduled' : st}
                  </button>
                ))}
              </div>

              <button
                onClick={() => {
                  setSelectedConversationId(conversations[0]?.id || '');
                  setScheduledMessageBody('');
                  setScheduledMessageDateTime('');
                  setShowCreateScheduledModal(true);
                }}
                className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs flex items-center gap-1.5 transition shadow-lg shadow-indigo-600/30"
              >
                <Plus className="w-4 h-4" />
                Schedule Message
              </button>
            </div>

            {scheduledMessages.length === 0 ? (
              <div className="p-12 text-center bg-slate-900/40 border border-slate-800/80 rounded-2xl">
                <Clock className="w-12 h-12 text-slate-600 mx-auto mb-3" />
                <h3 className="text-base font-bold text-slate-300">No scheduled messages</h3>
                <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
                  Queue messages for delivery across time zones and outside working hours.
                </p>
              </div>
            ) : (
              <div className="space-y-3">
                {scheduledMessages.map(msg => {
                  const conv = conversations.find(c => c.id === msg.conversationId);
                  const scheduledTime = new Date(msg.scheduledFor).toLocaleString();
                  return (
                    <div
                      key={msg.id}
                      className="p-4 rounded-2xl bg-slate-900/80 border border-slate-800/80 flex flex-wrap items-center justify-between gap-4"
                    >
                      <div className="space-y-1.5 flex-1 min-w-[280px]">
                        <div className="flex items-center gap-2">
                          <span className="text-xs font-bold text-indigo-400">
                            #{conv?.name || 'Channel'}
                          </span>
                          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full capitalize ${
                            msg.status === 'scheduled' ? 'bg-amber-500/20 text-amber-300' :
                            msg.status === 'sent' ? 'bg-emerald-500/20 text-emerald-300' :
                            msg.status === 'cancelled' ? 'bg-slate-500/20 text-slate-400' : 'bg-red-500/20 text-red-300'
                          }`}>
                            {msg.status}
                          </span>
                          <span className="text-xs text-slate-500">
                            Deliver: <strong className="text-slate-300">{scheduledTime}</strong>
                          </span>
                        </div>
                        <p className="text-sm text-slate-200 whitespace-pre-wrap">{msg.body}</p>
                      </div>

                      {msg.status === 'scheduled' && (
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => handleSendNow(msg.id)}
                            className="px-3 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs flex items-center gap-1 transition"
                          >
                            <Send className="w-3.5 h-3.5" />
                            Send Now
                          </button>
                          <button
                            onClick={() => handleCancelScheduled(msg.id)}
                            className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition"
                          >
                            Cancel
                          </button>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* ===================== REMINDERS TAB ===================== */}
        {activeTab === 'reminders' && (
          <div className="max-w-6xl mx-auto space-y-6">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div className="flex items-center gap-2">
                {(['all', 'pending', 'fired', 'dismissed'] as const).map(st => (
                  <button
                    key={st}
                    onClick={() => setReminderFilter(st)}
                    className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition capitalize ${
                      reminderFilter === st
                        ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/20'
                        : 'bg-slate-900 border border-slate-800 text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    {st === 'all' ? 'All Reminders' : st}
                  </button>
                ))}
              </div>

              <button
                onClick={() => {
                  setReminderBody('');
                  setReminderDateTime('');
                  setShowCreateReminderModal(true);
                }}
                className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs flex items-center gap-1.5 transition shadow-lg shadow-indigo-600/30"
              >
                <Plus className="w-4 h-4" />
                New Reminder
              </button>
            </div>

            {reminders.length === 0 ? (
              <div className="p-12 text-center bg-slate-900/40 border border-slate-800/80 rounded-2xl">
                <Bell className="w-12 h-12 text-slate-600 mx-auto mb-3" />
                <h3 className="text-base font-bold text-slate-300">No active reminders</h3>
                <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
                  Set reminders on any message, task, or create custom alerts for upcoming deadlines.
                </p>
              </div>
            ) : (
              <div className="space-y-3">
                {reminders.map(rem => {
                  const remindTime = new Date(rem.remindAt).toLocaleString();
                  const isPending = rem.status === 'pending';
                  return (
                    <div
                      key={rem.id}
                      className="p-4 rounded-2xl bg-slate-900/80 border border-slate-800/80 flex flex-wrap items-center justify-between gap-4"
                    >
                      <div className="space-y-1 flex-1 min-w-[280px]">
                        <div className="flex items-center gap-2">
                          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full capitalize ${
                            rem.status === 'pending' ? 'bg-amber-500/20 text-amber-300' :
                            rem.status === 'fired' ? 'bg-red-500/20 text-red-300' : 'bg-slate-500/20 text-slate-400'
                          }`}>
                            {rem.status}
                          </span>
                          {rem.sourceType && (
                            <span className="text-[10px] font-semibold text-indigo-400 px-2 py-0.5 rounded bg-indigo-950 border border-indigo-800/50 uppercase">
                              {rem.sourceType}
                            </span>
                          )}
                          <span className="text-xs text-slate-400 flex items-center gap-1">
                            <Clock className="w-3 h-3 text-slate-500" />
                            {remindTime}
                          </span>
                        </div>
                        <p className="text-sm font-medium text-slate-200">{rem.body}</p>
                      </div>

                      <div className="flex items-center gap-2">
                        {isPending && (
                          <>
                            <button
                              onClick={() => handleSnoozeReminder(rem.id, 15)}
                              className="px-2.5 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-300 transition"
                            >
                              +15m
                            </button>
                            <button
                              onClick={() => handleSnoozeReminder(rem.id, 60)}
                              className="px-2.5 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-xs font-semibold text-slate-300 transition"
                            >
                              +1h
                            </button>
                            <button
                              onClick={() => handleDismissReminder(rem.id)}
                              className="px-3 py-1.5 rounded-xl bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-xs font-semibold transition"
                            >
                              Dismiss
                            </button>
                          </>
                        )}
                        <button
                          onClick={() => handleDeleteReminder(rem.id)}
                          className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-800 transition"
                          title="Delete"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* ===================== STATUS & PRESENCE TAB ===================== */}
        {activeTab === 'status' && (
          <div className="max-w-2xl mx-auto space-y-6">
            <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 space-y-6">
              <div>
                <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                  <Smile className="w-5 h-5 text-indigo-400" />
                  Custom User Status
                </h3>
                <p className="text-xs text-slate-400 mt-1">
                  Let your team know what you are focusing on right now.
                </p>
              </div>

              {/* Status Presets */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {STATUS_PRESETS.map(preset => (
                  <button
                    key={preset.text}
                    onClick={() => {
                      setCustomEmoji(preset.emoji);
                      setCustomText(preset.text);
                      setCustomDuration(preset.durationMins);
                    }}
                    className="p-3 rounded-xl bg-slate-950 border border-slate-800 hover:border-indigo-500/50 flex items-center gap-3 text-left transition group"
                  >
                    <span className="text-xl group-hover:scale-110 transition">{preset.emoji}</span>
                    <div>
                      <span className="text-xs font-semibold text-slate-200 block">{preset.text}</span>
                      <span className="text-[10px] text-slate-500">{preset.durationMins / 60} hours</span>
                    </div>
                  </button>
                ))}
              </div>

              {/* Custom Input */}
              <div className="space-y-4 pt-4 border-t border-slate-800">
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    value={customEmoji}
                    onChange={e => setCustomEmoji(e.target.value)}
                    className="w-14 bg-slate-950 border border-slate-800 rounded-xl px-2 py-2.5 text-center text-lg focus:outline-none focus:border-indigo-500"
                    placeholder="🎯"
                  />
                  <input
                    type="text"
                    value={customText}
                    onChange={e => setCustomText(e.target.value)}
                    className="flex-1 bg-slate-950 border border-slate-800 rounded-xl px-4 py-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                    placeholder="What is your current status?"
                  />
                </div>

                <div className="flex items-center justify-between text-xs">
                  <span className="text-slate-400">Clear status after:</span>
                  <select
                    value={customDuration}
                    onChange={e => setCustomDuration(Number(e.target.value))}
                    className="bg-slate-950 border border-slate-800 rounded-xl px-3 py-1.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  >
                    <option value={30}>30 minutes</option>
                    <option value={60}>1 hour</option>
                    <option value={240}>4 hours</option>
                    <option value={1440}>Today (24h)</option>
                    <option value={0}>Don't clear</option>
                  </select>
                </div>

                <div className="flex items-center justify-end gap-3 pt-2">
                  <button
                    onClick={handleClearStatus}
                    className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition"
                  >
                    Clear Status
                  </button>
                  <button
                    onClick={() => handleUpdateStatus(customEmoji, customText, customDuration)}
                    disabled={!customEmoji.trim() && !customText.trim()}
                    className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-semibold text-xs transition shadow-lg shadow-indigo-600/30"
                  >
                    Save Status
                  </button>
                </div>
              </div>
            </div>

            {/* Presence Heartbeat Card */}
            <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800/80 space-y-4">
              <div>
                <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                  <Shield className="w-5 h-5 text-emerald-400" />
                  Realtime Presence Control
                </h3>
                <p className="text-xs text-slate-400 mt-1">
                  Control how you appear across all channels, task assignees, and active calls.
                </p>
              </div>

              <div className="flex items-center gap-3">
                {(['online', 'away', 'offline'] as const).map(state => (
                  <button
                    key={state}
                    onClick={() => handleSetPresenceState(state)}
                    className={`flex-1 py-2.5 px-3 rounded-xl border text-xs font-bold transition flex items-center justify-center gap-2 capitalize ${
                      presence?.state === state
                        ? 'bg-indigo-600 text-white border-indigo-500 shadow-md shadow-indigo-600/20'
                        : 'bg-slate-950 border-slate-800 text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <span className={`w-2 h-2 rounded-full ${
                      state === 'online' ? 'bg-emerald-400' : state === 'away' ? 'bg-amber-400' : 'bg-slate-400'
                    }`} />
                    {state}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* ===================== CREATE / EDIT TEMPLATE MODAL ===================== */}
      {showCreateTemplateModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <Sparkles className="w-5 h-5 text-indigo-400" />
                {editingTemplate ? 'Edit Template' : 'New Template'}
              </h3>
              <button
                onClick={() => setShowCreateTemplateModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-200"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveTemplate} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-1">Template Name *</label>
                <input
                  type="text"
                  value={templateName}
                  onChange={e => setTemplateName(e.target.value)}
                  placeholder="e.g. Daily Standup or Bug Report"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-400 block mb-1">Shortcut (optional)</label>
                  <div className="flex items-center bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200">
                    <span className="text-slate-500 mr-1">/</span>
                    <input
                      type="text"
                      value={templateShortcut}
                      onChange={e => setTemplateShortcut(e.target.value.toLowerCase().replace(/[^a-z0-9_-]/g, ''))}
                      placeholder="standup"
                      className="bg-transparent focus:outline-none w-full"
                    />
                  </div>
                </div>

                <div>
                  <label className="text-xs font-semibold text-slate-400 block mb-1">Scope</label>
                  <select
                    value={templateScope}
                    onChange={e => setTemplateScope(e.target.value as any)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  >
                    <option value="user">Personal (Only me)</option>
                    <option value="org">Organization (All members)</option>
                  </select>
                </div>
              </div>

              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="text-xs font-semibold text-slate-400">Template Content *</label>
                  <div className="flex items-center gap-1 text-[10px] text-slate-500">
                    <span>Variables:</span>
                    {['{{user.name}}', '{{org.name}}', '{{date}}'].map(v => (
                      <button
                        key={v}
                        type="button"
                        onClick={() => setTemplateBody(prev => prev + ' ' + v)}
                        className="px-1.5 py-0.5 rounded bg-slate-800 text-indigo-400 hover:bg-slate-700"
                      >
                        {v}
                      </button>
                    ))}
                  </div>
                </div>
                <textarea
                  rows={6}
                  value={templateBody}
                  onChange={e => setTemplateBody(e.target.value)}
                  placeholder="### Daily Standup&#10;1. Yesterday:&#10;2. Today:&#10;3. Blockers:"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 font-mono focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setShowCreateTemplateModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 text-xs font-semibold hover:bg-slate-700 transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold transition shadow-lg shadow-indigo-600/30"
                >
                  {editingTemplate ? 'Update' : 'Create Template'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ===================== CREATE REMINDER MODAL ===================== */}
      {showCreateReminderModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <Bell className="w-5 h-5 text-indigo-400" />
                New Reminder
              </h3>
              <button
                onClick={() => setShowCreateReminderModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-200"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateReminder} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-1">What to remind? *</label>
                <input
                  type="text"
                  value={reminderBody}
                  onChange={e => setReminderBody(e.target.value)}
                  placeholder="Review PR #42 or Deploy release"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-1">Remind Date & Time *</label>
                <input
                  type="datetime-local"
                  value={reminderDateTime}
                  onChange={e => setReminderDateTime(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>

              {/* Quick Presets */}
              <div className="flex items-center gap-2 pt-1">
                {[
                  { label: 'In 30m', mins: 30 },
                  { label: 'In 2h', mins: 120 },
                  { label: 'Tomorrow 9am', mins: 1440 },
                ].map(p => (
                  <button
                    key={p.label}
                    type="button"
                    onClick={() => {
                      const d = new Date(Date.now() + p.mins * 60 * 1000);
                      const iso = new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
                      setReminderDateTime(iso);
                    }}
                    className="px-2.5 py-1 rounded-lg bg-slate-800 text-[11px] font-semibold text-slate-300 hover:bg-slate-700 transition"
                  >
                    {p.label}
                  </button>
                ))}
              </div>

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setShowCreateReminderModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 text-xs font-semibold hover:bg-slate-700 transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold transition shadow-lg shadow-indigo-600/30"
                >
                  Set Reminder
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ===================== CREATE SCHEDULED MESSAGE MODAL ===================== */}
      {showCreateScheduledModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-slate-100 flex items-center gap-2">
                <Clock className="w-5 h-5 text-indigo-400" />
                Schedule Message
              </h3>
              <button
                onClick={() => setShowCreateScheduledModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-200"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateScheduledMessage} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-1">Target Conversation *</label>
                <select
                  value={selectedConversationId}
                  onChange={e => setSelectedConversationId(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                >
                  {conversations.map(c => (
                    <option key={c.id} value={c.id}>
                      #{c.name} ({c.type})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-1">Message Content *</label>
                <textarea
                  rows={4}
                  value={scheduledMessageBody}
                  onChange={e => setScheduledMessageBody(e.target.value)}
                  placeholder="Type message to deliver..."
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-1">Delivery Date & Time *</label>
                <input
                  type="datetime-local"
                  value={scheduledMessageDateTime}
                  onChange={e => setScheduledMessageDateTime(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                  required
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setShowCreateScheduledModal(false)}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 text-xs font-semibold hover:bg-slate-700 transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold transition shadow-lg shadow-indigo-600/30"
                >
                  Schedule Delivery
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
