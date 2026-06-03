import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import type { ReactNode } from "react";
import { useAuth } from "./auth/AuthContext";
import { AppShell } from "./layout/AppShell";
import { LoginPage } from "./pages/LoginPage";
import { LoadingState } from "./components/ui";

import { OrgsPage } from "./pages/platform/OrgsPage";
import { UsersPage } from "./pages/platform/UsersPage";
import { HealthPage } from "./pages/platform/HealthPage";
import { AuditPage } from "./pages/platform/AuditPage";

import { MembersPage } from "./pages/org/MembersPage";
import { RetentionPage } from "./pages/org/RetentionPage";
import { CompliancePage } from "./pages/org/CompliancePage";
import { ModerationPage } from "./pages/org/ModerationPage";

function RequireAuth({ children }: { children: ReactNode }) {
  const { loading, user } = useAuth();
  if (loading) {
    return (
      <div className="grid h-screen place-items-center">
        <LoadingState label="Authenticating…" />
      </div>
    );
  }
  if (!user) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

/** Lands the user on the most relevant portal for their access. */
function HomeRedirect() {
  const { isSuperAdmin, adminOrgs } = useAuth();
  if (isSuperAdmin) return <Navigate to="/platform/orgs" replace />;
  if (adminOrgs.length > 0) return <Navigate to="/org/members" replace />;
  return <NoAccess />;
}

function NoAccess() {
  return (
    <div className="grid h-screen place-items-center px-6 text-center">
      <div>
        <h1 className="font-display text-2xl font-bold text-ink">No admin access</h1>
        <p className="mt-2 text-sm text-muted">
          This account is neither a platform super-admin nor an organization admin.
        </p>
      </div>
    </div>
  );
}

function SuperAdminOnly({ children }: { children: ReactNode }) {
  const { isSuperAdmin } = useAuth();
  return isSuperAdmin ? <>{children}</> : <Navigate to="/" replace />;
}

function OrgAdminOnly({ children }: { children: ReactNode }) {
  const { adminOrgs } = useAuth();
  return adminOrgs.length > 0 ? <>{children}</> : <Navigate to="/" replace />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          element={
            <RequireAuth>
              <AppShell />
            </RequireAuth>
          }
        >
          <Route index element={<HomeRedirect />} />

          <Route path="platform/orgs" element={<SuperAdminOnly><OrgsPage /></SuperAdminOnly>} />
          <Route path="platform/users" element={<SuperAdminOnly><UsersPage /></SuperAdminOnly>} />
          <Route path="platform/health" element={<SuperAdminOnly><HealthPage /></SuperAdminOnly>} />
          <Route path="platform/audit" element={<SuperAdminOnly><AuditPage /></SuperAdminOnly>} />

          <Route path="org/members" element={<OrgAdminOnly><MembersPage /></OrgAdminOnly>} />
          <Route path="org/retention" element={<OrgAdminOnly><RetentionPage /></OrgAdminOnly>} />
          <Route path="org/compliance" element={<OrgAdminOnly><CompliancePage /></OrgAdminOnly>} />
          <Route path="org/moderation" element={<OrgAdminOnly><ModerationPage /></OrgAdminOnly>} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
