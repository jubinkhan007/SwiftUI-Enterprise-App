import { useState } from "react";
import {
  Shield,
  Check,
  X,
} from "lucide-react";
import { useAuth } from "../../auth/AuthContext";
import { Badge, GlassCard, PageHeader, Table, Td, Th } from "../../components/ui";
import type { UserRole } from "../../types";

interface RoleDetails {
  role: UserRole;
  label: string;
  tone: "purple" | "emerald" | "blue" | "slate" | "amber";
  summary: string;
}

const ROLES: RoleDetails[] = [
  {
    role: "owner",
    label: "Owner",
    tone: "purple",
    summary: "Full administrative ownership, organization deletion, and billing control.",
  },
  {
    role: "admin",
    label: "Admin",
    tone: "emerald",
    summary: "Team management, compliance, data retention, and workspace configuration.",
  },
  {
    role: "manager",
    label: "Manager",
    tone: "blue",
    summary: "Sprint planning, release scheduling, team oversight, and analytics export.",
  },
  {
    role: "member",
    label: "Member",
    tone: "slate",
    summary: "Standard team member. Full task CRUD, comments, subtasks, checklists.",
  },
  {
    role: "viewer",
    label: "Viewer",
    tone: "amber",
    summary: "Read-only workspace visibility for stakeholders, analytics viewers, and clients.",
  },
  {
    role: "guest",
    label: "Guest",
    tone: "slate",
    summary: "Restricted guest. Can only view assigned tasks and notifications.",
  },
];

interface PermissionRow {
  category: string;
  name: string;
  description: string;
  roles: Record<UserRole, boolean>;
}

const PERMISSIONS_MATRIX: PermissionRow[] = [
  // Tasks
  {
    category: "Tasks",
    name: "View Tasks & Boards",
    description: "Browse workspace task lists, boards, and timelines",
    roles: { owner: true, admin: true, manager: true, member: true, viewer: true, guest: true },
  },
  {
    category: "Tasks",
    name: "Create & Edit Tasks",
    description: "Create new tasks and edit titles, descriptions, and statuses",
    roles: { owner: true, admin: true, manager: true, member: true, viewer: false, guest: false },
  },
  {
    category: "Tasks",
    name: "Assign Tasks",
    description: "Reassign tasks and update assignee assignments",
    roles: { owner: true, admin: true, manager: true, member: true, viewer: false, guest: false },
  },
  {
    category: "Tasks",
    name: "Delete Tasks",
    description: "Permanently delete tasks from lists and boards",
    roles: { owner: true, admin: true, manager: true, member: false, viewer: false, guest: false },
  },
  {
    category: "Tasks",
    name: "Subtasks & Checklists",
    description: "Create subtask hierarchies and manage checklist items",
    roles: { owner: true, admin: true, manager: true, member: true, viewer: false, guest: false },
  },

  // Team & Members
  {
    category: "Team & Members",
    name: "View Member Directory",
    description: "View workspace member names, avatars, and roles",
    roles: { owner: true, admin: true, manager: true, member: true, viewer: true, guest: true },
  },
  {
    category: "Team & Members",
    name: "Invite New Members",
    description: "Send invitation emails to add team members to workspace",
    roles: { owner: true, admin: true, manager: true, member: false, viewer: false, guest: false },
  },
  {
    category: "Team & Members",
    name: "Manage Roles & Permissions",
    description: "Promote or demote member roles up to administrator",
    roles: { owner: true, admin: true, manager: false, member: false, viewer: false, guest: false },
  },
  {
    category: "Team & Members",
    name: "Remove Members",
    description: "Eject members and revoke organization access",
    roles: { owner: true, admin: true, manager: false, member: false, viewer: false, guest: false },
  },

  // Projects
  {
    category: "Projects",
    name: "View Projects & Spaces",
    description: "Access project spaces and workflow configurations",
    roles: { owner: true, admin: true, manager: true, member: true, viewer: true, guest: false },
  },
  {
    category: "Projects",
    name: "Create & Edit Projects",
    description: "Create new projects and configure workflow statuses",
    roles: { owner: true, admin: true, manager: true, member: false, viewer: false, guest: false },
  },
  {
    category: "Projects",
    name: "Delete & Archive Projects",
    description: "Archive or permanently delete project workspaces",
    roles: { owner: true, admin: true, manager: false, member: false, viewer: false, guest: false },
  },

  // Agile & Releases
  {
    category: "Agile & Releases",
    name: "Manage Sprints",
    description: "Create, start, complete, and plan sprint backlogs",
    roles: { owner: true, admin: true, manager: true, member: false, viewer: false, guest: false },
  },
  {
    category: "Agile & Releases",
    name: "Manage Releases & Versions",
    description: "Draft release notes and lock release candidate versions",
    roles: { owner: true, admin: true, manager: true, member: false, viewer: false, guest: false },
  },
  {
    category: "Agile & Releases",
    name: "Edit Bug Classification",
    description: "Set bug severity, environment, and reproduction steps",
    roles: { owner: true, admin: true, manager: true, member: false, viewer: false, guest: false },
  },

  // Analytics & Reports
  {
    category: "Analytics & Reports",
    name: "View Workspace Analytics",
    description: "View team velocity, task throughput, and time logs",
    roles: { owner: true, admin: true, manager: true, member: false, viewer: true, guest: false },
  },
  {
    category: "Analytics & Reports",
    name: "Export Reports & CSV",
    description: "Export project time tracking reports and CSV metrics",
    roles: { owner: true, admin: true, manager: true, member: false, viewer: false, guest: false },
  },

  // Workspace Settings
  {
    category: "Workspace Settings",
    name: "Branding & SSO Configuration",
    description: "Configure workspace logos, custom domains, and SAML SSO",
    roles: { owner: true, admin: true, manager: false, member: false, viewer: false, guest: false },
  },
  {
    category: "Workspace Settings",
    name: "Data Retention & Compliance",
    description: "Set automated message purge policies and run compliance exports",
    roles: { owner: true, admin: true, manager: false, member: false, viewer: false, guest: false },
  },
  {
    category: "Workspace Settings",
    name: "Billing & Subscription Tier",
    description: "Manage subscription plan upgrades, invoices, and Stripe portal",
    roles: { owner: true, admin: true, manager: false, member: false, viewer: false, guest: false },
  },
  {
    category: "Workspace Settings",
    name: "View Audit Log",
    description: "Review administrative actions and audit history",
    roles: { owner: true, admin: true, manager: false, member: false, viewer: false, guest: false },
  },
];

