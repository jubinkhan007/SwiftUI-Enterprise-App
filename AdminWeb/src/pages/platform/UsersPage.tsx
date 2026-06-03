import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Users, KeyRound, ShieldCheck, ShieldOff } from "lucide-react";
import { api } from "../../lib/api";
import type { AdminUser, UserRole } from "../../types";
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
import { Field, Modal, SelectInput, TextInput } from "../../components/Modal";
import { useAuth } from "../../auth/AuthContext";
import { formatDate } from "../../lib/format";

const ROLES: UserRole[] = ["guest", "viewer", "member", "manager", "admin", "owner"];

export function UsersPage() {
  const qc = useQueryClient();
  const { user: me } = useAuth();
  const [search, setSearch] = useState("");
  const [resetFor, setResetFor] = useState<AdminUser | null>(null);

  const { data, isLoading, error } = useQuery({
    queryKey: ["admin", "users", search],
    queryFn: () => api<AdminUser[]>(`/admin/users${search ? `?q=${encodeURIComponent(search)}` : ""}`),
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ["admin", "users"] });

  const changeRole = useMutation({
    mutationFn: ({ id, role }: { id: string; role: UserRole }) =>
      api(`/admin/users/${id}/role`, { method: "PUT", body: { role } }),
    onSuccess: invalidate,
  });

  const toggleSuper = useMutation({
    mutationFn: ({ id, value }: { id: string; value: boolean }) =>
      api(`/admin/users/${id}/super-admin`, { method: "PUT", body: { is_super_admin: value } }),
    onSuccess: invalidate,
    onError: (e) => alert(e instanceof Error ? e.message : "Failed"),
  });

  const users = data ?? [];

  return (
    <div>
      <PageHeader title="Users" subtitle="Every registered account across the platform" />

      <GlassCard className="p-5">
        <SearchInput
          placeholder="Search by email or name…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="mb-4 max-w-xs"
        />

        {isLoading ? (
          <LoadingState />
        ) : error ? (
          <ErrorState message={(error as Error).message} />
        ) : users.length === 0 ? (
          <EmptyState icon={<Users size={32} />} title="No users found" />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>User</Th>
                <Th>Global role</Th>
                <Th className="text-center">Super admin</Th>
                <Th className="text-right">Workspaces</Th>
                <Th>Joined</Th>
                <Th className="text-right">Actions</Th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => {
                const isSelf = u.id === me?.id;
                return (
                  <tr key={u.id} className="transition hover:bg-white/[0.03]">
                    <Td>
                      <div className="flex items-center gap-3">
                        <div className="grid h-8 w-8 place-items-center rounded-full bg-gradient-to-br from-primary to-emerald text-xs font-semibold text-white">
                          {u.display_name.slice(0, 1).toUpperCase()}
                        </div>
                        <div>
                          <div className="font-medium text-ink">
                            {u.display_name} {isSelf && <span className="text-xs text-faint">(you)</span>}
                          </div>
                          <div className="text-xs text-faint">{u.email}</div>
                        </div>
                      </div>
                    </Td>
                    <Td>
                      <SelectInput
                        value={u.role}
                        onChange={(e) => changeRole.mutate({ id: u.id, role: e.target.value as UserRole })}
                        className="!w-32 !py-1.5 text-xs"
                      >
                        {ROLES.map((r) => (
                          <option key={r} value={r}>
                            {r}
                          </option>
                        ))}
                      </SelectInput>
                    </Td>
                    <Td className="text-center">
                      {u.is_super_admin ? <Badge tone="emerald">Yes</Badge> : <Badge tone="slate">No</Badge>}
                    </Td>
                    <Td className="text-right tabular-nums text-ink">{u.org_count}</Td>
                    <Td className="text-muted">{formatDate(u.created_at)}</Td>
                    <Td>
                      <div className="flex justify-end gap-1.5">
                        <Button variant="ghost" title="Reset password" onClick={() => setResetFor(u)}>
                          <KeyRound size={16} />
                        </Button>
                        <Button
                          variant="ghost"
                          title={u.is_super_admin ? "Revoke super-admin" : "Grant super-admin"}
                          disabled={isSelf && u.is_super_admin}
                          onClick={() => toggleSuper.mutate({ id: u.id, value: !u.is_super_admin })}
                        >
                          {u.is_super_admin ? (
                            <ShieldOff size={16} className="text-amber" />
                          ) : (
                            <ShieldCheck size={16} className="text-emerald" />
                          )}
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

      <ResetPasswordModal user={resetFor} onClose={() => setResetFor(null)} />
    </div>
  );
}

function ResetPasswordModal({ user, onClose }: { user: AdminUser | null; onClose: () => void }) {
  const [pw, setPw] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  const reset = useMutation({
    mutationFn: () => api(`/admin/users/${user!.id}/reset-password`, { method: "POST", body: { new_password: pw } }),
    onSuccess: () => {
      setDone(true);
      setTimeout(() => close(), 900);
    },
    onError: (e) => setErr(e instanceof Error ? e.message : "Failed"),
  });

  function close() {
    setPw("");
    setErr(null);
    setDone(false);
    onClose();
  }

  return (
    <Modal
      open={!!user}
      title={`Reset password · ${user?.display_name ?? ""}`}
      onClose={close}
      footer={
        <>
          <Button variant="ghost" onClick={close}>
            Cancel
          </Button>
          <Button
            variant="primary"
            loading={reset.isPending}
            disabled={pw.length < 8}
            onClick={() => reset.mutate()}
          >
            {done ? "Updated ✓" : "Set password"}
          </Button>
        </>
      }
    >
      <Field label="New password (min 8 characters)">
        <TextInput type="password" value={pw} onChange={(e) => setPw(e.target.value)} placeholder="••••••••" />
      </Field>
      {err && <ErrorState message={err} />}
    </Modal>
  );
}
