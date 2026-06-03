import type { ApiEnvelope } from "../types";

const BASE = "/api";

export class ApiError extends Error {
  status: number;
  code?: string;
  constructor(message: string, status: number, code?: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

interface RequestOptions {
  method?: string;
  body?: unknown;
  /** X-Org-Id header for tenant-scoped (`/admin/org/...`) routes. */
  orgId?: string;
  /** Internal: prevents infinite refresh recursion. */
  _retried?: boolean;
}

let refreshInFlight: Promise<boolean> | null = null;

/** Attempt a single silent session refresh; dedupes concurrent callers. */
async function refreshSession(): Promise<boolean> {
  if (!refreshInFlight) {
    refreshInFlight = fetch(`${BASE}/admin/auth/refresh`, {
      method: "POST",
      credentials: "include",
    })
      .then((r) => r.ok)
      .catch(() => false)
      .finally(() => {
        // Allow the next failure to trigger a fresh refresh.
        setTimeout(() => (refreshInFlight = null), 0);
      });
  }
  return refreshInFlight;
}

async function raw(path: string, opts: RequestOptions): Promise<Response> {
  const headers: Record<string, string> = {};
  if (opts.body !== undefined) headers["Content-Type"] = "application/json";
  if (opts.orgId) headers["X-Org-Id"] = opts.orgId;

  return fetch(`${BASE}${path}`, {
    method: opts.method ?? "GET",
    credentials: "include",
    headers,
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
  });
}

/**
 * Core request: credentialed fetch that transparently refreshes an expired
 * access cookie once (plan §5.2 silent refresh), then unwraps the API envelope.
 */
export async function api<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  let res = await raw(path, opts);

  if (res.status === 401 && !opts._retried && !path.startsWith("/admin/auth")) {
    const refreshed = await refreshSession();
    if (refreshed) {
      res = await raw(path, { ...opts, _retried: true });
    }
  }

  if (res.status === 204) return undefined as T;

  let json: ApiEnvelope<T> | null = null;
  try {
    json = (await res.json()) as ApiEnvelope<T>;
  } catch {
    /* non-JSON body */
  }

  if (!res.ok || (json && json.success === false)) {
    const message = json?.error?.message ?? res.statusText ?? "Request failed";
    throw new ApiError(message, res.status, json?.error?.code);
  }
  return (json?.data ?? (json as unknown)) as T;
}

/** Fetch a tenant export as a Blob (honors X-Org-Id + credentials). */
export async function downloadBlob(path: string, orgId: string): Promise<Blob> {
  const res = await fetch(`${BASE}${path}`, {
    credentials: "include",
    headers: { "X-Org-Id": orgId },
  });
  if (!res.ok) throw new ApiError("Download failed", res.status);
  return res.blob();
}
