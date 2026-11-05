import { useCallback, useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Radio, ScrollText } from "lucide-react";
import { useAuth } from "../../auth/AuthContext";
import { api } from "../../lib/api";
import { formatDate, relativeTime } from "../../lib/format";
import { normalizeAuditLog, useAuditStream, type RawAuditLog } from "../../lib/useAuditStream";
import type { AuditLog } from "../../types";
import {
  Badge,
  EmptyState,
  ErrorState,
  GlassCard,
  LoadingState,
  PageHeader,
  SearchInput,
  Table,
  Td,
  Th,
} from "../../components/ui";

type CategoryFilter = "all" | "members" | "security" | "channels" | "settings" | "tasks";

const CATEGORIES: { id: CategoryFilter; label: string }[] = [
  { id: "all", label: "All Events" },
  { id: "members", label: "Members & Roles" },
  { id: "security", label: "Security & Sessions" },
  { id: "channels", label: "Channels & Moderation" },
  { id: "settings", label: "Compliance & Settings" },
  { id: "tasks", label: "Tasks & Projects" },
];

export function categoryForAudit(log: AuditLog): CategoryFilter {
  const a = log.action.toLowerCase();
  const r = log.resource_type.toLowerCase();
  if (a.includes("member") || a.includes("invite") || a.includes("join_request") || r === "member" || r === "invite") {
    return "members";
  }
  if (a.includes("session") || a.includes("sso") || a.includes("auth") || r === "session") {
    return "security";
  }
  if (a.includes("channel") || a.includes("message") || r === "channel") {
    return "channels";
  }
  if (a.includes("retention") || a.includes("compliance") || a.includes("branding") || a.includes("org.") || r === "org") {
    return "settings";
  }
  return "tasks";
}

export function toneForAuditAction(action: string): "rose" | "amber" | "emerald" | "blue" | "purple" | "slate" {
  const a = action.toLowerCase();
  if (a.includes("delete") || a.includes("remove") || a.includes("revoke") || a.includes("suspend")) return "rose";
  if (a.includes("lock") || a.includes("archive") || a.includes("purge")) return "amber";
  if (a.includes("create") || a.includes("invite") || a.includes("accept") || a.includes("activate")) return "emerald";
  if (a.includes("role") || a.includes("export") || a.includes("retention") || a.includes("branding")) return "blue";
  if (a.includes("session")) return "purple";
  return "slate";
}

export function OrgAuditPage() {
  const { activeOrg } = useAuth();
  const orgId = activeOrg?.id;
  const queryClient = useQueryClient();

  const [search, setSearch] = useState("");
  const [category, setCategory] = useState<CategoryFilter>("all");
  const [recentLiveIds, setRecentLiveIds] = useState<Set<string>>(new Set());

  const { data, isLoading, error } = useQuery({
    queryKey: ["org", orgId, "audit-log"],
    queryFn: async () => {
      const rows = await api<RawAuditLog[]>(`/organizations/${orgId}/audit-log?limit=200`, { orgId });
      return (rows ?? []).map(normalizeAuditLog);
    },
    enabled: !!orgId,
  });

  const handleAuditCreated = useCallback(
    (entry: AuditLog) => {
      if (!orgId) return;
      setRecentLiveIds((prev) => {
        const next = new Set(prev);
        next.add(entry.id);
        return next;
      });
      queryClient.setQueryData<AuditLog[]>(["org", orgId, "audit-log"], (old) => {
        const list = old ?? [];
        if (list.some((x) => x.id === entry.id)) return list;
        return [entry, ...list];
      });
    },
    [orgId, queryClient],
  );

  const { connected, liveCount } = useAuditStream(orgId, handleAuditCreated);

  const filtered = useMemo(() => {
    const logs = data ?? [];
    const q = search.trim().toLowerCase();
    return logs.filter((l) => {
      if (category !== "all" && categoryForAudit(l) !== category) return false;
      if (!q) return true;
      return (
        l.action.toLowerCase().includes(q) ||
        l.user_email.toLowerCase().includes(q) ||
        l.resource_type.toLowerCase().includes(q) ||
        (l.details ?? "").toLowerCase().includes(q)
      );
    });
  }, [data, search, category]);

  if (!activeOrg) {
    return <EmptyState icon={<ScrollText size={32} />} title="No organization selected" />;
  }

  return (
    <div>
      <PageHeader
        title="Workspace Audit Log"
        subtitle={`Real-time security and governance trail for ${activeOrg.name}`}
        actions={
          <div className="flex items-center gap-2">
            <Badge tone={connected ? "emerald" : "slate"}>
              <span className="inline-flex items-center gap-1.5">
                <Radio size={12} className={connected ? "animate-pulse" : ""} />
                {connected ? "Live Stream Connected" : "Reconnecting…"}
              </span>
            </Badge>
            {liveCount > 0 && <Badge tone="purple">+{liveCount} live</Badge>}
          </div>
        }
      />

      <GlassCard className="p-5">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <SearchInput
            placeholder="Filter by action, actor email, resource, or details…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full max-w-sm"
          />
          <div className="flex flex-wrap gap-1.5">
            {CATEGORIES.map((c) => (
              <button
                key={c.id}
                type="button"
                onClick={() => setCategory(c.id)}
                className={`rounded-xl px-3 py-1.5 text-xs font-medium transition ${
                  category === c.id
                    ? "bg-primary text-white shadow-sm"
                    : "bg-white/5 text-muted hover:bg-white/10 hover:text-ink"
                }`}
              >
                {c.label}
              </button>
            ))}
          </div>
        </div>

        {isLoading ? (
          <LoadingState />
        ) : error ? (
          <ErrorState message={(error as Error).message} />
        ) : filtered.length === 0 ? (
          <EmptyState
            icon={<ScrollText size={32} />}
            title="No matching audit entries"
            hint="Administrative actions, role updates, and session revocations will appear here in real time."
          />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>Action</Th>
                <Th>Actor</Th>
                <Th>Resource</Th>
                <Th>Details</Th>
                <Th className="text-right">When</Th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((l) => {
                const isLive = recentLiveIds.has(l.id);
                return (
                  <tr
                    key={l.id}
                    className={`transition hover:bg-white/[0.03] ${isLive ? "bg-emerald-500/[0.06]" : ""}`}
                  >
                    <Td>
                      <div className="flex items-center gap-2">
                        <Badge tone={toneForAuditAction(l.action)}>{l.action}</Badge>
                        {isLive && <Badge tone="emerald">LIVE</Badge>}
                      </div>
                    </Td>
                    <Td className="text-muted">{l.user_email || "system"}</Td>
                    <Td className="text-muted">
                      {l.resource_type}
                      {l.resource_id && (
                        <span className="ml-1 text-xs text-faint">#{l.resource_id.slice(0, 8)}</span>
                      )}
                    </Td>
                    <Td className="max-w-xs truncate text-muted">{l.details ?? "—"}</Td>
                    <Td className="text-right text-muted" title={formatDate(l.created_at)}>
                      {relativeTime(l.created_at)}
                    </Td>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        )}
      </GlassCard>
    </div>
  );
}

