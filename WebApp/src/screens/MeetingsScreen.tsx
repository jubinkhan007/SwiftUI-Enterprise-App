import React, { useEffect, useState } from 'react';
import { MeetingDTO, TimeLogDTO } from '../types';
import { api } from '../services/api';
import { 
  Calendar, 
  Clock, 
  Plus, 
  Video, 
  CheckCircle2, 
  RefreshCw, 
  FileText,
  User
} from 'lucide-react';

export const MeetingsScreen: React.FC = () => {
  const [meetings, setMeetings] = useState<MeetingDTO[]>([]);
  const [loading, setLoading] = useState(true);

  // Modals
  const [showScheduleModal, setShowScheduleModal] = useState(false);
  const [showTimeLogModal, setShowTimeLogModal] = useState(false);

  // Schedule Form State
  const [meetingTitle, setMeetingTitle] = useState('');
  const [meetingDesc, setMeetingDesc] = useState('');
  const [meetingDate, setMeetingDate] = useState('');
  const [durationMins, setDurationMins] = useState(30);

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

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-slate-950 text-slate-100">
      {/* Top Header */}
      <div className="p-6 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-100 flex items-center gap-2">
            <Calendar className="w-6 h-6 text-indigo-400" />
            Meetings & Time Tracking
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Schedule team syncs and log work hours directly to tasks
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowTimeLogModal(true)}
            className="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 transition border border-slate-700 flex items-center gap-2 text-xs font-semibold"
          >
            <Clock className="w-4 h-4 text-emerald-400" />
            Log Hours
          </button>
          <button
            onClick={() => setShowScheduleModal(true)}
            className="px-4 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white transition flex items-center gap-2 text-xs font-semibold shadow-lg shadow-indigo-600/30"
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

                <div className="pt-4 border-t border-slate-800/80 flex items-center justify-between">
                  <span className="text-xs text-slate-400 flex items-center gap-1">
                    <User className="w-3.5 h-3.5" />
                    Host: {meeting.hostId ? `User ${meeting.hostId.slice(0, 4)}` : 'You'}
                  </span>

                  {meeting.meetingUrl && (
                    <a
                      href={meeting.meetingUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="px-3 py-1.5 rounded-xl bg-indigo-600/20 border border-indigo-500/40 text-indigo-300 hover:bg-indigo-600 hover:text-white transition text-xs font-semibold flex items-center gap-1.5"
                    >
                      <Video className="w-3.5 h-3.5" />
                      Join Video
                    </a>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Schedule Meeting Modal */}
      {showScheduleModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <form onSubmit={handleScheduleMeeting} className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
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
                  rows={3}
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
            </div>

            <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
              <button
                type="button"
                onClick={() => setShowScheduleModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="px-4 py-2 rounded-xl text-xs font-semibold bg-indigo-600 text-white hover:bg-indigo-500 shadow-lg shadow-indigo-600/30"
              >
                Schedule Meeting
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Log Hours Worked Modal */}
      {showTimeLogModal && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <form onSubmit={handleLogTime} className="bg-slate-900 border border-slate-800 rounded-2xl p-6 w-full max-w-md shadow-2xl space-y-4">
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
                className="px-4 py-2 rounded-xl text-xs font-medium bg-slate-800 text-slate-300 hover:bg-slate-700"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="px-4 py-2 rounded-xl text-xs font-semibold bg-emerald-600 text-white hover:bg-emerald-500 shadow-lg shadow-emerald-600/30"
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
