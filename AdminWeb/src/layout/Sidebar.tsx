import { NavLink } from "react-router-dom";
import {
  Building2,
  Users,
  Activity,
  ScrollText,
  UsersRound,
  Clock,
  FileArchive,
  ShieldAlert,
  ShieldCheck,
  BarChart3,
  type LucideIcon,
} from "lucide-react";
import { useAuth } from "../auth/AuthContext";
import { cn } from "../components/ui";

interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
}

const platformNav: NavItem[] = [
  { to: "/platform/orgs", label: "Organizations", icon: Building2 },
  { to: "/platform/users", label: "Users", icon: Users },
  { to: "/platform/health", label: "Server Health", icon: Activity },
  { to: "/platform/audit", label: "Audit Trail", icon: ScrollText },
  { to: "/platform/analytics", label: "Analytics", icon: BarChart3 },
];

const orgNav: NavItem[] = [
  { to: "/org/members", label: "Members", icon: UsersRound },
  { to: "/org/retention", label: "Retention", icon: Clock },
  { to: "/org/compliance", label: "Compliance", icon: FileArchive },
  { to: "/org/moderation", label: "Moderation", icon: ShieldAlert },
];

function NavSection({ title, items }: { title: string; items: NavItem[] }) {
  return (
    <div className="mb-6">
      <p className="px-3 pb-2 text-[11px] font-semibold uppercase tracking-wider text-faint">
        {title}
      </p>
      <nav className="space-y-1">
        {items.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              cn(
                "ring-focus flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition",
                isActive
                  ? "bg-primary/15 text-ink shadow-inner shadow-primary/10"
                  : "text-muted hover:bg-white/5 hover:text-ink",
              )
            }
          >
            <Icon size={17} />
            {label}
          </NavLink>
        ))}
      </nav>
    </div>
  );
}

export function Sidebar() {
  const { isSuperAdmin, adminOrgs, activeOrgId } = useAuth();
  return (
    <aside className="glass m-3 flex w-60 shrink-0 flex-col rounded-2xl p-4">
      <div className="mb-7 flex items-center gap-2.5 px-1">
        <div className="grid h-9 w-9 place-items-center rounded-xl bg-gradient-to-br from-emerald to-primary text-white">
          <ShieldCheck size={18} />
        </div>
        <div>
          <p className="font-display text-sm font-bold leading-tight text-ink">Enterprise</p>
          <p className="text-[11px] leading-tight text-faint">Admin Console</p>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto">
        {isSuperAdmin && <NavSection title="Platform" items={platformNav} />}
        {(adminOrgs.length > 0 || (isSuperAdmin && activeOrgId)) && <NavSection title="Workspace" items={orgNav} />}
      </div>
    </aside>
  );
}
