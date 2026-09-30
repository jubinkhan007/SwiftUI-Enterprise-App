import React, { useState, useEffect } from 'react';
import {
  KeyRound,
  Webhook,
  Plus,
  Trash2,
  Copy,
  Check,
  AlertTriangle,
  Send,
  RefreshCw,
  X,
  ExternalLink,
  ShieldAlert,
  Clock,
  CheckCircle2,
  Lock,
  Globe
} from 'lucide-react';
import {
  APIKeyDTO,
  APIKeyScope,
  CreateAPIKeyRequest,
  WebhookSubscriptionDTO,
  CreateWebhookSubscriptionRequest,
  NavDestination
} from '../types';
import { api } from '../services/api';

export interface IntegrationSettingsScreenProps {
  onNavigate?: (dest: NavDestination) => void;
}

const AVAILABLE_SCOPES: { id: APIKeyScope; label: string; desc: string }[] = [
  { id: 'admin', label: 'Admin Access', desc: 'Full administrative access across all endpoints' },
  { id: 'tasks.read', label: 'Read Tasks', desc: 'Read tasks, backlogs, views, and comments' },
  { id: 'tasks.write', label: 'Write Tasks', desc: 'Create, update, and manage task lifecycles' },
  { id: 'webhooks.manage', label: 'Manage Webhooks', desc: 'Register and modify outgoing webhook subscriptions' },
  { id: 'apikeys.manage', label: 'Manage API Keys', desc: 'Create and revoke personal developer access tokens' },
];

const AVAILABLE_EVENTS = [
  { id: 'task.created', label: 'Task Created', desc: 'Fires when a new task or issue is logged' },
  { id: 'task.updated', label: 'Task Updated', desc: 'Fires when task title, status, or assignee changes' },
  { id: 'task.deleted', label: 'Task Deleted', desc: 'Fires when a task is permanently removed' },
  { id: 'comment.created', label: 'Comment Created', desc: 'Fires when comments or activity items are posted' },
  { id: 'sprint.closed', label: 'Sprint Closed', desc: 'Fires when an agile sprint is finalized' },
];

