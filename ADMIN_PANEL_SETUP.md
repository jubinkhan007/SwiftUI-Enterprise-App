# Enterprise Web Admin Panel — Setup & Deployment

A React + Vite + TypeScript single-page admin console for the platform, backed by
cookie-session routes on the existing Vapor server. It serves two portals:

- **Super Admin** (platform owner): organization directory, global user management,
  live server health, and a platform-wide audit trail.
- **Org Admin** (tenant admin/owner): member management, message retention policy,
  on-demand compliance export, and a channel/message moderation panel.

The web app lives in [`AdminWeb/`](AdminWeb). Backend routes live under `/api/admin/*`.

---

## 1. Architecture

```
Browser (SPA)  ──/api──►  reverse proxy / Vite dev proxy  ──►  Vapor backend
   │  HttpOnly cookies (admin_access 15m, admin_refresh 7d, SameSite=Strict)
   ▼
React Router  ──►  Auth gate (/admin/auth/me)  ──►  Super-Admin | Org-Admin portal
```

- **Auth:** `POST /api/admin/auth/login` verifies credentials and sets two HttpOnly,
  `SameSite=Strict` cookies — a 15-minute access token and a 7-day sliding refresh
  token. The SPA never reads tokens from JS. On a `401`, the API client silently
  calls `POST /api/admin/auth/refresh` once and retries.
- **Super-admin identity:** the `users.is_super_admin` boolean column. Bootstrap it
  with the `SUPER_ADMIN_EMAILS` env allowlist (below) — listed emails are promoted
  on their next admin login. After bootstrap, super-admins can grant/revoke the flag
  for others in the Users page.
- **Tenant isolation:** org-admin routes require the `X-Org-Id` header plus an
  `admin`/`owner` membership in that org (`OrgTenantMiddleware` + `RequireOrgAdminMiddleware`).

---

## 2. Backend environment variables

| Variable             | Required | Purpose                                                                 |
| -------------------- | -------- | ----------------------------------------------------------------------- |
| `SUPER_ADMIN_EMAILS` | for bootstrap | Comma-separated emails auto-promoted to super-admin on admin login. e.g. `ops@acme.com,cto@acme.com` |
| `JWT_SECRET`         | prod     | HMAC key signing both the mobile JWTs and the admin cookie tokens. Use a long random value in production. |
| `DATABASE_PATH`      | optional | SQLite path (defaults: `enterprise_app.db` on macOS, `/data/...` on Linux). |

Cookies are flagged `Secure` automatically when the app runs in the `production`
environment (`--env production`), so production **must** be served over HTTPS.

### Bootstrap the first super-admin

```bash
# 1. Register the account normally (mobile app or curl)
curl -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"ops@acme.com","password":"<strong>","displayName":"Ops"}'

# 2. Start the backend with the allowlist
SUPER_ADMIN_EMAILS="ops@acme.com" JWT_SECRET="<random>" swift run App serve

# 3. Log into the admin panel — the account is promoted on first admin login.
```

---

## 3. Local development

Two processes: the Vapor backend and the Vite dev server. Vite proxies `/api` to the
backend, keeping the SPA and API **same-origin** so `SameSite=Strict` cookies are sent.

```bash
# Terminal 1 — backend (port 8080)
cd Backend
SUPER_ADMIN_EMAILS="ops@acme.com" swift run App serve --hostname 127.0.0.1 --port 8080

# Terminal 2 — admin web (port 5173, proxies /api -> 8080)
cd AdminWeb
npm install
npm run dev
# open http://localhost:5173
```

Point Vite at a different backend with `ADMIN_API_PROXY`:

```bash
ADMIN_API_PROXY=http://127.0.0.1:9000 npm run dev
```

---

## 4. Production build & deployment

```bash
cd AdminWeb
npm install
npm run build      # tsc typecheck + vite build -> AdminWeb/dist/
```

Serve `AdminWeb/dist/` as static files behind a reverse proxy that also forwards
`/api` to the Vapor backend on the **same origin** (so cookies stay first-party).

### Example nginx

```nginx
server {
    listen 443 ssl;
    server_name admin.acme.com;
    # ssl_certificate ... ; ssl_certificate_key ... ;

    root /var/www/admin-web/dist;
    index index.html;

    # SPA history fallback
    location / {
        try_files $uri /index.html;
    }

    # Same-origin API — keeps SameSite=Strict session cookies first-party
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

> If you must serve the SPA on a different origin than the API, the backend already
> sends credentialed CORS (`Access-Control-Allow-Credentials: true`, origin-reflected).
> However, `SameSite=Strict` cookies are not sent on cross-site requests — for a
> cross-origin deployment, relax the cookie to `SameSite=None; Secure` in
> `AdminSession.attachCookies` (Backend/Sources/App/Middleware/AdminAuthMiddleware.swift).

---

## 5. Compliance export & retention

- **Export:** `POST /api/admin/org/export?format=json|csv` writes a file to the server
  temp dir and returns a 10-minute signed download link
  (`/api/admin/org/export/download?token=<jwt>`). The SPA fetches it as a credentialed
  blob and triggers a browser download. For large-scale / durable exports, swap the
  temp-file step for S3 + a pre-signed S3 URL (the descriptor shape already matches).
- **Retention:** `organizations.retention_days` (nil = indefinite). The
  `RetentionPurgeRunner` (hourly) permanently deletes messages older than the window;
  "Purge now" runs the same logic on demand.

---

## 6. Endpoint reference

**Auth** — `POST /api/admin/auth/{login,refresh,logout}`, `GET /api/admin/auth/me`

**Super-admin** (`/api/admin`, super-admin only):
`GET/POST orgs`, `POST orgs/:id/{suspend,activate}`, `DELETE orgs/:id`,
`GET users`, `POST users/:id/reset-password`, `PUT users/:id/{role,super-admin}`,
`GET health`, `GET audit`

**Org-admin** (`/api/admin/org`, requires `X-Org-Id` + admin/owner):
`GET/PUT retention`, `POST retention/purge-now`, `POST export`, `GET export/download`,
`GET members`, `PUT members/:id/role`, `DELETE members/:id`,
`GET join-requests`, `POST join-requests/:id/respond`,
`GET channels`, `POST channels/:id/{archive,lock}`, `DELETE channels/:id`,
`GET moderation/messages`
