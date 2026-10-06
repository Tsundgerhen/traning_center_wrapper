---
name: api-layer
description: Use when calling the API from a component or page, fetching/mutating data, or handling an API error in the frontend app `lms-erp-tenant/`. Covers its lib/api/*, hooks/use-api.ts, and app/api/[...path]/route.ts. For the NestJS side of an endpoint, use the nest-backend skill instead.
---

# API layer (frontend)

The **client side** of the wire, in `lms-erp-tenant/`. Every path below is relative to that
app — prefix it when working from the workspace root. The endpoint itself (controller, DTO,
core service, permissions) lives in `lms-erp/`; see the **nest-backend** skill. When adding
an endpoint, build the backend first, then write the `BackendX` type and `toX` mapper here
against the real response.

Full reference: `lms-erp-tenant/docs/api-layer.md`. This is the short version.

## The one rule

Components never call `fetch` directly. They call a function from a resource module in
`lib/api/` (e.g. `lib/api/students.ts`). That module calls `http.get/post/put/patch/del`
from `lib/api/http.ts`, which hits same-origin `/api/...`. The catch-all route handler
`app/api/[...path]/route.ts` (backed by `lib/api/proxy.ts`) forwards that to the NestJS
backend at `/v1/...` and attaches the access token server-side. The browser never sees a
token or the backend's URL.

`app/api/auth/{login,register,refresh,logout}/route.ts` are the one exception — they set
cookies directly, so they're their own route handlers, not proxied.

## Add an endpoint

Copy `lib/api/students.ts`, rename `students` to your resource, change the paths, add
request/response types to `lib/api/types.ts`:

```ts
import { http } from "./http";
import { query } from "./query";
import type { List, Student, StudentFilter, StudentInput } from "./types";

export const students = {
  list: (filter: StudentFilter = {}) =>
    http.get<List<Student>>(`/students${query(filter)}`),
  get: (id: string) => http.get<Student>(`/students/${id}`),
  create: (input: StudentInput) => http.post<Student>("/students", input),
  update: (id: string, input: Partial<StudentInput>) =>
    http.patch<Student>(`/students/${id}`, input),
  remove: (id: string) => http.del<void>(`/students/${id}`),
};
```

That's it — five lines. No route handler to write; the catch-all already forwards it.

## Call it from a component

```tsx
// read, refetches when deps change
const list = useApiQuery(() => students.list({ page, size: 20 }), [page]);
list.status; // "idle" | "loading" | "success" | "error"
list.data; // List<Student> | null

// action, call explicitly
const create = useApi(students.create);
const created = await create.run(input); // data, or null on failure — never throws
```

Both from `@/hooks/use-api`.

## Errors

Every non-2xx response throws/returns an `ApiError` (`.status`, `.messages` from the
backend). For user-facing text, use `errorKey(error)` from `@/lib/api/errors` with the
`errors` i18n namespace: `te(errorKey(error))`. Add new cases there, not as inline
`if (status === ...)` checks in components.

## What not to do

- No `fetch()` in components — go through a resource module.
- No `BACKEND_API_URL` or token access in client code.
- No `cache: "force-cache"` on an authenticated backend request (see `docs/api-layer.md`).
- No hand-rolled `page + 1` — that's what `query()` in `lib/api/query.ts` does.
