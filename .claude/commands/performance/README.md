# Performance Commands

Performance work across the workspace. **Say which app you are optimizing first** — the two
halves have different costs and different tools:

- **`lms-erp-tenant/`** (Next.js App Router frontend): serialized backend round-trips in
  Server Components, duplicate uncached fetches, `"use client"` placed too high in the
  tree, bundle weight. Prefer the `performance-auditor` agent for a specific change.
  Numbers come from `npm run build` (per-route First Load JS) and, in the browser,
  Lighthouse or the React DevTools Profiler.
- **`lms-erp/`** (NestJS + Prisma backend): N+1 queries, missing indexes on newly hot
  filters and sorts, over-fetching `include`s, work done per-row that belongs in one query,
  oversized transactions, cron jobs that scan whole tables. Prefer the `backend-auditor`
  agent, which covers these alongside correctness. Numbers come from Prisma query logs and
  `EXPLAIN ANALYZE` against the dev database (`make db` / port 5433).

Do not report a database finding against the frontend or a bundle finding against the
backend — neither layer exists there.

## Available Commands

- **performance-audit.md** — broad performance assessment
- **optimize-bundle-size.md** — reduce client bundle size (frontend only)
- **optimize-build.md** — speed up the build

All three are generic full-stack templates. There is no Redis, CDN config, APM, or load-test
harness in either app; skip steps that assume one, and do not propose adding infrastructure
unprompted.
