import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { ScrollText } from "lucide-react";
import { api } from "../../lib/api";
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

function toneForAction(action: string): "rose" | "amber" | "emerald" | "blue" | "slate" {
  if (action.includes("delete") || action.includes("eject") || action.includes("suspend")) return "rose";
  if (action.includes("lock") || action.includes("archived") || action.includes("purge")) return "amber";
  if (action.includes("create") || action.includes("invite") || action.includes("activate")) return "emerald";
  if (action.includes("role") || action.includes("export") || action.includes("retention")) return "blue";
  return "slate";
}

export function AuditPage() {
  const [search, setSearch] = useState("");
  const { data, isLoading, error } = useQuery({
    queryKey: ["admin", "audit"],
    queryFn: () => api<AuditLog[]>("/admin/audit?limit=300"),
    refetchInterval: 20000,
  });

  const filtered = useMemo(() => {
    const logs = data ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return logs;
    return logs.filter(
      (l) =>
        l.action.toLowerCase().includes(q) ||
        l.user_email.toLowerCase().includes(q) ||
        l.resource_type.toLowerCase().includes(q),
    );
  }, [data, search]);

  return (
    <div>
      <PageHeader title="Audit Trail" subtitle="Platform-wide record of administrative activity" />

      <GlassCard className="p-5">
        <SearchInput
          placeholder="Filter by action, email, or resource…"
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
              {filtered.map((l) => (
                <tr key={l.id} className="transition hover:bg-white/[0.03]">
                  <Td>
                    <Badge tone={toneForAction(l.action)}>{l.action}</Badge>
                  </Td>
                  <Td className="text-muted">{l.user_email}</Td>
                  <Td className="text-muted">
                    {l.resource_type}
                    {l.resource_id && (
                      <span className="ml-1 text-xs text-faint">#{l.resource_id.slice(0, 8)}</span>
                    )}
                  </Td>
                  <Td className="max-w-xs truncate text-muted" >{l.details ?? "—"}</Td>
                  <Td className="text-right text-muted" title={formatDate(l.created_at)}>
                    {relativeTime(l.created_at)}
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </GlassCard>
    </div>
  );
}
