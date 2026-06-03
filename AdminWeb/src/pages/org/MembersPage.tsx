import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { UserRound, UserCheck, UserX, Trash2 } from "lucide-react";
import { api } from "../../lib/api";
import type { JoinRequest, OrgMember, UserRole } from "../../types";
import {
  Badge,
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
import { SelectInput } from "../../components/Modal";
import { useAuth } from "../../auth/AuthContext";
import { formatDate } from "../../lib/format";

const ROLES: UserRole[] = ["guest", "viewer", "member", "manager", "admin", "owner"];

function roleTone(role: UserRole): "emerald" | "blue" | "slate" {
  if (role === "owner") return "emerald";
  if (role === "admin" || role === "manager") return "blue";
  return "slate";
}

export function MembersPage() {
  const qc = useQueryClient();
  const { activeOrgId, user } = useAuth();
  const orgId = activeOrgId ?? undefined;

  const membersQ = useQuery({
    queryKey: ["org", orgId, "members"],
    queryFn: () => api<OrgMember[]>("/admin/org/members", { orgId }),
    enabled: !!orgId,
  });

  const joinQ = useQuery({
    queryKey: ["org", orgId, "join-requests"],
    queryFn: () => api<JoinRequest[]>("/admin/org/join-requests", { orgId }),
    enabled: !!orgId,
  });

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["org", orgId, "members"] });
    qc.invalidateQueries({ queryKey: ["org", orgId, "join-requests"] });
  };

  const changeRole = useMutation({
    mutationFn: ({ id, role }: { id: string; role: UserRole }) =>
      api(`/admin/org/members/${id}/role`, { method: "PUT", body: { role }, orgId }),
    onSuccess: invalidate,
  });

  const remove = useMutation({
    mutationFn: (id: string) => api(`/admin/org/members/${id}`, { method: "DELETE", orgId }),
    onSuccess: invalidate,
    onError: (e) => alert(e instanceof Error ? e.message : "Failed"),
  });

  const respond = useMutation({
    mutationFn: ({ id, action }: { id: string; action: "accept" | "reject" }) =>
      api(`/admin/org/join-requests/${id}/respond`, { method: "POST", body: { action }, orgId }),
    onSuccess: invalidate,
  });

  const members = membersQ.data ?? [];
  const requests = joinQ.data ?? [];

  return (
    <div>
      <PageHeader title="Members" subtitle="Manage who belongs to this workspace and their roles" />

      {requests.length > 0 && (
        <GlassCard className="mb-6 p-5">
          <h3 className="mb-3 flex items-center gap-2 font-display text-sm font-semibold text-ink">
            Pending join requests <Badge tone="amber">{requests.length}</Badge>
          </h3>
          <div className="space-y-2">
            {requests.map((r) => (
              <div
                key={r.id}
                className="flex items-center justify-between rounded-xl border border-white/8 bg-white/[0.03] px-4 py-3"
              >
                <div>
                  <div className="font-medium text-ink">{r.display_name}</div>
                  <div className="text-xs text-faint">{r.email}</div>
                </div>
                <div className="flex gap-2">
                  <Button variant="primary" onClick={() => respond.mutate({ id: r.id, action: "accept" })}>
                    <UserCheck size={15} /> Approve
                  </Button>
                  <Button variant="ghost" onClick={() => respond.mutate({ id: r.id, action: "reject" })}>
                    <UserX size={15} /> Decline
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </GlassCard>
      )}

      <GlassCard className="p-5">
        {membersQ.isLoading ? (
          <LoadingState />
        ) : membersQ.error ? (
          <ErrorState message={(membersQ.error as Error).message} />
        ) : members.length === 0 ? (
          <EmptyState icon={<UserRound size={32} />} title="No members" />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>Member</Th>
                <Th>Role</Th>
                <Th>Joined</Th>
                <Th className="text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {members.map((m) => {
                const isSelf = m.user_id === user?.id;
                return (
                  <tr key={m.id} className="transition hover:bg-white/[0.03]">
                    <Td>
                      <div className="flex items-center gap-3">
                        <div className="grid h-8 w-8 place-items-center rounded-full bg-gradient-to-br from-primary to-emerald text-xs font-semibold text-white">
                          {m.display_name.slice(0, 1).toUpperCase()}
                        </div>
                        <div>
                          <div className="font-medium text-ink">
                            {m.display_name} {isSelf && <span className="text-xs text-faint">(you)</span>}
                          </div>
                          <div className="text-xs text-faint">{m.email}</div>
                        </div>
                      </div>
                    </Td>
                    <Td>
                      <div className="flex items-center gap-2">
                        <Badge tone={roleTone(m.role)}>{m.role}</Badge>
                        <SelectInput
                          value={m.role}
                          disabled={isSelf}
                          onChange={(e) => changeRole.mutate({ id: m.id, role: e.target.value as UserRole })}
                          className="!w-28 !py-1.5 text-xs"
                        >
                          {ROLES.map((r) => (
                            <option key={r} value={r}>
                              {r}
                            </option>
                          ))}
                        </SelectInput>
                      </div>
                    </Td>
                    <Td className="text-muted">{formatDate(m.joined_at)}</Td>
                    <Td>
                      <div className="flex justify-end">
                        <Button
                          variant="ghost"
                          title="Remove member"
                          disabled={isSelf}
                          onClick={() => {
                            if (confirm(`Remove ${m.display_name} from this workspace?`)) remove.mutate(m.id);
                          }}
                        >
                          <Trash2 size={16} className="text-rose" />
                        </Button>
                      </div>
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
