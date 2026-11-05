import { useCallback, useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Radio, ScrollText } from "lucide-react";
import { useAuth } from "../../auth/AuthContext";
import { api } from "../../lib/api";
import { useAuditStream } from "../../lib/useAuditStream";
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
import { relativeTime, formatDate } from "../../lib/format";
import { toneForAuditAction } from "../org/OrgAuditPage";

export function AuditPage() {
  const { activeOrg } = useAuth();
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [recentLiveIds, setRecentLiveIds] = useState<Set<string>>(new Set());

  const { data, isLoading, error } = useQuery({
    queryKey: ["admin", "audit"],
    queryFn: () => api<AuditLog[]>("/admin/audit?limit=300"),
    refetchInterval: 20000,
  });

  const handleAuditCreated = useCallback(
    (entry: AuditLog) => {
      setRecentLiveIds((prev) => {
        const next = new Set(prev);
        next.add(entry.id);
        return next;
      });
      queryClient.setQueryData<AuditLog[]>(["admin", "audit"], (old) => {
        const list = old ?? [];
        if (list.some((x) => x.id === entry.id)) return list;
        return [entry, ...list];
      });
    },
    [queryClient],
  );

  const { connected, liveCount } = useAuditStream(activeOrg?.id, handleAuditCreated);

  const filtered = useMemo(() => {
    const logs = data ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return logs;
    return logs.filter(
      (l) =>
        l.action.toLowerCase().includes(q) ||
        l.user_email.toLowerCase().includes(q) ||
        l.resource_type.toLowerCase().includes(q) ||
        (l.details ?? "").toLowerCase().includes(q),
    );
  }, [data, search]);

  return (
    <div>
      <PageHeader
        title="Audit Trail"
        subtitle="Platform-wide record of administrative activity"
        actions={
          activeOrg ? (
            <div className="flex items-center gap-2">
              <Badge tone={connected ? "emerald" : "slate"}>
                <span className="inline-flex items-center gap-1.5">
                  <Radio size={12} className={connected ? "animate-pulse" : ""} />
                  {connected ? `Live (${activeOrg.name})` : "Polling"}
                </span>
              </Badge>
              {liveCount > 0 && <Badge tone="purple">+{liveCount} live</Badge>}
            </div>
          ) : undefined
        }
      />

      <GlassCard className="p-5">
        <SearchInput
          placeholder="Filter by action, email, resource, or details…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="mb-4 max-w-sm"
        />

        {isLoading ? (
          <LoadingState />
        ) : error ? (
          <ErrorState message={(error as Error).message} />
        ) : filtered.length === 0 ? (
          <EmptyState icon={<ScrollText size={32} />} title="No audit entries" />
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
                    <Td className="text-muted">{l.user_email}</Td>
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
