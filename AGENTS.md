# training_center — Bilig LMS ERP (one backend, three web clients)

One workspace, **four independent applications, each with its own git repo**:

| Path              | App                        | Realm → routes               | Stack                                   | Pkg mgr    |
| ----------------- | -------------------------- | ---------------------------- | --------------------------------------- | ---------- |
| `lms-erp/`        | Backend API                | serves all three             | NestJS 11 · Prisma 7 · PostgreSQL       | **yarn 4** |
| `lms-erp-tenant/` | Tenant web (center staff)  | `employee` → `/v1/company/*` | Next.js 16 · next-intl · shadcn         | **npm**    |
| `lms-erp-admin/`  | Admin web (Bilig staff)    | `admin` → `/v1/admin/*`      | Next.js 16 · shadcn · Vitest/Playwright | **npm**    |
| `bilig_user_web/` | Student & parent web       | `user` → `/v1/user/*`        | Next.js 16 · OpenAPI-generated zod      | **npm**    |

The workspace root is a **separate wrapper git repo** with no `package.json`. It holds this
file, the `.claude/` rules, and a `Makefile` that orchestrates the apps, and it tracks
**only** those setup files: its `.gitignore` whitelists them and ignores every app folder.
`git` run from the root commits workspace setup, never app code — to commit app changes,
`cd` into the app first, and never assume a change in one app lands in another's commit.

Product: multi-tenant SaaS for training centers in Mongolia — organization, branches,
classes, students, attendance, assessment, billing (QPay + eBarimt), reports. Bilig's own
staff run plans/subscriptions/invoices for tenants from the admin web; students and parents
use the user web (the browser form of the `bilig_mobile` Flutter app).

## Which app am I in?

Decide before writing code — the four apps have different, sometimes opposite, rules.

- Touching data, schema, permissions, money math, cron, tokens → **backend** (`lms-erp/`).
- Screens for tenant staff (branches, classes, students, attendance, billing) →
  `lms-erp-tenant/`.
- Screens for Bilig platform staff (tenants, plans, subscriptions, invoices, discounts) →
  `lms-erp-admin/`.
- Screens for students or parents (tasks, grades, attendance, schedule, pay, inbox) →
  `bilig_user_web/`.
- "Add an endpoint" almost always means **backend + one client**. Pick the surface by who
  calls it (`company/`, `admin/`, `user/`), build the controller + core service first, then
  the client — every client's mapper/schema is written against the real wire shape, not a
  guess.

Each app keeps its own detailed docs; read them before editing that app:

- `lms-erp/README.md` — architecture, surfaces, auth, billing flow, operational notes.
- `lms-erp/ASSUMPTIONS.md` — every design decision and gap-fill made against the spec.
- `lms-erp/school_management_v3.dbml` — **the schema's source of truth**.
- `lms-erp-tenant/AGENTS.md` — the tenant web's full rulebook.
- `lms-erp-tenant/docs/api-layer.md` — the tenant web's client-side API layer in detail.
- `lms-erp-admin/AGENTS.md` — the admin web's shape and its two-layer test setup.
- `bilig_user_web/README.md` — the user web's layout, mobile→web decisions, design tokens.
  Its "UI only / fixture data" framing is **stale**: the app is wired to the real API now
  (`src/lib/api/`), and `src/lib/data*.ts` no longer exists. Trust the code.

Every frontend's `AGENTS.md` starts with a `<!-- BEGIN:nextjs-agent-rules -->` block
written by `next dev` — leave it alone. It means what it says: this Next.js version differs
from training data, so consult that app's `node_modules/next/dist/docs/` rather than
recalling APIs (e.g. `middleware.ts` is now `proxy.ts`).

## Commands

Prefer the root `Makefile` — it starts embedded Postgres, waits for it, and frees stale
ports first. `make help` lists everything.

