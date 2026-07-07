import { useState, useEffect } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { CreditCard, ShieldAlert, Sparkles, Building, BarChart3, Database } from "lucide-react";
import { api } from "../../lib/api";
import { Button, GlassCard, PageHeader } from "../../components/ui";
import { useAuth } from "../../auth/AuthContext";
import type { AdminOrg, OrgMember } from "../../types";

export function BillingPage() {
  const { activeOrgId } = useAuth();
  const orgId = activeOrgId ?? undefined;
  const [error, setError] = useState<string | null>(null);

  // 1. Fetch organization details
  const { data: org, refetch: refetchOrg } = useQuery<AdminOrg>({
    queryKey: ["org", orgId],
    queryFn: async () => {
      if (!orgId) throw new Error("No workspace selected");
      return api<AdminOrg>(`/organizations/${orgId}`, { orgId });
    },
    enabled: !!orgId,
  });

  // 2. Fetch members to count usage
  const { data: members } = useQuery<OrgMember[]>({
    queryKey: ["org-members", orgId],
    queryFn: async () => {
      if (!orgId) throw new Error("No workspace selected");
      return api<OrgMember[]>(`/organizations/${orgId}/members`, { orgId });
    },
    enabled: !!orgId,
  });

  // 3. Initiate Checkout Session
  const checkout = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No workspace selected");
      const resp = await api<{ url: string }>(`/org/billing/checkout`, {
        method: "POST",
        orgId,
      });
      return resp.url;
    },
    onSuccess: (url) => {
      window.location.href = url;
    },
    onError: (e) => setError(e instanceof Error ? e.message : "Checkout redirect failed"),
  });

  // 4. Initiate Customer Portal
  const portal = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No workspace selected");
      const resp = await api<{ url: string }>(`/org/billing/portal`, {
        method: "POST",
        orgId,
      });
      return resp.url;
    },
    onSuccess: (url) => {
      window.location.href = url;
    },
    onError: (e) => setError(e instanceof Error ? e.message : "Portal redirect failed"),
  });

  // Mock checkout success handler from query params
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get("mock_checkout") === "success" || params.get("stripe_session_id")) {
      refetchOrg();
    }
  }, [refetchOrg]);

  if (!org) {
    return (
      <div className="flex h-64 items-center justify-center text-muted">
        Loading organization details...
      </div>
    );
  }

  const tier = org.subscription_tier?.toLowerCase() ?? "free";
  const memberLimit = 5;
  const projectLimit = 1;
  const storageLimitMB = 100;

  const currentMembersCount = members?.length ?? 0;
  // Fallback estimates if stats are not loaded
  const currentProjectsCount = org.member_count > 0 ? 1 : 0; // Simple stub for UI layout
  const currentStorageMB = org.message_count > 0 ? 4.5 : 0.0;

  return (
    <div>
      <PageHeader
        title="Billing &amp; Subscriptions"
        subtitle="Manage your organization's subscription plans, invoices, and feature limit tiers"
      />

      {error && (
        <div className="mb-6 rounded-2xl border border-rose/20 bg-rose/10 p-4 text-sm text-rose">
          {error}
        </div>
      )}

      {/* Plans Section */}
      <div className="mb-8 grid gap-6 md:grid-cols-3">
        {/* Free Plan Card */}
        <GlassCard className={`relative overflow-hidden p-6 border ${tier === "free" ? "border-primary/40 bg-white/[0.04]" : "border-white/5"}`}>
          {tier === "free" && (
            <div className="absolute right-3 top-3 rounded-full bg-white/10 px-2 py-0.5 text-xs text-ink font-medium">
              Current Plan
            </div>
          )}
          <h3 className="font-display text-lg font-bold text-ink">Free Tier</h3>
          <p className="text-xs text-muted mb-4">Best for small teams and prototypes</p>
          <div className="mb-4">
            <span className="text-3xl font-extrabold text-ink">$0</span>
            <span className="text-xs text-muted"> / month</span>
          </div>
          <ul className="text-xs text-muted space-y-2 mb-6">
            <li>✓ Up to 5 team members</li>
            <li>✓ 1 active project</li>
            <li>✓ 100MB shared storage</li>
            <li className="text-faint">✗ Webhooks &amp; API keys</li>
            <li className="text-faint">✗ Live video/audio calling</li>
            <li className="text-faint">✗ SAML Single Sign-On</li>
          </ul>
        </GlassCard>

        {/* Pro Plan Card */}
        <GlassCard className={`relative overflow-hidden p-6 border ${tier === "pro" ? "border-indigo-500/40 bg-indigo-500/5" : "border-white/5"}`}>
          {tier === "pro" && (
            <div className="absolute right-3 top-3 rounded-full bg-indigo-500/30 px-2 py-0.5 text-xs text-indigo-300 font-medium">
              Current Plan
            </div>
          )}
          <h3 className="font-display text-lg font-bold text-indigo-300 flex items-center gap-1">
            <Sparkles size={16} /> Pro Plan
          </h3>
          <p className="text-xs text-muted mb-4">For fast-growing collaboration teams</p>
          <div className="mb-4">
            <span className="text-3xl font-extrabold text-ink">$19</span>
            <span className="text-xs text-muted"> / month</span>
          </div>
          <ul className="text-xs text-muted space-y-2 mb-6">
            <li>✓ Unlimited members &amp; projects</li>
            <li>✓ 50GB workspace storage</li>
            <li>✓ Webhooks &amp; Custom Branding</li>
            <li>✓ Live video/audio calling</li>
            <li className="text-faint">✗ SAML Single Sign-On</li>
          </ul>
          {tier === "free" ? (
            <Button
              className="w-full"
              variant="primary"
              loading={checkout.isPending}
              onClick={() => checkout.mutate()}
            >
              Upgrade to Pro
            </Button>
          ) : tier === "pro" ? (
            <Button
              className="w-full"
              variant="subtle"
              loading={portal.isPending}
              onClick={() => portal.mutate()}
            >
              <CreditCard size={14} className="mr-1.5" /> Manage Card / Portal
            </Button>
          ) : null}
        </GlassCard>

        {/* Enterprise Card */}
        <GlassCard className={`relative overflow-hidden p-6 border ${tier === "enterprise" ? "border-amber-500/40 bg-amber-500/5" : "border-white/5"}`}>
          {tier === "enterprise" && (
            <div className="absolute right-3 top-3 rounded-full bg-amber-500/30 px-2 py-0.5 text-xs text-amber-300 font-medium">
              Current Plan
            </div>
          )}
          <h3 className="font-display text-lg font-bold text-amber-300 flex items-center gap-1">
            <Building size={16} /> Enterprise
          </h3>
          <p className="text-xs text-muted mb-4">Complete compliance and whitelabeling</p>
          <div className="mb-4">
            <span className="text-3xl font-extrabold text-ink">$99</span>
            <span className="text-xs text-muted"> / month</span>
          </div>
          <ul className="text-xs text-muted space-y-2 mb-6">
            <li>✓ All features in Pro plan</li>
            <li>✓ Enforced SAML / OIDC SSO</li>
            <li>✓ Dedicated custom domain mapping</li>
            <li>✓ Custom CNAME instructions</li>
            <li>✓ 24/7 Priority support SLA</li>
          </ul>
          {tier !== "enterprise" ? (
            <Button
              className="w-full border-amber-500/30 text-amber-300 hover:bg-amber-500/10"
              variant="subtle"
              onClick={() => alert("Please contact enterprise sales support at support@platform.com to configure contracts.")}
            >
              Contact Sales
            </Button>
          ) : (
            <Button
              className="w-full"
              variant="subtle"
              loading={portal.isPending}
              onClick={() => portal.mutate()}
            >
              <CreditCard size={14} className="mr-1.5" /> Manage Invoices
            </Button>
          )}
        </GlassCard>
      </div>

      {/* Usage Gauges */}
      <h3 className="mb-4 font-display text-base font-semibold text-ink flex items-center gap-2">
        <BarChart3 size={18} /> Plan Usage &amp; Workspace Quotas
      </h3>
      <div className="grid gap-6 md:grid-cols-3">
        {/* Members Gauge */}
        <GlassCard className="p-5 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-ink">Active Members</span>
              <span className="text-xs text-muted">
                {currentMembersCount} / {tier === "free" ? memberLimit : "Unlimited"}
              </span>
            </div>
            <div className="h-2 w-full rounded-full bg-white/5 overflow-hidden">
              <div
                className={`h-full rounded-full ${currentMembersCount >= memberLimit && tier === "free" ? "bg-rose" : "bg-primary"}`}
                style={{ width: `${tier === "free" ? (currentMembersCount / memberLimit) * 100 : 10}%` }}
              />
            </div>
          </div>
          {tier === "free" && currentMembersCount >= memberLimit && (
            <div className="mt-3 flex items-start gap-1.5 text-xs text-rose">
              <ShieldAlert size={14} className="shrink-0 mt-0.5" />
              <span>Workspace user limit reached. Upgrade to Pro to invite more team members.</span>
            </div>
          )}
        </GlassCard>

        {/* Projects Gauge */}
        <GlassCard className="p-5 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-ink">Active Projects</span>
              <span className="text-xs text-muted">
                {currentProjectsCount} / {tier === "free" ? projectLimit : "Unlimited"}
              </span>
            </div>
            <div className="h-2 w-full rounded-full bg-white/5 overflow-hidden">
              <div
                className={`h-full rounded-full ${currentProjectsCount >= projectLimit && tier === "free" ? "bg-rose" : "bg-primary"}`}
                style={{ width: `${tier === "free" ? (currentProjectsCount / projectLimit) * 100 : 10}%` }}
              />
            </div>
          </div>
          {tier === "free" && currentProjectsCount >= projectLimit && (
            <div className="mt-3 flex items-start gap-1.5 text-xs text-rose">
              <ShieldAlert size={14} className="shrink-0 mt-0.5" />
              <span>Project limits reached. Upgrade to Pro to configure multiple initiatives.</span>
            </div>
          )}
        </GlassCard>

        {/* Storage Gauge */}
        <GlassCard className="p-5 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-ink flex items-center gap-1"><Database size={14} /> Shared Storage</span>
              <span className="text-xs text-muted">
                {currentStorageMB.toFixed(1)}MB / {tier === "free" ? storageLimitMB : "50"} {tier === "free" ? "MB" : "GB"}
              </span>
            </div>
            <div className="h-2 w-full rounded-full bg-white/5 overflow-hidden">
              <div
                className="h-full rounded-full bg-primary"
                style={{ width: `${(currentStorageMB / storageLimitMB) * 100}%` }}
              />
            </div>
          </div>
          <div className="mt-3 text-xxs text-faint">
            Aggregated storage encompasses file attachments, images, and document logs uploaded in messages or tasks.
          </div>
        </GlassCard>
      </div>
    </div>
  );
}
