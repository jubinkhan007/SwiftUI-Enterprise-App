import React, { useEffect, useState } from 'react';
import { 
  CreditCard, 
  Sparkles, 
  ShieldCheck, 
  Users, 
  Layers, 
  HardDrive, 
  Check, 
  ExternalLink, 
  AlertCircle, 
  RefreshCw, 
  ArrowRight,
  Shield,
  Video,
  Webhook,
  HelpCircle,
  CheckCircle2
} from 'lucide-react';
import { api } from '../services/api';
import { NavDestination, OrganizationDetailsDTO } from '../types';

interface BillingScreenProps {
  onNavigate?: (dest: NavDestination) => void;
}

export const BillingScreen: React.FC<BillingScreenProps> = ({ onNavigate }) => {
  const [org, setOrg] = useState<OrganizationDetailsDTO | null>(null);
  const [loading, setLoading] = useState(true);
  const [checkoutLoading, setCheckoutLoading] = useState(false);
  const [portalLoading, setPortalLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successBanner, setSuccessBanner] = useState<string | null>(null);

  const fetchBillingData = async () => {
    setLoading(true);
    setError(null);
    try {
      let orgId = api.getSelectedOrgId();
      if (!orgId) {
        const workspaces = await api.getWorkspaces().catch(() => []);
        if (workspaces && workspaces.length > 0) {
          orgId = workspaces[0].id;
          api.setOrgId(orgId);
        }
      }

      if (orgId) {
        const orgData = await api.getOrganization(orgId);
        setOrg(orgData);
      }
    } catch (err: any) {
      console.error('Failed to load organization billing details:', err);
      setError(err.message || 'Failed to load organization billing details');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBillingData();

    // Check for mock or stripe redirect query params
    const params = new URLSearchParams(window.location.search);
    if (params.get('mock_checkout') === 'success' || params.get('stripe_session_id')) {
      setSuccessBanner('Payment successful! Your workspace has been upgraded to the Pro Plan.');
      // Clean query params from URL without reload
      window.history.replaceState({}, document.title, window.location.pathname);
    } else if (params.get('mock_portal') === 'downgrade') {
      setSuccessBanner('Subscription updated via customer portal.');
      window.history.replaceState({}, document.title, window.location.pathname);
    }
  }, []);

  const handleUpgradeToPro = async () => {
    setCheckoutLoading(true);
    setError(null);
    try {
      const checkoutUrl = await api.getBillingCheckoutUrl();
      if (checkoutUrl) {
        window.location.href = checkoutUrl;
      }
    } catch (err: any) {
      console.error('Failed to initiate checkout:', err);
      setError(err.message || 'Failed to initiate Stripe checkout redirect');
      setCheckoutLoading(false);
    }
  };

  const handleManagePortal = async () => {
    setPortalLoading(true);
    setError(null);
    try {
      const portalUrl = await api.getBillingPortalUrl();
      if (portalUrl) {
        window.location.href = portalUrl;
      }
    } catch (err: any) {
      console.error('Failed to initiate customer portal:', err);
      setError(err.message || 'Failed to initiate Stripe billing portal redirect');
      setPortalLoading(false);
    }
  };

  const currentTier = org?.subscriptionTier?.toLowerCase() || 'free';
  const memberCount = org?.memberCount ?? 1;
  const isPro = currentTier === 'pro';
  const isEnterprise = currentTier === 'enterprise';
  const isFree = !isPro && !isEnterprise;

  // Limits
  const memberLimit = isFree ? 5 : 9999;
  const memberPercentage = Math.min(100, Math.round((memberCount / (isFree ? 5 : 100)) * 100));

  return (
    <div className="flex-1 flex flex-col h-full overflow-y-auto bg-slate-950 text-slate-100">
      {/* Top Header */}
      <div className="p-6 border-b border-slate-800 bg-slate-900/60 backdrop-blur-md flex flex-wrap items-center justify-between gap-4 shrink-0">
        <div>
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-indigo-500/10 border border-indigo-500/20 text-indigo-400">
              <CreditCard className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-xl font-bold tracking-tight text-white flex items-center gap-2">
                Subscription &amp; Billing
                <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold uppercase tracking-wider ${
                  isEnterprise 
                    ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30' 
                    : isPro 
                      ? 'bg-indigo-500/20 text-indigo-300 border border-indigo-500/30' 
                      : 'bg-slate-700/50 text-slate-300 border border-slate-600'
                }`}>
                  {currentTier} Plan
                </span>
              </h1>
              <p className="text-xs text-slate-400 mt-0.5">
                Manage your organization's subscription tier, invoices, and quota allocations.
              </p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={fetchBillingData}
            disabled={loading}
            className="px-3 py-2 rounded-xl bg-slate-800/80 hover:bg-slate-700/80 text-slate-300 text-xs font-medium border border-slate-700/70 transition flex items-center gap-1.5"
            title="Refresh billing information"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>

          {(isPro || isEnterprise) && (
            <button
              onClick={handleManagePortal}
              disabled={portalLoading}
              className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-white text-xs font-semibold border border-slate-600 transition flex items-center gap-2 shadow-sm"
            >
              {portalLoading ? (
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <ExternalLink className="w-3.5 h-3.5 text-indigo-400" />
              )}
              Stripe Customer Portal
            </button>
          )}

          {isFree && (
            <button
              onClick={handleUpgradeToPro}
              disabled={checkoutLoading}
              className="px-4 py-2 rounded-xl bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white text-xs font-bold transition flex items-center gap-2 shadow-lg shadow-indigo-600/30"
            >
              {checkoutLoading ? (
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <Sparkles className="w-3.5 h-3.5 text-amber-300" />
              )}
              Upgrade to Pro ($19/mo)
            </button>
          )}
        </div>
      </div>

      <div className="p-6 max-w-7xl mx-auto w-full space-y-8">
        {/* Alerts / Banners */}
        {successBanner && (
          <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 flex items-center justify-between text-sm animate-fadeIn">
            <div className="flex items-center gap-3">
              <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
              <span>{successBanner}</span>
            </div>
            <button 
              onClick={() => setSuccessBanner(null)}
              className="text-xs text-emerald-400 hover:text-emerald-200 font-semibold px-2 py-1"
            >
              Dismiss
            </button>
          </div>
        )}

        {error && (
          <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 text-rose-300 flex items-center justify-between text-sm">
            <div className="flex items-center gap-3">
              <AlertCircle className="w-5 h-5 text-rose-400 shrink-0" />
              <span>{error}</span>
            </div>
            <button 
              onClick={() => setError(null)}
              className="text-xs text-rose-400 hover:text-rose-200 font-semibold px-2 py-1"
            >
              Dismiss
            </button>
          </div>
        )}

        {/* Current Plan & Quota Usage Overview */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
          {/* Active Plan Card */}
          <div className="p-6 rounded-2xl bg-slate-900/70 border border-slate-800 backdrop-blur-md relative overflow-hidden flex flex-col justify-between">
            <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/5 rounded-full blur-3xl -mr-10 -mt-10 pointer-events-none" />
            <div>
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Current Plan</span>
                <span className="flex items-center gap-1.5 text-xs text-emerald-400 font-medium bg-emerald-500/10 px-2 py-0.5 rounded-full border border-emerald-500/20">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  Active
                </span>
              </div>
              <h2 className="text-2xl font-black text-white mt-2 capitalize">
                {currentTier} Plan
              </h2>
              <p className="text-xs text-slate-400 mt-1">
                Workspace: <span className="text-slate-200 font-medium">{org?.name || 'Main Workspace'}</span>
              </p>
            </div>

            <div className="mt-6 pt-4 border-t border-slate-800/80 flex items-center justify-between">
              <div>
                <span className="text-xl font-bold text-white">
                  {isFree ? '$0' : isPro ? '$19' : '$99'}
                </span>
                <span className="text-xs text-slate-400 ml-1">/ month</span>
              </div>
              {isFree ? (
                <button
                  onClick={handleUpgradeToPro}
                  disabled={checkoutLoading}
                  className="px-3 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold transition"
                >
                  Upgrade
                </button>
              ) : (
                <button
                  onClick={handleManagePortal}
                  disabled={portalLoading}
                  className="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium border border-slate-700 transition"
                >
                  Manage
                </button>
              )}
            </div>
          </div>

          {/* Seat Quota Gauge */}
          <div className="p-6 rounded-2xl bg-slate-900/70 border border-slate-800 backdrop-blur-md flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
                  <Users className="w-3.5 h-3.5 text-indigo-400" />
                  Team Seats
                </span>
                <span className="text-xs text-slate-400">
                  {isFree ? `${memberCount} / 5 used` : `${memberCount} active (Unlimited)`}
                </span>
              </div>
              <div className="mt-4">
                <div className="flex justify-between text-xs mb-1.5">
                  <span className="font-semibold text-white">{memberCount} Members</span>
                  <span className="text-slate-400">{isFree ? '5 Max' : '∞ Limit'}</span>
                </div>
                <div className="w-full h-2 rounded-full bg-slate-800 overflow-hidden">
                  <div 
                    className={`h-full rounded-full transition-all duration-500 ${
                      isFree && memberCount >= 5 
                        ? 'bg-rose-500' 
                        : 'bg-gradient-to-r from-indigo-500 to-purple-500'
                    }`}
                    style={{ width: `${isFree ? memberPercentage : 18}%` }}
                  />
                </div>
              </div>
            </div>

            <p className="text-xs text-slate-400 mt-4">
              {isFree && memberCount >= 4 ? (
                <span className="text-amber-400 font-medium">Near seat limit. Upgrade to Pro for unlimited team members.</span>
              ) : (
                'Invite team members to collaborate on tasks and projects.'
              )}
            </p>
          </div>

          {/* Project & Storage Usage */}
          <div className="p-6 rounded-2xl bg-slate-900/70 border border-slate-800 backdrop-blur-md flex flex-col justify-between">
            <div>
              <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider flex items-center gap-1.5">
                <HardDrive className="w-3.5 h-3.5 text-purple-400" />
                Storage &amp; Projects
              </span>
              <div className="mt-4 space-y-3">
                <div>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-slate-300">Active Projects</span>
                    <span className="text-white font-semibold">{isFree ? '1 / 1 limit' : 'Unlimited'}</span>
                  </div>
                  <div className="w-full h-1.5 rounded-full bg-slate-800 overflow-hidden">
                    <div className="h-full bg-purple-500 rounded-full" style={{ width: isFree ? '100%' : '25%' }} />
                  </div>
                </div>
                <div>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-slate-300">File Storage</span>
                    <span className="text-white font-semibold">{isFree ? '4.5 MB / 100 MB' : '4.5 MB / 50 GB'}</span>
                  </div>
                  <div className="w-full h-1.5 rounded-full bg-slate-800 overflow-hidden">
                    <div className="h-full bg-indigo-500 rounded-full" style={{ width: '4.5%' }} />
                  </div>
                </div>
              </div>
            </div>
            <span className="text-xs text-slate-400 mt-4">
              {isFree ? '100MB shared workspace storage limit on Free plan.' : '50GB high-speed cloud attachment storage.'}
            </span>
          </div>
        </div>

        {/* Pricing Tier Comparison Cards */}
        <div>
          <div className="text-center mb-8">
            <h3 className="text-2xl font-bold text-white tracking-tight">Flexible Plans Built for High-Velocity Teams</h3>
            <p className="text-sm text-slate-400 mt-1">
              Choose the plan that best fits your workflow. Upgrade or downgrade at any time.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 items-stretch">
            {/* Free Tier */}
            <div className={`p-6 rounded-2xl bg-slate-900/60 border ${
              isFree ? 'border-slate-600 bg-slate-900/80 shadow-md' : 'border-slate-800/80'
            } flex flex-col justify-between transition hover:border-slate-700`}>
              <div>
                <div className="flex items-center justify-between">
                  <h4 className="text-lg font-bold text-white">Free</h4>
                  {isFree && (
                    <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-700 text-slate-200 border border-slate-600">
                      Current Plan
                    </span>
                  )}
                </div>
                <p className="text-xs text-slate-400 mt-1">Essential task management for small teams and solo developers.</p>
                <div className="mt-4">
                  <span className="text-3xl font-extrabold text-white">$0</span>
                  <span className="text-xs text-slate-400 ml-1">/ month</span>
                </div>

                <div className="mt-6 space-y-3 border-t border-slate-800 pt-6">
                  <p className="text-xs font-semibold text-slate-300 uppercase tracking-wider">Features Included:</p>
                  <ul className="space-y-2.5 text-xs text-slate-300">
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      Up to 5 team members
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      1 active project &amp; space
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      100 MB secure file storage
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      Standard Kanban boards &amp; lists
                    </li>
                    <li className="flex items-center gap-2 text-slate-500">
                      <span className="w-4 h-4 flex items-center justify-center font-bold text-xs">—</span>
                      No video or voice calls
                    </li>
                    <li className="flex items-center gap-2 text-slate-500">
                      <span className="w-4 h-4 flex items-center justify-center font-bold text-xs">—</span>
                      No webhook automations
                    </li>
                  </ul>
                </div>
              </div>

              <div className="mt-8 pt-4">
                <button
                  disabled={isFree}
                  onClick={handleManagePortal}
                  className={`w-full py-2.5 rounded-xl text-xs font-semibold border transition ${
                    isFree 
                      ? 'bg-slate-800 text-slate-400 border-slate-700 cursor-default' 
                      : 'bg-slate-800/80 hover:bg-slate-700 text-slate-200 border-slate-700'
                  }`}
                >
                  {isFree ? 'Current Plan' : 'Downgrade via Portal'}
                </button>
              </div>
            </div>

            {/* Pro Tier (Featured) */}
            <div className={`p-6 rounded-2xl bg-gradient-to-b from-slate-900 to-indigo-950/30 border-2 ${
              isPro ? 'border-indigo-500 shadow-xl shadow-indigo-500/10' : 'border-indigo-500/50 hover:border-indigo-400'
            } flex flex-col justify-between relative transition scale-100 lg:-translate-y-1`}>
              {/* Popular Badge */}
              <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-gradient-to-r from-indigo-500 to-purple-500 text-white font-bold text-[10px] uppercase tracking-wider shadow-md flex items-center gap-1">
                <Sparkles className="w-3 h-3 text-amber-300" />
                Recommended
              </div>

              <div>
                <div className="flex items-center justify-between">
                  <h4 className="text-lg font-bold text-white flex items-center gap-2">
                    Pro
                    <span className="px-2 py-0.5 rounded-md bg-indigo-500/20 text-indigo-300 text-[10px] font-bold uppercase tracking-wider">
                      Popular
                    </span>
                  </h4>
                  {isPro && (
                    <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-indigo-500/30 text-indigo-200 border border-indigo-500/40">
                      Current Plan
                    </span>
                  )}
                </div>
                <p className="text-xs text-slate-400 mt-1">Supercharged productivity, meetings, and team collaboration.</p>
                <div className="mt-4">
                  <span className="text-3xl font-extrabold text-white">$19</span>
                  <span className="text-xs text-slate-400 ml-1">/ month</span>
                </div>

                <div className="mt-6 space-y-3 border-t border-slate-800 pt-6">
                  <p className="text-xs font-semibold text-indigo-300 uppercase tracking-wider">Everything in Free, plus:</p>
                  <ul className="space-y-2.5 text-xs text-slate-200">
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      <strong className="text-white">Unlimited</strong> team members &amp; guests
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      <strong className="text-white">Unlimited</strong> projects &amp; spaces
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      50 GB high-speed cloud storage
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      <span className="flex items-center gap-1">
                        <Video className="w-3.5 h-3.5 text-indigo-400" />
                        Live video &amp; audio calling (LiveKit)
                      </span>
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      <span className="flex items-center gap-1">
                        <Webhook className="w-3.5 h-3.5 text-indigo-400" />
                        Custom webhooks &amp; automations
                      </span>
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      Activity inbox &amp; thread notifications
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      Priority email &amp; chat support
                    </li>
                  </ul>
                </div>
              </div>

              <div className="mt-8 pt-4">
                {isPro ? (
                  <button
                    onClick={handleManagePortal}
                    disabled={portalLoading}
                    className="w-full py-2.5 rounded-xl text-xs font-bold bg-indigo-600/30 hover:bg-indigo-600/40 text-indigo-200 border border-indigo-500/50 transition flex items-center justify-center gap-2 shadow-sm"
                  >
                    {portalLoading ? (
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                    ) : (
                      <CreditCard className="w-3.5 h-3.5" />
                    )}
                    Manage via Stripe Portal
                  </button>
                ) : (
                  <button
                    onClick={handleUpgradeToPro}
                    disabled={checkoutLoading}
                    className="w-full py-2.5 rounded-xl text-xs font-bold bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white transition flex items-center justify-center gap-2 shadow-lg shadow-indigo-600/40"
                  >
                    {checkoutLoading ? (
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                    ) : (
                      <>
                        <Sparkles className="w-3.5 h-3.5 text-amber-300" />
                        Upgrade to Pro
                        <ArrowRight className="w-3.5 h-3.5 ml-1" />
                      </>
                    )}
                  </button>
                )}
              </div>
            </div>

            {/* Enterprise Tier */}
            <div className={`p-6 rounded-2xl bg-slate-900/60 border ${
              isEnterprise ? 'border-amber-500/50 bg-slate-900/80 shadow-md' : 'border-slate-800/80'
            } flex flex-col justify-between transition hover:border-slate-700`}>
              <div>
                <div className="flex items-center justify-between">
                  <h4 className="text-lg font-bold text-white flex items-center gap-1.5">
                    Enterprise
                    <Shield className="w-4 h-4 text-amber-400" />
                  </h4>
                  {isEnterprise && (
                    <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-500/20 text-amber-300 border border-amber-500/30">
                      Current Plan
                    </span>
                  )}
                </div>
                <p className="text-xs text-slate-400 mt-1">Advanced security, custom domain, compliance, and dedicated SLA.</p>
                <div className="mt-4">
                  <span className="text-3xl font-extrabold text-white">$99</span>
                  <span className="text-xs text-slate-400 ml-1">/ month</span>
                </div>

                <div className="mt-6 space-y-3 border-t border-slate-800 pt-6">
                  <p className="text-xs font-semibold text-amber-300 uppercase tracking-wider">Everything in Pro, plus:</p>
                  <ul className="space-y-2.5 text-xs text-slate-300">
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      SAML 2.0 &amp; OIDC Single Sign-On (SSO)
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      Custom domain whitelabeling
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      Audit log exports &amp; compliance tools
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      Custom data retention policies
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      99.9% uptime SLA guarantee
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-emerald-400 shrink-0" />
                      Dedicated enterprise account manager
                    </li>
                  </ul>
                </div>
              </div>

              <div className="mt-8 pt-4">
                <a
                  href="mailto:enterprise@taskflow.local?subject=TaskFlow%20Enterprise%20Inquiry"
                  className="w-full py-2.5 rounded-xl text-xs font-semibold bg-slate-800/80 hover:bg-slate-700 text-slate-200 border border-slate-700 transition flex items-center justify-center gap-2"
                >
                  <MailIcon className="w-3.5 h-3.5 text-amber-400" />
                  Contact Sales
                </a>
              </div>
            </div>
          </div>
        </div>

        {/* Feature Comparison Matrix */}
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-md">
          <h4 className="text-base font-bold text-white mb-4 flex items-center gap-2">
            <Layers className="w-4 h-4 text-indigo-400" />
            Plan Comparison Breakdown
          </h4>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-slate-800 text-slate-400 font-semibold">
                  <th className="pb-3 pr-4">Feature</th>
                  <th className="pb-3 px-4">Free ($0)</th>
                  <th className="pb-3 px-4 text-indigo-300">Pro ($19/mo)</th>
                  <th className="pb-3 pl-4 text-amber-300">Enterprise ($99/mo)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 text-slate-300">
                <tr>
                  <td className="py-3 pr-4 font-medium text-white">Team Members</td>
                  <td className="py-3 px-4">5 members max</td>
                  <td className="py-3 px-4 font-semibold text-white">Unlimited</td>
                  <td className="py-3 pl-4 font-semibold text-white">Unlimited</td>
                </tr>
                <tr>
                  <td className="py-3 pr-4 font-medium text-white">Spaces &amp; Projects</td>
                  <td className="py-3 px-4">1 project</td>
                  <td className="py-3 px-4 font-semibold text-white">Unlimited</td>
                  <td className="py-3 pl-4 font-semibold text-white">Unlimited</td>
                </tr>
                <tr>
                  <td className="py-3 pr-4 font-medium text-white">File &amp; Attachment Storage</td>
                  <td className="py-3 px-4">100 MB</td>
                  <td className="py-3 px-4">50 GB</td>
                  <td className="py-3 pl-4 font-semibold text-white">500 GB+</td>
                </tr>
                <tr>
                  <td className="py-3 pr-4 font-medium text-white">Live Video &amp; Voice Calls</td>
                  <td className="py-3 px-4 text-slate-500">—</td>
                  <td className="py-3 px-4 text-emerald-400 font-semibold">Included (LiveKit)</td>
                  <td className="py-3 pl-4 text-emerald-400 font-semibold">Included (LiveKit)</td>
                </tr>
                <tr>
                  <td className="py-3 pr-4 font-medium text-white">Webhooks &amp; API Integrations</td>
                  <td className="py-3 px-4 text-slate-500">—</td>
                  <td className="py-3 px-4 text-emerald-400">Full Access</td>
                  <td className="py-3 pl-4 text-emerald-400">Full Access</td>
                </tr>
                <tr>
                  <td className="py-3 pr-4 font-medium text-white">SAML SSO &amp; Custom Domain</td>
                  <td className="py-3 px-4 text-slate-500">—</td>
                  <td className="py-3 px-4 text-slate-500">—</td>
                  <td className="py-3 pl-4 text-emerald-400 font-semibold">Included</td>
                </tr>
                <tr>
                  <td className="py-3 pr-4 font-medium text-white">Stripe Checkout &amp; Portal</td>
                  <td className="py-3 px-4 text-slate-400">Upgrade to Pro</td>
                  <td className="py-3 px-4 text-emerald-400">Self-serve portal</td>
                  <td className="py-3 pl-4 text-emerald-400">Invoicing &amp; Portal</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};

function MailIcon(props: { className?: string }) {
  return (
    <svg 
      className={props.className || 'w-4 h-4'} 
      fill="none" 
      stroke="currentColor" 
      viewBox="0 0 24 24" 
      xmlns="http://www.w3.org/2000/svg"
    >
      <path 
        strokeLinecap="round" 
        strokeLinejoin="round" 
        strokeWidth={2} 
        d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" 
      />
    </svg>
  );
}