```bash
make dev          # backend + tenant web, one terminal, Ctrl+C kills all
make dev-all      # backend + tenant + admin + user webs
make backend      # db + prisma studio + API only
make tenant       # tenant web only  |  make admin  # admin web  |  make user  # user web
make stop         # free every dev port (postgres keeps running; make db-stop ends it)
make db-migrate NAME=add_foo   # prisma migrate dev, with a guaranteed-live db
make db-reset                  # drop → migrate deploy → generate → seed
make install / build / lint    # all four apps
```

Ports (dev): tenant web **3000**, user web **3001**, admin web **3002**, API **3003**,
prisma studio **5555**, dev Postgres **5433**. `next dev` defaults to 3000, so the admin
and user webs must be started with `-p` (the Makefile does this).

How each client reaches the backend — all three are server-side (BFF), the browser never
sees a token or the API address:

| App               | Env var           | Value shape                        | Transport for client-side writes          |
| ----------------- | ----------------- | ---------------------------------- | ----------------------------------------- |
| `lms-erp-tenant/` | `BACKEND_API_URL` | no `/v1` (added by `serverGet`)    | `/api/[...path]` proxy                    |
| `lms-erp-admin/`  | `BACKEND_API_URL` | no `/v1` (added by `serverGet`)    | `/api/[...path]` proxy                    |
| `bilig_user_web/` | `API_BASE_URL`    | **includes** `/v1`, no trailing `/` | Server Actions (no route handlers at all) |

