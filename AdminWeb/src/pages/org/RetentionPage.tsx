import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Clock, Trash2, Infinity as InfinityIcon, Check } from "lucide-react";
import { api } from "../../lib/api";
import type { RetentionPolicy } from "../../types";
import { Button, ErrorState, GlassCard, LoadingState, PageHeader, cn } from "../../components/ui";
import { useAuth } from "../../auth/AuthContext";

interface PurgeResult {
  deleted_count: number;
}

const PRESETS: { label: string; days: number | null; hint: string }[] = [
  { label: "30 days", days: 30, hint: "Aggressive — keeps a month" },
  { label: "90 days", days: 90, hint: "Balanced quarter" },
  { label: "1 year", days: 365, hint: "Annual compliance" },
  { label: "Indefinite", days: null, hint: "Never auto-delete" },
];

export function RetentionPage() {
  const qc = useQueryClient();
  const { activeOrgId } = useAuth();
  const orgId = activeOrgId ?? undefined;

  const { data, isLoading, error } = useQuery({
    queryKey: ["org", orgId, "retention"],
    queryFn: () => api<RetentionPolicy>("/admin/org/retention", { orgId }),
    enabled: !!orgId,
  });

  const [selected, setSelected] = useState<number | null | undefined>(undefined);
  useEffect(() => {
    if (data) setSelected(data.retention_days);
  }, [data]);

  const save = useMutation({
    mutationFn: (days: number | null) =>
      api<RetentionPolicy>("/admin/org/retention", { method: "PUT", body: { retention_days: days }, orgId }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["org", orgId, "retention"] }),
  });

  const purge = useMutation({
    mutationFn: () => api<PurgeResult>("/admin/org/retention/purge-now", { method: "POST", orgId }),
  });

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState message={(error as Error).message} />;

  const dirty = selected !== data?.retention_days;
  const current = data?.retention_days;

  return (
    <div>
      <PageHeader
        title="Message Retention"
        subtitle="Automatically delete messages older than the selected window"
      />

      <GlassCard className="mb-6 p-6">
        <p className="mb-4 text-sm text-muted">
          Current policy:{" "}
          <span className="font-medium text-ink">
            {current == null ? "Retain indefinitely" : `Delete after ${current} days`}
          </span>
        </p>

        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {PRESETS.map((p) => {
            const active = selected === p.days;
            return (
              <button
                key={p.label}
                onClick={() => setSelected(p.days)}
                className={cn(
                  "ring-focus glass-hover rounded-2xl border p-4 text-left transition",
                  active
                    ? "border-primary/60 bg-primary/10"
                    : "border-white/8 bg-white/[0.02]",
                )}
              >
                <div className="mb-2 flex items-center justify-between">
                  {p.days == null ? (
                    <InfinityIcon size={18} className={active ? "text-primary" : "text-faint"} />
                  ) : (
                    <Clock size={18} className={active ? "text-primary" : "text-faint"} />
                  )}
                  {active && <Check size={16} className="text-primary" />}
                </div>
                <div className="font-display text-lg font-bold text-ink">{p.label}</div>
                <div className="text-xs text-muted">{p.hint}</div>
              </button>
            );
          })}
        </div>

        <div className="mt-5 flex items-center gap-3">
          <Button
            variant="primary"
            disabled={!dirty}
            loading={save.isPending}
            onClick={() => selected !== undefined && save.mutate(selected)}
          >
            Save policy
          </Button>
          {save.isSuccess && !dirty && <span className="text-sm text-emerald">Saved ✓</span>}
        </div>
      </GlassCard>

      <GlassCard className="p-6">
        <div className="flex items-center justify-between gap-4">
          <div>
            <h3 className="font-display text-sm font-semibold text-ink">Run purge now</h3>
            <p className="mt-1 text-sm text-muted">
              Immediately delete messages already older than the saved window. This cannot be undone.
            </p>
          </div>
          <Button
            variant="danger"
            loading={purge.isPending}
            disabled={current == null}
            onClick={() => {
              if (confirm("Permanently delete all messages older than the retention window?")) purge.mutate();
            }}
          >
            <Trash2 size={15} /> Purge now
          </Button>
        </div>
        {purge.isSuccess && (
          <p className="mt-3 text-sm text-emerald">
            Purged {purge.data?.deleted_count ?? 0} message(s).
          </p>
        )}
        {current == null && (
          <p className="mt-3 text-xs text-faint">Set a finite retention window above to enable purging.</p>
        )}
      </GlassCard>
    </div>
  );
}