export const IntegrationSettingsScreen: React.FC<IntegrationSettingsScreenProps> = ({ onNavigate: _onNavigate }) => {
  const [activeTab, setActiveTab] = useState<'api_keys' | 'webhooks'>('api_keys');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // API Keys state
  const [apiKeys, setApiKeys] = useState<APIKeyDTO[]>([]);
  const [showCreateKeyModal, setShowCreateKeyModal] = useState(false);
  const [newKeyName, setNewKeyName] = useState('');
  const [newKeyScopes, setNewKeyScopes] = useState<APIKeyScope[]>(['tasks.read', 'tasks.write']);
  const [newKeyExpiresDays, setNewKeyExpiresDays] = useState<string>('90');
  const [createdSecretToken, setCreatedSecretToken] = useState<string | null>(null);
  const [copiedSecret, setCopiedSecret] = useState(false);
  const [revokingKeyId, setRevokingKeyId] = useState<string | null>(null);

  // Webhooks state
  const [webhooks, setWebhooks] = useState<WebhookSubscriptionDTO[]>([]);
  const [showCreateWebhookModal, setShowCreateWebhookModal] = useState(false);
  const [newWebhookUrl, setNewWebhookUrl] = useState('');
  const [newWebhookSecret, setNewWebhookSecret] = useState('');
  const [newWebhookEvents, setNewWebhookEvents] = useState<string[]>(['task.created', 'task.updated']);
  const [testingWebhookId, setTestingWebhookId] = useState<string | null>(null);
  const [testResult, setTestResult] = useState<{ id: string; success: boolean; message: string } | null>(null);
  const [deletingWebhookId, setDeletingWebhookId] = useState<string | null>(null);

  const fetchData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [fetchedKeys, fetchedWebhooks] = await Promise.all([
        api.getApiKeys().catch(e => {
          console.error('Failed to load API keys', e);
          return [];
        }),
        api.getWebhooks().catch(e => {
          console.error('Failed to load webhooks', e);
          return [];
        }),
      ]);
      setApiKeys(fetchedKeys);
      setWebhooks(fetchedWebhooks);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch integrations data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // --- API Key Handlers ---
  const handleCreateKeySubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newKeyName.trim()) return;

    try {
      let expiresAt: string | null = null;
      if (newKeyExpiresDays !== 'never') {
        const d = new Date();
        d.setDate(d.getDate() + parseInt(newKeyExpiresDays, 10));
        expiresAt = d.toISOString();
      }

      const payload: CreateAPIKeyRequest = {
        name: newKeyName.trim(),
        scopes: newKeyScopes,
        expiresAt,
      };

      const res = await api.createApiKey(payload);
      setApiKeys(prev => [res.apiKey, ...prev]);
      setCreatedSecretToken(res.rawKey);
      setShowCreateKeyModal(false);
      setNewKeyName('');
      setNewKeyScopes(['tasks.read', 'tasks.write']);
      setNewKeyExpiresDays('90');
    } catch (err: any) {
      alert(`Failed to create API key: ${err.message || err}`);
    }
  };

  const handleRevokeKey = async (id: string) => {
    if (!confirm('Are you sure you want to revoke this API key? Applications using this token will immediately lose access.')) {
      return;
    }
    setRevokingKeyId(id);
    try {
      await api.revokeApiKey(id);
      setApiKeys(prev => prev.filter(k => k.id !== id));
    } catch (err: any) {
      alert(`Failed to revoke key: ${err.message || err}`);
    } finally {
      setRevokingKeyId(null);
    }
  };

  const handleCopySecret = () => {
    if (!createdSecretToken) return;
    navigator.clipboard.writeText(createdSecretToken);
    setCopiedSecret(true);
    setTimeout(() => setCopiedSecret(false), 2500);
  };

  const toggleScope = (scope: APIKeyScope) => {
    setNewKeyScopes(prev => 
      prev.includes(scope) ? prev.filter(s => s !== scope) : [...prev, scope]
    );
  };

  // --- Webhook Handlers ---
  const handleCreateWebhookSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const url = newWebhookUrl.trim();
    if (!url) return;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      alert('Please provide a valid URL starting with https:// or http://');
      return;
    }

    if (newWebhookEvents.length === 0) {
      alert('Please select at least one event subscription');
      return;
    }

    try {
      const payload: CreateWebhookSubscriptionRequest = {
        targetUrl: url,
        events: newWebhookEvents,
        secret: newWebhookSecret.trim() || undefined,
      };

      const created = await api.createWebhook(payload);
      setWebhooks(prev => [created, ...prev]);
      setShowCreateWebhookModal(false);
      setNewWebhookUrl('');
      setNewWebhookSecret('');
      setNewWebhookEvents(['task.created', 'task.updated']);
    } catch (err: any) {
      alert(`Failed to create webhook: ${err.message || err}`);
    }
  };

  const handleToggleWebhook = async (webhook: WebhookSubscriptionDTO) => {
    const nextState = !webhook.isActive;
    try {
      const updated = await api.updateWebhook(webhook.id, { isActive: nextState });
      setWebhooks(prev => prev.map(w => w.id === webhook.id ? updated : w));
    } catch (err: any) {
      alert(`Failed to update webhook: ${err.message || err}`);
    }
  };

  const handleTestWebhook = async (id: string) => {
    setTestingWebhookId(id);
    setTestResult(null);
    try {
      const res = await api.testWebhook(id);
      setTestResult({
        id,
        success: res.delivered,
        message: res.delivered 
          ? `Ping delivered successfully (HTTP ${res.statusCode || 200})` 
          : `Delivery failed with status ${res.statusCode || 'unreachable'}`
      });
    } catch (err: any) {
      setTestResult({
        id,
        success: false,
        message: err.message || 'Webhook test request failed'
      });
    } finally {
      setTestingWebhookId(null);
    }
  };

  const handleDeleteWebhook = async (id: string) => {
    if (!confirm('Are you sure you want to delete this webhook subscription?')) {
      return;
    }
    setDeletingWebhookId(id);
    try {
      await api.deleteWebhook(id);
      setWebhooks(prev => prev.filter(w => w.id !== id));
    } catch (err: any) {
      alert(`Failed to delete webhook: ${err.message || err}`);
    } finally {
      setDeletingWebhookId(null);
    }
  };

  const toggleEvent = (event: string) => {
    setNewWebhookEvents(prev => 
      prev.includes(event) ? prev.filter(e => e !== event) : [...prev, event]
    );
  };

  return (
    <div className="flex-1 flex flex-col h-full bg-slate-950 text-slate-100 overflow-y-auto">
      {/* Header Bar */}
      <div className="border-b border-slate-800/80 bg-slate-900/60 backdrop-blur-md px-6 py-6 sticky top-0 z-20">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 shadow-inner">
              <KeyRound className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-bold tracking-tight text-white">Integrations & API</h1>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-indigo-500/20 text-indigo-400 border border-indigo-500/30">
                  DEVELOPER
                </span>
              </div>
              <p className="text-xs text-slate-400 mt-0.5">
                Generate secure API tokens and dispatch automated webhook payloads to external systems.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={fetchData}
              disabled={loading}
              className="p-2 rounded-xl border border-slate-800 bg-slate-900/80 hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition"
              title="Refresh integrations"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-indigo-400' : ''}`} />
            </button>

            {activeTab === 'api_keys' ? (
              <button
                onClick={() => setShowCreateKeyModal(true)}
                className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-medium text-xs shadow-lg shadow-indigo-600/30 transition flex items-center gap-2"
                id="btn-create-api-key"
              >
                <Plus className="w-4 h-4" />
                Generate New Key
              </button>
            ) : (
              <button
                onClick={() => setShowCreateWebhookModal(true)}
                className="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-medium text-xs shadow-lg shadow-indigo-600/30 transition flex items-center gap-2"
                id="btn-create-webhook"
              >
                <Plus className="w-4 h-4" />
                Add Webhook
              </button>
            )}
          </div>
        </div>

        {/* Tab Switcher */}
        <div className="max-w-6xl mx-auto mt-6 flex border-b border-slate-800/80">
          <button
            onClick={() => setActiveTab('api_keys')}
            className={`pb-3 px-4 font-semibold text-xs transition border-b-2 flex items-center gap-2 ${
              activeTab === 'api_keys'
                ? 'border-indigo-500 text-indigo-400'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
            id="tab-api-keys"
          >
            <KeyRound className="w-3.5 h-3.5" />
            Personal API Keys ({apiKeys.length})
          </button>
          <button
            onClick={() => setActiveTab('webhooks')}
            className={`pb-3 px-4 font-semibold text-xs transition border-b-2 flex items-center gap-2 ${
              activeTab === 'webhooks'
                ? 'border-indigo-500 text-indigo-400'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
            id="tab-webhooks"
          >
            <Webhook className="w-3.5 h-3.5" />
            Outgoing Webhooks ({webhooks.length})
          </button>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="max-w-6xl mx-auto w-full p-6 space-y-6">
        {error && (
          <div className="p-4 rounded-xl bg-red-950/40 border border-red-800/60 text-red-300 text-xs flex items-center gap-3">
            <AlertTriangle className="w-4 h-4 text-red-400 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {/* ===================== TAB: API KEYS ===================== */}
        {activeTab === 'api_keys' && (
          <div className="space-y-4">
            <div className="bg-slate-900/40 border border-slate-800/80 rounded-2xl p-5 backdrop-blur-xs flex items-start justify-between">
              <div>
                <h3 className="text-sm font-semibold text-slate-200">API Access Tokens</h3>
                <p className="text-xs text-slate-400 mt-1 max-w-2xl">
                  API keys allow automated tools, CLI scripts, and third-party integrations to authenticate with TaskFlow on behalf of your account.
                  Never share your secret keys in public repositories or client-side web apps.
                </p>
              </div>
            </div>

            {apiKeys.length === 0 && !loading ? (
              <div className="p-12 text-center border border-dashed border-slate-800 rounded-2xl bg-slate-900/20">
                <KeyRound className="w-10 h-10 text-slate-600 mx-auto mb-3" />
                <h4 className="text-sm font-semibold text-slate-300">No API keys generated yet</h4>
                <p className="text-xs text-slate-500 mt-1 mb-4">
                  Create your first API key to start connecting external automations and custom scripts.
                </p>
                <button
                  onClick={() => setShowCreateKeyModal(true)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-medium text-xs border border-slate-700 transition"
                >
                  Create API Key
                </button>
              </div>
            ) : (
              <div className="space-y-3">
                {apiKeys.map(key => (
                  <div
                    key={key.id}
                    className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 hover:border-slate-700/80 transition flex flex-col md:flex-row md:items-center justify-between gap-4"
                    id={`key-card-${key.id}`}
                  >
                    <div className="space-y-1.5">
                      <div className="flex items-center gap-3">
                        <span className="font-semibold text-sm text-white">{key.name}</span>
                        <code className="px-2 py-0.5 rounded-md bg-slate-800 border border-slate-700/60 font-mono text-[11px] text-indigo-300">
                          {key.keyPrefix ? `tf_${key.keyPrefix}...` : 'tf_••••••••'}
                        </code>
                        {key.isRevoked && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-red-950/60 text-red-400 border border-red-800/60">
                            REVOKED
                          </span>
                        )}
                      </div>

                      <div className="flex flex-wrap items-center gap-2">
                        {key.scopes && key.scopes.length > 0 ? (
                          key.scopes.map(s => (
                            <span
                              key={s}
                              className="px-2 py-0.5 rounded-md bg-slate-800/80 border border-slate-700/40 text-[10px] text-slate-300 font-medium"
                            >
                              {s}
                            </span>
                          ))
                        ) : (
                          <span className="text-[10px] text-slate-500">No specific scopes</span>
                        )}
                      </div>

                      <div className="flex items-center gap-4 text-[11px] text-slate-500 pt-1">
                        <span className="flex items-center gap-1">
                          <Clock className="w-3 h-3" />
                          Created: {key.createdAt ? new Date(key.createdAt).toLocaleDateString() : 'Recent'}
                        </span>
                        {key.lastUsedAt && (
                          <span>Last used: {new Date(key.lastUsedAt).toLocaleDateString()}</span>
                        )}
                        {key.expiresAt && (
                          <span>Expires: {new Date(key.expiresAt).toLocaleDateString()}</span>
                        )}
                      </div>
                    </div>

                    <div className="flex items-center gap-2 self-end md:self-center">
                      <button
                        onClick={() => handleRevokeKey(key.id)}
                        disabled={revokingKeyId === key.id || key.isRevoked}
                        className="px-3 py-1.5 rounded-xl border border-red-900/40 hover:bg-red-950/40 text-red-400 hover:text-red-300 font-medium text-xs transition flex items-center gap-1.5 disabled:opacity-40"
                        title="Revoke Key"
                        id={`btn-revoke-key-${key.id}`}
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                        Revoke
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ===================== TAB: WEBHOOKS ===================== */}
        {activeTab === 'webhooks' && (
          <div className="space-y-4">
            <div className="bg-slate-900/40 border border-slate-800/80 rounded-2xl p-5 backdrop-blur-xs flex items-start justify-between">
              <div>
                <h3 className="text-sm font-semibold text-slate-200">Event Subscriptions</h3>
                <p className="text-xs text-slate-400 mt-1 max-w-2xl">
                  Configure outgoing webhooks to push JSON event payloads when tasks are created, modified, or completed.
                  Signatures are calculated using HMAC-SHA256 for secure verification.
                </p>
              </div>
            </div>

            {webhooks.length === 0 && !loading ? (
              <div className="p-12 text-center border border-dashed border-slate-800 rounded-2xl bg-slate-900/20">
                <Webhook className="w-10 h-10 text-slate-600 mx-auto mb-3" />
                <h4 className="text-sm font-semibold text-slate-300">No webhooks registered</h4>
                <p className="text-xs text-slate-500 mt-1 mb-4">
                  Add an endpoint URL to receive real-time notifications when issues and sprints update.
                </p>
                <button
                  onClick={() => setShowCreateWebhookModal(true)}
                  className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-medium text-xs border border-slate-700 transition"
                >
                  Add Webhook
                </button>
              </div>
            ) : (
              <div className="space-y-3">
                {webhooks.map(wh => (
                  <div
                    key={wh.id}
                    className="p-4 rounded-2xl bg-slate-900/60 border border-slate-800/80 hover:border-slate-700/80 transition flex flex-col md:flex-row md:items-center justify-between gap-4"
                    id={`webhook-card-${wh.id}`}
                  >
                    <div className="space-y-1.5 max-w-xl">
                      <div className="flex items-center gap-3">
                        <Globe className="w-4 h-4 text-slate-400 shrink-0" />
                        <span className="font-mono text-xs font-semibold text-indigo-300 truncate" title={wh.targetUrl}>
                          {wh.targetUrl}
                        </span>
                        <span
                          className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${
                            wh.isActive
                              ? 'bg-emerald-950/60 text-emerald-400 border-emerald-800/60'
                              : 'bg-slate-800 text-slate-400 border-slate-700'
                          }`}
                        >
                          {wh.isActive ? 'ACTIVE' : 'PAUSED'}
                        </span>
                        {wh.failureCount > 0 && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-950/60 text-amber-400 border border-amber-800/60">
                            {wh.failureCount} ERRORS
                          </span>
                        )}
                      </div>

                      <div className="flex flex-wrap items-center gap-1.5 pt-1">
                        {wh.events.map(ev => (
                          <span
                            key={ev}
                            className="px-2 py-0.5 rounded-md bg-slate-800/80 border border-slate-700/40 text-[10px] text-slate-300 font-medium"
                          >
                            {ev}
                          </span>
                        ))}
                      </div>

                      <div className="text-[11px] text-slate-500 pt-1">
                        Secret: <code className="text-slate-400 font-mono">••••••••••••••••</code>
                      </div>

                      {testResult && testResult.id === wh.id && (
                        <div className={`mt-2 p-2 rounded-lg text-xs flex items-center gap-2 border ${
                          testResult.success
                            ? 'bg-emerald-950/40 border-emerald-800/50 text-emerald-300'
                            : 'bg-red-950/40 border-red-800/50 text-red-300'
                        }`}>
                          {testResult.success ? <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" /> : <AlertTriangle className="w-3.5 h-3.5 text-red-400" />}
                          <span>{testResult.message}</span>
                        </div>
                      )}
                    </div>

                    <div className="flex items-center gap-2 self-end md:self-center">
                      <button
                        onClick={() => handleToggleWebhook(wh)}
                        className={`px-3 py-1.5 rounded-xl border text-xs font-semibold transition ${
                          wh.isActive
                            ? 'bg-slate-800 border-slate-700 text-slate-300 hover:text-white'
                            : 'bg-indigo-950/60 border-indigo-800/60 text-indigo-300 hover:bg-indigo-900/60'
                        }`}
                        title={wh.isActive ? 'Pause Webhook' : 'Activate Webhook'}
                      >
                        {wh.isActive ? 'Pause' : 'Activate'}
                      </button>

                      <button
                        onClick={() => handleTestWebhook(wh.id)}
                        disabled={testingWebhookId === wh.id}
                        className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-medium transition flex items-center gap-1.5 disabled:opacity-40"
                        title="Send Mock Ping Event"
                        id={`btn-test-webhook-${wh.id}`}
                      >
                        <Send className={`w-3.5 h-3.5 ${testingWebhookId === wh.id ? 'animate-bounce text-indigo-400' : ''}`} />
                        Test Ping
                      </button>

                      <button
                        onClick={() => handleDeleteWebhook(wh.id)}
                        disabled={deletingWebhookId === wh.id}
                        className="p-1.5 rounded-xl border border-red-900/40 hover:bg-red-950/40 text-red-400 hover:text-red-300 transition"
                        title="Delete Webhook"
                        id={`btn-delete-webhook-${wh.id}`}
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* ===================== MODAL: GENERATE API KEY ===================== */}
      {showCreateKeyModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-lg p-6 shadow-2xl relative">
            <button
              onClick={() => setShowCreateKeyModal(false)}
              className="absolute top-5 right-5 text-slate-400 hover:text-slate-200"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex items-center gap-3 mb-5">
              <div className="w-10 h-10 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
                <KeyRound className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-white">Generate Personal API Key</h3>
                <p className="text-xs text-slate-400">Specify token metadata and authorization scopes.</p>
              </div>
            </div>

            <form onSubmit={handleCreateKeySubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Key Name <span className="text-red-400">*</span>
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. CI/CD Release Runner, Zapier Automation"
                  value={newKeyName}
                  onChange={e => setNewKeyName(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-slate-200 focus:outline-none focus:border-indigo-500 transition"
                  id="input-key-name"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Expiration</label>
                <select
                  value={newKeyExpiresDays}
                  onChange={e => setNewKeyExpiresDays(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-slate-200 focus:outline-none focus:border-indigo-500 transition"
                >
                  <option value="30">30 Days</option>
                  <option value="60">60 Days</option>
                  <option value="90">90 Days (Recommended)</option>
                  <option value="365">1 Year</option>
                  <option value="never">No Expiration</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-2">Granted Scopes</label>
                <div className="space-y-2 max-h-48 overflow-y-auto pr-1">
                  {AVAILABLE_SCOPES.map(sc => (
                    <label
                      key={sc.id}
                      className={`p-3 rounded-xl border flex items-start gap-3 cursor-pointer transition ${
                        newKeyScopes.includes(sc.id)
                          ? 'bg-indigo-950/30 border-indigo-800/80 text-white'
                          : 'bg-slate-950 border-slate-800/80 text-slate-400 hover:border-slate-700'
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={newKeyScopes.includes(sc.id)}
                        onChange={() => toggleScope(sc.id)}
                        className="mt-0.5 rounded text-indigo-600 focus:ring-indigo-500 bg-slate-900 border-slate-700"
                      />
                      <div>
                        <div className="text-xs font-semibold">{sc.label}</div>
                        <div className="text-[11px] text-slate-500">{sc.desc}</div>
                      </div>
                    </label>
                  ))}
                </div>
              </div>

              <div className="pt-3 flex items-center justify-end gap-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowCreateKeyModal(false)}
                  className="px-4 py-2 rounded-xl text-slate-400 hover:text-white text-xs font-medium transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={!newKeyName.trim()}
                  className="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-medium text-xs shadow-lg shadow-indigo-600/30 transition disabled:opacity-40"
                  id="btn-submit-create-key"
                >
                  Generate Key
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ===================== MODAL: ONE-TIME SECRET TOKEN ===================== */}
      {createdSecretToken && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-lg p-6 shadow-2xl relative">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                <ShieldAlert className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-white">Save Your API Key</h3>
                <p className="text-xs text-amber-400/90 font-medium">
                  This token will NEVER be shown again!
                </p>
              </div>
            </div>

            <p className="text-xs text-slate-300 leading-relaxed mb-4">
              Make sure to copy your API key and store it in a secure password manager or environment variable.
              If you lose this key, you must generate a new one.
            </p>

            <div className="bg-slate-950 border border-slate-800 rounded-2xl p-4 flex items-center justify-between gap-3 mb-6">
              <code className="font-mono text-xs text-emerald-400 break-all select-all font-semibold" id="secret-token-display">
                {createdSecretToken}
              </code>
              <button
                onClick={handleCopySecret}
                className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 text-xs font-semibold transition shrink-0 flex items-center gap-1.5"
                id="btn-copy-token"
              >
                {copiedSecret ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4" />}
                {copiedSecret ? 'Copied!' : 'Copy'}
              </button>
            </div>

            <button
              onClick={() => setCreatedSecretToken(null)}
              className="w-full py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-xs transition shadow-lg shadow-indigo-600/30"
              id="btn-done-copy-token"
            >
              I have copied my API key
            </button>
          </div>
        </div>
      )}

      {/* ===================== MODAL: CREATE WEBHOOK ===================== */}
      {showCreateWebhookModal && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-lg p-6 shadow-2xl relative">
            <button
              onClick={() => setShowCreateWebhookModal(false)}
              className="absolute top-5 right-5 text-slate-400 hover:text-slate-200"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex items-center gap-3 mb-5">
              <div className="w-10 h-10 rounded-xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400">
                <Webhook className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-white">Register Outgoing Webhook</h3>
                <p className="text-xs text-slate-400">Configure endpoint and events to subscribe to.</p>
              </div>
            </div>

            <form onSubmit={handleCreateWebhookSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Target Endpoint URL <span className="text-red-400">*</span>
                </label>
                <input
                  type="url"
                  required
                  placeholder="https://api.example.com/webhooks/taskflow"
                  value={newWebhookUrl}
                  onChange={e => setNewWebhookUrl(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-slate-200 focus:outline-none focus:border-indigo-500 transition font-mono"
                  id="input-webhook-url"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Signing Secret <span className="text-slate-500 font-normal">(Optional, auto-generated if left blank)</span>
                </label>
                <input
                  type="text"
                  placeholder="Leave empty for a secure 32-character random secret"
                  value={newWebhookSecret}
                  onChange={e => setNewWebhookSecret(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3.5 py-2 text-sm text-slate-200 focus:outline-none focus:border-indigo-500 transition font-mono text-xs"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-2">Event Subscriptions</label>
                <div className="space-y-2">
                  {AVAILABLE_EVENTS.map(ev => (
                    <label
                      key={ev.id}
                      className={`p-3 rounded-xl border flex items-start gap-3 cursor-pointer transition ${
                        newWebhookEvents.includes(ev.id)
                          ? 'bg-indigo-950/30 border-indigo-800/80 text-white'
                          : 'bg-slate-950 border-slate-800/80 text-slate-400 hover:border-slate-700'
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={newWebhookEvents.includes(ev.id)}
                        onChange={() => toggleEvent(ev.id)}
                        className="mt-0.5 rounded text-indigo-600 focus:ring-indigo-500 bg-slate-900 border-slate-700"
                        id={`chk-event-${ev.id}`}
                      />
                      <div>
                        <div className="text-xs font-semibold">{ev.label}</div>
                        <div className="text-[11px] text-slate-500">{ev.desc}</div>
                      </div>
                    </label>
                  ))}
                </div>
              </div>

              <div className="pt-3 flex items-center justify-end gap-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowCreateWebhookModal(false)}
                  className="px-4 py-2 rounded-xl text-slate-400 hover:text-white text-xs font-medium transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={!newWebhookUrl.trim() || newWebhookEvents.length === 0}
                  className="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-medium text-xs shadow-lg shadow-indigo-600/30 transition disabled:opacity-40"
                  id="btn-submit-create-webhook"
                >
                  Create Webhook
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
