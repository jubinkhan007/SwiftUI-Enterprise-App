import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Laptop, Smartphone, Globe, Trash2, CheckCircle2 } from "lucide-react";
import { api } from "../../lib/api";
import { useAuth } from "../../auth/AuthContext";
import type { UserSessionDTO } from "../../types";
import {
  Button,
  EmptyState,
  ErrorState,
  GlassCard,
  LoadingState,
  PageHeader,
  Table,
  Td,
  Th,
} from "../../components/ui";
import { formatDate, relativeTime } from "../../lib/format";

function getDeviceIcon(deviceType: string, userAgent: string) {
  const dt = (deviceType + " " + userAgent).toLowerCase();
  if (dt.includes("iphone") || dt.includes("android") || dt.includes("mobile")) {
    return <Smartphone size={16} className="text-primary" />;
  }
  if (dt.includes("mac") || dt.includes("windows") || dt.includes("linux") || dt.includes("admin")) {
    return <Laptop size={16} className="text-emerald" />;
  }
  return <Globe size={16} className="text-muted" />;
}

export function MySessionsPage() {
  const { user } = useAuth();
  const qc = useQueryClient();
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  const { data: sessions, isLoading, error } = useQuery({
    queryKey: ["my-sessions"],
    queryFn: () => api<UserSessionDTO[]>("/me/sessions"),
    refetchInterval: 30000,
  });

  const revokeMutation = useMutation({
    mutationFn: (sessionId: string) =>
      api(`/me/sessions/${sessionId}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["my-sessions"] });
      setSuccessMsg("Session revoked successfully.");
      setTimeout(() => setSuccessMsg(null), 4000);
    },
  });

  return (
    <div className="space-y-6">
      <PageHeader
        title="Active Login Sessions"
        subtitle={`Active device tokens and sessions associated with ${user?.email ?? "your account"}`}
      />

      {successMsg && (
        <div className="flex items-center gap-2 p-3 text-xs rounded-xl bg-emerald/15 border border-emerald/25 text-emerald">
          <CheckCircle2 size={16} />
          <span>{successMsg}</span>
        </div>
      )}

      <GlassCard className="p-5">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="font-display text-sm font-semibold text-ink">
              Device Sessions ({sessions?.length ?? 0})
            </h3>
            <p className="text-xs text-muted">
              Revoke any unfamiliar or legacy sessions to force immediate sign-out.
            </p>
          </div>
        </div>

        {isLoading ? (
          <LoadingState label="Loading active sessions…" />
        ) : error ? (
          <ErrorState message={(error as Error).message} />
        ) : !sessions || sessions.length === 0 ? (
          <EmptyState icon={<Laptop size={32} />} title="No active sessions found" />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>Device / Client</Th>
                <Th>IP Address</Th>
                <Th>Created</Th>
                <Th>Expires</Th>
                <Th className="text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {sessions.map((s) => (
                <tr key={s.id} className="transition hover:bg-white/[0.03]">
                  <Td>
                    <div className="flex items-center gap-2.5">
                      <div className="grid h-8 w-8 place-items-center rounded-lg bg-white/5">
                        {getDeviceIcon(s.device_type, s.user_agent)}
                      </div>
                      <div>
                        <p className="text-xs font-medium text-ink">{s.device_type || "Web Browser"}</p>
                        <p className="text-[11px] text-muted max-w-xs truncate" title={s.user_agent}>
                          {s.user_agent || "Standard Client"}
                        </p>
                      </div>
                    </div>
                  </Td>
                  <Td className="text-xs text-muted font-mono">{s.ip_address || "127.0.0.1"}</Td>
                  <Td className="text-xs text-muted" title={formatDate(s.created_at)}>
                    {relativeTime(s.created_at)}
                  </Td>
                  <Td className="text-xs text-muted">
                    {formatDate(s.expires_at)}
                  </Td>
                  <Td className="text-right">
                    <Button
                      variant="danger"
                      className="px-2.5 py-1 text-xs"
                      loading={revokeMutation.isPending && revokeMutation.variables === s.id}
                      onClick={() => revokeMutation.mutate(s.id)}
                      title="Revoke session"
                    >
                      <Trash2 size={13} />
                      Revoke
                    </Button>
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
