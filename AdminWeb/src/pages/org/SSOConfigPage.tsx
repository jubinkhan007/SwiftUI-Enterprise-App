import { useState, useEffect } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { Server, Key, Lock, AlertTriangle } from "lucide-react";
import { api } from "../../lib/api";
import { Button, GlassCard, PageHeader } from "../../components/ui";
import { useAuth } from "../../auth/AuthContext";
import type { AdminOrg } from "../../types";

export function SSOConfigPage() {
  const { activeOrgId } = useAuth();
  const orgId = activeOrgId ?? undefined;

  const [ssoEnabled, setSsoEnabled] = useState(false);
  const [ssoIdpUrl, setSsoIdpUrl] = useState("");
  const [ssoEntityId, setSsoEntityId] = useState("");
  const [ssoCertificate, setSsoCertificate] = useState("");

  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // 1. Fetch organization details
  const { data: org, refetch } = useQuery<AdminOrg>({
    queryKey: ["org", orgId],
    queryFn: async () => {
      if (!orgId) throw new Error("No workspace selected");
      return api<AdminOrg>(`/organizations/${orgId}`, { orgId });
    },
    enabled: !!orgId,
  });

  useEffect(() => {
    if (org) {
      setSsoEnabled(org.sso_enabled ?? false);
      setSsoIdpUrl(org.sso_idp_url ?? "");
      setSsoEntityId(org.sso_entity_id ?? "");
      setSsoCertificate(org.sso_certificate ?? "");
    }
  }, [org]);

  // 2. Save SSO settings mutation
  const saveSSO = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No workspace selected");
      return api<AdminOrg>(`/organizations/${orgId}/sso-settings`, {
        method: "PUT",
        orgId,
        body: {
          ssoEnabled,
          ssoIdpUrl,
          ssoEntityId,
          ssoCertificate,
        },
      });
    },
    onSuccess: () => {
      setMessage({ type: "success", text: "Enterprise SAML SSO configuration updated successfully!" });
      refetch();
    },
    onError: (e) => {
      setMessage({ type: "error", text: e instanceof Error ? e.message : "Failed to save SSO configuration" });
    },
  });

  if (!org) {
    return (
      <div className="flex h-64 items-center justify-center text-muted">
        Loading organization details...
      </div>
    );
  }

  const isEnterprise = (org.subscription_tier?.toLowerCase() ?? "free") === "enterprise";

  return (
    <div>
      <PageHeader
        title="Enterprise SSO Integration"
        subtitle="Configure SAML 2.0 Identity Provider authentication to manage workspace team member logins"
      />

      {message && (
        <div
          className={`mb-6 rounded-2xl border p-4 text-sm ${
            message.type === "success"
              ? "border-emerald/20 bg-emerald/10 text-emerald"
              : "border-rose/20 bg-rose/10 text-rose"
          }`}
        >
          {message.text}
        </div>
      )}

      {!isEnterprise && (
        <div className="mb-6 rounded-2xl border border-amber-500/20 bg-amber-500/10 p-5 flex items-start gap-4">
          <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-amber-500/20 text-amber-300">
            <Lock size={20} />
          </div>
          <div>
            <h4 className="font-semibold text-ink text-sm">Enterprise Feature Locked</h4>
            <p className="text-xs text-muted mt-1 mb-3">
              Single Sign-On (SSO) integrations require an active **Enterprise subscription plan**. Contact system administration to upgrade your workspace contract limits.
            </p>
            <a href="/org/billing" className="text-xs font-semibold text-amber-400 hover:underline">
              View Enterprise billing info &rarr;
            </a>
          </div>
        </div>
      )}

      <div className="grid gap-6 md:grid-cols-3">
        {/* Config forms */}
        <div className="md:col-span-2 space-y-6">
          <GlassCard className="p-6">
            <h3 className="mb-4 font-display text-sm font-semibold text-ink flex items-center gap-2">
              <Server size={16} /> Identity Provider Configuration (SAML 2.0)
            </h3>

            <div className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-muted mb-1">IdP Single Sign-On Target URL</label>
                <input
                  type="text"
                  placeholder="https://sso.okta.com/app/v1/sso/saml"
                  value={ssoIdpUrl}
                  disabled={!isEnterprise}
                  onChange={(e) => setSsoIdpUrl(e.target.value)}
                  className="w-full rounded-xl border border-white/8 bg-white/[0.03] px-4 py-2 text-sm text-ink outline-none ring-focus transition focus:border-primary/50 disabled:opacity-40"
                />
                <p className="text-xxs text-muted mt-1">
                  The target endpoint on your Identity Provider where authentication request SAML tokens are sent.
                </p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-muted mb-1">IdP Entity ID (Issuer URI)</label>
                <input
                  type="text"
                  placeholder="urn:amazon:cognito:sp:us-east-1"
                  value={ssoEntityId}
                  disabled={!isEnterprise}
                  onChange={(e) => setSsoEntityId(e.target.value)}
                  className="w-full rounded-xl border border-white/8 bg-white/[0.03] px-4 py-2 text-sm text-ink outline-none ring-focus transition focus:border-primary/50 disabled:opacity-40"
                />
                <p className="text-xxs text-muted mt-1">
                  The unique global identifier mapping your SP metadata profile to the Identity Provider.
                </p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-muted mb-1">SAML Signing Certificate (PEM)</label>
                <textarea
                  placeholder="-----BEGIN CERTIFICATE-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...\n-----END CERTIFICATE-----"
                  value={ssoCertificate}
                  disabled={!isEnterprise}
                  onChange={(e) => setSsoCertificate(e.target.value)}
                  rows={6}
                  className="w-full rounded-xl border border-white/8 bg-white/[0.03] px-4 py-2 text-xs font-mono text-ink outline-none ring-focus transition focus:border-primary/50 disabled:opacity-40 resize-y"
                />
                <p className="text-xxs text-muted mt-1">
                  Paste the raw X.509 public signing key certificate supplied by your IdP.
                </p>
              </div>
            </div>
          </GlassCard>

          <GlassCard className="p-6">
            <h3 className="mb-4 font-display text-sm font-semibold text-ink flex items-center gap-2">
              <Key size={16} /> Enforcement Rules &amp; Security Toggles
            </h3>

            <div className="flex items-start gap-3">
              <input
                type="checkbox"
                id="ssoEnabled"
                checked={ssoEnabled}
                disabled={!isEnterprise || !ssoIdpUrl || !ssoEntityId}
                onChange={(e) => setSsoEnabled(e.target.checked)}
                className="mt-1 h-4 w-4 cursor-pointer rounded border-white/8 bg-white/[0.03] text-primary focus:ring-focus disabled:opacity-40"
              />
              <div>
                <label htmlFor="ssoEnabled" className={`text-sm font-medium ${!isEnterprise ? "text-muted" : "text-ink"}`}>
                  Enforce Single Sign-On (SSO) login for all team members
                </label>
                <p className="text-xs text-muted mt-1">
                  When enabled, standard username/password logins are blocked for workspace members. They must authenticate via the configured Identity Provider.
                </p>
                {!ssoIdpUrl && (
                  <p className="text-xxs text-rose mt-1">
                    Please configure SSO target URLs and entity IDs before turning on validation enforcement.
                  </p>
                )}
              </div>
            </div>

            <div className="mt-6 flex gap-3">
              <Button
                variant="primary"
                disabled={!isEnterprise}
                loading={saveSSO.isPending}
                onClick={() => {
                  setMessage(null);
                  saveSSO.mutate();
                }}
              >
                Save SSO Configuration
              </Button>
            </div>
          </GlassCard>
        </div>

        {/* Sidebar instructions */}
        <div className="space-y-6">
          <GlassCard className="p-6">
            <h4 className="font-display text-xs font-bold uppercase tracking-wider text-muted mb-3">Service Provider (SP) Metadata</h4>
            <div className="space-y-3 text-xxs text-muted leading-relaxed">
              <p>
                Configure the following parameters in your Identity Provider (e.g. Okta, Azure AD, OneLogin):
              </p>
              <div>
                <span className="block font-semibold text-ink">Single Sign-On URL (ACS)</span>
                <code className="block bg-white/5 p-1.5 rounded mt-1 border border-white/8 text-primary overflow-x-auto select-all">
                  https://api.platform.com/api/sso/saml/acs
                </code>
              </div>
              <div>
                <span className="block font-semibold text-ink">Audience URI (SP Entity ID)</span>
                <code className="block bg-white/5 p-1.5 rounded mt-1 border border-white/8 text-primary overflow-x-auto select-all">
                  https://api.platform.com/api/sso/saml/metadata
                </code>
              </div>
              <div>
                <span className="block font-semibold text-ink">NameID Format</span>
                <code className="block bg-white/5 p-1.5 rounded mt-1 border border-white/8 text-ink">
                  EmailAddress
                </code>
              </div>
            </div>
          </GlassCard>

          <GlassCard className="p-6">
            <h4 className="font-display text-xs font-bold uppercase tracking-wider text-muted mb-2 flex items-center gap-1">
              <AlertTriangle size={14} className="text-amber-500" /> Cautionary Advice
            </h4>
            <p className="text-xxs text-muted leading-relaxed">
              Before checking "Enforce SSO", test signups inside a private/incognito window. Locking standard credential logins can isolate your administrators if incorrect XML configurations are saved.
            </p>
          </GlassCard>
        </div>
      </div>
    </div>
  );
}
