# Security Commands

Security analysis across the workspace. **Say which app you are auditing first** — the real
attack surface is almost entirely on the backend:

- **`lms-erp/`** (NestJS + Prisma): tenant isolation (`tenant_id` from the JWT only,
  cross-tenant reads must 404), the fail-closed guard markers
  (`@RequireModule` / `@RequireAdminRole` / `@AllowAnyEmployee`, realm decorators), per-realm
  JWT secrets and `aud` claims, public QPay/eBarimt callbacks and their HMAC tokens,
  AES-256-GCM tenant credentials, DTO validation, secret handling and log redaction, the
  append-only audit trail. Prefer the `backend-auditor` agent for a specific change.
- **`lms-erp-tenant/`** (Next.js): `server-only` modules leaking into the client bundle,
  httpOnly cookie handling in `app/api/auth/*`, the `app/api/[...path]` proxy, and
  permission-driven UI. Prefer the `security-auditor` agent. There is no database, ORM, or
  SQL here — SQL injection and connection-string findings belong to the backend or nowhere.

The frontend hiding a button is never enforcement; authorization is `PermissionsGuard`'s job
on the backend. A finding that a UI check can be bypassed is only real if the backend route
also lacks its marker.

## Available Commands

- **security-audit.md** — broad security assessment of the codebase
- **dependency-audit.md** — audit dependencies for known vulnerabilities
  (`cd lms-erp && yarn npm audit` · `cd lms-erp-tenant && npm audit`)

Both are generic full-stack templates; map each step onto the app you are actually in, and
skip infrastructure/compliance steps neither app owns.
