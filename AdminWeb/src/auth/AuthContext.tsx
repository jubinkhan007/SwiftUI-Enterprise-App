import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { api } from "../lib/api";
import type { AdminMeResponse, AdminOrgSummary, AdminUserSelf, UserRole } from "../types";

export interface AuthState {
  loading: boolean;
  user: AdminUserSelf | null;
  isSuperAdmin: boolean;
  /** Organizations where the user is admin/owner. */
  adminOrgs: AdminOrgSummary[];
  /** All organizations the user is a member of across any role. */
  memberships: AdminOrgSummary[];
  /** All accessible organizations for the selector. */
  allOrgs: AdminOrgSummary[];
  /** Currently selected org id. */
  activeOrgId: string | null;
  /** Active organization summary with current role. */
  activeOrg: AdminOrgSummary | null;
  /** User's role in the active organization. */
  activeRole: UserRole | null;

  // RBAC capability helpers
  isOwner: boolean;
  isAdmin: boolean;
  isAdminOrOwner: boolean;
  isManager: boolean;
  isManagerOrAbove: boolean;
  canManageMembers: boolean;
  canInviteMembers: boolean;
  canManageSettings: boolean;
  canViewAnalytics: boolean;
  canViewAudit: boolean;

  setActiveOrgId: (id: string) => void;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refresh: () => Promise<void>;
}

const AuthCtx = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [me, setMe] = useState<AdminMeResponse | null>(null);
  const [activeOrgId, setActiveOrgIdState] = useState<string | null>(null);

  function applyMe(next: AdminMeResponse | null) {
    setMe(next);
    if (next) {
      const orgList = (next.memberships && next.memberships.length > 0)
        ? next.memberships
        : next.admin_orgs;
      setActiveOrgIdState((cur) => {
        if (cur && orgList.some((o) => o.id === cur)) return cur;
        return orgList[0]?.id ?? null;
      });
    } else {
      setActiveOrgIdState(null);
    }
  }

  async function loadMe() {
    try {
      const data = await api<AdminMeResponse>("/admin/auth/me");
      applyMe(data);
    } catch {
      applyMe(null);
    }
  }

  useEffect(() => {
    void loadMe().finally(() => setLoading(false));
  }, []);

  const value = useMemo<AuthState>(() => {
    const user = me?.user ?? null;
    const isSuperAdmin = me?.is_super_admin ?? false;
    const adminOrgs = me?.admin_orgs ?? [];
    const memberships = me?.memberships ?? [];
    const allOrgs = memberships.length > 0 ? memberships : adminOrgs;

    const activeOrg = allOrgs.find((o) => o.id === activeOrgId) ?? allOrgs[0] ?? null;
    const activeRole = activeOrg?.role ?? user?.role ?? null;

    const isOwner = activeRole === "owner";
    const isAdmin = activeRole === "admin";
    const isAdminOrOwner = isOwner || isAdmin;
    const isManager = activeRole === "manager";
    const isManagerOrAbove = isOwner || isAdmin || isManager;

    // Permissions according to SharedModels default mapping
    const canManageMembers = isAdminOrOwner;
    const canInviteMembers = isManagerOrAbove;
    const canManageSettings = isAdminOrOwner;
    const canViewAnalytics = isManagerOrAbove || activeRole === "viewer";
    const canViewAudit = isAdminOrOwner;

    return {
      loading,
      user,
      isSuperAdmin,
      adminOrgs,
      memberships,
      allOrgs,
      activeOrgId: activeOrg?.id ?? activeOrgId,
      activeOrg,
      activeRole,
      isOwner,
      isAdmin,
      isAdminOrOwner,
      isManager,
      isManagerOrAbove,
      canManageMembers,
      canInviteMembers,
      canManageSettings,
      canViewAnalytics,
      canViewAudit,
      setActiveOrgId: setActiveOrgIdState,
      async login(email, password) {
        const data = await api<AdminMeResponse>("/admin/auth/login", {
          method: "POST",
          body: { email, password },
        });
        applyMe(data);
      },
      async logout() {
        await api("/admin/auth/logout", { method: "POST" }).catch(() => {});
        applyMe(null);
      },
      async refresh() {
        await loadMe();
      },
    };
  }, [loading, me, activeOrgId]);

  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthCtx);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