**Chat is the one exception.** A WebSocket cannot go through a BFF proxy or a Server
Action, so the tenant and user webs pass `CHAT_SOCKET_URL` (the API's public origin) to the
browser, which opens a receive-only Socket.IO connection to it. It still never sees a token:
each connection presents a single-use 60-second ticket the BFF obtained from
`POST …/chat/socket-ticket`. Sending stays on the normal transport (proxy / Server Actions).
The API's `CORS_ORIGINS` must list both web origins for the socket handshake. See
`lms-erp/README.md#chat`.

Some defaults inside the newer apps still assume the backend is on 3000 — the admin
web's `AGENTS.md`/e2e helpers and `bilig_user_web/scripts/verify-contract.mts`
(`http://localhost:3000/v1`). Point them at **3003** through env. The admin web's
`playwright.config.ts` starts its own `next dev` on **3003** too, which collides with a
running API — stop the API or change that port before `npm run test:e2e`.

Per app, when the Makefile is overkill:

```bash
cd lms-erp        && yarn start:dev | yarn lint | yarn build | yarn test | yarn test:e2e
cd lms-erp-tenant && npm run dev | lint | typecheck | format | build
cd lms-erp-admin  && npm run dev -- -p 3002 | lint | build | test | test:e2e
cd bilig_user_web && npm run dev -- -p 3001 | lint | typecheck | build
                  && npm run check:i18n | check:forms | check:icons | api:types | verify:contract
```

Test runners differ per app — do not assume one app's setup in another:

- `lms-erp/` — jest unit (`yarn test`) + e2e on embedded Postgres (`yarn test:e2e`). Add and
  run them.
- `lms-erp-tenant/` — **no test runner at all**. Never report "missing tests" there, never
  propose adding one unprompted.
- `lms-erp-admin/` — Vitest + RTL (`npm test`, pure logic and isolated client components)
  and Playwright (`npm run test:e2e`, against the **real** running backend and seeded admin).
  New mapper/zod/format logic gets a `*.test.ts` next to it.
- `bilig_user_web/` — no unit runner; its guard rails are `typecheck` plus the `check:*`
  scripts and `verify:contract` (parses live API responses against the generated schemas).
  Run the `check:*` scripts relevant to your change; don't propose a test framework unprompted.

`.env` files are secrets and are deny-listed (`.env.example` is caught by the same rule —
ask the user if you need a variable's name). Each app validates its env at boot; do not add
defaults to "fix" a startup error.

---

# Backend — `lms-erp/`

NestJS 11, Prisma 7 with a driver adapter, PostgreSQL, Joi-validated env, URI versioning
(everything is served under `/v1`). Boot fails loudly on a missing or malformed env var —
that is intentional, do not add defaults to `src/config/env.validation.ts` to "fix" a
startup error.

## Three realms, three surfaces

| Surface       | Routes          | Swagger        | Token realm | Who                |
| ------------- | --------------- | -------------- | ----------- | ------------------ |
| `src/admin/`  | `/v1/admin/*`   | `/docs/admin`  | `admin`     | platform staff     |
| `src/company/`| `/v1/company/*` | `/docs/company`| `employee`  | tenant staff       |
| `src/user/`   | `/v1/user/*`    | `/docs/user`   | `user`      | students & parents |

Separate JWT secrets **and** `aud` claims per realm: a token from one realm is always a 401
on another. Each surface folder has a `*-surface.module.ts` aggregator that `AppModule`
imports and Swagger uses as its include-filter — a new feature module must be added there
or it exists in neither.

## Layering (hard rule)

```
src/<surface>/<feature>/   thin controller + dto/  — no business logic
src/core/<domain>/         ALL business logic, as services taking tenantId first
src/common/                guards, decorators, interceptors, filters, strategies, utils
src/prisma/                PrismaService (soft-delete client extension)
```

A controller validates, pulls the actor from the JWT, calls one core service, returns.
If a controller contains an `if` about domain state or touches `PrismaService`, it is in
the wrong layer. Two surfaces calling the same core service is normal and correct — that is
why `core/` exists.

## Auth & authorization markers (fail closed)

`RealmGuard` and `PermissionsGuard` are global. Every route must carry markers or it is
denied — that is the design, not a bug to route around.

- Every controller/route: `@Public()` **or** one of `@AdminApi()` / `@CompanyApi()` /
  `@UserApi()`. Unmarked → 500 "Route is not attached to an auth realm".
- Every **company** route additionally: `@RequireModule('branches', 'view')` **or**
  `@RequireAdminRole()` (Director-only, role/permission management) **or**
  `@AllowAnyEmployee()` (self-service reads). None of the three → denied.
- `@Audit('<module_key>')` on mutating company/admin controllers feeds the append-only
  `employee_log` / `admin_log` via `AuditInterceptor`.
- Get the actor from `@CurrentEmployee()` / the matching decorator in
  `src/common/decorators/current-actor.decorators.ts`.

**`tenant_id` always comes from the JWT, never from the client body, query, or path.**
Every core service takes `tenantId` as its first argument and filters on it. A row from
another tenant is a **404**, never a 403 — do not leak existence. Parent access to
`/v1/user/parent/children/:childId/*` requires a `user_connection` row (`ParentAccessGuard`).

Branch is an authorization boundary inside a tenant: a Director sees all branches, every
other role is scoped to their own. Any list, filter, or report must respect that.

## Database

- **`school_management_v3.dbml` is the single source of truth.** `prisma/schema.prisma`
  mirrors it 1:1. Never add, rename, or drop a table or column in `schema.prisma` without
  changing the DBML in the same edit — and say so in the summary.
- Migrations: `make db-migrate NAME=...`. Never hand-edit an applied migration, never
  `prisma db push` against a migrated database. `prisma migrate deploy` does **not**
  regenerate the client — run `npx prisma generate` (or `make db-deploy`) after it.
- Money is **`BigInt`, integer MNT — never a float, never `Number`**. Responses serialize
  BigInt to strings via `BigIntSerializerInterceptor`; the frontend's mappers parse them.
- Use `PrismaService.db` (soft-delete extension: reads auto-filter `deleted_at IS NULL`,
  `delete` becomes an update — `Admin`, `Tenant`, `User`, `Employee` only). `PrismaService.raw`
  is the escape hatch for restore flows and hard deletes; reaching for it in ordinary CRUD
  is a bug.
- Multi-step writes (billing → installments, payment → allocation → rollup) go in **one**
  `$transaction`. Discount `used_count` increments atomically.
- Audit logs are append-only. Nothing updates or deletes a log row.

## Tests

`yarn test` (jest, `src/**/*.spec.ts`) covers installment math, discounts, and
`PermissionsGuard`. `yarn test:e2e` (`test/*.e2e-spec.ts`) boots embedded Postgres and
exercises the real pipeline from `configure-app` — login/refresh rotation, the cross-realm
rejection matrix, tenant isolation, registration, the parent guard. New auth, permission, or
cross-tenant behavior belongs in the e2e suite; new money math belongs in a unit spec.

## Before committing (backend)

```bash
cd lms-erp && yarn lint && yarn build && npx prisma validate && yarn test
```

---

# Tenant web — `lms-erp-tenant/`

For training-center staff; `employee` realm, `/v1/company/*`.
**Read `lms-erp-tenant/AGENTS.md` before writing tenant-web code** — it is the authority and
carries the details this summary compresses. Its first block is written by `next dev`:
this Next.js version differs from training data, so consult
`lms-erp-tenant/node_modules/next/dist/docs/` rather than recalling APIs.

Frontend only: no database, no ORM, no migrations, no server business logic. The only server
code is `app/api/auth/*` (cookie handling) and the `app/api/[...path]` proxy.

The rules that break a build or a release when ignored:

- **Server Components by default.** `"use client"` only for state, effects, or handlers, and
  on the leaf component — never on `page.tsx`. `params` and `searchParams` are Promises.
- **Data fetching lives in the route's `_lib/data-fetching.ts`**, which calls `serverGet`
  from `lib/api/backend.ts` with a full `/company/...` path and maps via that resource's
  `toX`. `page.tsx` composes and passes props; independent reads share one `Promise.all`.
- **No component calls `fetch`.** Client components call the resource object in
  `lib/api/<resource>.ts` (bound to `lib/api/http.ts`) through `useApi` / `useApiToast` /
  `useApiQuery`; that hits same-origin `/api/...` and the proxy attaches the token. The
  browser never sees a token or the backend URL. Do not add route handlers under `app/api/`
  beyond the existing auth ones.
- **No hardcoded user-facing string** — including placeholders, `aria-label`s, and toasts.
  Everything goes in `i18n/dictionary/en/*.json` **and** `mn/*.json` (default locale `mn`),
  and a new namespace must be registered by hand in `i18n/request.ts`.
- **Navigate with `Link` / `useRouter` / `redirect` / `usePathname` from `@/i18n/navigation`**,
  never `next/link` or `next/navigation`; `href` omits the locale segment.
- **UI is shadcn `base-nova` over `@base-ui/react`, not Radix** — use the `shadcn` skill.
  Tailwind v4, semantic tokens only, no `tailwind.config.js`.
- All components live in top-level `components/` (`ui/`, `shared/`, `<feature>/`), never
  inline in `app/`.
- Code, comments, identifiers, and commit messages are **English**; only dictionary values
  are Mongolian.

## Before committing (tenant web)

```bash
cd lms-erp-tenant && npm run format && npm run lint && npm run typecheck
```

Lefthook runs Prettier + `eslint --fix` on staged files and `npm run typecheck` on push.
Known issue: `components/ui/*.tsx` is shadcn CLI output without semicolons against a
`"semi": true` Prettier config, so `format:check` flags it — pre-existing, do not reformat.

---

# Admin web — `lms-erp-admin/`

Internal operations tool for **Bilig's own platform staff**: tenants, plans, billing
intervals, subscriptions, invoices, campaign discounts. Talks only to the `admin` realm
(`POST /v1/auth/admin/*` for login, `/v1/admin/*` for data; Swagger `/docs/admin`). Read
`lms-erp-admin/AGENTS.md` first.

Same skeleton as the tenant web — so most tenant habits carry over — with these differences:

- **Same:** frontend only; server code is just `app/api/auth/*` (login/logout/refresh cookies)
  and the `app/api/[...path]/route.ts` proxy. Server Components read through
  `lib/api/backend.ts#serverGet` from the route's `_lib/data-fetching.ts` with a full
  `/admin/...` path; client components write through `lib/api/http.ts` via
  `hooks/use-api.ts`; one `lib/api/<resource>.ts` per resource holds the `BackendX` type,
  `toX` mapper and write object. Routes live under `app/(admin)/`. Components in top-level
  `components/`, never in `app/`. shadcn-style `components/ui/*` over `@base-ui/react`
  (not Radix), Tailwind v4. Forms are react-hook-form + zod (`lib/forms.ts`).
- **No i18n framework.** Mongolian-only; UI strings are written in Mongolian directly in the
  component. Do **not** introduce next-intl or dictionaries here, and do not flag inline
  strings as a violation. Code, comments, identifiers stay English.
- **Plain Next navigation** — `next/link` / `next/navigation` are correct here (there is no
  `@/i18n/navigation`).
- **It has tests** (see Commands). A new mapper, query builder, zod schema, or formatter
  gets a colocated `*.test.ts`; a new page flow can get a Playwright spec in `e2e/` that runs
  against the real backend. Subscriptions and invoices have no delete endpoint — e2e drives
  them to a terminal status instead of cleaning up.
- No `components.json`, no Prettier script, no Lefthook — `npx shadcn add` needs care.

## Before committing (admin web)

```bash
cd lms-erp-admin && npm run lint && npm test && npm run build
```

---

# User web — `bilig_user_web/`

Students and parents, in the browser — the web form of the `bilig_mobile` Flutter app,
routes mirroring its router path for path. Talks only to the `user` realm
(`/v1/auth/user/*`, `/v1/user/*`; Swagger `/docs/user`). Architecturally it is the
**odd one out**: do not copy tenant/admin patterns into it, or its patterns out of it.

- **Layout:** everything under `src/` (`@/` → `src/`). Routes: `src/app/student/*`,
  `src/app/parent/*`, plus `login`, `forgot-password`, `change-password`, `terms`,
  `select-workspace` outside both shells. Components in `src/components/`
  (`ui/`, `shell/`, `navigation/`, `student/`, `parent/`, `shared/`, `auth/`).
- **Contract is generated, never hand-written.** `src/lib/api/generated/` (`types.gen.ts`,
  `zod.gen.ts`) comes from the backend's OpenAPI via `npm run api:types`, which runs
  `../lms-erp/scripts/emit-openapi.mjs` (needs the sibling checkout) then `openapi-ts`.
  Never edit `generated/` or `openapi-user-api.json` by hand — change the Nest DTO,
  regenerate. `npm run verify:contract -- <student> <parent> [password]` then parses live
  responses against those schemas (read-only GETs).
- **Reads:** Server Components call `apiFetch(path, zSchema)` from `src/lib/api/fetch.ts`
  (through the domain modules `user.ts` / `parent.ts` / `child.ts` / `workspace.ts`).
  Every response is zod-parsed at the boundary; a mismatch is a thrown 502, not an `any`.
  Default `cache: "no-store"` — this is one person's own data; only cache with explicit
  `tags`. Shaping for the UI lives in `src/lib/view/*`.
- **Writes are Server Actions**, not a proxy: `src/lib/api/actions.ts` (and
  `lib/auth/actions.ts`, `lib/i18n/actions.ts`), inputs validated with
  `src/lib/forms/schemas.ts` via `parseForm`/`parseInput`, returning an `ActionResult`
  (`action-result.ts`), then `revalidatePath`. A `"use server"` module may export only
  async functions. There are **no route handlers under `/api`** — don't add one without
  handling token refresh inside it (see `proxy.ts`'s matcher comment).
- **Auth:** the session is an encrypted cookie (jose, A256GCM, `SESSION_SECRET`) holding
  both tokens — `src/lib/session.ts`, `src/lib/auth/session.ts`. `src/proxy.ts` is the
  optimistic route gate (role → `/student` or `/parent`, ordered account gates:
  change-password → terms → home) **and the only place a rotated token pair may be
  persisted**. Refresh there is single-flight and skipped for prefetches; never refresh
  from a Server Component or retry a refresh — the backend rotates refresh tokens and a
  replay signs the user out.
- **i18n is home-grown, not next-intl.** Strings live in `src/lib/i18n/messages.ts` as
  typed `en` and `mn` objects (a key in one and not the other is a compile error); read them
  with `getT()` (`lib/i18n/server.ts`) / `t()`, plurals via `_one`/`_other` + `t.plural()`.
  Locale is a cookie (`bilig_locale`), no URL segment, `DEFAULT_LOCALE` is `en`. Dates and
  numbers come from `Intl` via `src/lib/format.ts`, never hand-written tables. Mongolian is
  lifted from the mobile app's `app_mn.arb`; new mn strings are marked `REVIEW`. No
  hardcoded user-facing strings — run `npm run check:i18n` after touching messages.
- **UI is a hand-ported widget library** (`src/components/ui/`), **not shadcn, not
  base-ui** — the shadcn skill does not apply here. Tokens are all in
  `src/app/globals.css`; colour is taken by **role** (`info`/`success`/`warning`/`danger`/
  `violet`/`neutral`) via `src/lib/roles.ts`, never by hex. Three layouts (390 / 834 /
  1440), not one that shrinks.
- **Navigation:** plain `next/link` / `next/navigation` (no locale segment), but links
  inside the student/parent shells go through `ScopedLink` / `useScopedHref`
  (`src/components/navigation/scoped-link.tsx`) so the active scope — `?tenant=` for a
  student, `?child=` for a parent — travels with them. A bare `Link` there drops the
  selection.
- Parent data is never merged across schools; one QPay invoice settles one bill; quiz
  results show only the server's aggregate — see the README's "Notes for when the API
  lands" for the product rules the screens encode.

## Before committing (user web)

```bash
cd bilig_user_web && npm run lint && npm run typecheck && npm run check:i18n \
  && npm run check:forms && npm run check:icons
```

---

## Which tool applies to which app

The `.claude/` agents and skills were written for the original two apps. Their
descriptions name the app they cover — respect that:

| App               | Skills                          | Review agents                                                        |
| ----------------- | ------------------------------- | -------------------------------------------------------------------- |
| `lms-erp/`        | `nest-backend`                  | `backend-auditor`                                                    |
| `lms-erp-tenant/` | `shadcn`, `api-layer`           | `code-auditor`, `security-auditor`, `performance-auditor`            |
| `lms-erp-admin/`  | `shadcn` (UI parts only)        | none dedicated — review against the Admin web section above          |
| `bilig_user_web/` | none                            | none dedicated — review against the User web section above           |

Do not run the tenant auditors' rules (next-intl, `@/i18n/navigation`, dictionaries) against
the admin or user web — they would flag correct code. `jse-code-review` is diff-based and
works in any of the four repos.

## Cross-cutting

- **The wire contract is the backend's.** When a response shape changes in `lms-erp/`,
  update the consuming client in the same session, and check that surface's Swagger doc
  rather than guessing:
  - `/v1/company/*` → `lms-erp-tenant/lib/api/<resource>.ts` (`BackendX` + `toX`), `/docs/company`.
  - `/v1/admin/*` → `lms-erp-admin/lib/api/<resource>.ts` (+ its `*.test.ts`), `/docs/admin`.
  - `/v1/user/*` or `/v1/auth/user/*` → `cd bilig_user_web && npm run api:types`, fix what
    `typecheck` breaks, then `verify:contract` against a running API. `/docs/user`.
- **Realms are hard walls.** Each web holds tokens for exactly one realm; never call another
  realm's routes from it (a cross-realm token is always a 401 by design).
- No client checks permissions for real — `PermissionsGuard`, `RealmGuard` and
  `ParentAccessGuard` on the backend do. A UI that hides a button, and the user web's
  `proxy.ts` role gate, are conveniences, never the enforcement.
- Money arrives as **strings** (serialized BigInt). Every client parses them in its
  mapper/schema; never do money math in a `Number`.
- Four repos, separate commits. State clearly which app each change landed in.
- `lms-erp-tenant/constants/routes.ts` is stale — verify routes against `app/`.
- `NEXT_PUBLIC_API_URL` appears in the tenant web's `.env.example` and README but is read by
  no code; `BACKEND_API_URL` is the real variable.
