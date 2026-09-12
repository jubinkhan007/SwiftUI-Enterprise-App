import React, { useState } from 'react';
import { Bolt, Lock, Mail, Server, User as UserIcon, AlertCircle } from 'lucide-react';
import { AuthBackground } from '../components/AuthBackground';
import { api } from '../services/api';
import { UserDTO } from '../types';

interface AuthScreenProps {
  onLoginSuccess: (user: UserDTO) => void;
}

export const AuthScreen: React.FC<AuthScreenProps> = ({ onLoginSuccess }) => {
  const [isLoginMode, setIsLoginMode] = useState(true);
  const [serverUrl, setServerUrl] = useState('');
  const [email, setEmail] = useState('alice@acme.com');
  const [password, setPassword] = useState('Password123!');
  const [displayName, setDisplayName] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const performLogin = async (targetEmail: string, targetPass: string) => {
    setIsLoading(true);
    setErrorMessage(null);

    try {
      api.setBaseUrl(serverUrl);
      const res = await api.login(targetEmail, targetPass);
      setIsLoading(false);
      onLoginSuccess(res.user);
    } catch (err: any) {
      setIsLoading(false);
      setErrorMessage(err.message || 'Authentication failed');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await performLogin(email, password);
  };

  const handleQuickLogin = async (quickEmail: string, quickPass: string) => {
    setEmail(quickEmail);
    setPassword(quickPass);
    await performLogin(quickEmail, quickPass);
  };

  return (
    <div className="min-h-screen relative flex items-center justify-center p-4 bg-slate-950">
      <AuthBackground />

      <div className="w-full max-w-md relative z-10 space-y-6">
        {/* Header Branding */}
        <div className="flex flex-col items-center text-center">
          <div className="w-16 h-16 rounded-full bg-gradient-to-tr from-indigo-500 via-indigo-600 to-teal-400 p-[2px] shadow-xl shadow-indigo-500/25">
            <div className="w-full h-full rounded-full bg-slate-950 flex items-center justify-center">
              <Bolt className="w-8 h-8 text-teal-400 fill-teal-400" />
            </div>
          </div>
          <h1 className="mt-4 text-2xl font-bold text-slate-100 tracking-tight">Enterprise App</h1>
          <p className="text-sm text-slate-400">Secure access for modern teams.</p>
        </div>

        {/* Mode Picker Switcher Pill */}
        <div className="p-1 rounded-full bg-slate-800/70 border border-slate-700/50 flex">
          <button
            type="button"
            onClick={() => { setIsLoginMode(true); setErrorMessage(null); }}
            className={`flex-1 py-2 rounded-full text-xs font-bold transition-all cursor-pointer ${
              isLoginMode 
                ? 'bg-gradient-to-r from-indigo-600 to-indigo-500 text-white shadow-md' 
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Sign in
          </button>
          <button
            type="button"
            onClick={() => { setIsLoginMode(false); setErrorMessage(null); }}
            className={`flex-1 py-2 rounded-full text-xs font-bold transition-all cursor-pointer ${
              !isLoginMode 
                ? 'bg-gradient-to-r from-indigo-600 to-indigo-500 text-white shadow-md' 
                : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            Create account
          </button>
        </div>

        {/* Card Form */}
        <div className="p-6 rounded-2xl bg-slate-900/90 backdrop-blur-xl border border-slate-800 shadow-2xl shadow-black/50 space-y-4">
          <h2 className="text-base font-bold text-slate-200">
            {isLoginMode ? 'Welcome back' : 'Create your account'}
          </h2>

          <form onSubmit={handleSubmit} className="space-y-3">
            {!isLoginMode && (
              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1">Display Name</label>
                <div className="relative">
                  <UserIcon className="absolute left-3 top-2.5 w-4 h-4 text-slate-500" />
                  <input
                    type="text"
                    value={displayName}
                    onChange={(e) => setDisplayName(e.target.value)}
                    placeholder="Alice Chief"
                    className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:border-indigo-500"
                  />
                </div>
              </div>
            )}

            <div>
              <label className="block text-xs font-semibold text-slate-400 mb-1">Email</label>
              <div className="relative">
                <Mail className="absolute left-3 top-2.5 w-4 h-4 text-slate-500" />
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="alice@acme.com"
                  className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:border-indigo-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-400 mb-1">Password</label>
              <div className="relative">
                <Lock className="absolute left-3 top-2.5 w-4 h-4 text-slate-500" />
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:border-indigo-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-400 mb-1">API Server URL (Optional)</label>
              <div className="relative">
                <Server className="absolute left-3 top-2.5 w-4 h-4 text-slate-500" />
                <input
                  type="text"
                  value={serverUrl}
                  onChange={(e) => setServerUrl(e.target.value)}
                  placeholder="Leave empty for Vite Proxy (/api)"
                  className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:border-indigo-500"
                />
              </div>
            </div>

            {errorMessage && (
              <div className="flex items-center gap-2 p-2.5 rounded-lg bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs font-medium">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{errorMessage}</span>
              </div>
            )}

            <button
              type="submit"
              disabled={isLoading}
              className="w-full mt-2 py-3 rounded-xl bg-gradient-to-r from-indigo-600 to-indigo-500 text-white text-sm font-bold shadow-lg shadow-indigo-500/25 hover:opacity-95 transition-opacity disabled:opacity-50 cursor-pointer flex items-center justify-center"
            >
              {isLoading ? (
                <div className="flex items-center gap-2">
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  <span>Signing in...</span>
                </div>
              ) : (
                isLoginMode ? 'Sign in' : 'Create account'
              )}
            </button>
          </form>

          {/* Quick Seed Buttons */}
          <div className="pt-3 border-t border-slate-800 space-y-2">
            <span className="text-[11px] font-semibold text-slate-400">Instant Seed Login Options:</span>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                disabled={isLoading}
                onClick={() => handleQuickLogin('alice@acme.com', 'Password123!')}
                className="px-3 py-2 rounded-xl bg-slate-800/80 border border-slate-700/60 text-xs font-semibold text-indigo-300 hover:bg-slate-800 hover:border-indigo-500/50 transition cursor-pointer disabled:opacity-50"
              >
                Alice (Owner)
              </button>
              <button
                type="button"
                disabled={isLoading}
                onClick={() => handleQuickLogin('bob@acme.com', 'Password123!')}
                className="px-3 py-2 rounded-xl bg-slate-800/80 border border-slate-700/60 text-xs font-semibold text-indigo-300 hover:bg-slate-800 hover:border-indigo-500/50 transition cursor-pointer disabled:opacity-50"
              >
                Bob (Manager)
              </button>
              <button
                type="button"
                disabled={isLoading}
                onClick={() => handleQuickLogin('charlie@acme.com', 'Password123!')}
                className="px-3 py-2 rounded-xl bg-slate-800/80 border border-slate-700/60 text-xs font-semibold text-indigo-300 hover:bg-slate-800 hover:border-indigo-500/50 transition cursor-pointer disabled:opacity-50"
              >
                Charlie (Dev)
              </button>
              <button
                type="button"
                disabled={isLoading}
                onClick={() => handleQuickLogin('ops@acme.com', 'Password123!')}
                className="px-3 py-2 rounded-xl bg-slate-800/80 border border-slate-700/60 text-xs font-semibold text-indigo-300 hover:bg-slate-800 hover:border-indigo-500/50 transition cursor-pointer disabled:opacity-50"
              >
                Ops (Admin)
              </button>
            </div>
          </div>
        </div>

        <p className="text-center text-[11px] text-slate-500">
          By continuing, you agree to your organization's security policies.
        </p>
      </div>
    </div>
  );
};
