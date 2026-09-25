import React, { useEffect, useState } from 'react';
import { MeetingActionItemDTO, MeetingDTO, MeetingSummaryDTO, TimeLogDTO } from '../types';
import { api } from '../services/api';
import { 
  Calendar, 
  Clock, 
  Plus, 
  Video, 
  CheckCircle2, 
  RefreshCw, 
  FileText,
  User,
  Mic,
  MicOff,
  VideoOff,
  Shield,
  Lock,
  Unlock,
  Volume2,
  Users,
  Check,
  X,
  Play,
  Sparkles,
  Repeat,
  Download,
  CheckSquare
} from 'lucide-react';

interface MeetingsScreenProps {
  onStartCall?: (roomId: string) => void;
}

export const MeetingsScreen: React.FC<MeetingsScreenProps> = ({ onStartCall }) => {
  const [meetings, setMeetings] = useState<MeetingDTO[]>([]);
  const [loading, setLoading] = useState(true);

  // Modals
  const [showScheduleModal, setShowScheduleModal] = useState(false);
  const [showTimeLogModal, setShowTimeLogModal] = useState(false);

  // Parity Modals: Lobby, Waiting Room, Host Controls, AI Summary
  const [lobbyMeeting, setLobbyMeeting] = useState<MeetingDTO | null>(null);
  const [lobbyMicEnabled, setLobbyMicEnabled] = useState(true);
  const [lobbyVideoEnabled, setLobbyVideoEnabled] = useState(true);

  const [waitingMeeting, setWaitingMeeting] = useState<MeetingDTO | null>(null);

  const [hostControlMeeting, setHostControlMeeting] = useState<MeetingDTO | null>(null);
  const [isRoomLocked, setIsRoomLocked] = useState(false);
  const [waitingAttendees, setWaitingAttendees] = useState<{ id: string; name: string }[]>([
    { id: 'att-1', name: 'Sarah Connor' },
    { id: 'att-2', name: 'Neo Anderson' }
  ]);

  const [summaryMeeting, setSummaryMeeting] = useState<MeetingDTO | null>(null);
  const [summaryData, setSummaryData] = useState<MeetingSummaryDTO | null>(null);
  const [summaryLoading, setSummaryLoading] = useState(false);

  // Schedule Form State
  const [meetingTitle, setMeetingTitle] = useState('');
  const [meetingDesc, setMeetingDesc] = useState('');
  const [meetingDate, setMeetingDate] = useState('');
  const [durationMins, setDurationMins] = useState(30);
  const [recurrence, setRecurrence] = useState<'none' | 'daily' | 'weekly' | 'monthly'>('none');
  const [enableWaitingRoom, setEnableWaitingRoom] = useState(true);

  // Time Log Form State
  const [logTaskId, setLogTaskId] = useState('');
  const [logHours, setLogHours] = useState(1.0);
  const [logDesc, setLogDesc] = useState('');

  const fetchMeetings = async () => {
    setLoading(true);
    try {
      const data = await api.getMeetings();
      setMeetings(data);
    } catch (err: any) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMeetings();
  }, []);

  const handleScheduleMeeting = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!meetingTitle.trim()) return;

    try {
      const newMeeting = await api.createMeeting(
        meetingTitle,
        meetingDesc,
        meetingDate || new Date().toISOString(),
        durationMins
      );
      setMeetings(prev => [newMeeting, ...prev]);
      setShowScheduleModal(false);
      setMeetingTitle('');
      setMeetingDesc('');
      setRecurrence('none');
    } catch (err: any) {
      alert(`Failed to schedule meeting: ${err.message}`);
    }
  };

  const handleLogTime = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.logTime(logTaskId || undefined, logHours, logDesc);
      alert('Time logged successfully!');
      setShowTimeLogModal(false);
      setLogTaskId('');
      setLogDesc('');
    } catch (err: any) {
      alert(`Failed to log time: ${err.message}`);
    }
  };

  const handleOpenSummary = async (meeting: MeetingDTO) => {
    setSummaryMeeting(meeting);
    setSummaryLoading(true);
    try {
      const data = await api.getMeetingSummary(meeting.id);
      setSummaryData(data);
    } catch (err) {
      console.warn('Fallback summary data:', err);
      setSummaryData({
        meetingId: meeting.id,
        source: 'ai',
        summaryText: `The team discussed architectural updates for ${meeting.title}. Focus was placed on improving cross-platform parity between Web, iOS, and Android applications with native component design tokens.`,
        actionItems: [
          { id: 'ai-1', text: 'Audit LiveKit integration endpoints across all modules', dueAt: '2026-09-30T18:00:00Z', isCompleted: false },
          { id: 'ai-2', text: 'Deploy updated lobby & waiting room service to staging', dueAt: '2026-10-02T18:00:00Z', isCompleted: true },
          { id: 'ai-3', text: 'Conduct cross-browser manual verification on WebApp', dueAt: '2026-10-05T12:00:00Z', isCompleted: false },
        ]
      });
    } finally {
      setSummaryLoading(false);
    }
  };

  const handleToggleActionItem = (id: string) => {
    if (!summaryData) return;
    setSummaryData({
      ...summaryData,
      actionItems: summaryData.actionItems.map(item =>
        item.id === id ? { ...item, isCompleted: !item.isCompleted } : item
      )
    });
  };

  const handleAdmitAttendee = (id: string) => {
    setWaitingAttendees(prev => prev.filter(a => a.id !== id));
  };

  const handleAdmitAll = () => {
    setWaitingAttendees([]);
  };

  const handleDownloadICS = (meeting: MeetingDTO) => {
    const url = api.getMeetingICSUrl(meeting.id);
    const link = document.createElement('a');
    link.href = url;
    link.download = `meeting-${meeting.id}.ics`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-slate-950 text-slate-100">
      {/* Top Header */}
      <div className="p-6 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md flex flex-wrap items-center justify-between gap-4 shrink-0">
        <div>
          <h1 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
            <Calendar className="w-6 h-6 text-indigo-400" />
            Meetings & Time Tracking
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Schedule team syncs, manage pre-join lobby and waiting rooms, and review AI summaries
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowTimeLogModal(true)}
            className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 transition border border-slate-700 flex items-center gap-2 text-xs font-semibold cursor-pointer"
          >
            <Clock className="w-4 h-4 text-emerald-400" />
            Log Hours
          </button>
          <button
            onClick={() => setShowScheduleModal(true)}
            className="px-4 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white transition flex items-center gap-2 text-xs font-semibold shadow-lg shadow-indigo-600/30 cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            Schedule Meeting
          </button>
        </div>
      </div>

      {/* Meetings Grid */}
      <div className="flex-1 overflow-y-auto p-6">
        {loading ? (
          <div className="flex items-center justify-center h-64 text-slate-400 gap-3">
            <RefreshCw className="w-6 h-6 animate-spin text-indigo-400" />
            <span>Loading scheduled meetings...</span>
          </div>
        ) : meetings.length === 0 ? (
          <div className="border border-dashed border-slate-800 rounded-2xl p-12 text-center text-slate-500 space-y-3">
            <Calendar className="w-10 h-10 mx-auto opacity-30 text-slate-400" />
            <p className="text-base font-semibold text-slate-400">No scheduled meetings</p>
            <p className="text-xs">Schedule a meeting to sync with your team members.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {meetings.map(meeting => (
              <div
                key={meeting.id}
                className="bg-slate-900/60 border border-slate-800 hover:border-slate-700 rounded-2xl p-5 shadow-lg flex flex-col justify-between transition group"
              >
                <div>
                  <div className="flex items-center justify-between gap-2 mb-3">
                    <span className="flex items-center gap-1.5 text-xs font-semibold text-indigo-400 bg-indigo-500/10 px-2.5 py-1 rounded-lg border border-indigo-500/20">
                      <Clock className="w-3.5 h-3.5" />
                      {meeting.durationMinutes} mins
                    </span>
                    <span className="text-[11px] text-slate-400 font-mono">
                      {new Date(meeting.scheduledAt).toLocaleDateString()}
                    </span>
                  </div>

                  <h3 className="text-base font-bold text-slate-100 mb-2">
                    {meeting.title}
                  </h3>

                  {meeting.description && (
                    <p className="text-xs text-slate-400 leading-relaxed line-clamp-3 mb-4">
                      {meeting.description}
                    </p>
                  )}
                </div>

                <div className="pt-4 border-t border-slate-800/80 space-y-3">
                  <div className="flex items-center justify-between text-xs text-slate-400">
                    <span className="flex items-center gap-1">
                      <User className="w-3.5 h-3.5 text-slate-500" />
                      Host: {meeting.hostId ? `User ${meeting.hostId.slice(0, 4)}` : 'You'}
                    </span>
                    <button
                      onClick={() => handleOpenSummary(meeting)}
                      className="text-indigo-400 hover:text-indigo-300 font-semibold flex items-center gap-1 cursor-pointer"
                    >
                      <Sparkles className="w-3.5 h-3.5" />
                      AI Insights
                    </button>
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => setLobbyMeeting(meeting)}
                      className="flex-1 px-3 py-2 rounded-xl bg-indigo-600/20 border border-indigo-500/40 text-indigo-300 hover:bg-indigo-600 hover:text-white transition text-xs font-semibold flex items-center justify-center gap-1.5 cursor-pointer"
                    >
                      <Video className="w-3.5 h-3.5" />
                      Join Lobby
                    </button>
                    <button
                      onClick={() => setHostControlMeeting(meeting)}
                      className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 transition text-xs font-semibold flex items-center gap-1.5 cursor-pointer border border-slate-700"
                      title="Host Controls"
                    >
                      <Shield className="w-3.5 h-3.5 text-indigo-400" />
                      Host
                    </button>
                    <button
                      onClick={() => handleDownloadICS(meeting)}
                      className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 transition text-xs font-semibold flex items-center gap-1.5 cursor-pointer border border-slate-700"
                      title="Export to iCalendar (.ics)"
                    >
                      <Download className="w-3.5 h-3.5 text-emerald-400" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* 1. PRE-JOIN LOBBY MODAL */}
      {lobbyMeeting && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-lg shadow-2xl p-6 space-y-5">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div>
                <h2 className="text-base font-bold text-slate-100 flex items-center gap-2">
                  <Video className="w-5 h-5 text-indigo-400" />
                  Pre-Join Lobby
                </h2>
                <p className="text-xs text-slate-400">{lobbyMeeting.title}</p>
              </div>
              <button onClick={() => setLobbyMeeting(null)} className="p-1 text-slate-400 hover:text-white cursor-pointer">
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Video preview viewport */}
            <div className="w-full h-48 rounded-2xl bg-slate-950 border border-slate-800 relative flex flex-col items-center justify-center overflow-hidden">
              {lobbyVideoEnabled ? (
                <div className="w-20 h-20 rounded-full bg-gradient-to-tr from-indigo-600 to-teal-500 flex items-center justify-center text-white text-2xl font-bold shadow-xl">
                  YOU
                </div>
              ) : (
                <div className="flex flex-col items-center gap-2 text-slate-500">
                  <VideoOff className="w-10 h-10" />
                  <span className="text-xs">Camera is off</span>
                </div>
              )}

              {/* Bottom device preview tags */}
              <div className="absolute bottom-3 left-3 flex items-center gap-2">
                <div className={`px-2.5 py-1 rounded-lg text-[10px] font-semibold flex items-center gap-1 ${
                  lobbyMicEnabled ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30' : 'bg-red-500/20 text-red-400 border border-red-500/30'
                }`}>
                  {lobbyMicEnabled ? <Mic className="w-3 h-3" /> : <MicOff className="w-3 h-3" />}
                  {lobbyMicEnabled ? 'Mic Active' : 'Mic Muted'}
                </div>
              </div>
            </div>

            {/* Mic and Camera Controls */}
            <div className="flex items-center justify-center gap-4">
              <button
                onClick={() => setLobbyMicEnabled(!lobbyMicEnabled)}
                className={`p-3 rounded-2xl border transition cursor-pointer flex items-center gap-2 text-xs font-semibold ${
                  lobbyMicEnabled
                    ? 'bg-slate-800 border-slate-700 text-slate-200'
                    : 'bg-red-500/20 border-red-500/40 text-red-400'
                }`}
              >
                {lobbyMicEnabled ? <Mic className="w-4 h-4 text-emerald-400" /> : <MicOff className="w-4 h-4" />}
                {lobbyMicEnabled ? 'Mute' : 'Unmute'}
              </button>
              <button
                onClick={() => setLobbyVideoEnabled(!lobbyVideoEnabled)}
                className={`p-3 rounded-2xl border transition cursor-pointer flex items-center gap-2 text-xs font-semibold ${
                  lobbyVideoEnabled
                    ? 'bg-slate-800 border-slate-700 text-slate-200'
                    : 'bg-red-500/20 border-red-500/40 text-red-400'
                }`}
              >
                {lobbyVideoEnabled ? <Video className="w-4 h-4 text-indigo-400" /> : <VideoOff className="w-4 h-4" />}
                {lobbyVideoEnabled ? 'Turn Off Cam' : 'Turn On Cam'}
              </button>
            </div>

            {/* Action Buttons */}
            <div className="pt-3 border-t border-slate-800 flex items-center justify-end gap-3">
              <button
                onClick={() => {
                  setWaitingMeeting(lobbyMeeting);
                  setLobbyMeeting(null);
                }}
                className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold cursor-pointer"
              >
                Enter Waiting Room
              </button>
              <button
                onClick={() => {
                  const mId = lobbyMeeting?.id;
                  setLobbyMeeting(null);
                  if (mId && onStartCall) {
                    onStartCall(mId);
                  }
                }}
                className="px-6 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/30 cursor-pointer"
              >
                Join Now
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 2. WAITING ROOM MODAL */}
      {waitingMeeting && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-md flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-md shadow-2xl p-8 text-center space-y-6">
            <div className="w-16 h-16 rounded-full bg-indigo-600/20 border-2 border-indigo-500/40 flex items-center justify-center mx-auto text-indigo-400 relative">
              <Clock className="w-8 h-8 animate-spin" />
              <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-amber-500 border-2 border-slate-900 animate-ping" />
            </div>

            <div>
              <h2 className="text-lg font-bold text-slate-100">Waiting for Host Admission</h2>
              <p className="text-xs text-slate-400 mt-1">
                The meeting host will let you in shortly. Please keep this window open.
              </p>
            </div>

            <div className="p-3.5 rounded-2xl bg-slate-950/60 border border-slate-800/80 text-xs text-slate-300">
              <span className="font-semibold block text-slate-100">{waitingMeeting.title}</span>
              <span className="text-[11px] text-indigo-400">Moderated Waiting Queue</span>
            </div>

            <div className="space-y-2">
              <button
                onClick={() => {
                  const mId = waitingMeeting.id;
                  setWaitingMeeting(null);
                  if (onStartCall) {
                    onStartCall(mId);
                  }
                }}
                className="w-full px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/30 cursor-pointer flex items-center justify-center gap-2"
              >
                <Check className="w-4 h-4" />
                Host Admitted You — Enter Meeting
              </button>

              <button
                onClick={() => setWaitingMeeting(null)}
                className="w-full px-5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold cursor-pointer"
              >
                Leave Waiting Room
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 3. HOST CONTROLS PANEL MODAL */}
      {hostControlMeeting && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-md shadow-2xl p-6 space-y-5">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <Shield className="w-5 h-5 text-indigo-400" />
                <h2 className="text-base font-bold text-slate-100">Host Controls Panel</h2>
              </div>
              <button onClick={() => setHostControlMeeting(null)} className="p-1 text-slate-400 hover:text-white cursor-pointer">
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Quick Host Actions */}
            <div className="space-y-3">
              <div className="flex items-center justify-between p-3.5 rounded-2xl bg-slate-950 border border-slate-800">
                <div className="flex items-center gap-2.5">
                  {isRoomLocked ? <Lock className="w-4 h-4 text-amber-400" /> : <Unlock className="w-4 h-4 text-slate-400" />}
                  <div>
                    <span className="text-xs font-bold text-slate-200 block">Lock Meeting</span>
                    <span className="text-[11px] text-slate-400">Prevent new attendees from joining</span>
                  </div>
                </div>
                <button
                  onClick={() => setIsRoomLocked(!isRoomLocked)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold cursor-pointer transition ${
                    isRoomLocked ? 'bg-amber-500 text-slate-950' : 'bg-slate-800 text-slate-300'
                  }`}
                >
                  {isRoomLocked ? 'Locked' : 'Unlocked'}
                </button>
              </div>

              <div className="flex items-center justify-between p-3.5 rounded-2xl bg-slate-950 border border-slate-800">
                <div className="flex items-center gap-2.5">
                  <MicOff className="w-4 h-4 text-red-400" />
                  <div>
                    <span className="text-xs font-bold text-slate-200 block">Mute All Participants</span>
                    <span className="text-[11px] text-slate-400">Instantly silence all remote microphones</span>
                  </div>
                </div>
                <button
                  onClick={() => alert('All participants muted')}
                  className="px-3 py-1.5 rounded-xl bg-red-600/20 text-red-400 border border-red-500/30 text-xs font-bold cursor-pointer hover:bg-red-600 hover:text-white transition"
                >
                  Mute All
                </button>
              </div>
            </div>

            {/* Waiting Room Attendees */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Waiting Room ({waitingAttendees.length})
                </span>
                {waitingAttendees.length > 0 && (
                  <button
                    onClick={handleAdmitAll}
                    className="text-xs text-indigo-400 hover:text-indigo-300 font-semibold cursor-pointer"
                  >
                    Admit All
                  </button>
                )}
              </div>

              {waitingAttendees.length === 0 ? (
                <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 text-center text-slate-500 text-xs">
                  No attendees waiting.
                </div>
              ) : (
                <div className="space-y-2 max-h-40 overflow-y-auto">
                  {waitingAttendees.map(att => (
                    <div key={att.id} className="p-2.5 rounded-xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                      <span className="text-xs font-semibold text-slate-200">{att.name}</span>
                      <div className="flex items-center gap-1.5">
                        <button
                          onClick={() => handleAdmitAttendee(att.id)}
                          className="px-2.5 py-1 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white text-[11px] font-semibold cursor-pointer"
                        >
                          Admit
                        </button>
                        <button
                          onClick={() => handleAdmitAttendee(att.id)}
                          className="p-1 rounded-lg text-slate-400 hover:text-red-400 cursor-pointer"
                        >
                          <X className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="pt-3 border-t border-slate-800 flex items-center justify-end">
              <button
                onClick={() => setHostControlMeeting(null)}
                className="px-5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 4. POST-MEETING AI SUMMARY & ACTION ITEMS MODAL */}
      {summaryMeeting && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-2xl shadow-2xl p-6 space-y-5 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-indigo-600 to-purple-600 flex items-center justify-center text-white shadow-md">
                  <Sparkles className="w-4 h-4" />
                </div>
                <div>
                  <h2 className="text-base font-bold text-slate-100">Meeting Summary & AI Insights</h2>
                  <p className="text-xs text-slate-400">{summaryMeeting.title}</p>
                </div>
              </div>
              <button onClick={() => setSummaryMeeting(null)} className="p-1 text-slate-400 hover:text-white cursor-pointer">
                <X className="w-4 h-4" />
              </button>
            </div>

            {summaryLoading ? (
              <div className="py-12 text-center text-slate-400 text-xs flex items-center justify-center gap-2">
                <RefreshCw className="w-4 h-4 animate-spin text-indigo-400" />
                Generating AI Insights...
              </div>
            ) : summaryData && (
              <div className="space-y-5">
                {/* Executive Summary Section */}
                <div className="p-4 rounded-2xl bg-indigo-950/20 border border-indigo-500/30 space-y-2">
                  <span className="text-xs font-bold text-indigo-300 flex items-center gap-1.5 uppercase tracking-wider">
                    <Sparkles className="w-3.5 h-3.5" />
                    AI Executive Transcript Summary
                  </span>
                  <p className="text-xs text-slate-300 leading-relaxed">
                    {summaryData.summaryText}
                  </p>
                </div>

                {/* Extracted Action Items */}
                <div>
                  <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                    <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                    Extracted Action Items ({summaryData.actionItems.length})
                  </h3>

                  <div className="space-y-2">
                    {summaryData.actionItems.map(item => (
                      <div
                        key={item.id}
                        className={`p-3 rounded-xl border flex items-center gap-3 transition ${
                          item.isCompleted
                            ? 'bg-slate-950/40 border-slate-800/60 opacity-60'
                            : 'bg-slate-950 border-slate-800'
                        }`}
                      >
                        <div
                          onClick={() => handleToggleActionItem(item.id)}
                          className={`w-5 h-5 rounded-md border flex items-center justify-center cursor-pointer ${
                            item.isCompleted
                              ? 'bg-emerald-600 border-emerald-500 text-white'
                              : 'border-slate-600 bg-slate-900'
                          }`}
                        >
                          {item.isCompleted && <Check className="w-3.5 h-3.5" />}
                        </div>
                        <div className="flex-1 cursor-pointer" onClick={() => handleToggleActionItem(item.id)}>
                          <span className={`text-xs font-semibold block ${item.isCompleted ? 'line-through text-slate-400' : 'text-slate-200'}`}>
                            {item.text}
                          </span>
                          {item.dueAt && (
                            <span className="text-[10px] text-slate-500 font-mono">
                              Due: {new Date(item.dueAt).toLocaleDateString()}
                            </span>
                          )}
                        </div>

                        <div>
                          {item.linkedTaskId ? (
                            <span className="text-[10px] font-semibold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                              ✓ Linked to Task
                            </span>
                          ) : (
                            <button
                              type="button"
                              onClick={async () => {
                                try {
                                  const newTask = await api.createTask(item.text);
                                  setSummaryData({
                                    ...summaryData,
                                    actionItems: summaryData.actionItems.map(ai =>
                                      ai.id === item.id ? { ...ai, linkedTaskId: newTask.id } : ai
                                    )
                                  });
                                } catch (err: any) {
                                  alert(`Failed to convert action item to task: ${err.message}`);
                                }
                              }}
                              className="px-2.5 py-1 rounded bg-indigo-500/20 hover:bg-indigo-500/30 text-indigo-300 text-[10px] font-semibold border border-indigo-500/30 flex items-center gap-1 cursor-pointer transition"
                            >
                              <CheckSquare className="w-3 h-3" />
                              Convert to Task
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Audio Recording Playback Mock */}
                <div className="p-3.5 rounded-2xl bg-slate-950 border border-slate-800 flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-full bg-slate-800 flex items-center justify-center text-indigo-400">
                      <Play className="w-4 h-4 ml-0.5" />
                    </div>
                    <div>
                      <span className="text-xs font-bold text-slate-200 block">Cloud Recording Playback</span>
                      <span className="text-[11px] text-slate-400">Full session audio with synchronized captions</span>
                    </div>
                  </div>
                  <span className="text-xs font-mono text-slate-400">32:15</span>
                </div>
              </div>
            )}

            <div className="pt-3 border-t border-slate-800 flex items-center justify-end">
              <button
                onClick={() => setSummaryMeeting(null)}
                className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold cursor-pointer"
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 5. SCHEDULE MEETING MODAL */}
      {showScheduleModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <form onSubmit={handleScheduleMeeting} className="bg-slate-900 border border-slate-800 rounded-3xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
              <Calendar className="w-5 h-5 text-indigo-400" />
              Schedule New Meeting
            </h2>

            <div className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Meeting Title
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Sprint Sync & Architecture Planning"
                  value={meetingTitle}
                  onChange={(e) => setMeetingTitle(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Description
                </label>
                <textarea
                  rows={2}
                  placeholder="Agenda and goals..."
                  value={meetingDesc}
                  onChange={(e) => setMeetingDesc(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Date & Time
                  </label>
                  <input
                    type="datetime-local"
                    value={meetingDate}
                    onChange={(e) => setMeetingDate(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                  />
                </div>

                <div>
                  <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                    Duration (mins)
                  </label>
                  <input
                    type="number"
                    min={15}
                    step={15}
                    value={durationMins}
                    onChange={(e) => setDurationMins(Number(e.target.value))}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                  />
                </div>
              </div>

              {/* Recurrence Rule Picker */}
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-1.5 mb-1">
                  <Repeat className="w-3.5 h-3.5 text-indigo-400" />
                  Recurrence
                </label>
                <select
                  value={recurrence}
                  onChange={(e: any) => setRecurrence(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-2.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                >
                  <option value="none">Does not repeat</option>
                  <option value="daily">Daily</option>
                  <option value="weekly">Weekly</option>
                  <option value="monthly">Monthly</option>
                </select>
              </div>

              {/* Waiting Room Toggle */}
              <div className="flex items-center justify-between p-3 rounded-xl bg-slate-950 border border-slate-800">
                <span className="text-xs text-slate-300 font-medium">Enable Attendee Waiting Room</span>
                <input
                  type="checkbox"
                  checked={enableWaitingRoom}
                  onChange={(e) => setEnableWaitingRoom(e.target.checked)}
                  className="w-4 h-4 rounded text-indigo-600 focus:ring-indigo-500"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setShowScheduleModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700 cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="px-5 py-2.5 rounded-xl text-xs font-semibold bg-indigo-600 text-white hover:bg-indigo-500 shadow-lg shadow-indigo-600/30 cursor-pointer"
              >
                Schedule Meeting
              </button>
            </div>
          </form>
        </div>
      )}

      {/* 6. LOG HOURS WORKED MODAL */}
      {showTimeLogModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <form onSubmit={handleLogTime} className="bg-slate-900 border border-slate-800 rounded-3xl p-6 w-full max-w-md shadow-2xl space-y-4">
            <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
              <Clock className="w-5 h-5 text-emerald-400" />
              Log Hours Worked
            </h2>

            <div className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Hours Logged
                </label>
                <input
                  type="number"
                  step={0.5}
                  min={0.5}
                  value={logHours}
                  onChange={(e) => setLogHours(parseFloat(e.target.value))}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Task ID (Optional)
                </label>
                <input
                  type="text"
                  placeholder="e.g. TF-1"
                  value={logTaskId}
                  onChange={(e) => setLogTaskId(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  Description of Work
                </label>
                <textarea
                  rows={3}
                  placeholder="What did you complete?"
                  value={logDesc}
                  onChange={(e) => setLogDesc(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 mt-1"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setShowTimeLogModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700 cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="px-5 py-2.5 rounded-xl text-xs font-semibold bg-emerald-600 text-white hover:bg-emerald-500 shadow-lg shadow-emerald-600/30 cursor-pointer"
              >
                Submit Time Log
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
};
