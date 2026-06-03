import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { FileJson, FileSpreadsheet, Download, ShieldCheck } from "lucide-react";
import { api, downloadBlob } from "../../lib/api";
import type { ExportDescriptor } from "../../types";
import { Button, GlassCard, PageHeader, cn } from "../../components/ui";
import { useAuth } from "../../auth/AuthContext";
import { formatBytes } from "../../lib/format";

type Format = "json" | "csv";

export function CompliancePage() {
  const { activeOrgId } = useAuth();
  const orgId = activeOrgId ?? undefined;
  const [format, setFormat] = useState<Format>("json");
  const [error, setError] = useState<string | null>(null);

  const run = useMutation({
    mutationFn: async () => {
      if (!orgId) throw new Error("No workspace selected");
      const desc = await api<ExportDescriptor>(`/admin/org/export?format=${format}`, {
        method: "POST",
        orgId,
      });
      const blob = await downloadBlob(desc.download_url, orgId);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `compliance-export.${desc.format}`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      return desc;
    },
    onError: (e) => setError(e instanceof Error ? e.message : "Export failed"),
  });

  return (
    <div>
      <PageHeader
        title="Compliance Export"
        subtitle="Generate a complete export of workspace messages, members, and media logs"
      />

      <GlassCard className="mb-6 p-6">
        <h3 className="mb-1 font-display text-sm font-semibold text-ink">Export format</h3>
        <p className="mb-4 text-sm text-muted">
          Exports are generated on demand and delivered over a short-lived signed link.
        </p>

        <div className="grid gap-3 sm:grid-cols-2">
          <FormatCard
            active={format === "json"}
            onClick={() => setFormat("json")}
            icon={<FileJson size={20} />}
            title="JSON bundle"
            hint="Full structured export: org, members, messages, media logs"
          />
          <FormatCard
            active={format === "csv"}
            onClick={() => setFormat("csv")}
            icon={<FileSpreadsheet size={20} />}
            title="CSV (messages)"
            hint="Spreadsheet-friendly message log"
          />
        </div>

        <div className="mt-5 flex items-center gap-3">
          <Button
            variant="primary"
            loading={run.isPending}
            onClick={() => {
              setError(null);
              run.mutate();
            }}
          >
            <Download size={16} /> Generate &amp; download
          </Button>
          {run.isSuccess && run.data && (
            <span className="text-sm text-emerald">
              {formatBytes(run.data.size_bytes)} exported ✓
            </span>
          )}
        </div>
        {error && <p className="mt-3 text-sm text-rose">{error}</p>}
      </GlassCard>

      <GlassCard className="p-6">
        <div className="flex items-start gap-3">
          <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-emerald/15 text-emerald">
            <ShieldCheck size={20} />
          </div>
          <div className="text-sm text-muted">
            <p className="font-medium text-ink">What's included</p>
            <ul className="mt-2 list-inside list-disc space-y-1">
              <li>Organization metadata &amp; current retention policy</li>
              <li>All members with roles and join dates</li>
              <li>Every message (including edited / deleted markers)</li>
              <li>Media logs — uploaded file metadata</li>
            </ul>
            <p className="mt-3 text-xs text-faint">
              Each export action is recorded in the platform audit trail.
            </p>
          </div>
        </div>
      </GlassCard>
    </div>
  );
}

function FormatCard({
  active,
  onClick,
  icon,
  title,
  hint,
}: {
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
  title: string;
  hint: string;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "ring-focus glass-hover flex items-start gap-3 rounded-2xl border p-4 text-left transition",
        active ? "border-primary/60 bg-primary/10" : "border-white/8 bg-white/[0.02]",
      )}
    >
      <div className={cn("mt-0.5", active ? "text-primary" : "text-faint")}>{icon}</div>
      <div>
        <div className="font-medium text-ink">{title}</div>
        <div className="text-xs text-muted">{hint}</div>
      </div>
    </button>
  );
}
