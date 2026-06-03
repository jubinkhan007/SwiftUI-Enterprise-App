import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Building2, Plus, Trash2, Ban, CheckCircle2, Users2, MessagesSquare, FolderOpen } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";
import { api } from "../../lib/api";
import type { AdminOrg } from "../../types";
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
import { StatCard } from "../../components/StatCard";
import { Field, Modal, TextInput } from "../../components/Modal";
import { formatDate, formatNumber } from "../../lib/format";

export function OrgsPage() {
  const qc = useQueryClient();
  const [search, setSearch] = useState("");
  const [creating, setCreating] = useState(false);
  const navigate = useNavigate();
  const { setActiveOrgId } = useAuth();

  const { data, isLoading, error } = useQuery({
    queryKey: ["admin", "orgs", search],
    queryFn: () => api<AdminOrg[]>(`/admin/orgs${search ? `?q=${encodeURIComponent(search)}` : ""}`),
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ["admin", "orgs"] });

  const setStatus = useMutation({
    mutationFn: ({ id, action }: { id: string; action: "suspend" | "activate" }) =>
      api(`/admin/orgs/${id}/${action}`, { method: "POST" }),
    onSuccess: invalidate,
  });

  const remove = useMutation({
    mutationFn: (id: string) => api(`/admin/orgs/${id}`, { method: "DELETE" }),
    onSuccess: invalidate,
  });

  const orgs = data ?? [];
  const totalMembers = orgs.reduce((s, o) => s + o.member_count, 0);
  const totalMessages = orgs.reduce((s, o) => s + o.message_count, 0);
  const suspended = orgs.filter((o) => o.status === "suspended").length;

  return (
    <div>
      <PageHeader
        title="Organizations"
        subtitle="Manage every tenant workspace on the platform"
        actions={
          <Button variant="primary" onClick={() => setCreating(true)}>
            <Plus size={16} /> New organization
          </Button>
        }
      />

      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label="Organizations" value={formatNumber(orgs.length)} icon={Building2} />
        <StatCard label="Suspended" value={formatNumber(suspended)} icon={Ban} accent="amber" />
        <StatCard label="Members" value={formatNumber(totalMembers)} icon={Users2} accent="emerald" />
        <StatCard label="Messages" value={formatNumber(totalMessages)} icon={MessagesSquare} accent="primary" />
      </div>

      <GlassCard className="p-5">
        <div className="mb-4 flex items-center justify-between gap-3">
          <SearchInput
            placeholder="Search by name or slug…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="max-w-xs"
          />
        </div>

        {isLoading ? (
          <LoadingState />
        ) : error ? (
          <ErrorState message={(error as Error).message} />
        ) : orgs.length === 0 ? (
          <EmptyState icon={<Building2 size={32} />} title="No organizations" hint="Create the first tenant workspace." />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>Organization</Th>
                <Th>Owner</Th>
                <Th>Status</Th>
                <Th className="text-right">Members</Th>
                <Th className="text-right">Messages</Th>
                <Th>Created</Th>
                <Th className="text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {orgs.map((o) => (
                <tr key={o.id} className="transition hover:bg-white/[0.03]">
                  <Td>
                    <button
                      className="text-left group/btn focus:outline-none"
                      onClick={() => {
                        setActiveOrgId(o.id);
                        navigate("/org/members");
                      }}
                    >
                      <div className="font-medium text-primary group-hover/btn:underline">{o.name}</div>
                      <div className="text-xs text-faint">/{o.slug}</div>
                    </button>
                  </Td>
                  <Td className="text-muted">{o.owner_email ?? "—"}</Td>
                  <Td>
                    {o.status === "suspended" ? (
                      <Badge tone="rose">Suspended</Badge>
                    ) : (
                      <Badge tone="emerald">Active</Badge>
                    )}
                  </Td>
                  <Td className="text-right tabular-nums text-ink">{formatNumber(o.member_count)}</Td>
                  <Td className="text-right tabular-nums text-ink">{formatNumber(o.message_count)}</Td>
                  <Td className="text-muted">{formatDate(o.created_at)}</Td>
                  <Td>
                    <div className="flex justify-end gap-1.5">
                      <Button
                        variant="ghost"
                        title="Open Portal"
                        onClick={() => {
                          setActiveOrgId(o.id);
                          navigate("/org/members");
                        }}
                      >
                        <FolderOpen size={16} className="text-primary" />
                      </Button>
                      {o.status === "suspended" ? (
                        <Button
                          variant="ghost"
                          title="Activate"
                          onClick={() => setStatus.mutate({ id: o.id, action: "activate" })}
                        >
                          <CheckCircle2 size={16} className="text-emerald" />
                        </Button>
                      ) : (
                        <Button
                          variant="ghost"
                          title="Suspend"
                          onClick={() => setStatus.mutate({ id: o.id, action: "suspend" })}
                        >
                          <Ban size={16} className="text-amber" />
                        </Button>
                      )}
                      <Button
                        variant="ghost"
                        title="Delete"
                        onClick={() => {
                          if (confirm(`Delete "${o.name}"? This removes the workspace and its members.`))
                            remove.mutate(o.id);
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

      <CreateOrgModal open={creating} onClose={() => setCreating(false)} onCreated={invalidate} />
    </div>
  );
}

function CreateOrgModal({
  open,
  onClose,
  onCreated,
}: {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
}) {
  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [ownerEmail, setOwnerEmail] = useState("");
  const [err, setErr] = useState<string | null>(null);

  const create = useMutation({
    mutationFn: () =>
      api<AdminOrg>("/admin/orgs", {
        method: "POST",
        body: { name, slug, owner_email: ownerEmail || undefined },
      }),
    onSuccess: () => {
      onCreated();
      reset();
      onClose();
    },
    onError: (e) => setErr(e instanceof Error ? e.message : "Failed to create"),
  });

  function reset() {
    setName("");
    setSlug("");
    setOwnerEmail("");
    setErr(null);
  }

  return (
    <Modal
      open={open}
      title="New organization"
      onClose={() => {
        reset();
        onClose();
      }}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" loading={create.isPending} onClick={() => create.mutate()}>
            Create
          </Button>
        </>
      }
    >
      <Field label="Name">
        <TextInput
          value={name}
          onChange={(e) => {
            setName(e.target.value);
            if (!slug) setSlug(e.target.value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""));
          }}
          placeholder="Acme Corporation"
        />
      </Field>
      <Field label="Slug">
        <TextInput value={slug} onChange={(e) => setSlug(e.target.value)} placeholder="acme" />
      </Field>
      <Field label="Owner email (optional — defaults to you)">
        <TextInput
          value={ownerEmail}
          onChange={(e) => setOwnerEmail(e.target.value)}
          placeholder="owner@acme.com"
        />
      </Field>
      {err && <ErrorState message={err} />}
    </Modal>
  );
}
