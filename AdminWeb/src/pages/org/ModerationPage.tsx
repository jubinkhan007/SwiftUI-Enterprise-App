import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Hash,
  Lock,
  LockOpen,
  Archive,
  ArchiveRestore,
  Trash2,
  ShieldAlert,
  Pencil,
} from "lucide-react";
import { api } from "../../lib/api";
import type { ModerationChannel, ModerationMessage } from "../../types";
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
  cn,
} from "../../components/ui";
import { useAuth } from "../../auth/AuthContext";
import { formatDate, formatNumber, relativeTime } from "../../lib/format";

type Tab = "channels" | "flagged";

export function ModerationPage() {
  const { activeOrgId } = useAuth();
  const orgId = activeOrgId ?? undefined;
  const [tab, setTab] = useState<Tab>("channels");

  return (
    <div>
      <PageHeader title="Moderation" subtitle="Govern channels and review flagged message activity" />

      <div className="mb-5 inline-flex rounded-xl border border-white/10 bg-white/5 p-1">
        {(["channels", "flagged"] as Tab[]).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={cn(
              "ring-focus rounded-lg px-4 py-1.5 text-sm font-medium capitalize transition",
              tab === t ? "bg-primary/20 text-ink" : "text-muted hover:text-ink",
            )}
          >
            {t === "flagged" ? "Flagged messages" : "Channels"}
          </button>
        ))}
      </div>

      {tab === "channels" ? <ChannelsTab orgId={orgId} /> : <FlaggedTab orgId={orgId} />}
    </div>
  );
}

function ChannelsTab({ orgId }: { orgId?: string }) {
  const qc = useQueryClient();
  const { data, isLoading, error } = useQuery({
    queryKey: ["org", orgId, "channels"],
    queryFn: () => api<ModerationChannel[]>("/admin/org/channels", { orgId }),
    enabled: !!orgId,
  });
  const invalidate = () => qc.invalidateQueries({ queryKey: ["org", orgId, "channels"] });

  const setArchived = useMutation({
    mutationFn: ({ id, archived }: { id: string; archived: boolean }) =>
      api(`/admin/org/channels/${id}/archive`, { method: "POST", body: { archived }, orgId }),
    onSuccess: invalidate,
  });
  const setLocked = useMutation({
    mutationFn: ({ id, locked }: { id: string; locked: boolean }) =>
      api(`/admin/org/channels/${id}/lock`, { method: "POST", body: { locked }, orgId }),
    onSuccess: invalidate,
  });
  const remove = useMutation({
    mutationFn: (id: string) => api(`/admin/org/channels/${id}`, { method: "DELETE", orgId }),
    onSuccess: invalidate,
  });

  const channels = data ?? [];

  return (
    <GlassCard className="p-5">
      {isLoading ? (
        <LoadingState />
      ) : error ? (
        <ErrorState message={(error as Error).message} />
      ) : channels.length === 0 ? (
        <EmptyState icon={<Hash size={32} />} title="No channels" hint="Conversations in this workspace will appear here." />
      ) : (
        <Table>
          <thead>
            <tr>
              <Th>Channel</Th>
              <Th>State</Th>
              <Th className="text-right">Members</Th>
              <Th className="text-right">Messages</Th>
              <Th>Last activity</Th>
              <Th className="text-right">Actions</Th>
            </tr>
          </thead>
          <tbody>
            {channels.map((c) => (
              <tr key={c.id} className="transition hover:bg-white/[0.03]">
                <Td>
                  <div className="flex items-center gap-2">
                    <Hash size={15} className="text-faint" />
                    <span className="font-medium text-ink">{c.name ?? "Direct message"}</span>
                  </div>
                  <div className="ml-6 text-xs text-faint">{c.type}{c.is_private ? " · private" : ""}</div>
                </Td>
                <Td>
                  <div className="flex gap-1.5">
                    {c.is_locked && <Badge tone="amber">Locked</Badge>}
                    {c.is_archived && <Badge tone="slate">Archived</Badge>}
                    {!c.is_locked && !c.is_archived && <Badge tone="emerald">Active</Badge>}
                  </div>
                </Td>
                <Td className="text-right tabular-nums text-ink">{formatNumber(c.member_count)}</Td>
                <Td className="text-right tabular-nums text-ink">{formatNumber(c.message_count)}</Td>
                <Td className="text-muted">{c.last_message_at ? relativeTime(c.last_message_at) : "—"}</Td>
                <Td>
                  <div className="flex justify-end gap-1.5">
                    <Button
                      variant="ghost"
                      title={c.is_locked ? "Unlock" : "Lock"}
                      onClick={() => setLocked.mutate({ id: c.id, locked: !c.is_locked })}
                    >
                      {c.is_locked ? <LockOpen size={16} className="text-emerald" /> : <Lock size={16} className="text-amber" />}
                    </Button>
                    <Button
                      variant="ghost"
                      title={c.is_archived ? "Unarchive" : "Archive"}
                      onClick={() => setArchived.mutate({ id: c.id, archived: !c.is_archived })}
                    >
                      {c.is_archived ? <ArchiveRestore size={16} /> : <Archive size={16} />}
                    </Button>
                    <Button
                      variant="ghost"
                      title="Delete channel"
                      onClick={() => {
                        if (confirm(`Delete "${c.name ?? "this channel"}" and all its messages?`)) remove.mutate(c.id);
                      }}
                    >
                      <Trash2 size={16} className="text-rose" />
                    </Button>
                  </div>
                </Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </GlassCard>
  );
}

function FlaggedTab({ orgId }: { orgId?: string }) {
  const { data, isLoading, error } = useQuery({
    queryKey: ["org", orgId, "flagged"],
    queryFn: () => api<ModerationMessage[]>("/admin/org/moderation/messages?limit=200", { orgId }),
    enabled: !!orgId,
  });
  const messages = data ?? [];

  return (
    <GlassCard className="p-5">
      {isLoading ? (
        <LoadingState />
      ) : error ? (
        <ErrorState message={(error as Error).message} />
      ) : messages.length === 0 ? (
        <EmptyState icon={<ShieldAlert size={32} />} title="Nothing flagged" hint="Edited or deleted messages will surface here." />
      ) : (
        <Table>
          <thead>
            <tr>
              <Th>Message</Th>
              <Th>Channel</Th>
              <Th>Flag</Th>
              <Th className="text-right">When</Th>
            </tr>
          </thead>
          <tbody>
            {messages.map((m) => (
              <tr key={m.id} className="transition hover:bg-white/[0.03]">
                <Td className="max-w-md">
                  <p className={cn("truncate", m.deleted_at ? "italic text-faint line-through" : "text-ink")}>
                    {m.body || "—"}
                  </p>
                </Td>
                <Td className="text-muted">{m.conversation_name ?? "Direct message"}</Td>
                <Td>
                  {m.deleted_at ? (
                    <Badge tone="rose">
                      <Trash2 size={11} /> Deleted
                    </Badge>
                  ) : (
                    <Badge tone="amber">
                      <Pencil size={11} /> Edited
                    </Badge>
                  )}
                </Td>
                <Td className="text-right text-muted" title={formatDate(m.created_at)}>
                  {relativeTime(m.edited_at ?? m.deleted_at ?? m.created_at)}
                </Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </GlassCard>
  );
}
