import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import type { ReactNode } from "react";
import { useAuth } from "./auth/AuthContext";
import { AppShell } from "./layout/AppShell";
import { LoginPage } from "./pages/LoginPage";
import { LoadingState } from "./components/ui";

import { OrgsPage } from "./pages/platform/OrgsPage";
import { OrgDetailsPage } from "./pages/platform/OrgDetailsPage";
import { UsersPage } from "./pages/platform/UsersPage";
import { HealthPage } from "./pages/platform/HealthPage";
import { AuditPage } from "./pages/platform/AuditPage";
import { AnalyticsPage } from "./pages/platform/AnalyticsPage";

import { MembersPage } from "./pages/org/MembersPage";
import { PermissionsPage } from "./pages/org/PermissionsPage";
import { MySessionsPage } from "./pages/org/MySessionsPage";
import { RetentionPage } from "./pages/org/RetentionPage";
import { CompliancePage } from "./pages/org/CompliancePage";
import { ModerationPage } from "./pages/org/ModerationPage";
import { BillingPage } from "./pages/org/BillingPage";
import { BrandingPage } from "./pages/org/BrandingPage";
import { SSOConfigPage } from "./pages/org/SSOConfigPage";

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

/** Lands the user on the most relevant portal for their role & access. */
function HomeRedirect() {
  const { isSuperAdmin, allOrgs } = useAuth();
  if (isSuperAdmin) return <Navigate to="/platform/orgs" replace />;
  if (allOrgs.length > 0) return <Navigate to="/org/members" replace />;
  return <Navigate to="/org/sessions" replace />;
}

function SuperAdminOnly({ children }: { children: ReactNode }) {
  const { isSuperAdmin } = useAuth();
  return isSuperAdmin ? <>{children}</> : <Navigate to="/" replace />;
}

function AdminOrOwnerOnly({ children }: { children: ReactNode }) {
  const { isAdminOrOwner, isSuperAdmin } = useAuth();
  return (isAdminOrOwner || isSuperAdmin) ? <>{children}</> : <Navigate to="/org/members" replace />;
}

function WorkspaceMemberOnly({ children }: { children: ReactNode }) {
  const { allOrgs, isSuperAdmin } = useAuth();
  return (allOrgs.length > 0 || isSuperAdmin) ? <>{children}</> : <Navigate to="/org/sessions" replace />;
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

          {/* Platform Super-Admin Portal */}
          <Route path="platform/orgs" element={<SuperAdminOnly><OrgsPage /></SuperAdminOnly>} />
          <Route path="platform/orgs/:id" element={<SuperAdminOnly><OrgDetailsPage /></SuperAdminOnly>} />
          <Route path="platform/users" element={<SuperAdminOnly><UsersPage /></SuperAdminOnly>} />
          <Route path="platform/health" element={<SuperAdminOnly><HealthPage /></SuperAdminOnly>} />
          <Route path="platform/audit" element={<SuperAdminOnly><AuditPage /></SuperAdminOnly>} />
          <Route path="platform/analytics" element={<SuperAdminOnly><AnalyticsPage /></SuperAdminOnly>} />

          {/* Workspace Team & Governance Portal (Accessible to all roles in org) */}
          <Route path="org/members" element={<WorkspaceMemberOnly><MembersPage /></WorkspaceMemberOnly>} />
          <Route path="org/permissions" element={<WorkspaceMemberOnly><PermissionsPage /></WorkspaceMemberOnly>} />

          {/* Administrative Settings (Admin & Owner only) */}
          <Route path="org/retention" element={<AdminOrOwnerOnly><RetentionPage /></AdminOrOwnerOnly>} />
          <Route path="org/compliance" element={<AdminOrOwnerOnly><CompliancePage /></AdminOrOwnerOnly>} />
          <Route path="org/moderation" element={<AdminOrOwnerOnly><ModerationPage /></AdminOrOwnerOnly>} />
          <Route path="org/billing" element={<AdminOrOwnerOnly><BillingPage /></AdminOrOwnerOnly>} />
          <Route path="org/branding" element={<AdminOrOwnerOnly><BrandingPage /></AdminOrOwnerOnly>} />
          <Route path="org/sso" element={<AdminOrOwnerOnly><SSOConfigPage /></AdminOrOwnerOnly>} />

          {/* Self-Service Account Security (All authenticated users) */}
          <Route path="org/sessions" element={<MySessionsPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
