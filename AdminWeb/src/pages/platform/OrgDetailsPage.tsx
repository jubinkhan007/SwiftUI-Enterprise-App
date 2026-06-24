import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useParams, useNavigate, Link } from "react-router-dom";
import {
  Users2,
  MessagesSquare,
  Calendar,
  FolderOpen,
  Ban,
  CheckCircle2,
  Trash2,
  ArrowLeft,
  Clock,
  Lock,
  Unlock,
  Archive,
  Settings,
  Hash,
} from "lucide-react";
import { useAuth } from "../../auth/AuthContext";
import { api } from "../../lib/api";
import type { AdminOrg, OrgMember, ModerationChannel, AuditLog } from "../../types";
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
import { StatCard } from "../../components/StatCard";
import { Field, SelectInput } from "../../components/Modal";
import { formatDate, formatNumber } from "../../lib/format";

type Tab = "overview" | "members" | "channels" | "audit";

export function OrgDetailsPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { setActiveOrgId } = useAuth();
  const [activeTab, setActiveTab] = useState<Tab>("overview");
  const [retentionInput, setRetentionInput] = useState<string>("");

  // 1. Fetch organization details
  const {
    data: org,
    isLoading: loadingOrg,
    error: orgError,
  } = useQuery({
    queryKey: ["admin", "orgs", id],
    queryFn: () => api<AdminOrg>(`/admin/orgs/${id}`),
    enabled: !!id,
  });

  // Sync retention input state with fetched data
  useEffect(() => {
    if (org) {
      setRetentionInput(org.retention_days !== null && org.retention_days !== undefined ? String(org.retention_days) : "");
    }
  }, [org]);

  // 2. Fetch organization members
  const {
    data: membersData,
    isLoading: loadingMembers,
    error: membersError,
  } = useQuery({
    queryKey: ["admin", "org", id, "members"],
    queryFn: () => api<OrgMember[]>(`/admin/org/members`, { orgId: id }),
    enabled: !!id && activeTab === "members",
  });

  // 3. Fetch organization channels
  const {
    data: channelsData,
    isLoading: loadingChannels,
    error: channelsError,
  } = useQuery({
    queryKey: ["admin", "org", id, "channels"],
    queryFn: () => api<ModerationChannel[]>(`/admin/org/channels`, { orgId: id }),
    enabled: !!id && activeTab === "channels",
  });

  // 4. Fetch organization audit logs
  const {
    data: auditLogs,
    isLoading: loadingAudit,
    error: auditError,
  } = useQuery({
    queryKey: ["admin", "org", id, "audit"],
    queryFn: () => api<AuditLog[]>(`/admin/audit?orgId=${id}`),
    enabled: !!id && activeTab === "audit",
  });

  const invalidateOrg = () => {
    qc.invalidateQueries({ queryKey: ["admin", "orgs", id] });
    qc.invalidateQueries({ queryKey: ["admin", "orgs"] });
  };

  // Mutators for organization
  const setStatus = useMutation({
    mutationFn: (action: "suspend" | "activate") =>
      api<AdminOrg>(`/admin/orgs/${id}/${action}`, { method: "POST" }),
    onSuccess: invalidateOrg,
  });

  const removeOrg = useMutation({
    mutationFn: () => api(`/admin/orgs/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "orgs"] });
      navigate("/platform/orgs");
    },
  });

  const updateRetention = useMutation({
    mutationFn: (days: number | null) =>
      api(`/admin/org/retention`, {
        method: "PUT",
        orgId: id,
        body: { retention_days: days },
      }),
    onSuccess: invalidateOrg,
  });

  // Mutators for members
  const updateMemberRole = useMutation({
    mutationFn: ({ memberId, role }: { memberId: string; role: string }) =>
      api(`/admin/org/members/${memberId}/role`, {
        method: "PUT",
        orgId: id,
        body: { role },
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "org", id, "members"] });
    },
  });

  const removeMember = useMutation({
    mutationFn: (memberId: string) =>
      api(`/admin/org/members/${memberId}`, {
        method: "DELETE",
        orgId: id,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "org", id, "members"] });
      invalidateOrg();
    },
  });

  // Mutators for channels
  const toggleArchiveChannel = useMutation({
    mutationFn: ({ cid, archived }: { cid: string; archived: boolean }) =>
      api(`/admin/org/channels/${cid}/archive`, {
        method: "POST",
        orgId: id,
        body: { archived },
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "org", id, "channels"] });
    },
  });

  const toggleLockChannel = useMutation({
    mutationFn: ({ cid, locked }: { cid: string; locked: boolean }) =>
      api(`/admin/org/channels/${cid}/lock`, {
        method: "POST",
        orgId: id,
        body: { locked },
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "org", id, "channels"] });
    },
  });

  const deleteChannel = useMutation({
    mutationFn: (cid: string) =>
      api(`/admin/org/channels/${cid}`, {
        method: "DELETE",
        orgId: id,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin", "org", id, "channels"] });
      invalidateOrg();
    },
  });

  if (loadingOrg) return <LoadingState label="Loading organization details…" />;
  if (orgError || !org) return <ErrorState message={orgError ? (orgError as Error).message : "Organization not found."} />;

  const members = membersData ?? [];
  const channels = channelsData ?? [];

  return (
    <div>
      <Link
        to="/platform/orgs"
        className="mb-4 inline-flex items-center gap-2 text-sm text-muted transition hover:text-ink"
      >
        <ArrowLeft size={16} /> Back to Organizations
      </Link>

      <PageHeader
        title={org.name}
        subtitle={`/${org.slug}`}
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="primary"
              onClick={() => {
                setActiveOrgId(org.id);
                navigate("/org/members");
              }}
            >
              <FolderOpen size={16} /> Open Portal
            </Button>
            {org.status === "suspended" ? (
              <Button
                variant="subtle"
                onClick={() => setStatus.mutate("activate")}
                loading={setStatus.isPending}
              >
                <CheckCircle2 size={16} className="text-emerald" /> Activate
              </Button>
            ) : (
              <Button
                variant="subtle"
                onClick={() => setStatus.mutate("suspend")}
                loading={setStatus.isPending}
              >
                <Ban size={16} className="text-amber" /> Suspend
              </Button>
            )}
            <Button
              variant="danger"
              onClick={() => {
                if (confirm(`Delete "${org.name}"? This removes the workspace and its members permanently.`)) {
                  removeOrg.mutate();
                }
              }}
              loading={removeOrg.isPending}
            >
              <Trash2 size={16} /> Delete
            </Button>
          </div>
        }
      />

      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard
          label="Status"
          value={org.status === "suspended" ? "Suspended" : "Active"}
          icon={org.status === "suspended" ? Ban : CheckCircle2}
          accent={org.status === "suspended" ? "amber" : "emerald"}
        />
        <StatCard label="Members" value={formatNumber(org.member_count)} icon={Users2} accent="emerald" />
        <StatCard label="Messages" value={formatNumber(org.message_count)} icon={MessagesSquare} accent="primary" />
        <StatCard
          label="Retention Policy"
          value={org.retention_days ? `${org.retention_days} days` : "Indefinite"}
          icon={Calendar}
        />
      </div>

      {/* Tabs */}
      <div className="mb-6 flex border-b border-white/10 text-sm">
        <button
          onClick={() => setActiveTab("overview")}
          className={`px-4 py-2 font-medium transition ${
            activeTab === "overview"
              ? "border-b-2 border-primary text-ink"
              : "text-muted hover:text-ink"
          }`}
        >
          Overview
        </button>
        <button
          onClick={() => setActiveTab("members")}
          className={`px-4 py-2 font-medium transition ${
            activeTab === "members"
              ? "border-b-2 border-primary text-ink"
              : "text-muted hover:text-ink"
          }`}
        >
          Members ({org.member_count})
        </button>
        <button
          onClick={() => setActiveTab("channels")}
          className={`px-4 py-2 font-medium transition ${
            activeTab === "channels"
              ? "border-b-2 border-primary text-ink"
              : "text-muted hover:text-ink"
          }`}
        >
          Channels
        </button>
        <button
          onClick={() => setActiveTab("audit")}
          className={`px-4 py-2 font-medium transition ${
            activeTab === "audit"
              ? "border-b-2 border-primary text-ink"
              : "text-muted hover:text-ink"
          }`}
        >
          Audit Log
        </button>
      </div>

      {/* Tab Panels */}
      {activeTab === "overview" && (
        <div className="grid gap-6 md:grid-cols-3">
          <GlassCard className="col-span-2 p-5 space-y-4">
            <h3 className="font-display text-lg font-semibold text-ink">Organization Details</h3>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <div className="text-xs text-muted font-medium">Organization ID</div>
                <div className="font-mono text-ink mt-1 truncate" title={org.id}>{org.id}</div>
              </div>
              <div>
                <div className="text-xs text-muted font-medium">Workspace Slug</div>
                <div className="text-ink mt-1 font-semibold">/{org.slug}</div>
              </div>
              <div>
                <div className="text-xs text-muted font-medium">Owner Email</div>
                <div className="text-ink mt-1">{org.owner_email ?? "—"}</div>
              </div>
              <div>
                <div className="text-xs text-muted font-medium">Created At</div>
                <div className="text-ink mt-1">{formatDate(org.created_at)}</div>
              </div>
            </div>
          </GlassCard>

          <GlassCard className="p-5 space-y-4">
            <h3 className="font-display text-lg font-semibold text-ink">Retention Policy Settings</h3>
            <div className="space-y-3">
              <Field label="Retention (days) — leave empty for indefinite">
                <input
                  type="number"
                  min="1"
                  value={retentionInput}
                  onChange={(e) => setRetentionInput(e.target.value)}
                  placeholder="Indefinite"
                  className="ring-focus w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-ink placeholder:text-faint"
                />
              </Field>
              <Button
                variant="primary"
                className="w-full"
                loading={updateRetention.isPending}
                onClick={() => {
                  const val = retentionInput.trim();
                  const days = val === "" ? null : parseInt(val, 10);
                  if (days !== null && (Number.isNaN(days) || days < 1)) {
                    alert("Please enter a valid number of days (min 1).");
                    return;
                  }
                  updateRetention.mutate(days);
                }}
              >
                <Settings size={15} /> Save Retention Policy
              </Button>
            </div>
          </GlassCard>
        </div>
      )}

      {activeTab === "members" && (
        <GlassCard className="p-5">
          <h3 className="font-display text-lg font-semibold text-ink mb-4">Workspace Members</h3>
          {loadingMembers ? (
            <LoadingState />
          ) : membersError ? (
            <ErrorState message={(membersError as Error).message} />
          ) : members.length === 0 ? (
            <EmptyState icon={<Users2 size={32} />} title="No members" />
          ) : (
            <Table>
              <thead>
                <tr>
                  <Th>Member</Th>
                  <Th>Email</Th>
                  <Th>Role</Th>
                  <Th>Joined</Th>
                  <Th className="text-right">Actions</Th>
                </tr>
              </thead>
              <tbody>
                {members.map((m) => (
                  <tr key={m.id} className="transition hover:bg-white/[0.02]">
                    <Td className="font-medium text-ink">{m.display_name}</Td>
                    <Td className="text-muted">{m.email}</Td>
                    <Td>
                      <SelectInput
                        value={m.role}
                        onChange={(e) => updateMemberRole.mutate({ memberId: m.id, role: e.target.value })}
                        disabled={updateMemberRole.isPending}
                        className="max-w-[120px] bg-white/5 border border-white/10 rounded px-2 py-0.5 text-xs text-ink"
                      >
                        <option value="member">Member</option>
                        <option value="admin">Admin</option>
                        <option value="owner">Owner</option>
                        <option value="manager">Manager</option>
                        <option value="viewer">Viewer</option>
                        <option value="guest">Guest</option>
                      </SelectInput>
                    </Td>
                    <Td className="text-muted">{formatDate(m.joined_at)}</Td>
                    <Td className="text-right">
                      <Button
                        variant="ghost"
                        title="Remove Member"
                        onClick={() => {
                          if (confirm(`Remove ${m.display_name} (${m.email}) from workspace?`)) {
                            removeMember.mutate(m.id);
                          }
                        }}
                        loading={removeMember.isPending}
                      >
                        <Trash2 size={15} className="text-rose" />
                      </Button>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </GlassCard>
      )}

      {activeTab === "channels" && (
        <GlassCard className="p-5">
          <h3 className="font-display text-lg font-semibold text-ink mb-4">Workspace Channels</h3>
          {loadingChannels ? (
            <LoadingState />
          ) : channelsError ? (
            <ErrorState message={(channelsError as Error).message} />
          ) : channels.length === 0 ? (
            <EmptyState icon={<Hash size={32} />} title="No channels" hint="No channels have been created yet." />
          ) : (
            <Table>
              <thead>
                <tr>
                  <Th>Channel</Th>
                  <Th>Type</Th>
                  <Th className="text-right">Members</Th>
                  <Th className="text-right">Messages</Th>
                  <Th>Status</Th>
                  <Th className="text-right">Actions</Th>
                </tr>
              </thead>
              <tbody>
                {channels.map((c) => (
                  <tr key={c.id} className="transition hover:bg-white/[0.02]">
                    <Td className="font-medium text-ink">
                      <div className="flex items-center gap-1.5">
                        <Hash size={14} className="text-faint" />
                        <span>{c.name || "Unnamed"}</span>
                      </div>
                    </Td>
                    <Td className="text-muted font-mono text-xs uppercase">{c.type}</Td>
                    <Td className="text-right text-ink tabular-nums">{formatNumber(c.member_count)}</Td>
                    <Td className="text-right text-ink tabular-nums">{formatNumber(c.message_count)}</Td>
                    <Td className="space-x-1">
                      {c.is_private && <Badge tone="rose">Private</Badge>}
                      {c.is_locked && <Badge tone="amber">Locked</Badge>}
                      {c.is_archived && <Badge tone="slate">Archived</Badge>}
                      {!c.is_private && !c.is_locked && !c.is_archived && <Badge tone="emerald">Active</Badge>}
                    </Td>
                    <Td className="text-right">
                      <div className="flex justify-end gap-1">
                        <Button
                          variant="ghost"
                          title={c.is_locked ? "Unlock" : "Lock"}
                          onClick={() => toggleLockChannel.mutate({ cid: c.id, locked: !c.is_locked })}
                          loading={toggleLockChannel.isPending}
                        >
                          {c.is_locked ? <Unlock size={15} className="text-emerald" /> : <Lock size={15} className="text-amber" />}
                        </Button>
                        <Button
                          variant="ghost"
                          title={c.is_archived ? "Unarchive" : "Archive"}
                          onClick={() => toggleArchiveChannel.mutate({ cid: c.id, archived: !c.is_archived })}
                          loading={toggleArchiveChannel.isPending}
                        >
                          <Archive size={15} className={c.is_archived ? "text-emerald" : "text-muted"} />
                        </Button>
                        <Button
                          variant="ghost"
                          title="Delete Channel"
                          onClick={() => {
                            if (confirm(`Delete channel "${c.name || "Unnamed"}" and all its messages?`)) {
                              deleteChannel.mutate(c.id);
                            }
                          }}
                          loading={deleteChannel.isPending}
                        >
                          <Trash2 size={15} className="text-rose" />
                        </Button>
                      </div>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </GlassCard>
      )}

      {activeTab === "audit" && (
        <GlassCard className="p-5">
          <h3 className="font-display text-lg font-semibold text-ink mb-4">Workspace Audit Logs</h3>
          {loadingAudit ? (
            <LoadingState />
          ) : auditError ? (
            <ErrorState message={(auditError as Error).message} />
          ) : (auditLogs ?? []).length === 0 ? (
            <EmptyState icon={<Clock size={32} />} title="No audit entries" hint="No actions have been recorded yet." />
          ) : (
            <Table>
              <thead>
                <tr>
                  <Th>Actor</Th>
                  <Th>Action</Th>
                  <Th>Resource</Th>
                  <Th>Details</Th>
                  <Th>Timestamp</Th>
                </tr>
              </thead>
              <tbody>
                {(auditLogs ?? []).map((log) => (
                  <tr key={log.id} className="transition hover:bg-white/[0.02]">
                    <Td className="font-medium text-ink">{log.user_email}</Td>
                    <Td>
                      <Badge tone="blue">{log.action}</Badge>
                    </Td>
                    <Td className="text-muted font-mono text-xs">
                      {log.resource_type}
                      {log.resource_id && <span className="text-faint block truncate max-w-[120px]">{log.resource_id}</span>}
                    </Td>
                    <Td className="text-muted font-mono text-xs max-w-xs truncate" title={log.details ?? ""}>
                      {log.details ?? "—"}
                    </Td>
                    <Td className="text-muted text-xs whitespace-nowrap">{formatDate(log.created_at)}</Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </GlassCard>
      )}
    </div>
  );
}
