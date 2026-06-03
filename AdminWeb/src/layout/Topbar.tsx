import { LogOut, ChevronDown } from "lucide-react";
import { useAuth } from "../auth/AuthContext";
import { Badge, Button } from "../components/ui";

export function Topbar() {
  const { user, isSuperAdmin, adminOrgs, activeOrgId, setActiveOrgId, logout } = useAuth();

  return (
    <header className="glass mx-3 mt-3 flex items-center justify-between rounded-2xl px-5 py-3">
      <div className="flex items-center gap-3">
        {adminOrgs.length > 0 && (
          <div className="relative">
            <select
              value={activeOrgId ?? ""}
              onChange={(e) => setActiveOrgId(e.target.value)}
              className="ring-focus appearance-none rounded-xl border border-white/10 bg-white/5 py-2 pl-3 pr-8 text-sm font-medium text-ink"
            >
              {adminOrgs.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
            <ChevronDown
              size={15}
              className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-faint"
            />
          </div>
        )}
        {isSuperAdmin && <Badge tone="emerald">Super Admin</Badge>}
      </div>

      <div className="flex items-center gap-3">
        <div className="text-right">
          <p className="text-sm font-medium leading-tight text-ink">{user?.display_name}</p>
          <p className="text-[11px] leading-tight text-faint">{user?.email}</p>
        </div>
        <div className="grid h-9 w-9 place-items-center rounded-full bg-gradient-to-br from-primary to-emerald text-sm font-semibold text-white">
          {(user?.display_name ?? "?").slice(0, 1).toUpperCase()}
        </div>
        <Button variant="ghost" onClick={() => void logout()} title="Sign out">
          <LogOut size={16} />
        </Button>
      </div>
    </header>
  );
}
