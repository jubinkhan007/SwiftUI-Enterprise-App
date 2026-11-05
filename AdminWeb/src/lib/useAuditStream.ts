import { useEffect, useState } from "react";
import type { AuditLog } from "../types";

export interface RawAuditLog {
  id: string;
  org_id?: string;
  orgId?: string;
  user_id?: string;
  userId?: string;
  user_email?: string;
  userEmail?: string;
  action: string;
  resource_type?: string;
  resourceType?: string;
  resource_id?: string | null;
  resourceId?: string | null;
  details?: string | null;
  created_at?: string | null;
  createdAt?: string | null;
}

/** Normalizes both snake_case (/api/admin/audit) and camelCase (/api/organizations/:id/audit-log) rows. */
export function normalizeAuditLog(raw: RawAuditLog): AuditLog {
  return {
    id: raw.id,
    org_id: raw.org_id ?? raw.orgId ?? "",
    user_id: raw.user_id ?? raw.userId ?? "",
    user_email: raw.user_email ?? raw.userEmail ?? "system",
    action: raw.action,
    resource_type: raw.resource_type ?? raw.resourceType ?? "",
    resource_id: (raw.resource_id ?? raw.resourceId) || null,
    details: raw.details || null,
    created_at: raw.created_at ?? raw.createdAt ?? new Date().toISOString(),
  };
}

interface ServerEventEnvelope {
  eventId?: string;
  orgId?: string;
  type?: string;
  entityId?: string;
  updatedAt?: string;
  payload?: Record<string, string>;
}

/**
 * Connects to `/ws?org_id=:orgId` (authenticated via the `admin_access` cookie)
 * and streams live `audit.created` events in real time.
 */
export function useAuditStream(
  orgId: string | undefined,
  onAuditCreated: (entry: AuditLog) => void,
) {
  const [connected, setConnected] = useState(false);
  const [liveCount, setLiveCount] = useState(0);

  useEffect(() => {
    if (!orgId) {
      setConnected(false);
      return;
    }

    let closed = false;
    let ws: WebSocket | null = null;
    let reconnectTimer: number | undefined;

    function connect() {
      if (closed) return;
      const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
      const url = `${proto}//${window.location.host}/ws?org_id=${encodeURIComponent(orgId!)}`;
      ws = new WebSocket(url);

      ws.onopen = () => {
        if (!closed) setConnected(true);
      };

      ws.onmessage = (msg) => {
        try {
          const ev = JSON.parse(msg.data) as ServerEventEnvelope;
          if (ev.type === "audit.created" && ev.payload) {
            const p = ev.payload;
            const entry: AuditLog = {
              id: p.id || ev.entityId || crypto.randomUUID(),
              org_id: p.orgId || ev.orgId || orgId!,
              user_id: p.userId || "",
              user_email: p.userEmail || "system",
              action: p.action || "audit.event",
              resource_type: p.resourceType || "org",
              resource_id: p.resourceId || null,
              details: p.details || null,
              created_at: ev.updatedAt || new Date().toISOString(),
            };
            setLiveCount((c) => c + 1);
            onAuditCreated(entry);
          }
        } catch {
          /* ignore non-JSON frames */
        }
      };

      ws.onclose = () => {
        if (closed) return;
        setConnected(false);
        reconnectTimer = window.setTimeout(connect, 3000);
      };

      ws.onerror = () => {
        ws?.close();
      };
    }

    connect();

    return () => {
      closed = true;
      if (reconnectTimer !== undefined) window.clearTimeout(reconnectTimer);
      ws?.close();
    };
  }, [orgId, onAuditCreated]);

  return { connected, liveCount };
}

