import React, { useEffect, useState } from 'react';
import { NavDestination, NotificationDTO, UserDTO } from './types';
import { api } from './services/api';
import { AuthScreen } from './screens/AuthScreen';
import { SidebarDrawer } from './components/SidebarDrawer';
import { WorkspaceHeader } from './components/WorkspaceHeader';
import { KanbanBoardScreen } from './screens/KanbanBoardScreen';
import { InboxScreen } from './screens/InboxScreen';
import { ChatScreen } from './screens/ChatScreen';
import { MeetingsScreen } from './screens/MeetingsScreen';
import { TeamScreen } from './screens/TeamScreen';
import { ProductivityScreen } from './screens/ProductivityScreen';
import { SessionAuditScreen } from './screens/SessionAuditScreen';
import { InCallScreen } from './screens/InCallScreen';
import { BillingScreen } from './screens/BillingScreen';
import { BacklogScreen } from './screens/BacklogScreen';
import { ReleaseManagementScreen } from './screens/ReleaseManagementScreen';
import { ProjectSettingsScreen } from './screens/ProjectSettingsScreen';
import { IntegrationSettingsScreen } from './screens/IntegrationSettingsScreen';
import { SyncCenterModal } from './components/SyncCenterModal';
import { OmnibarModal } from './components/OmnibarModal';
import { getCurrentLocationDeeplink, parseDeeplink, syncUrlWithDestination, DeeplinkRoute } from './services/deeplink';
import { Video, PhoneOff } from 'lucide-react';

