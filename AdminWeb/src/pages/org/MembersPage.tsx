import { useState } from "react";
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
  SearchInput,
  Table,
  Td,
  Th,
} from "../../components/ui";
import { SelectInput } from "../../components/Modal";
import { useAuth } from "../../auth/AuthContext";
import { formatDate } from "../../lib/format";

const ROLES: UserRole[] = ["guest", "viewer", "member", "manager", "admin", "owner"];

function roleTone(role: UserRole): "purple" | "emerald" | "blue" | "slate" | "amber" {
  if (role === "owner") return "purple";
  if (role === "admin") return "emerald";
  if (role === "manager") return "blue";
  if (role === "viewer") return "amber";
  return "slate";
}

export function MembersPage() {
  const qc = useQueryClient();
  const { activeOrgId, activeOrg, user, canManageMembers, canInviteMembers } = useAuth();
  const orgId = activeOrgId ?? undefined;
  const [search, setSearch] = useState("");

  // Use /organizations/:orgID/members which works across all roles having members.view
  const membersQ = useQuery({
    queryKey: ["org", orgId, "members"],
    queryFn: () => api<OrgMember[]>(`/organizations/${orgId}/members`, { orgId }),
    enabled: !!orgId,
  });

  // Join requests are only available to admins/owners
  const joinQ = useQuery({
    queryKey: ["org", orgId, "join-requests"],
    queryFn: () => api<JoinRequest[]>("/admin/org/join-requests", { orgId }),
    enabled: !!orgId && canManageMembers,
  });

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["org", orgId, "members"] });
    qc.invalidateQueries({ queryKey: ["org", orgId, "join-requests"] });
  };

  const changeRole = useMutation({
    mutationFn: ({ id, role }: { id: string; role: UserRole }) =>
      api(`/admin/org/members/${id}/role`, { method: "PUT", body: { role }, orgId }),
    onSuccess: invalidate,
    onError: (e) => alert(e instanceof Error ? e.message : "Role update failed"),
  });

  const remove = useMutation({
    mutationFn: (id: string) => api(`/admin/org/members/${id}`, { method: "DELETE", orgId }),
    onSuccess: invalidate,
    onError: (e) => alert(e instanceof Error ? e.message : "Failed to remove member"),
  });

  const respond = useMutation({
    mutationFn: ({ id, action }: { id: string; action: "accept" | "reject" }) =>
      api(`/admin/org/join-requests/${id}/respond`, { method: "POST", body: { action }, orgId }),
    onSuccess: invalidate,
  });

  const members = (membersQ.data ?? []).filter((m) => {
    if (!search.trim()) return true;
    const q = search.toLowerCase();
    return m.display_name.toLowerCase().includes(q) || m.email.toLowerCase().includes(q) || m.role.includes(q);
  });

  const requests = joinQ.data ?? [];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <PageHeader
          title="Team Members"
          subtitle={`Member directory and role assignments for ${activeOrg?.name ?? "this workspace"}`}
        />
        {canInviteMembers && (
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted">
              {canManageMembers ? "Full Admin Control" : "Manager Invite Access"}
            </span>
          </div>
        )}
      </div>

      {canManageMembers && requests.length > 0 && (
        <GlassCard className="p-5 border-l-4 border-l-amber">
          <h3 className="mb-3 flex items-center gap-2 font-display text-sm font-semibold text-ink">
            Pending Join Requests <Badge tone="amber">{requests.length}</Badge>
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
        <div className="flex items-center justify-between mb-4 gap-3">
          <SearchInput
            placeholder="Search team members by name or email…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="max-w-xs"
          />
          <div className="text-xs text-muted">
            Total Members: <span className="font-semibold text-ink">{members.length}</span>
          </div>
        </div>

        {membersQ.isLoading ? (
          <LoadingState label="Loading workspace members…" />
        ) : membersQ.error ? (
          <ErrorState message={(membersQ.error as Error).message} />
        ) : members.length === 0 ? (
          <EmptyState icon={<UserRound size={32} />} title="No members found" />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>Member</Th>
                <Th>Role</Th>
                <Th>Joined</Th>
                {canManageMembers && <Th className="text-right">Actions</Th>}
              </tr>
            </thead>
            <tbody>
              {members.map((m) => {
                const isSelf = m.user_id === user?.id;
                const isOrgOwner = m.role === "owner";
                return (
                  <tr key={m.id} className="transition hover:bg-white/[0.03]">
                    <Td>
                      <div className="flex items-center gap-3">
                        <div className="grid h-8 w-8 place-items-center rounded-full bg-gradient-to-br from-primary to-emerald text-xs font-semibold text-white">
                          {m.display_name.slice(0, 1).toUpperCase()}
                        </div>
                        <div>
                          <div className="font-medium text-ink flex items-center gap-1.5">
                            {m.display_name}
                            {isSelf && <span className="text-xs text-primary font-medium">(you)</span>}
                          </div>
                          <div className="text-xs text-faint">{m.email}</div>
                        </div>
                      </div>
                    </Td>
                    <Td>
                      <div className="flex items-center gap-2">
                        <Badge tone={roleTone(m.role)}>{m.role}</Badge>
                        {canManageMembers && !isSelf && !isOrgOwner && (
                          <SelectInput
                            value={m.role}
                            onChange={(e) => changeRole.mutate({ id: m.id, role: e.target.value as UserRole })}
                            className="!w-28 !py-1 text-xs"
                          >
                            {ROLES.filter((r) => r !== "owner").map((r) => (
                              <option key={r} value={r}>
                                {r}
                              </option>
                            ))}
                          </SelectInput>
                        )}
                      </div>
                    </Td>
                    <Td className="text-muted text-xs">{formatDate(m.joined_at)}</Td>
                    {canManageMembers && (
                      <Td>
                        <div className="flex justify-end">
                          {!isSelf && !isOrgOwner && (
                            <Button
                              variant="ghost"
                              title="Remove member"
                              onClick={() => {
                                if (confirm(`Remove ${m.display_name} from this workspace?`)) remove.mutate(m.id);
                              }}
                            >
                              <Trash2 size={15} className="text-rose" />
                            </Button>
                          )}
                        </div>
                      </Td>
                    )}
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
