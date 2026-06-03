// Wire types — keys are snake_case to match the Vapor backend's JSON encoder.

export type UserRole = "guest" | "viewer" | "member" | "manager" | "admin" | "owner";

export interface ApiEnvelope<T> {
  success: boolean;
  data?: T;
  error?: { code: string; message: string; details?: string | null };
}

export interface AdminUserSelf {
  id: string;
  email: string;
  display_name: string;
  role: UserRole;
  is_super_admin?: boolean | null;
  created_at?: string | null;
  updated_at?: string | null;
}

export interface AdminOrgSummary {
  id: string;
  name: string;
  slug: string;
  role: UserRole;
}

export interface AdminMeResponse {
  user: AdminUserSelf;
  is_super_admin: boolean;
  admin_orgs: AdminOrgSummary[];
}

// ---- Super-admin platform ----

export interface AdminOrg {
  id: string;
  name: string;
  slug: string;
  status: string; // "active" | "suspended"
  owner_id: string;
  owner_email?: string | null;
  member_count: number;
  message_count: number;
  retention_days?: number | null;
  created_at?: string | null;
}

export interface AdminUser {
  id: string;
  email: string;
  display_name: string;
  role: UserRole;
  is_super_admin: boolean;
  org_count: number;
  created_at?: string | null;
}

export interface ServerHealth {
  status: string;
  uptime_seconds: number;
  memory_used_mb: number;
  total_connections: number;
  unique_users: number;
  active_channels: number;
  db_latency_ms: number;
  user_count: number;
  org_count: number;
  message_count: number;
  timestamp: string;
}

export interface AuditLog {
  id: string;
  org_id: string;
  user_id: string;
  user_email: string;
  action: string;
  resource_type: string;
  resource_id?: string | null;
  details?: string | null;
  created_at?: string | null;
}

// ---- Org-admin tenant ----

export interface RetentionPolicy {
  retention_days: number | null;
}

export interface ExportDescriptor {
  download_url: string;
  format: string;
  size_bytes: number;
  expires_at: string;
}

export interface ModerationChannel {
  id: string;
  name?: string | null;
  type: string;
  is_private: boolean;
  is_archived: boolean;
  is_locked: boolean;
  member_count: number;
  message_count: number;
  last_message_at?: string | null;
  created_at?: string | null;
}

export interface ModerationMessage {
  id: string;
  conversation_id: string;
  conversation_name?: string | null;
  sender_id: string;
  body: string;
  message_type: string;
  edited_at?: string | null;
  deleted_at?: string | null;
  created_at?: string | null;
}

export interface OrgMember {
  id: string;
  user_id: string;
  org_id: string;
  role: UserRole;
  display_name: string;
  email: string;
  joined_at?: string | null;
}

export interface JoinRequest {
  id: string;
  org_id: string;
  user_id: string;
  display_name: string;
  email: string;
  status: string;
  created_at?: string | null;
}