export function PermissionsPage() {
  const { activeRole, activeOrg } = useAuth();
  const [selectedFilter, setSelectedFilter] = useState<string>("All");

  const categories = ["All", "Tasks", "Team & Members", "Projects", "Agile & Releases", "Analytics & Reports", "Workspace Settings"];

  const filtered = selectedFilter === "All"
    ? PERMISSIONS_MATRIX
    : PERMISSIONS_MATRIX.filter((p) => p.category === selectedFilter);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Role & Permissions Matrix"
        subtitle={`Role-Based Access Control (RBAC) governance for ${activeOrg?.name ?? "Workspace"}`}
      />

      {/* Current User Active Role Card */}
      <GlassCard className="p-5 border-l-4 border-l-primary">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="grid h-10 w-10 place-items-center rounded-xl bg-primary/20 text-primary">
              <Shield size={20} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="font-display text-base font-semibold text-ink">
                  Your Current Role:
                </h3>
                {activeRole && (
                  <Badge tone={activeRole === "owner" ? "purple" : activeRole === "admin" ? "emerald" : activeRole === "manager" ? "blue" : activeRole === "viewer" ? "amber" : "slate"}>
                    {activeRole.toUpperCase()}
                  </Badge>
                )}
              </div>
              <p className="text-xs text-muted mt-0.5">
                {ROLES.find((r) => r.role === activeRole)?.summary ?? "Standard workspace member permissions apply."}
              </p>
            </div>
          </div>
        </div>
      </GlassCard>

      {/* Roles Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        {ROLES.map((r) => {
          const isCurrent = r.role === activeRole;
          return (
            <GlassCard
              key={r.role}
              className={`p-4 transition ${
                isCurrent ? "ring-2 ring-primary/40 bg-primary/[0.04]" : ""
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <Badge tone={r.tone}>{r.label}</Badge>
                {isCurrent && (
                  <span className="text-[10px] uppercase font-bold tracking-wider text-primary">
                    Active Role
                  </span>
                )}
              </div>
              <p className="text-xs text-muted leading-relaxed">{r.summary}</p>
            </GlassCard>
          );
        })}
      </div>

      {/* Matrix Table */}
      <GlassCard className="p-5">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
          <h3 className="font-display text-sm font-semibold text-ink">
            Access Matrix by Capability
          </h3>
          <div className="flex flex-wrap gap-1.5">
            {categories.map((cat) => (
              <button
                key={cat}
                onClick={() => setSelectedFilter(cat)}
                className={`px-2.5 py-1 text-xs rounded-lg font-medium transition ${
                  selectedFilter === cat
                    ? "bg-primary text-white shadow-sm"
                    : "bg-white/5 text-muted hover:text-ink hover:bg-white/10"
                }`}
              >
                {cat}
              </button>
            ))}
          </div>
        </div>

        <Table>
          <thead>
            <tr>
              <Th>Capability</Th>
              <Th>Description</Th>
              {ROLES.map((r) => (
                <Th
                  key={r.role}
                  className={`text-center ${r.role === activeRole ? "text-primary font-bold" : ""}`}
                >
                  {r.label}
                </Th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map((item, idx) => (
              <tr key={idx} className="transition hover:bg-white/[0.03]">
                <Td className="font-medium text-ink">
                  <div className="flex items-center gap-1.5">
                    <span className="text-xs">{item.name}</span>
                  </div>
                </Td>
                <Td className="text-xs text-muted max-w-xs">{item.description}</Td>
                {ROLES.map((r) => {
                  const has = item.roles[r.role];
                  const isCurrent = r.role === activeRole;
                  return (
                    <Td
                      key={r.role}
                      className={`text-center ${isCurrent ? "bg-primary/[0.04]" : ""}`}
                    >
                      {has ? (
                        <span className="inline-flex items-center justify-center h-5 w-5 rounded-full bg-emerald/15 text-emerald">
                          <Check size={12} strokeWidth={3} />
                        </span>
                      ) : (
                        <span className="inline-flex items-center justify-center h-5 w-5 rounded-full bg-white/5 text-faint">
                          <X size={12} strokeWidth={2} />
                        </span>
                      )}
                    </Td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </Table>
      </GlassCard>
    </div>
  );
}