export const App: React.FC = () => {
  const [user, setUser] = useState<UserDTO | null>(api.currentUser);
  const [currentNav, setCurrentNav] = useState<NavDestination>('all_tasks');
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [selectedChannelId, setSelectedChannelId] = useState<string | null>(null);
  const [selectedMeetingId, setSelectedMeetingId] = useState<string | null>(null);
  const [activeCallConvId, setActiveCallConvId] = useState<string | null>(null);
  const [incomingCallNotification, setIncomingCallNotification] = useState<NotificationDTO | null>(null);
  const [showSyncCenter, setShowSyncCenter] = useState(false);
  const [showOmnibar, setShowOmnibar] = useState(false);
  const [isOnline, setIsOnline] = useState(typeof navigator !== 'undefined' ? navigator.onLine : true);

  const applyDeeplinkRoute = (route: DeeplinkRoute) => {
    setCurrentNav(route.destination);
    if (route.taskId) setSelectedTaskId(route.taskId);
    if (route.channelId) setSelectedChannelId(route.channelId);
    if (route.meetingId) setSelectedMeetingId(route.meetingId);
  };

  useEffect(() => {
    const route = getCurrentLocationDeeplink();
    if (route) {
      applyDeeplinkRoute(route);
    }

    const onUrlChange = () => {
      const r = getCurrentLocationDeeplink();
      if (r) applyDeeplinkRoute(r);
    };

    window.addEventListener('popstate', onUrlChange);
    window.addEventListener('hashchange', onUrlChange);
    return () => {
      window.removeEventListener('popstate', onUrlChange);
      window.removeEventListener('hashchange', onUrlChange);
    };
  }, []);

  useEffect(() => {
    if (!user) return;
    const registerDevice = async () => {
      try {
        const token = localStorage.getItem('taskflow_web_device_token') || `web_${crypto.randomUUID()}`;
        localStorage.setItem('taskflow_web_device_token', token);
        await api.registerDeviceToken(token, 'web', 'production');
      } catch (err) {
        // non-fatal
      }
    };
    registerDevice();
  }, [user]);

  const handleNavigate = (nav: NavDestination, taskId?: string, channelId?: string, meetingId?: string) => {
    setCurrentNav(nav);
    setSelectedTaskId(taskId || null);
    setSelectedChannelId(channelId || null);
    setSelectedMeetingId(meetingId || null);
    syncUrlWithDestination({ destination: nav, taskId, channelId, meetingId });
  };

  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setShowOmnibar(prev => !prev);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const handleLoginSuccess = (user: UserDTO) => {
    setUser(user);
  };

  const handleLogout = () => {
    api.logout();
    setUser(null);
  };

  // Poll notifications every 3 seconds for incoming call alerts
  useEffect(() => {
    if (!user) return;

    const checkIncomingCalls = async () => {
      try {
        const notifications = await api.getNotifications();
        const callNotif = notifications.find(n => n.type === 'call.incoming' && !n.isRead);
        if (callNotif) {
          setIncomingCallNotification(callNotif);
        } else if (incomingCallNotification && notifications.every(n => n.id !== incomingCallNotification.id || n.isRead)) {
          setIncomingCallNotification(null);
        }
      } catch (err) {
        console.warn('Call notification check error:', err);
      }
    };

    checkIncomingCalls();
    const interval = setInterval(checkIncomingCalls, 3000);
    return () => clearInterval(interval);
  }, [user]);

  const handleAcceptCall = async () => {
    if (!incomingCallNotification) return;
    try {
      await api.markNotificationRead(incomingCallNotification.id);
      const convId = incomingCallNotification.callSessionId || incomingCallNotification.id;
      setActiveCallConvId(convId);
      setIncomingCallNotification(null);
    } catch (err) {
      console.error('Failed to accept call:', err);
    }
  };

  const handleDeclineCall = async () => {
    if (!incomingCallNotification) return;
    try {
      await api.markNotificationRead(incomingCallNotification.id);
    } catch (err) {
      console.warn('Failed to mark call notification read:', err);
    } finally {
      setIncomingCallNotification(null);
    }
  };

  if (!user) {
    return <AuthScreen onLoginSuccess={handleLoginSuccess} />;
  }

  return (
    <div className="flex flex-col h-screen w-screen bg-slate-950 text-slate-100 overflow-hidden font-sans relative">
      {/* Incoming Call Notification Banner */}
      {incomingCallNotification && (
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-50 w-full max-w-lg bg-slate-900/95 border-2 border-indigo-500/80 backdrop-blur-xl p-4 rounded-2xl shadow-2xl shadow-indigo-500/20 flex items-center justify-between gap-4 animate-bounce">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-gradient-to-tr from-indigo-600 to-purple-600 flex items-center justify-center text-white shadow-lg relative">
              <Video className="w-6 h-6 animate-pulse" />
              <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-emerald-500 border-2 border-slate-900 animate-ping" />
            </div>
            <div>
              <h4 className="text-sm font-bold text-slate-100 flex items-center gap-2">
                {incomingCallNotification.title || 'Incoming Video Call'}
              </h4>
              <p className="text-xs text-indigo-300 font-medium">
                {incomingCallNotification.body || `${incomingCallNotification.actorName || 'Team Member'} is calling you...`}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handleAcceptCall}
              className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs transition flex items-center gap-1.5 shadow-lg shadow-emerald-600/30"
            >
              <Video className="w-4 h-4" />
              Accept
            </button>
            <button
              onClick={handleDeclineCall}
              className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 font-semibold text-xs border border-slate-700 transition flex items-center gap-1"
            >
              <PhoneOff className="w-4 h-4 text-red-400" />
              Decline
            </button>
          </div>
        </div>
      )}

      {/* Workspace Header Topbar */}
      <WorkspaceHeader
        currentUser={user}
        onLogout={handleLogout}
        onProfileSaved={setUser}
        onOpenSyncCenter={() => setShowSyncCenter(true)}
        onOpenOmnibar={() => setShowOmnibar(true)}
        isLive={isOnline}
      />

      {/* Main Container with Sidebar + Content */}
      <div className="flex-1 flex overflow-hidden">
        {/* Sidebar Drawer */}
        <SidebarDrawer
          currentNav={currentNav}
          onNavigate={(nav) => handleNavigate(nav)}
          currentUser={user}
          onLogout={handleLogout}
        />

        {/* Dynamic Screen View */}
        <main className="flex-1 flex flex-col h-full overflow-hidden">
          {currentNav === 'all_tasks' && (
            <KanbanBoardScreen
              myTasksOnly={false}
              onNavigate={handleNavigate}
              initialTaskId={selectedTaskId}
              onCloseTaskDetail={() => {
                setSelectedTaskId(null);
                syncUrlWithDestination({ destination: 'all_tasks' });
              }}
            />
          )}
          {currentNav === 'my_tasks' && (
            <KanbanBoardScreen
              myTasksOnly={true}
              onNavigate={handleNavigate}
              initialTaskId={selectedTaskId}
              onCloseTaskDetail={() => {
                setSelectedTaskId(null);
                syncUrlWithDestination({ destination: 'my_tasks' });
              }}
            />
          )}
          {currentNav === 'backlog' && <BacklogScreen onNavigate={handleNavigate} />}
          {currentNav === 'releases' && <ReleaseManagementScreen onNavigate={handleNavigate} />}
          {currentNav === 'settings' && <ProjectSettingsScreen onNavigate={handleNavigate} />}
          {currentNav === 'integrations' && <IntegrationSettingsScreen onNavigate={handleNavigate} />}
          {currentNav === 'inbox' && <InboxScreen onNavigate={handleNavigate} />}
          {currentNav === 'messages' && (
            <ChatScreen
              onStartCall={(convId) => setActiveCallConvId(convId)}
              initialChannelId={selectedChannelId}
            />
          )}
          {currentNav === 'meetings' && (
            <MeetingsScreen
              onStartCall={(roomId) => setActiveCallConvId(roomId)}
              initialMeetingId={selectedMeetingId}
            />
          )}
          {currentNav === 'team' && <TeamScreen onNavigate={handleNavigate} />}
          {currentNav === 'billing' && <BillingScreen onNavigate={handleNavigate} />}
          {currentNav === 'productivity' && <ProductivityScreen />}
          {currentNav === 'sessions' && <SessionAuditScreen />}
        </main>
      </div>

      {/* Live In-Call Video Overlay */}
      {activeCallConvId && (
        <InCallScreen
          conversationId={activeCallConvId}
          onEndCall={() => setActiveCallConvId(null)}
        />
      )}

      {/* Sync Center Modal */}
      <SyncCenterModal
        isOpen={showSyncCenter}
        onClose={() => setShowSyncCenter(false)}
        isLive={isOnline}
      />

      {/* Enterprise Unified Omnibar Search (Cmd+K) & AI Copilot */}
      <OmnibarModal
        isOpen={showOmnibar}
        onClose={() => setShowOmnibar(false)}
        onSelectRoute={applyDeeplinkRoute}
      />
    </div>
  );
};

export default App;
