import React, { useState, useEffect } from 'react';
import { 
  Mic, 
  MicOff, 
  Video as VideoIcon, 
  VideoOff, 
  PhoneOff, 
  Monitor, 
  Users, 
  ShieldCheck, 
  Lock, 
  Unlock, 
  X, 
  Shield, 
  UserMinus, 
  Radio
} from 'lucide-react';
import { CallParticipantDTO } from '../types';

interface InCallScreenProps {
  conversationId: string;
  onEndCall: () => void;
}

export const InCallScreen: React.FC<InCallScreenProps> = ({ conversationId, onEndCall }) => {
  const [isMuted, setIsMuted] = useState(false);
  const [isVideoOff, setIsVideoOff] = useState(false);
  const [isScreenSharing, setIsScreenSharing] = useState(false);
  const [callDurationSeconds, setCallDurationSeconds] = useState(0);

  // Parity State: Adaptive Participants & Host Moderation
  const [participants, setParticipants] = useState<CallParticipantDTO[]>([
    {
      id: 'cp-self',
      userId: 'user-me',
      displayName: 'You (Host)',
      role: 'host',
      isAudioMuted: false,
      isVideoMuted: false,
      isScreenSharing: false,
      isSpeaking: false,
    },
    {
      id: 'cp-1',
      userId: 'user-a',
      displayName: 'Alice Owner',
      role: 'host',
      isAudioMuted: false,
      isVideoMuted: false,
      isScreenSharing: false,
      isSpeaking: true,
    },
    {
      id: 'cp-2',
      userId: 'user-b',
      displayName: 'Sarah Connor',
      role: 'participant',
      isAudioMuted: true,
      isVideoMuted: false,
      isScreenSharing: false,
      isSpeaking: false,
    },
  ]);

  const [showHostControls, setShowHostControls] = useState(false);
  const [isRoomLocked, setIsRoomLocked] = useState(false);

  useEffect(() => {
    const timer = setInterval(() => {
      setCallDurationSeconds(prev => prev + 1);
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const formatTimer = (totalSeconds: number) => {
    const mins = Math.floor(totalSeconds / 60);
    const secs = totalSeconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const handleToggleMic = () => {
    setIsMuted(!isMuted);
    setParticipants(prev =>
      prev.map(p => (p.id === 'cp-self' ? { ...p, isAudioMuted: !isMuted } : p))
    );
  };

  const handleToggleVideo = () => {
    setIsVideoOff(!isVideoOff);
    setParticipants(prev =>
      prev.map(p => (p.id === 'cp-self' ? { ...p, isVideoMuted: !isVideoOff } : p))
    );
  };

  const handleToggleScreenShare = () => {
    setIsScreenSharing(!isScreenSharing);
    setParticipants(prev =>
      prev.map(p => (p.id === 'cp-self' ? { ...p, isScreenSharing: !isScreenSharing } : p))
    );
  };

  const handleRemoteMuteAudio = (participantId: string) => {
    setParticipants(prev =>
      prev.map(p => (p.id === participantId ? { ...p, isAudioMuted: true } : p))
    );
  };

  const handleRemoteMuteVideo = (participantId: string) => {
    setParticipants(prev =>
      prev.map(p => (p.id === participantId ? { ...p, isVideoMuted: true } : p))
    );
  };

  const handleToggleRole = (participantId: string) => {
    setParticipants(prev =>
      prev.map(p =>
        p.id === participantId
          ? { ...p, role: p.role === 'presenter' ? 'participant' : 'presenter' }
          : p
      )
    );
  };

  const handleEjectParticipant = (participantId: string) => {
    setParticipants(prev => prev.filter(p => p.id !== participantId));
  };

  // Adaptive Grid Column Sizing matching iOS & Android
  const gridColsClass =
    participants.length <= 1
      ? 'grid-cols-1 max-w-2xl'
      : participants.length <= 4
      ? 'grid-cols-1 md:grid-cols-2 max-w-5xl'
      : 'grid-cols-1 md:grid-cols-2 lg:grid-cols-3 max-w-6xl';

  return (
    <div className="fixed inset-0 z-50 bg-slate-950/95 backdrop-blur-xl flex flex-col items-center justify-between p-6">
      {/* Top Header */}
      <div className="w-full max-w-6xl flex items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <div className="w-3.5 h-3.5 rounded-full bg-emerald-500 animate-ping" />
          <div>
            <h2 className="text-base font-bold text-slate-100 flex items-center gap-2">
              LiveKit Encrypted Room
              <span className="text-xs font-mono font-semibold bg-emerald-500/20 text-emerald-300 px-2.5 py-0.5 rounded-full border border-emerald-500/30">
                {formatTimer(callDurationSeconds)}
              </span>
              {isRoomLocked && (
                <span className="text-xs font-semibold bg-amber-500/20 text-amber-300 px-2 py-0.5 rounded-full border border-amber-500/30 flex items-center gap-1">
                  <Lock className="w-3 h-3" /> Locked
                </span>
              )}
            </h2>
            <p className="text-xs text-slate-400">
              WebRTC Audio & HD Video Bridge
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 bg-slate-900/80 border border-slate-800 px-3.5 py-1.5 rounded-xl text-xs text-slate-300">
          <Users className="w-4 h-4 text-indigo-400" />
          <span className="font-semibold">{participants.length} Active Participants</span>
        </div>
      </div>

      {/* Adaptive Video Participant Grid */}
      <div className={`w-full flex-1 my-6 grid gap-6 items-center justify-center overflow-y-auto ${gridColsClass}`}>
        {participants.map(p => {
          const initials = p.displayName.slice(0, 2).toUpperCase();
          return (
            <div
              key={p.id}
              className={`aspect-video bg-slate-900/90 rounded-3xl relative overflow-hidden flex flex-col items-center justify-center shadow-2xl transition duration-200 ${
                p.isSpeaking
                  ? 'border-2 border-emerald-500 shadow-emerald-500/20 shadow-xl'
                  : 'border border-slate-800'
              }`}
            >
              {p.isVideoMuted ? (
                <div className="flex flex-col items-center gap-2 text-slate-500">
                  <div className="w-20 h-20 rounded-full bg-slate-800 flex items-center justify-center text-xl font-bold text-slate-400">
                    {initials}
                  </div>
                  <span className="text-xs">Camera turned off</span>
                </div>
              ) : (
                <div className="flex flex-col items-center">
                  <div className="w-20 h-20 rounded-full bg-gradient-to-tr from-indigo-600 to-purple-600 flex items-center justify-center text-white text-2xl font-bold shadow-xl border-4 border-slate-800">
                    {initials}
                  </div>
                </div>
              )}

              {/* Bottom-left display name pill */}
              <div className="absolute bottom-3 left-3 bg-slate-950/80 backdrop-blur-md px-3 py-1 rounded-xl border border-slate-800 flex items-center gap-1.5 text-xs font-semibold text-slate-200">
                <span>{p.displayName}</span>
                {p.role === 'host' && (
                  <span className="text-[10px] px-1.5 py-0.2 rounded bg-indigo-500/20 text-indigo-300 font-bold">
                    HOST
                  </span>
                )}
                {p.role === 'presenter' && (
                  <span className="text-[10px] px-1.5 py-0.2 rounded bg-amber-500/20 text-amber-300 font-bold">
                    PRESENTER
                  </span>
                )}
              </div>

              {/* Top-right status pills */}
              <div className="absolute top-3 right-3 flex items-center gap-1.5">
                {p.isSpeaking && (
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500 text-slate-950 flex items-center gap-1 animate-pulse">
                    <Radio className="w-3 h-3" /> Speaking
                  </span>
                )}
                {p.isAudioMuted && (
                  <div className="bg-red-500/20 text-red-400 border border-red-500/30 p-1.5 rounded-lg">
                    <MicOff className="w-3.5 h-3.5" />
                  </div>
                )}
                {p.isScreenSharing && (
                  <div className="bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 p-1.5 rounded-lg">
                    <Monitor className="w-3.5 h-3.5" />
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Floating In-Call Controls Dock */}
      <div className="flex items-center gap-3 bg-slate-900/90 border border-slate-800 p-3 rounded-2xl shadow-2xl backdrop-blur-xl shrink-0">
        <button
          onClick={handleToggleMic}
          className={`p-3.5 rounded-xl border transition cursor-pointer ${
            isMuted
              ? 'bg-red-500/20 border-red-500/40 text-red-400'
              : 'bg-slate-800 border-slate-700 text-slate-200 hover:bg-slate-700'
          }`}
          title={isMuted ? 'Unmute microphone' : 'Mute microphone'}
        >
          {isMuted ? <MicOff className="w-5 h-5" /> : <Mic className="w-5 h-5" />}
        </button>

        <button
          onClick={handleToggleVideo}
          className={`p-3.5 rounded-xl border transition cursor-pointer ${
            isVideoOff
              ? 'bg-red-500/20 border-red-500/40 text-red-400'
              : 'bg-slate-800 border-slate-700 text-slate-200 hover:bg-slate-700'
          }`}
          title={isVideoOff ? 'Turn on camera' : 'Turn off camera'}
        >
          {isVideoOff ? <VideoOff className="w-5 h-5" /> : <VideoIcon className="w-5 h-5" />}
        </button>

        <button
          onClick={handleToggleScreenShare}
          className={`p-3.5 rounded-xl border transition cursor-pointer ${
            isScreenSharing
              ? 'bg-indigo-600 text-white border-indigo-500'
              : 'bg-slate-800 border-slate-700 text-slate-200 hover:bg-slate-700'
          }`}
          title="Share Screen"
        >
          <Monitor className="w-5 h-5" />
        </button>

        {/* Host Controls Toggle */}
        <button
          onClick={() => setShowHostControls(!showHostControls)}
          className={`p-3.5 rounded-xl border transition cursor-pointer ${
            showHostControls
              ? 'bg-indigo-600 text-white border-indigo-500'
              : 'bg-slate-800 border-slate-700 text-slate-200 hover:bg-slate-700'
          }`}
          title="Host Controls"
        >
          <Shield className="w-5 h-5" />
        </button>

        <div className="w-px h-8 bg-slate-800 mx-1" />

        <button
          onClick={onEndCall}
          className="px-6 py-3.5 rounded-xl bg-red-600 hover:bg-red-500 text-white font-bold text-sm transition flex items-center gap-2 shadow-lg shadow-red-600/40 cursor-pointer"
        >
          <PhoneOff className="w-5 h-5" />
          End Call
        </button>
      </div>

      {/* Host Moderation Controls Sheet */}
      {showHostControls && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-md shadow-2xl p-6 space-y-4 max-h-[85vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-indigo-400" />
                <h3 className="text-base font-bold text-slate-100">Host Moderation</h3>
              </div>
              <button
                onClick={() => setShowHostControls(false)}
                className="p-1 text-slate-400 hover:text-white cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Room Lock */}
            <div className="flex items-center justify-between p-3.5 rounded-2xl bg-slate-950 border border-slate-800">
              <div className="flex items-center gap-2.5">
                {isRoomLocked ? <Lock className="w-4 h-4 text-amber-400" /> : <Unlock className="w-4 h-4 text-slate-400" />}
                <div>
                  <span className="text-xs font-bold text-slate-200 block">Lock Call Room</span>
                  <span className="text-[11px] text-slate-400">Block new callers from entering</span>
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

            {/* Remote Participants Moderation */}
            <div className="space-y-2">
              <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider block">
                Manage Remote Attendees
              </span>

              {participants
                .filter(p => p.id !== 'cp-self')
                .map(p => (
                  <div
                    key={p.id}
                    className="p-3 rounded-2xl bg-slate-950 border border-slate-800 flex items-center justify-between"
                  >
                    <div>
                      <span className="text-xs font-bold text-slate-200 block">{p.displayName}</span>
                      <span className="text-[10px] text-indigo-400 capitalize">{p.role}</span>
                    </div>

                    <div className="flex items-center gap-1.5">
                      <button
                        onClick={() => handleRemoteMuteAudio(p.id)}
                        className={`p-1.5 rounded-lg border text-xs cursor-pointer ${
                          p.isAudioMuted ? 'text-red-400 border-red-500/30 bg-red-500/10' : 'text-slate-300 border-slate-700 bg-slate-800'
                        }`}
                        title="Mute Audio"
                      >
                        <MicOff className="w-3.5 h-3.5" />
                      </button>

                      <button
                        onClick={() => handleRemoteMuteVideo(p.id)}
                        className={`p-1.5 rounded-lg border text-xs cursor-pointer ${
                          p.isVideoMuted ? 'text-red-400 border-red-500/30 bg-red-500/10' : 'text-slate-300 border-slate-700 bg-slate-800'
                        }`}
                        title="Mute Video"
                      >
                        <VideoOff className="w-3.5 h-3.5" />
                      </button>

                      <button
                        onClick={() => handleToggleRole(p.id)}
                        className="px-2 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-[10px] font-semibold border border-slate-700 cursor-pointer"
                        title="Promote or Demote Presenter"
                      >
                        {p.role === 'presenter' ? 'Demote' : 'Promote'}
                      </button>

                      <button
                        onClick={() => handleEjectParticipant(p.id)}
                        className="p-1.5 rounded-lg bg-red-600/20 hover:bg-red-600 text-red-400 hover:text-white border border-red-500/30 transition cursor-pointer"
                        title="Eject Attendee"
                      >
                        <UserMinus className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                ))}
            </div>

            <div className="pt-3 border-t border-slate-800 flex items-center justify-end">
              <button
                onClick={() => setShowHostControls(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
