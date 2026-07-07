import { useState, useEffect } from "react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { Palette, Globe, Info, Lock } from "lucide-react";
import { api } from "../../lib/api";
import { Button, GlassCard, PageHeader } from "../../components/ui";
import { useAuth } from "../../auth/AuthContext";
import type { AdminOrg } from "../../types";

export function BrandingPage() {
  const { activeOrgId } = useAuth();
  const orgId = activeOrgId ?? undefined;

  const [logoUrl, setLogoUrl] = useState("");
  const [brandColorHex, setBrandColorHex] = useState("#4f46e5");
  const [customDomain, setCustomDomain] = useState("");
  const [allowedDomains, setAllowedDomains] = useState("");

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
      setLogoUrl(org.logo_url ?? "");
      setBrandColorHex(org.brand_color_hex ?? "#4f46e5");
      setCustomDomain(org.custom_domain ?? "");
      setAllowedDomains(org.allowed_email_domains ?? "");
    }
  }, [org]);

  // 2. Branding mutation
  const saveBranding = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No workspace selected");
      return api<AdminOrg>(`/organizations/${orgId}/branding`, {
        method: "PUT",
        orgId,
        body: { logoUrl, brandColorHex },
      });
    },
    onSuccess: () => {
      setMessage({ type: "success", text: "Custom branding settings updated successfully!" });
      refetch();
    },
    onError: (e) => {
      setMessage({ type: "error", text: e instanceof Error ? e.message : "Failed to update branding settings" });
    },
  });

  // 3. Domain settings mutation
  const saveDomainSettings = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No workspace selected");
      return api<AdminOrg>(`/organizations/${orgId}/domain-settings`, {
        method: "PUT",
        orgId,
        body: { customDomain, allowedEmailDomains: allowedDomains },
      });
    },
    onSuccess: () => {
      setMessage({ type: "success", text: "Domain and auto-provisioning settings saved successfully!" });
      refetch();
    },
    onError: (e) => {
      setMessage({ type: "error", text: e instanceof Error ? e.message : "Failed to save domain settings" });
    },
  });

  if (!org) {
    return (
      <div className="flex h-64 items-center justify-center text-muted">
        Loading organization details...
      </div>
    );
  }

  const isFree = (org.subscription_tier?.toLowerCase() ?? "free") === "free";

  return (
    <div>
      <PageHeader
        title="Custom Branding &amp; Domains"
        subtitle="Whitelabel the platform for your organization with custom domains, logo assets, and brands"
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

      {isFree && (
        <div className="mb-6 rounded-2xl border border-indigo-500/20 bg-indigo-500/10 p-5 flex items-start gap-4">
          <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-indigo-500/20 text-indigo-300">
            <Lock size={20} />
          </div>
          <div>
            <h4 className="font-semibold text-ink text-sm">Feature Locked (Free Tier)</h4>
            <p className="text-xs text-muted mt-1 mb-3">
              Custom branding, whitelabeling accent colors, and CNAME domain routing require a **Pro Plan** or **Enterprise Plan**.
            </p>
            <a href="/org/billing" className="text-xs font-semibold text-indigo-400 hover:underline">
              Upgrade subscription now &rarr;
            </a>
          </div>
        </div>
      )}

      <div className="grid gap-6 md:grid-cols-2">
        {/* Branding assets */}
        <GlassCard className="p-6">
          <h3 className="mb-4 font-display text-sm font-semibold text-ink flex items-center gap-2">
            <Palette size={16} /> Whitelabel &amp; UI Customization
          </h3>

          <div className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-muted mb-1">Company Logo URL</label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="https://assets.acme.com/logo.png"
                  value={logoUrl}
                  disabled={isFree}
                  onChange={(e) => setLogoUrl(e.target.value)}
                  className="w-full rounded-xl border border-white/8 bg-white/[0.03] px-4 py-2 text-sm text-ink outline-none ring-focus transition focus:border-primary/50 disabled:opacity-40"
                />
              </div>
              <p className="text-xxs text-muted mt-1">
                Provide a secure HTTPS URL pointing to a transparent PNG or SVG logo image.
              </p>
            </div>

            <div>
              <label className="block text-xs font-semibold text-muted mb-1">Accent Brand Color</label>
              <div className="flex items-center gap-3">
                <input
                  type="color"
                  value={brandColorHex}
                  disabled={isFree}
                  onChange={(e) => setBrandColorHex(e.target.value)}
                  className="h-9 w-9 shrink-0 cursor-pointer rounded-lg border-0 bg-transparent disabled:opacity-40"
                />
                <input
                  type="text"
                  placeholder="#4f46e5"
                  value={brandColorHex}
                  disabled={isFree}
                  onChange={(e) => setBrandColorHex(e.target.value)}
                  className="w-32 rounded-xl border border-white/8 bg-white/[0.03] px-3 py-2 text-sm text-ink outline-none ring-focus transition focus:border-primary/50 disabled:opacity-40"
                />
              </div>
              <p className="text-xxs text-muted mt-1">
                This color will be used for buttons, active link tabs, and UI highlights.
              </p>
            </div>

            {logoUrl && !isFree && (
              <div className="mt-4 border border-white/5 rounded-2xl p-4 bg-white/[0.01]">
                <span className="block text-xxs font-semibold text-muted mb-2">Live Theme Preview</span>
                <div className="flex items-center justify-between p-3 rounded-xl border border-white/8 bg-white/[0.02]">
                  <img src={logoUrl} alt="Logo Preview" className="h-6 object-contain" />
                  <button
                    className="rounded-lg px-3 py-1.5 text-xs text-white font-medium"
                    style={{ backgroundColor: brandColorHex }}
                  >
                    Action Button
                  </button>
                </div>
              </div>
            )}

            <Button
              variant="primary"
              disabled={isFree}
              loading={saveBranding.isPending}
              onClick={() => {
                setMessage(null);
                saveBranding.mutate();
              }}
              className="mt-2"
            >
              Save Branding Options
            </Button>
          </div>
        </GlassCard>

        {/* Custom Domains & Provisioning */}
        <GlassCard className="p-6 flex flex-col justify-between">
          <div>
            <h3 className="mb-4 font-display text-sm font-semibold text-ink flex items-center gap-2">
              <Globe size={16} /> Domain Settings &amp; Auto-Provisioning
            </h3>

            <div className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-muted mb-1">Custom Domain Name</label>
                <input
                  type="text"
                  placeholder="chat.acme.com"
                  value={customDomain}
                  disabled={isFree}
                  onChange={(e) => setCustomDomain(e.target.value)}
                  className="w-full rounded-xl border border-white/8 bg-white/[0.03] px-4 py-2 text-sm text-ink outline-none ring-focus transition focus:border-primary/50 disabled:opacity-40"
                />
                <p className="text-xxs text-muted mt-1">
                  Point a CNAME record in your DNS server to: <code className="text-indigo-400">cname.platform.com</code>
                </p>
              </div>

              <div>
                <label className="block text-xs font-semibold text-muted mb-1">Allowed Email Domains</label>
                <input
                  type="text"
                  placeholder="acme.com, acme.co"
                  value={allowedDomains}
                  onChange={(e) => setAllowedDomains(e.target.value)}
                  className="w-full rounded-xl border border-white/8 bg-white/[0.03] px-4 py-2 text-sm text-ink outline-none ring-focus transition focus:border-primary/50"
                />
                <p className="text-xxs text-muted mt-1">
                  Comma-separated domains. Users signing up with these domains join the workspace automatically.
                </p>
              </div>

              <div className="rounded-2xl border border-white/5 bg-white/[0.01] p-4 flex items-start gap-2.5">
                <Info size={16} className="text-primary shrink-0 mt-0.5" />
                <div className="text-xxs text-muted leading-relaxed">
                  <strong>Domain Routing note:</strong> Once customized, users typing your custom URL directly will be routed straight to your workspace branding page bypassing general tenant discovery search checks.
                </div>
              </div>
            </div>
          </div>

          <Button
            variant="primary"
            loading={saveDomainSettings.isPending}
            onClick={() => {
              setMessage(null);
              saveDomainSettings.mutate();
            }}
            className="mt-6 align-self-start"
          >
            Save Domain Settings
          </Button>
        </GlassCard>
      </div>
    </div>
  );
}
