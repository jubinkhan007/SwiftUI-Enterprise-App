import React, { useEffect, useState } from 'react';
import { NotificationDTO, NavDestination } from '../types';
import { api } from '../services/api';
import { 
  Bell, 
  CheckCheck, 
  RefreshCw, 
  MessageSquare, 
  AtSign, 
  Calendar, 
  CheckCircle2, 
  Inbox as InboxIcon,
  Filter,
  Check,
  SlidersHorizontal,
  X,
  Volume2,
  VolumeX,
  Radio,
  Sparkles,
  ArrowUpRight
} from 'lucide-react';

interface InboxScreenProps {
  onNavigate?: (dest: NavDestination) => void;
}

export const InboxScreen: React.FC<InboxScreenProps> = ({ onNavigate }) => {
  const [notifications, setNotifications] = useState<NotificationDTO[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Filters matching iOS and Android: All, Mentions, Assignments, Updates, Messages, Meetings
  const [unreadOnly, setUnreadOnly] = useState(false);
  const [activeCategory, setActiveCategory] = useState<string>('All');

  // Preferences Modal State
  const [showPreferencesModal, setShowPreferencesModal] = useState(false);
  const [prefMuted, setPrefMuted] = useState(false);
  const [prefFrequency, setPrefFrequency] = useState<'all' | 'mentions' | 'none'>('all');
  const [isSavingPref, setIsSavingPref] = useState(false);
  const [prefSuccess, setPrefSuccess] = useState(false);

  const fetchNotifications = async (showLoading = false) => {
    if (showLoading) setLoading(true);
    setError(null);
    try {
      const data = await api.getNotifications();
      setNotifications(data);
    } catch (err: any) {
      if (showLoading) setError(err.message || 'Failed to fetch notifications');
    } finally {
      if (showLoading) setLoading(false);
    }
  };

  useEffect(() => {
    fetchNotifications(true);
    const interval = setInterval(() => {
      fetchNotifications(false);
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  const handleMarkAllRead = async () => {
    try {
      await api.markAllNotificationsRead();
      setNotifications(prev => prev.map(n => ({ ...n, isRead: true })));
    } catch (err: any) {
      alert(`Failed to mark all as read: ${err.message}`);
    }
  };

  const handleMarkSingleRead = async (notificationId: string) => {
    setNotifications(prev => prev.map(n => n.id === notificationId ? { ...n, isRead: true } : n));
    try {
      await api.markNotificationRead(notificationId);
    } catch (err: any) {
      console.error('Failed to mark notification read:', err);
    }
  };

  const handleNotificationClick = async (notification: NotificationDTO) => {
    if (!notification.isRead) {
      await handleMarkSingleRead(notification.id);
    }
    if (onNavigate) {
      const type = notification.type.toLowerCase();
      if (type.includes('task') || type.includes('assign') || type.includes('update')) {
        onNavigate('all_tasks');
      } else if (type.includes('meeting') || type.includes('call')) {
        onNavigate('meetings');
      } else if (type.includes('message') || type.includes('mention')) {
        onNavigate('messages');
      }
    }
  };

  const handleSavePreferences = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSavingPref(true);
    try {
      localStorage.setItem('taskflow_notif_muted', String(prefMuted));
      localStorage.setItem('taskflow_notif_frequency', prefFrequency);
      setPrefSuccess(true);
      setTimeout(() => {
        setPrefSuccess(false);
        setShowPreferencesModal(false);
      }, 1200);
    } catch (err: any) {
      alert(`Failed to save preferences: ${err.message}`);
    } finally {
      setIsSavingPref(false);
    }
  };

  const getNotificationIcon = (type: string) => {
    const t = type.toLowerCase();
    if (t.includes('mention')) return <AtSign className="w-4 h-4 text-purple-400" />;
    if (t.includes('message')) return <MessageSquare className="w-4 h-4 text-blue-400" />;
    if (t.includes('meeting') || t.includes('call')) return <Calendar className="w-4 h-4 text-emerald-400" />;
    if (t.includes('assign') || t.includes('task')) return <CheckCircle2 className="w-4 h-4 text-amber-400" />;
    return <Bell className="w-4 h-4 text-indigo-400" />;
  };

  const getNotificationTitle = (n: NotificationDTO) => {
    const t = n.type.toLowerCase();
    if (t.includes('assign')) return 'New Assignment';
    if (t.includes('update') || t.includes('status')) return 'Task Updated';
    if (t.includes('mention')) return 'You were mentioned';
    if (t.includes('meeting')) return 'Meeting Invitation';
    if (t.includes('call')) return 'Incoming Call';
    if (t.includes('message')) return 'New Message';
    return n.title || 'Notification';
  };

  const formatRelativeTime = (dateStr: string) => {
    try {
      const date = new Date(dateStr);
      const now = new Date();
      const diffSec = Math.floor((now.getTime() - date.getTime()) / 1000);
      if (diffSec < 60) return 'Just now';
      if (diffSec < 3600) return `${Math.floor(diffSec / 60)}m ago`;
      if (diffSec < 86400) return `${Math.floor(diffSec / 3600)}h ago`;
      if (diffSec < 172800) return 'Yesterday';
      return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
    } catch {
      return dateStr;
    }
  };

  const categories = ['All', 'Mentions', 'Assignments', 'Updates', 'Messages', 'Meetings'];

  const filteredNotifications = notifications.filter(n => {
    if (unreadOnly && n.isRead) return false;
    const t = n.type.toLowerCase();
    switch (activeCategory) {
      case 'Mentions':
        return t.includes('mention');
      case 'Assignments':
        return t.includes('assign');
      case 'Updates':
        return t.includes('update') || t.includes('status');
      case 'Messages':
        return t.includes('message') || t.includes('chat');
      case 'Meetings':
        return t.includes('meeting') || t.includes('call');
      default:
        return true;
    }
  });

  const unreadCount = notifications.filter(n => !n.isRead).length;

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-slate-950 text-slate-100">
      {/* Top Header */}
      <div className="p-6 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
            <InboxIcon className="w-6 h-6 text-indigo-400" />
            Activity Inbox
            {unreadCount > 0 && (
              <span className="text-xs bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 px-2 py-0.5 rounded-full font-semibold">
                {unreadCount} unread
              </span>
            )}
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Stay updated with mentions, task updates, meetings, and channel activity
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowPreferencesModal(true)}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 transition border border-slate-700 flex items-center gap-2 text-sm font-medium cursor-pointer"
            title="Notification Preferences"
          >
            <SlidersHorizontal className="w-4 h-4 text-indigo-400" />
            <span>Preferences</span>
          </button>

          <button
            onClick={handleMarkAllRead}
            disabled={unreadCount === 0}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 disabled:opacity-50 text-slate-200 transition border border-slate-700 flex items-center gap-2 text-sm font-medium cursor-pointer"
            title="Mark All Read"
          >
            <CheckCheck className="w-4 h-4 text-indigo-400" />
            <span>Mark All Read</span>
          </button>

          <button
            onClick={() => fetchNotifications(true)}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 transition border border-slate-700 flex items-center gap-2 text-sm font-medium cursor-pointer"
            title="Refresh"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* Filter Chips Bar */}
      <div className="px-6 py-3 border-b border-slate-800/80 bg-slate-900/40 flex flex-wrap items-center justify-between gap-4">
        {/* Category Chips matching iOS/Android */}
        <div className="flex items-center gap-2 flex-wrap">
          {categories.map(cat => (
            <button
              key={cat}
              onClick={() => setActiveCategory(cat)}
              className={`px-3.5 py-1.5 rounded-full text-xs font-semibold transition cursor-pointer ${
                activeCategory === cat
                  ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/30'
                  : 'bg-slate-800/60 hover:bg-slate-800 text-slate-400 hover:text-slate-200 border border-slate-700/50'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Unread Only Toggle */}
        <button
          onClick={() => setUnreadOnly(!unreadOnly)}
          className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-semibold border transition cursor-pointer ${
            unreadOnly
              ? 'bg-indigo-600 border-indigo-500 text-white shadow-md shadow-indigo-600/30'
              : 'bg-slate-950/60 border-slate-800 text-slate-400 hover:text-slate-200'
          }`}
        >
          <Filter className="w-3.5 h-3.5" />
          Unread Only
        </button>
      </div>

      {/* Notifications List */}
      <div className="flex-1 overflow-y-auto p-6 max-w-4xl mx-auto w-full">
        {loading && notifications.length === 0 ? (
          <div className="flex items-center justify-center h-64 text-slate-400 gap-3">
            <RefreshCw className="w-6 h-6 animate-spin text-indigo-400" />
            <span>Loading notifications...</span>
          </div>
        ) : error ? (
          <div className="p-4 rounded-xl bg-red-950/40 border border-red-800 text-red-300 text-sm">
            {error}
          </div>
        ) : filteredNotifications.length === 0 ? (
          <div className="flex flex-col items-center justify-center p-12 text-center space-y-4">
            <div className="w-20 h-20 rounded-full bg-slate-900 border border-slate-800 flex items-center justify-center shadow-lg">
              <Bell className="w-8 h-8 text-indigo-400" />
            </div>
            <div className="space-y-1">
              <h3 className="text-lg font-bold text-slate-200">All caught up!</h3>
              <p className="text-xs text-slate-400 max-w-xs mx-auto">
                {unreadOnly ? "No unread notifications right now." : "You have no notifications yet."}
              </p>
            </div>
          </div>
        ) : (
          <div className="space-y-3">
            {filteredNotifications.map(notification => (
              <div
                key={notification.id}
                onClick={() => handleNotificationClick(notification)}
                className={`p-4 rounded-2xl border transition flex items-start gap-4 cursor-pointer group hover:scale-[1.005] ${
                  notification.isRead
                    ? 'bg-slate-900/30 border-slate-800/80 text-slate-400 hover:border-slate-700'
                    : 'bg-slate-900/90 border-slate-700/80 text-slate-100 shadow-md shadow-slate-950/50 hover:border-indigo-500/50'
                }`}
              >
                {/* Status Dot & Category Icon */}
                <div className="flex items-center gap-3 pt-0.5 shrink-0">
                  <div className="w-2 h-2 flex items-center justify-center">
                    {!notification.isRead && (
                      <span className="w-2 h-2 rounded-full bg-indigo-400 animate-pulse" />
                    )}
                  </div>
                  <div className="p-2.5 rounded-xl bg-slate-800/80 border border-slate-700/60 group-hover:border-indigo-500/40 transition">
                    {getNotificationIcon(notification.type)}
                  </div>
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2 mb-1">
                    <div className="flex items-center gap-2">
                      <h3 className={`text-sm font-bold truncate ${notification.isRead ? 'text-slate-300' : 'text-slate-100'}`}>
                        {getNotificationTitle(notification)}
                      </h3>
                      {notification.title && notification.title !== getNotificationTitle(notification) && (
                        <span className="text-[11px] font-mono text-indigo-400 bg-indigo-500/10 px-1.5 py-0.5 rounded border border-indigo-500/20">
                          {notification.title}
                        </span>
                      )}
                    </div>
                    <span className="text-[11px] text-slate-500 whitespace-nowrap">
                      {formatRelativeTime(notification.createdAt)}
                    </span>
                  </div>
                  
                  <p className="text-xs text-slate-400 leading-relaxed line-clamp-2">
                    {notification.body}
                  </p>
                </div>

                {/* Action: Single Mark as Read Button */}
                <div className="shrink-0 flex items-center gap-1">
                  {!notification.isRead && (
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleMarkSingleRead(notification.id);
                      }}
                      className="p-1.5 rounded-lg bg-indigo-500/10 hover:bg-indigo-500/20 text-indigo-400 hover:text-indigo-300 transition cursor-pointer"
                      title="Mark as read"
                    >
                      <Check className="w-4 h-4" />
                    </button>
                  )}
                  {onNavigate && (
                    <div className="opacity-0 group-hover:opacity-100 p-1 text-slate-500 transition">
                      <ArrowUpRight className="w-4 h-4" />
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Notification Preferences Modal */}
      {showPreferencesModal && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-md flex items-center justify-center p-4">
          <form 
            onSubmit={handleSavePreferences}
            className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-5"
          >
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                <SlidersHorizontal className="w-5 h-5 text-indigo-400" />
                Notification Preferences
              </h2>
              <button
                type="button"
                onClick={() => setShowPreferencesModal(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {prefSuccess && (
              <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 text-xs font-semibold flex items-center gap-2">
                <Check className="w-4 h-4" />
                Notification preferences updated successfully!
              </div>
            )}

            <div className="space-y-4">
              {/* Mute Toggle */}
              <div className="flex items-center justify-between p-3.5 rounded-xl bg-slate-950/60 border border-slate-800">
                <div className="flex items-center gap-3">
                  {prefMuted ? (
                    <VolumeX className="w-5 h-5 text-rose-400" />
                  ) : (
                    <Volume2 className="w-5 h-5 text-indigo-400" />
                  )}
                  <div>
                    <h4 className="text-xs font-semibold text-slate-200">Mute Notifications</h4>
                    <p className="text-[11px] text-slate-500">Temporarily silence audio and badge alerts</p>
                  </div>
                </div>
                <input
                  type="checkbox"
                  checked={prefMuted}
                  onChange={(e) => setPrefMuted(e.target.checked)}
                  className="w-4 h-4 accent-indigo-600 rounded cursor-pointer"
                />
              </div>

              {/* Notification Frequency Picker */}
              <div className="space-y-2">
                <label className="text-xs font-bold text-slate-400 uppercase tracking-wider">
                  Notify Me For
                </label>
                <div className="space-y-2">
                  {[
                    { id: 'all', title: 'All messages and updates', desc: 'Receive alerts for every task, mention, and message' },
                    { id: 'mentions', title: 'Mentions and direct assignments only', desc: 'Only alert when directly mentioned or assigned work' },
                    { id: 'none', title: 'Nothing', desc: 'Silence all inbox alerts until re-enabled' },
                  ].map(option => (
                    <label 
                      key={option.id}
                      onClick={() => setPrefFrequency(option.id as any)}
                      className={`flex items-start gap-3 p-3 rounded-xl border transition cursor-pointer ${
                        prefFrequency === option.id
                          ? 'bg-indigo-500/10 border-indigo-500/50 text-slate-100'
                          : 'bg-slate-950/40 border-slate-800 text-slate-400 hover:border-slate-700'
                      }`}
                    >
                      <input
                        type="radio"
                        name="prefFrequency"
                        value={option.id}
                        checked={prefFrequency === option.id}
                        onChange={() => setPrefFrequency(option.id as any)}
                        className="mt-0.5 accent-indigo-600 cursor-pointer"
                      />
                      <div>
                        <p className="text-xs font-semibold text-slate-200">{option.title}</p>
                        <p className="text-[11px] text-slate-500 mt-0.5">{option.desc}</p>
                      </div>
                    </label>
                  ))}
                </div>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setShowPreferencesModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSavingPref}
                className="px-4 py-2 rounded-xl text-xs font-semibold bg-indigo-600 hover:bg-indigo-500 text-white transition shadow-lg shadow-indigo-600/30 flex items-center gap-2"
              >
                {isSavingPref ? (
                  <>
                    <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                    <span>Saving...</span>
                  </>
                ) : (
                  <span>Save Preferences</span>
                )}
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
};
