import React, { useState, useEffect } from 'react';
import { 
  Mic, 
  MicOff, 
  Video as VideoIcon, 
  VideoOff, 
  PhoneOff, 
  Monitor, 
  Users, 
  ShieldCheck 
} from 'lucide-react';

interface InCallScreenProps {
  conversationId: string;
  onEndCall: () => void;
}

export const InCallScreen: React.FC<InCallScreenProps> = ({ conversationId, onEndCall }) => {
  const [isMuted, setIsMuted] = useState(false);
  const [isVideoOff, setIsVideoOff] = useState(false);
  const [callDurationSeconds, setCallDurationSeconds] = useState(0);

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

  return (
    <div className="fixed inset-0 z-50 bg-slate-950/90 backdrop-blur-xl flex flex-col items-center justify-between p-6">
      {/* Top Header */}
      <div className="w-full max-w-5xl flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-3 h-3 rounded-full bg-emerald-500 animate-ping" />
          <div>
            <h2 className="text-base font-bold text-slate-100 flex items-center gap-2">
              Live Team Call
              <span className="text-xs font-mono font-semibold bg-emerald-500/20 text-emerald-300 px-2 py-0.5 rounded-full border border-emerald-500/30">
                {formatTimer(callDurationSeconds)}
              </span>
            </h2>
            <p className="text-xs text-slate-400">
              Encrypted Real-Time Audio/Video Session
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 bg-slate-900/80 border border-slate-800 px-3 py-1.5 rounded-xl text-xs text-slate-300">
          <Users className="w-4 h-4 text-indigo-400" />
          <span>2 Participants</span>
        </div>
      </div>

      {/* Video Participant Grid */}
      <div className="w-full max-w-5xl flex-1 my-6 grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Main Remote Video Stream */}
        <div className="bg-slate-900 border border-slate-800 rounded-3xl relative overflow-hidden flex flex-col items-center justify-center shadow-2xl group">
          <div className="w-24 h-24 rounded-full bg-gradient-to-tr from-indigo-600 to-purple-600 flex items-center justify-center text-white text-3xl font-bold shadow-xl border-4 border-slate-800">
            AC
          </div>
          <p className="mt-4 text-sm font-semibold text-slate-200">Alice Owner</p>
          <span className="text-xs text-slate-400 mt-1">Speaking...</span>

          {/* Speaking Waveform Animation */}
          <div className="absolute bottom-4 left-4 flex items-end gap-1 h-5">
            <span className="w-1 bg-indigo-400 rounded-full animate-bounce h-3" />
            <span className="w-1 bg-indigo-400 rounded-full animate-bounce h-5 delay-75" />
            <span className="w-1 bg-indigo-400 rounded-full animate-bounce h-2 delay-150" />
            <span className="w-1 bg-indigo-400 rounded-full animate-bounce h-4 delay-200" />
          </div>
        </div>

        {/* Local Self Video Stream */}
        <div className="bg-slate-900 border border-slate-800 rounded-3xl relative overflow-hidden flex flex-col items-center justify-center shadow-2xl">
          {isVideoOff ? (
            <div className="flex flex-col items-center justify-center text-slate-500 space-y-2">
              <VideoOff className="w-12 h-12 text-slate-600" />
              <span className="text-xs">Camera Turned Off</span>
            </div>
          ) : (
            <>
              <div className="w-24 h-24 rounded-full bg-slate-800 border-2 border-indigo-500/50 flex items-center justify-center text-slate-300 text-3xl font-bold shadow-xl">
                YOU
              </div>
              <p className="mt-4 text-sm font-semibold text-slate-200">You (Host)</p>
            </>
          )}

          {isMuted && (
            <div className="absolute top-4 right-4 bg-red-500/20 text-red-400 border border-red-500/30 p-2 rounded-xl">
              <MicOff className="w-4 h-4" />
            </div>
          )}
        </div>
      </div>

      {/* Call Action Controls Bar */}
      <div className="flex items-center gap-4 bg-slate-900/90 border border-slate-800 p-3 rounded-2xl shadow-2xl backdrop-blur-md">
        <button
          onClick={() => setIsMuted(!isMuted)}
          className={`p-3.5 rounded-xl border transition ${
            isMuted
              ? 'bg-red-500/20 border-red-500/40 text-red-400'
              : 'bg-slate-800 border-slate-700 text-slate-200 hover:bg-slate-700'
          }`}
          title={isMuted ? 'Unmute microphone' : 'Mute microphone'}
        >
          {isMuted ? <MicOff className="w-5 h-5" /> : <Mic className="w-5 h-5" />}
        </button>

        <button
          onClick={() => setIsVideoOff(!isVideoOff)}
          className={`p-3.5 rounded-xl border transition ${
            isVideoOff
              ? 'bg-red-500/20 border-red-500/40 text-red-400'
              : 'bg-slate-800 border-slate-700 text-slate-200 hover:bg-slate-700'
          }`}
          title={isVideoOff ? 'Turn on camera' : 'Turn off camera'}
        >
          {isVideoOff ? <VideoOff className="w-5 h-5" /> : <VideoIcon className="w-5 h-5" />}
        </button>

        <button
          onClick={() => alert('Screen sharing initialized')}
          className="p-3.5 rounded-xl bg-slate-800 border border-slate-700 text-slate-200 hover:bg-slate-700 transition"
          title="Share Screen"
        >
          <Monitor className="w-5 h-5" />
        </button>

        <div className="w-px h-8 bg-slate-800 mx-1" />

        <button
          onClick={onEndCall}
          className="px-6 py-3.5 rounded-xl bg-red-600 hover:bg-red-500 text-white font-bold text-sm transition flex items-center gap-2 shadow-lg shadow-red-600/40"
        >
          <PhoneOff className="w-5 h-5" />
          End Call
        </button>
      </div>
    </div>
  );
};
