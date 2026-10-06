---
name: nest-backend
description: Use when adding or changing anything in the backend app `lms-erp/` — a controller, DTO, core service, guard, permission, Prisma model, migration, seed, cron job, or backend test. Triggers: NestJS, Nest module, controller, DTO, Prisma, schema.prisma, DBML, migration, tenant isolation, RequireModule, realm, JWT, QPay, eBarimt, billing/installments, audit log, e2e spec.
---

# nest-backend — `lms-erp/`

NestJS 11 + Prisma 7 + PostgreSQL, everything under `/v1` (URI versioning). All paths below
are relative to `lms-erp/`; prefix them when working from the workspace root.

Deeper references, in the app itself: `README.md` (architecture, auth, billing),
`ASSUMPTIONS.md` (why a decision was made), `school_management_v3.dbml` (schema truth).

## Layering — where code goes

```
src/<surface>/<feature>/<feature>.controllers.ts   thin: validate → call one core service → return
src/<surface>/<feature>/dto/*.dto.ts               class-validator DTOs
src/<surface>/<feature>/<feature>.module.ts        imports the core module, declares controllers
src/core/<domain>/<domain>.service.ts              ALL business logic, tenantId as first arg
src/common/                                        guards, decorators, interceptors, utils
src/prisma/prisma.service.ts                       soft-delete extended client
```

Surfaces: `src/admin/` → `/v1/admin/*`, `src/company/` → `/v1/company/*`, `src/user/` →
`/v1/user/*`. A controller holding an `if` about domain state, or importing `PrismaService`,
is in the wrong layer — move it to `core/`. Two surfaces sharing a core service is correct.

**A new feature module must be added to its surface aggregator** —
`src/<surface>/<surface>-surface.module.ts` — or it is registered in neither `AppModule`
nor the Swagger doc.

## Adding an endpoint — the checklist

1. Core service method in `src/core/<domain>/`, first parameter `tenantId: string`.
2. DTO in the surface feature's `dto/` with class-validator decorators. The global
   `ValidationPipe` runs `whitelist` + `forbidNonWhitelisted`, so an undeclared property is
   a 400 — declare everything you accept.
3. Controller method with **all** required markers (below), plus `@ApiOperation`,
   `@ApiResponse`, `@ApiErrors(...)` so the Swagger doc stays honest.
4. Pull the actor from `@CurrentEmployee()` (or the matching decorator in
   `src/common/decorators/current-actor.decorators.ts`) — never from the request body.
5. Paginated list? Use `PaginationQueryDto` + `pageArgs`/`paginated` from
   `src/common/types/pagination.ts` and return `{ data, meta }`.
6. Cover auth/permission/cross-tenant behavior in `test/*.e2e-spec.ts`; cover money math in
   a `*.spec.ts` next to the service.

## Markers — the guards fail closed

`RealmGuard` then `PermissionsGuard` run globally. A route missing its markers throws a 500
config error rather than being exposed. That is the design; never work around it by making a
route `@Public()`.

- Realm (every route): `@Public()` | `@AdminApi()` | `@CompanyApi()` | `@UserApi()`.
- Company routes also need exactly one of:
  - `@RequireModule('<module_key>', 'view'|'create'|'update'|'delete')` — the normal case;
    `is_admin` (Director) bypasses, everyone else needs the `can_*` flag on their role's
    `role_module_permission` row (missing row = deny, cached ~60s, invalidated on writes),
  - `@RequireAdminRole()` — Director-only (role & permission management),
  - `@AllowAnyEmployee()` — self-service reads that map to no single module.
- `@RequireSuper()` restricts an admin route to `is_super` admins.
- `@Audit('<module_key>')` on the controller records mutations into the append-only
  `employee_log` / `admin_log` with redacted before/after snapshots.

## Tenant isolation — non-negotiable

- `tenant_id` comes from the JWT. Never accept it from a body, query, or path param.
- Every core service filters by `tenantId`; a row from another tenant is **404**, not 403 —
  existence must not leak.
- Parent access to `/v1/user/parent/children/:childId/*` requires a `user_connection` row
  (`ParentAccessGuard`).
- Branch is an authorization boundary within a tenant: Director sees all, every other role
  is scoped to their own branch. Lists, filters, and reports must respect it.
- Realms are isolated by separate secrets **and** `aud` claims — a token from one surface is
  always a 401 on another. Do not add a shared secret or a "trusted" bypass.

## Prisma & the schema

- **`school_management_v3.dbml` is the single source of truth.** `prisma/schema.prisma`
  mirrors it 1:1. Any table/column add, rename, or drop changes the DBML in the same edit.
- `make db-migrate NAME=add_foo` from the workspace root (it guarantees a live database).
  Never hand-edit an applied migration; never `prisma db push` on a migrated database.
  `migrate deploy` does not regenerate the client — run `npx prisma generate` after it.
- Use `PrismaService.db`: reads auto-filter `deleted_at IS NULL` and `delete` becomes a soft
  delete for `Admin`, `Tenant`, `User`, `Employee`. `PrismaService.raw` is only for restore
  flows and genuine hard deletes.
- Connection URLs live in `prisma.config.ts` (CLI) and the driver adapter in
  `src/prisma/prisma.service.ts` (runtime) — **not** in `schema.prisma`, which Prisma 7 no
  longer accepts.

## Money

Integer MNT in `BigInt`. Never `number`, never a float, never `parseFloat`.
`BigIntSerializerInterceptor` renders BigInt as a string in responses; the frontend's `toX`
mappers parse it. Billing math (surcharge → discounts → installments) runs in a single
`$transaction`, with the remainder of integer division landing on the last installment so
the rows sum exactly.

## Env

`src/config/env.validation.ts` (Joi) is the contract; the app refuses to boot on a missing
or malformed value. Add a new variable to `EnvVars`, the schema, and `.env.example`
together. Do not add a default to silence a startup failure — a missing secret should fail.
`.env` itself is deny-listed; read `.env.example`.

## Checks

```bash
cd lms-erp && yarn lint && yarn build && npx prisma validate && yarn test
yarn test:e2e     # boots embedded Postgres; run for auth/permission/isolation changes
```
