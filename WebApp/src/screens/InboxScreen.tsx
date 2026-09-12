import React, { useEffect, useState } from 'react';
import { NotificationDTO } from '../types';
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
  Filter
} from 'lucide-react';

export const InboxScreen: React.FC = () => {
  const [notifications, setNotifications] = useState<NotificationDTO[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Filters
  const [unreadOnly, setUnreadOnly] = useState(false);
  const [activeCategory, setActiveCategory] = useState<string>('all');

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

  const getNotificationIcon = (type: string) => {
    switch (type.toLowerCase()) {
      case 'mention':
        return <AtSign className="w-4 h-4 text-indigo-400" />;
      case 'message':
        return <MessageSquare className="w-4 h-4 text-blue-400" />;
      case 'meeting':
        return <Calendar className="w-4 h-4 text-emerald-400" />;
      case 'task':
        return <CheckCircle2 className="w-4 h-4 text-amber-400" />;
      default:
        return <Bell className="w-4 h-4 text-purple-400" />;
    }
  };

  const filteredNotifications = notifications.filter(n => {
    if (unreadOnly && n.isRead) return false;
    if (activeCategory === 'mentions' && n.type !== 'mention') return false;
    if (activeCategory === 'messages' && n.type !== 'message') return false;
    if (activeCategory === 'meetings' && n.type !== 'meeting') return false;
    if (activeCategory === 'assigned' && n.type !== 'task') return false;
    return true;
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
            onClick={handleMarkAllRead}
            disabled={unreadCount === 0}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 disabled:opacity-50 text-slate-200 transition border border-slate-700 flex items-center gap-2 text-sm font-medium"
          >
            <CheckCheck className="w-4 h-4 text-indigo-400" />
            Mark All Read
          </button>
          <button
            onClick={() => fetchNotifications(true)}
            className="p-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 transition border border-slate-700 flex items-center gap-2 text-sm font-medium"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>
      </div>

      {/* Filter Chips Bar */}
      <div className="px-6 py-3 border-b border-slate-800/80 bg-slate-900/40 flex flex-wrap items-center justify-between gap-4">
        {/* Category Chips */}
        <div className="flex items-center gap-2 flex-wrap">
          {['all', 'mentions', 'assigned', 'messages', 'meetings'].map(cat => (
            <button
              key={cat}
              onClick={() => setActiveCategory(cat)}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold capitalize transition ${
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
          className={`flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-medium border transition ${
            unreadOnly
              ? 'bg-indigo-500/20 border-indigo-500/50 text-indigo-300'
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
          <div className="border border-dashed border-slate-800 rounded-2xl p-12 text-center text-slate-500 space-y-3">
            <Bell className="w-10 h-10 mx-auto opacity-30 text-slate-400" />
            <p className="text-base font-semibold text-slate-400">All caught up!</p>
            <p className="text-xs">No notifications match your current filter settings.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {filteredNotifications.map(notification => (
              <div
                key={notification.id}
                className={`p-4 rounded-2xl border transition flex items-start gap-4 ${
                  notification.isRead
                    ? 'bg-slate-900/40 border-slate-800/80 text-slate-400'
                    : 'bg-slate-900/90 border-slate-700/80 text-slate-100 shadow-md shadow-slate-950/50'
                }`}
              >
                {/* Status Dot & Icon */}
                <div className="flex items-center gap-3 pt-0.5">
                  <span
                    className={`w-2 h-2 rounded-full ${
                      notification.isRead ? 'bg-transparent' : 'bg-indigo-400 animate-pulse'
                    }`}
                  />
                  <div className="p-2.5 rounded-xl bg-slate-800/80 border border-slate-700/60">
                    {getNotificationIcon(notification.type)}
                  </div>
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2 mb-1">
                    <h3 className={`text-sm font-semibold truncate ${notification.isRead ? 'text-slate-300' : 'text-slate-100'}`}>
                      {notification.title}
                    </h3>
                    <span className="text-[11px] text-slate-500 whitespace-nowrap">
                      {new Date(notification.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    {notification.body}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
