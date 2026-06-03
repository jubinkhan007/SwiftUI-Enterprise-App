import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { api } from "../lib/api";
import type { AdminMeResponse, AdminOrgSummary, AdminUserSelf } from "../types";

interface AuthState {
  loading: boolean;
  user: AdminUserSelf | null;
  isSuperAdmin: boolean;
  adminOrgs: AdminOrgSummary[];
  /** Currently selected org for the tenant portal. */
  activeOrgId: string | null;
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
      setActiveOrgIdState((cur) => {
        if (cur && next.admin_orgs.some((o) => o.id === cur)) return cur;
        return next.admin_orgs[0]?.id ?? null;
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

  const value = useMemo<AuthState>(
    () => ({
      loading,
      user: me?.user ?? null,
      isSuperAdmin: me?.is_super_admin ?? false,
      adminOrgs: me?.admin_orgs ?? [],
      activeOrgId,
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
    }),
    [loading, me, activeOrgId],
  );

  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthCtx);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
